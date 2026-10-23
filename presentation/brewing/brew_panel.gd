extends Control
## Demleme makinesi. Snapshot okur, EventBus'a komut yollar; kuralı BrewingRules'tan önizler.
## Malzeme ikonları: res://assets/ui/ingredients/<id>.png
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const OPEN_X := 1024.0
const CLOSED_X := 1940.0
const SLIDE_TIME := 0.4
const SEGMENTS := 8
const SEGMENT_SIZE := Vector2(26, 26)
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
var ingredient_buttons: Dictionary = {}
var slot_rows: Array[Dictionary] = []
var stat_rows: Dictionary = {}
@onready var machine: Control = $Machine
@onready var shelf_title: Label = $Machine/Shelf/Box/Header/ShelfTitle
@onready var shutter_button: Button = $Machine/Shelf/Box/Header/ShutterButton
@onready var hint: Label = $Machine/Shelf/Box/Hint
@onready var grid: GridContainer = $Machine/Shelf/Box/Grid
@onready var shutter: ColorRect = $Machine/Shutter
@onready var body: Control = $Machine/Body
@onready var slots: VBoxContainer = $Machine/Body/Box/Left/Slots
@onready var reset_button: Button = $Machine/Body/Box/Left/Buttons/ResetButton
@onready var brew_button: Button = $Machine/Body/Box/Left/Buttons/BrewButton
@onready var stats_box: VBoxContainer = $Machine/Body/Box/Right/Stats
@onready var preview_liquid: TextureRect = $Machine/Body/Box/Right/CupPreview/Liquid
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
	_build_slots()
	_build_stats()
	reset_button.text = I18n.t("brew.reset")
	brew_button.text = I18n.t("button.brew")
	trash_button.text = I18n.t("button.trash")
	serve_button.text = I18n.t("button.serve")
	$Machine/Body/Box/Left/SlotsTitle.text = I18n.t("brew.machine")
	$Machine/Body/Box/Right/StatsTitle.text = I18n.t("brew.taste")
	$Machine/Result/Box/ResultTitle.text = I18n.t("brew.ready")
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
		_refresh_ingredients()
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
		line.add_theme_constant_override("separation", 14)
		row.add_child(line)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		line.add_child(icon)
		var label := Label.new()
		label.theme_type_variation = &"MachineLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		var tag := Label.new()
		tag.theme_type_variation = &"MachineLabel"
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(tag)
		slot_rows.append({"panel": row, "icon": icon, "label": label, "tag": tag})

func _build_stats() -> void:
	for stat: String in Brewing.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		stats_box.add_child(row)
		var name_label := Label.new()
		name_label.theme_type_variation = &"MachineLabel"
		name_label.custom_minimum_size = Vector2(110, 0)
		name_label.text = I18n.t(STAT_KEYS[stat])
		row.add_child(name_label)
		var segments: Array[ColorRect] = []
		for i in range(SEGMENTS):
			var segment := ColorRect.new()
			segment.custom_minimum_size = SEGMENT_SIZE
			segment.color = SEGMENT_OFF
			row.add_child(segment)
			segments.append(segment)
		var tier_label := Label.new()
		tier_label.theme_type_variation = &"MachineLabel"
		tier_label.custom_minimum_size = Vector2(70, 0)
		tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(tier_label)
		stat_rows[stat] = {"segments": segments, "tier": tier_label}

# --- Güncelleme ----------------------------------------------------------

func _shelf_items() -> Array:
	return view.get("ingredients", []).filter(func(item: Dictionary) -> bool: return item.side == view.get("shelf", "human"))

func _ingredient(id: String) -> Dictionary:
	for item: Dictionary in view.get("ingredients", []):
		if item.id == id:
			return item
	return {}

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
	hint.visible = hint.text != ""

func _refresh_ingredients() -> void:
	var items := _shelf_items()
	if ingredient_buttons.size() != items.size():
		_rebuild_ingredients()
		return
	var active: bool = view.stage == "brewing" and view.drink.is_empty()
	var map := _ingredient_map()
	for item: Dictionary in items:
		var button: Button = ingredient_buttons.get(item.id)
		if button == null:
			_rebuild_ingredients()
			return
		var left: int = int(view.stock.get(item.id, 0)) - view.selected.count(item.id)
		button.text = I18n.t("brew.ingredient_button", {"name": item.name, "count": left})
		button.disabled = not active or left <= 0 or Brewing.can_add(view.selected, item.id, map) != ""

func _rebuild_ingredients() -> void:
	for child: Node in grid.get_children():
		child.queue_free()
	ingredient_buttons.clear()
	var items := _shelf_items()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(270, 136)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = false
		var icon_path := ICON_PATH % item.id
		if ResourceLoader.exists(icon_path):
			button.icon = _scaled_icon(load(icon_path))
		button.tooltip_text = "%s · %s  [%d]" % [item.description, I18n.t("book.base_tag") if item.get("base", false) else I18n.t("book.mix_tag"), i + 1]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(func() -> void: _send("select", {"id": item.id}))
		button.mouse_entered.connect(func() -> void: hovered = item.id; _refresh_stats())
		button.mouse_exited.connect(func() -> void: hovered = ""; _refresh_stats())
		grid.add_child(button)
		ingredient_buttons[item.id] = button
	_refresh_ingredients()

func _scaled_icon(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

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
			row.label.text = I18n.t("brew.slot_empty", {"index": i + 1})
			row.icon.texture = null
		row.tag.text = I18n.t("brew.base_marker") if i == 0 else ""
		row.panel.modulate = Color.WHITE if i < view.selected.size() else Color(1, 1, 1, 0.6)

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
		_rebuild_ingredients()
		return
	var full := grid.size.y + 24.0
	var curtain := create_tween()
	curtain.tween_property(shutter, "size:y", full, 0.18).set_ease(Tween.EASE_IN)
	curtain.tween_callback(_rebuild_ingredients)
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
