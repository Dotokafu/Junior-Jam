extends Control
## Demleme ekranı: yakın plan raf (kavanozlar), kepenk, makine. Snapshot okur, EventBus'a komut yollar;
## tat önizlemesini BrewingRules'tan hesaplar. Kavanoz çizimleri: res://assets/ui/ingredients/<id>.png
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const OPEN_X := 780.0
const CLOSED_X := 1940.0
const SLIDE_TIME := 0.4
## Kavanozlar üst rafın üstüne dizilir (raf tahtası brew_shelf.png'de y=300).
const JAR_SIZE := Vector2(96, 120)
const JAR_ROW_Y := 180.0
const JAR_FIRST_X := 70.0
const JAR_STEP := 170.0
const JAR_LIFT := 10.0
const TAG_Y := 330.0
const SLOT_ICON := Vector2(40, 50)
const SEGMENTS := 8
const SEGMENT_SIZE := Vector2(15, 24)
const SEGMENT_ON := Color("6b3f2a")
const SEGMENT_PREVIEW := Color("c99a6b")
const SEGMENT_OFF := Color("cbbba0")
const FLASH := Color("fff2c9")
const STAT_KEYS := {"warm": "brew.stat_warm", "cool": "brew.stat_cool", "sweet": "brew.stat_sweet", "bitter": "brew.stat_bitter"}
var view: Dictionary = {}
var reduced_motion: bool = false
var busy: bool = false
var is_open: bool = false
var shelf_shown: String = ""
var had_drink: bool = false
var hovered: String = ""
var slide_tween: Tween
var jars: Dictionary = {}
var slot_rows: Array[Dictionary] = []
var stat_rows: Dictionary = {}
@onready var machine: Control = $Machine
@onready var shelf_title: Label = $Machine/ShelfTitle
@onready var jar_layer: Control = $Machine/Jars
@onready var shutter: ColorRect = $Machine/Shutter
@onready var hint: Label = $Machine/Hint
@onready var shutter_button: Button = $Machine/ShutterButton
@onready var body: Control = $Machine/Body
@onready var slots: VBoxContainer = $Machine/Body/Box/Left/Slots
@onready var stats_box: VBoxContainer = $Machine/Body/Box/Mid/Stats
@onready var preview_liquid: TextureRect = $Machine/Body/Box/Right/CupPreview/Liquid
@onready var reset_button: Button = $Machine/Body/Box/Right/ResetButton
@onready var brew_button: Button = $Machine/Body/Box/Right/BrewButton
@onready var result: Control = $Machine/Result
@onready var result_liquid: TextureRect = $Machine/Result/Box/CupHolder/CupStack/Liquid
@onready var drink_name: Label = $Machine/Result/Box/DrinkName
@onready var drink_stats: Label = $Machine/Result/Box/DrinkStats
@onready var trash_button: Button = $Machine/Result/Box/Buttons/TrashButton
@onready var serve_button: Button = $Machine/Result/Box/Buttons/ServeButton

func _ready() -> void:
	machine.position.x = CLOSED_X
	machine.hide()
	shutter.size.y = 0.0
	result.hide()
	reset_button.text = I18n.t("brew.reset")
	brew_button.text = I18n.t("button.brew")
	trash_button.text = I18n.t("button.trash")
	serve_button.text = I18n.t("button.serve")
	$Machine/Body/Box/Mid/StatsTitle.text = I18n.t("brew.taste")
	$Machine/Result/Box/ResultTitle.text = I18n.t("brew.ready")
	_build_slots()
	_build_stats()
	shutter_button.pressed.connect(func() -> void: _send("shelf"))
	reset_button.pressed.connect(func() -> void: _send("clear"))
	brew_button.pressed.connect(func() -> void: _send("brew"))
	trash_button.pressed.connect(func() -> void: _send("trash"))
	serve_button.pressed.connect(func() -> void: _send("serve"))

func apply(snapshot: Dictionary) -> void:
	view = snapshot
	var should_open: bool = view.get("started", false) and view.get("stage", "") in ["brewing", "tutorial"]
	_set_open(should_open)
	if not should_open:
		had_drink = false
		return
	_update_texts()
	if view.shelf != shelf_shown:
		_swap_shelf()
	else:
		_refresh_jars()
	_refresh_slots()
	_refresh_stats()
	var has_drink: bool = not view.drink.is_empty()
	if has_drink and not had_drink:
		_play_brew()
	elif not has_drink:
		result.hide()
		body.show()
		body.modulate.a = 1.0
	had_drink = has_drink
	_refresh_buttons()

func _send(action: String, payload: Dictionary = {}) -> void:
	if busy:
		return
	EventBus.request(action, payload)

func select_index(index: int) -> void:
	var items := _shelf_items()
	if index >= 0 and index < items.size():
		_send("select", {"id": items[index].id})

# --- Kurulum -------------------------------------------------------------

func _build_slots() -> void:
	for i in range(Brewing.SLOTS):
		var row := PanelContainer.new()
		row.theme_type_variation = &"SlotPanel"
		slots.add_child(row)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		row.add_child(line)
		var label := Label.new()
		label.theme_type_variation = &"MachineLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		var icon := TextureRect.new()
		icon.custom_minimum_size = SLOT_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		slot_rows.append({"panel": row, "icon": icon, "label": label})

func _build_stats() -> void:
	for stat: String in Brewing.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		stats_box.add_child(row)
		var name_label := Label.new()
		name_label.theme_type_variation = &"MachineLabel"
		name_label.custom_minimum_size = Vector2(84, 0)
		name_label.text = I18n.t(STAT_KEYS[stat])
		row.add_child(name_label)
		var segments: Array[ColorRect] = []
		for i in range(SEGMENTS):
			var segment := ColorRect.new()
			segment.custom_minimum_size = SEGMENT_SIZE
			segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			segment.color = SEGMENT_OFF
			row.add_child(segment)
			segments.append(segment)
		var tier_label := Label.new()
		tier_label.theme_type_variation = &"MachineLabel"
		tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tier_label)
		stat_rows[stat] = {"segments": segments, "tier": tier_label}

# --- Güncelleme ----------------------------------------------------------

func _shelf_items() -> Array:
	return view.get("ingredients", []).filter(func(item: Dictionary) -> bool: return item.side == view.get("shelf", "human"))

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
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var x := JAR_FIRST_X + i * JAR_STEP
		var button := TextureButton.new()
		var icon_path := ICON_PATH % item.id
		if ResourceLoader.exists(icon_path):
			button.texture_normal = load(icon_path)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.position = Vector2(x + (JAR_STEP - JAR_SIZE.x) / 2.0 - 20.0, JAR_ROW_Y)
		button.size = JAR_SIZE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var role := I18n.t("book.base_tag") if item.get("base", false) else I18n.t("book.mix_tag")
		button.tooltip_text = "%s · %s  [%d]" % [item.description, role, i + 1]
		button.pressed.connect(func() -> void: _send("select", {"id": item.id}))
		button.mouse_entered.connect(_on_jar_hover.bind(item.id, button, true))
		button.mouse_exited.connect(_on_jar_hover.bind(item.id, button, false))
		jar_layer.add_child(button)
		var tag := Label.new()
		tag.theme_type_variation = &"HudText"
		tag.add_theme_font_size_override("font_size", 24)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.position = Vector2(x - 20.0, TAG_Y)
		tag.size = Vector2(JAR_STEP, 60)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		jar_layer.add_child(tag)
		jars[item.id] = {"button": button, "tag": tag}
	_refresh_jars()

func _on_jar_hover(id: String, button: TextureButton, entered: bool) -> void:
	hovered = id if entered else ""
	_refresh_stats()
	if reduced_motion or button.disabled:
		button.position.y = JAR_ROW_Y
		return
	create_tween().tween_property(button, "position:y", JAR_ROW_Y - (JAR_LIFT if entered else 0.0), 0.08)

func _refresh_slots() -> void:
	var map := _ingredient_map()
	for i in range(slot_rows.size()):
		var row: Dictionary = slot_rows[i]
		if i < view.selected.size():
			var item: Dictionary = map.get(view.selected[i], {})
			row.label.text = str(item.get("name", "?")).to_upper()
			var icon_path := ICON_PATH % item.get("id", "")
			row.icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
		else:
			row.label.text = I18n.t("brew.slot_base") if i == 0 else I18n.t("brew.slot_empty", {"index": i + 1})
			row.icon.texture = null
		row.panel.modulate = Color.WHITE if i < view.selected.size() else Color(1, 1, 1, 0.65)

func _refresh_stats() -> void:
	if view.is_empty():
		return
	var map := _ingredient_map()
	var base_stats: Dictionary = view.drink.get("stats", view.get("brew", {}).get("stats", {}))
	var preview_stats := base_stats
	if hovered != "" and view.drink.is_empty() and Brewing.can_add(view.selected, hovered, map) == "":
		preview_stats = Brewing.stats(view.selected + [hovered], map)
	for stat: String in Brewing.STATS:
		var row: Dictionary = stat_rows[stat]
		var value := int(base_stats.get(stat, 0))
		var preview := int(preview_stats.get(stat, 0))
		for i in range(SEGMENTS):
			var segment: ColorRect = row.segments[i]
			segment.color = SEGMENT_ON if i < value else (SEGMENT_PREVIEW if i < preview else SEGMENT_OFF)
		row.tier.text = I18n.t("brew.tier_%d" % Brewing.tier(preview))
	var color_html: String = view.drink.get("color", view.get("brew", {}).get("color", ""))
	preview_liquid.visible = color_html != ""
	if color_html != "":
		preview_liquid.modulate = Color(color_html)

func _refresh_buttons() -> void:
	var brewing: bool = view.stage == "brewing"
	var has_drink: bool = not view.drink.is_empty()
	reset_button.disabled = busy or not brewing or (view.selected.is_empty() and not has_drink)
	brew_button.disabled = busy or not brewing or view.selected.size() != Brewing.SLOTS or has_drink
	serve_button.disabled = busy or not brewing or not has_drink
	trash_button.disabled = busy or not brewing or not has_drink

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
	var full := TAG_Y + 60.0 - shutter.position.y
	var curtain := create_tween()
	curtain.tween_property(shutter, "size:y", full, 0.18).set_ease(Tween.EASE_IN)
	curtain.tween_callback(_rebuild_jars)
	curtain.tween_interval(0.12)
	curtain.tween_property(shutter, "size:y", 0.0, 0.22).set_ease(Tween.EASE_OUT)

## Slotlar sırayla parlar, makine kapanır, fincan dolar ve adı belirir.
func _play_brew() -> void:
	drink_name.text = view.drink.get("name", "")
	drink_stats.text = _tier_summary(view.drink.get("tiers", {}))
	result_liquid.modulate = Color(view.drink.get("color", "ffffff"))
	if reduced_motion:
		body.hide()
		result.show()
		return
	busy = true
	_refresh_buttons()
	var chain := create_tween()
	for row: Dictionary in slot_rows:
		chain.tween_property(row.panel, "modulate", FLASH, 0.1)
		chain.tween_property(row.panel, "modulate", Color.WHITE, 0.12)
	chain.tween_property(body, "modulate:a", 0.0, 0.18)
	chain.tween_callback(func() -> void:
		body.hide()
		result.modulate.a = 0.0
		result_liquid.scale = Vector2(1, 0)
		result.show())
	chain.tween_property(result, "modulate:a", 1.0, 0.2)
	chain.tween_property(result_liquid, "scale:y", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	chain.tween_callback(func() -> void:
		busy = false
		_refresh_buttons())

func _tier_summary(tiers: Dictionary) -> String:
	var parts: Array[String] = []
	for stat: String in Brewing.STATS:
		if int(tiers.get(stat, 0)) > 0:
			parts.append(I18n.t(STAT_KEYS[stat]) + " " + I18n.t("brew.tier_%d" % int(tiers[stat])))
	return "  ·  ".join(parts)
