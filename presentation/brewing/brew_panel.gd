extends Control
## Demleme ekranı: yakın plan iki raf (kavanozlar), kepenk, makine. Coffee Talk gibi: üst rafta ana
## malzemeler (base), altta ek malzemeler (yalnızca mix), sağda uzun duran serbest malzeme (base + mix: süt). Snapshot okur, EventBus'a komut yollar;
## tat önizlemesini BrewingRules'tan hesaplar. Kavanoz çizimleri: res://assets/ui/ingredients/<id>.png
## Demle'ye basınca seçim ekranı (servis / çöp) çizgi roman sayfasında açılır: bkz. brew_comic.
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const OPEN_X := 780.0
const CLOSED_X := 1940.0
const SLIDE_TIME := 0.4
## Raf yerleşimi (brew_shelf.png'de üst tahta y=240 ve x<840, alt tahta y=450). Kavanoz tahtaya oturur,
## etiketi tahtanın altındadır.
const JAR_SIZE := Vector2(96, 120)
const TALL_SIZE := Vector2(150, 188)
const TOP_BOARD_Y := 240.0
const BOTTOM_BOARD_Y := 450.0
const JAR_FIRST_X := 70.0
const JAR_STEP := 190.0
const TALL_X := 875.0
const TAG_GAP := 8.0
const TAG_HEIGHT := 44.0
const JAR_LIFT := 10.0
## Yan yana iki kavanoz kutusu arasındaki boşluk.
const JAR_GAP := 40.0
var view: Dictionary = {}
var reduced_motion: bool = false
var is_open: bool = false
var shelf_shown: String = ""
var hovered: String = ""
var slide_tween: Tween
var jars: Dictionary = {}
const ROLE_KEYS := {"main": "brew.role_main", "free": "brew.role_free", "extra": "brew.role_extra"}
@onready var machine: Control = $Machine
@onready var shelf_title: Label = $Machine/ShelfTitle
@onready var jar_layer: Control = $Machine/Jars
@onready var shutter: TextureRect = $Machine/Shutter
@onready var hint: Label = $Machine/Hint
@onready var shutter_button: Button = $Machine/ShutterButton
@onready var readout: Control = $Machine/Body/Box/Readout
@onready var preview_liquid: TextureRect = $Machine/Body/Box/Right/CupPreview/Liquid
@onready var reset_button: Button = $Machine/Body/Box/Right/ResetButton
@onready var brew_button: Button = $Machine/Body/Box/Right/BrewButton

func _ready() -> void:
	machine.position.x = CLOSED_X
	machine.hide()
	shutter.size.y = 0.0
	reset_button.text = I18n.t("brew.reset")
	brew_button.text = I18n.t("button.brew")
	shutter_button.pressed.connect(func() -> void: EventBus.request("shelf"))
	reset_button.pressed.connect(func() -> void: EventBus.request("clear"))
	brew_button.pressed.connect(func() -> void: EventBus.request("brew"))

func apply(snapshot: Dictionary) -> void:
	view = snapshot
	var should_open: bool = view.get("started", false) and view.get("stage", "") in ["brewing", "tutorial"]
	_set_open(should_open)
	if not should_open:
		return
	_update_texts()
	if view.shelf != shelf_shown:
		_swap_shelf()
	else:
		_refresh_jars()
	readout.show_slots(view.selected, _ingredient_map())
	_refresh_stats()
	_refresh_buttons()

func select_index(index: int) -> void:
	var items := _shelf_items()
	if index >= 0 and index < items.size():
		EventBus.request("select", {"id": items[index].id})

# --- Güncelleme ----------------------------------------------------------

## Raftaki sıra (1–9 kısayolları da bu sırayı izler): ana malzemeler, serbest malzeme, ek malzemeler.
func _shelf_items() -> Array:
	var items: Array = view.get("ingredients", []).filter(func(item: Dictionary) -> bool: return item.side == view.get("shelf", "human"))
	var ordered: Array = []
	for role: String in ["main", "free", "extra"]:
		ordered.append_array(items.filter(func(item: Dictionary) -> bool: return _role(item) == role))
	return ordered

## main: yalnızca baz (üst raf); free: baz + karışım (sağda, uzun); extra: yalnızca karışım (alt raf).
static func _role(item: Dictionary) -> String:
	var base: bool = item.get("base", false)
	var mix: bool = item.get("mix", false)
	if base and mix:
		return "free"
	return "main" if base else "extra"

func _ingredient_map() -> Dictionary:
	var map := {}
	for item: Dictionary in view.get("ingredients", []):
		map[item.id] = item
	return map

func _update_texts() -> void:
	shelf_title.text = I18n.t("shelf.fallen") if view.shelf == "fallen" else I18n.t("shelf.human")
	var discovery: bool = view.tutorial == "switch_hint"
	shutter_button.text = I18n.t("button.shelf_discovery") if discovery else I18n.t("button.shelf")
	shutter_button.theme_type_variation = &"PrimaryButton" if discovery else &""
	shutter_button.disabled = view.tutorial not in ["switch_hint", "ready"]
	match view.tutorial:
		"book_hint", "tab_seen":
			hint.text = I18n.t("brew.hint_book") if view.stage == "tutorial" else ""
		"switch_hint":
			hint.text = I18n.t("brew.hint_switch")
		_:
			hint.text = ""

func _refresh_jars() -> void:
	var items := _shelf_items()
	if jars.size() != items.size():
		_rebuild_jars()
		return
	var active: bool = view.stage == "brewing" and view.drink.is_empty()
	var map := _ingredient_map()
	for item: Dictionary in items:
		var entry: Dictionary = jars.get(item.id, {})
		if entry.is_empty():
			_rebuild_jars()
			return
		var left: int = int(view.stock.get(item.id, 0)) - view.selected.count(item.id)
		var usable: bool = active and left > 0 and Brewing.can_add(view.selected, item.id, map) == ""
		entry.tag.text = I18n.t("brew.jar_tag", {"name": item.name, "count": left})
		entry.button.disabled = not usable
		entry.button.modulate = Color.WHITE if usable else Color(0.55, 0.52, 0.55)

func _rebuild_jars() -> void:
	for child: Node in jar_layer.get_children():
		child.queue_free()
	jars.clear()
	var items := _shelf_items()
	var row_index := {"main": 0, "extra": 0}
	var row_counts := {}
	for item: Dictionary in items:
		row_counts[_role(item)] = int(row_counts.get(_role(item), 0)) + 1
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var role := _role(item)
		var rect := _jar_rect(role, row_index.get(role, 0), row_counts.get(role, 1))
		if row_index.has(role):
			row_index[role] += 1
		var button := TextureButton.new()
		var icon_path := ICON_PATH % item.id
		if ResourceLoader.exists(icon_path):
			button.texture_normal = load(icon_path)
			rect = _fit_on_board(rect, button.texture_normal)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.position = rect.position
		button.size = rect.size
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "%s · %s  [%d]" % [item.description, I18n.t(ROLE_KEYS[role]), i + 1]
		button.pressed.connect(func() -> void: EventBus.request("select", {"id": item.id}))
		button.mouse_entered.connect(_on_jar_hover.bind(item.id, button, true))
		button.mouse_exited.connect(_on_jar_hover.bind(item.id, button, false))
		jar_layer.add_child(button)
		var tag := Label.new()
		tag.theme_type_variation = &"HudText"
		tag.add_theme_font_size_override("font_size", 24)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var slot := _jar_rect(role, 0, row_counts.get(role, 1))
		var tag_width := _row_step(row_counts.get(role, 1)) if role != "free" else TALL_SIZE.x + 40.0
		tag.position = Vector2(rect.get_center().x - tag_width / 2.0, slot.end.y + TAG_GAP)
		tag.size = Vector2(tag_width, TAG_HEIGHT)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jar_layer.add_child(tag)
		jars[item.id] = {"button": button, "tag": tag, "rest_y": rect.position.y}
	_refresh_jars()

## Kavanozun raftaki kutusu: ana malzemeler üst tahtada, ekler alt tahtada soldan sağa (süte çarpmadan
## sığacak aralıkla); serbest malzeme sağda alt tahtaya oturan uzun kutu.
func _jar_rect(role: String, index: int, count: int) -> Rect2:
	if role == "free":
		return Rect2(Vector2(TALL_X, BOTTOM_BOARD_Y - TALL_SIZE.y), TALL_SIZE)
	var board := TOP_BOARD_Y if role == "main" else BOTTOM_BOARD_Y
	var step := _row_step(count)
	var width := step - JAR_GAP
	return Rect2(Vector2(JAR_FIRST_X + index * step + JAR_GAP / 2.0, board - JAR_SIZE.y), Vector2(width, JAR_SIZE.y))

func _row_step(count: int) -> float:
	return minf(JAR_STEP, (TALL_X - TAG_GAP - JAR_FIRST_X) / maxf(count, 1.0))

## Çizimin görünen kısmı kutuya oranı korunarak sığdırılır; görünen alt kenarı tahtaya oturur, kutuda yatay
## ortalanır. Farklı ölçüdeki çizimler (32×40 yer tutucu, 96×96 tasarım) aynı rafta aynı boyda durur.
func _fit_on_board(box: Rect2, texture: Texture2D) -> Rect2:
	var used := texture.get_image().get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return box
	var scale := minf(box.size.x / used.size.x, box.size.y / used.size.y)
	var size := texture.get_size() * scale
	var visible_center_x := (used.position.x + used.size.x / 2.0) * scale
	var visible_bottom := (used.position.y + used.size.y) * scale
	return Rect2(Vector2(box.get_center().x - visible_center_x, box.end.y - visible_bottom), size)

func _on_jar_hover(id: String, button: TextureButton, entered: bool) -> void:
	hovered = id if entered else ""
	_refresh_stats()
	var rest: float = jars.get(id, {}).get("rest_y", button.position.y)
	if reduced_motion or button.disabled:
		button.position.y = rest
		return
	create_tween().tween_property(button, "position:y", rest - (JAR_LIFT if entered else 0.0), 0.08)

func _refresh_stats() -> void:
	if view.is_empty():
		return
	var map := _ingredient_map()
	var base_stats: Dictionary = view.drink.get("stats", view.get("brew", {}).get("stats", {}))
	var preview_stats := base_stats
	if hovered != "" and view.drink.is_empty() and Brewing.can_add(view.selected, hovered, map) == "":
		preview_stats = Brewing.stats(view.selected + [hovered], map)
	readout.show_stats(base_stats, preview_stats)
	var color_html: String = view.drink.get("color", view.get("brew", {}).get("color", ""))
	preview_liquid.visible = color_html != ""
	if color_html != "":
		preview_liquid.modulate = Color(color_html)

func _refresh_buttons() -> void:
	var brewing: bool = view.stage == "brewing"
	var has_drink: bool = not view.drink.is_empty()
	reset_button.disabled = not brewing or (view.selected.is_empty() and not has_drink)
	brew_button.disabled = not brewing or view.selected.size() != Brewing.SLOTS or has_drink

# --- Animasyonlar ---------------------------------------------------------

func _set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if slide_tween:
		slide_tween.kill()
	if open:
		machine.show()
		shelf_shown = ""
	if reduced_motion:
		machine.position.x = OPEN_X if open else CLOSED_X
		machine.visible = open
		return
	slide_tween = create_tween()
	slide_tween.tween_property(machine, "position:x", OPEN_X if open else CLOSED_X, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		slide_tween.tween_callback(machine.hide)

## Kepenk: perde iner, raf değişir, perde kalkar.
func _swap_shelf() -> void:
	var first := shelf_shown == ""
	shelf_shown = view.shelf
	if first or reduced_motion:
		_rebuild_jars()
		return
	var full := BOTTOM_BOARD_Y + TAG_GAP + TAG_HEIGHT - shutter.position.y
	var curtain := create_tween()
	curtain.tween_property(shutter, "size:y", full, 0.18).set_ease(Tween.EASE_IN)
	curtain.tween_callback(_rebuild_jars)
	curtain.tween_interval(0.12)
	curtain.tween_property(shutter, "size:y", 0.0, 0.22).set_ease(Tween.EASE_OUT)
