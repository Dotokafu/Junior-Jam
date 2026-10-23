extends Control
## Tam ekran katmanlar: giriş, Fall/şafak geçişi, son, içerik hatası ve Esc menüsü.
## Esc menüsü iki sütun: solda menü satırları, sağda açılan sayfa (ayarlar, kaydet, yükle, yardım…).
## Hepsi temadan stil alır; düzen bilinçli olarak sade tutuldu (tasarım gelince sahneye taşınabilir).
signal start_requested(action: String, mode: String)
signal new_game_requested(mode: String)
signal next_requested
signal modal_closed
signal sound_toggled
signal motion_toggled
signal speed_cycled
signal fullscreen_toggled
signal window_size_cycled
signal page_requested(kind: String)
signal save_requested(slot: int)
signal load_requested(slot: int)
signal main_menu_requested
signal quit_requested
const FADE_TIME := 0.25
## Sağ sütunu olan sayfalar; "pause" yalnızca sol listeyi gösterir.
const PAGES := ["pause", "settings", "save", "load", "help", "new_game", "confirm_new"]
const STRIP_WIDTH := 640.0
const PAGE_RECT := Rect2(720, 90, 1110, 900)
const ACTIVE_MARK := "▶  "
var screen: String = ""
var modal: String = ""
var reduced_motion: bool = false
@onready var screen_layer: Control = $ScreenLayer
@onready var modal_layer: Control = $ModalLayer

## Snapshot'a göre tam ekran katmanı seçer. Oyun alanını kapatıyorsa true döner.
func apply(view: Dictionary) -> bool:
	var wanted := ""
	if not view.get("content_errors", []).is_empty():
		wanted = "error"
	elif not view.get("started", false):
		wanted = "intro"
	elif view.phase == "ending":
		wanted = "ending"
	elif view.phase in ["fall", "dawn"]:
		wanted = view.phase
	var key := wanted + str(view.get("has_save", false)) + str(view.get("day", 0)) + str(_has_slot(view))
	if key != screen:
		screen = key
		_clear(screen_layer)
		match wanted:
			"error": _error(view)
			"intro": _intro(view)
			"ending": _ending(view)
			"fall", "dawn": _transition(view, wanted == "fall")
		_fade_in(screen_layer)
	return wanted != ""

func open_modal(kind: String, state: Dictionary) -> void:
	modal = kind
	_clear(modal_layer)
	var dim := _dim(modal_layer, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_strip(kind, state)
	if kind != "pause":
		_page(kind, state)

## Sol şerit: başlık + menü satırları. Oyun başlamadıysa yalnızca anlamlı satırlar görünür.
func _menu_strip(active: String, state: Dictionary) -> void:
	var strip := ColorRect.new()
	strip.color = Color("16121a")
	strip.size = Vector2(STRIP_WIDTH, 1080)
	modal_layer.add_child(strip)
	var edge := ColorRect.new()
	edge.color = Color("3d3446")
	edge.position = Vector2(STRIP_WIDTH - 6, 0)
	edge.size = Vector2(6, 1080)
	modal_layer.add_child(edge)
	var box := _vbox(modal_layer, 4)
	box.position = Vector2(80, 90)
	box.custom_minimum_size = Vector2(STRIP_WIDTH - 120, 0)
	var started: bool = state.get("started", false)
	_label(box, I18n.t("pause.title") if started else I18n.t("app.title"), "Title").add_theme_font_size_override("font_size", 64)
	_label(box, I18n.t("menu.title") if started else I18n.t("app.tagline"), "Caption")
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)
	if started:
		_menu_item(box, I18n.t("pause.resume"), "", active, func() -> void: modal_closed.emit())
		_menu_item(box, I18n.t("pause.save"), "save", active, func() -> void: page_requested.emit("save"), not state.get("can_save", false))
	_menu_item(box, I18n.t("pause.load"), "load", active, func() -> void: page_requested.emit("load"))
	_menu_item(box, I18n.t("pause.settings"), "settings", active, func() -> void: page_requested.emit("settings"))
	_menu_item(box, I18n.t("pause.help"), "help", active, func() -> void: page_requested.emit("help"))
	if started:
		_menu_item(box, I18n.t("pause.new_game"), "new_game", active, func() -> void: page_requested.emit("new_game"))
		_menu_item(box, I18n.t("pause.main_menu"), "", active, func() -> void: main_menu_requested.emit())
	else:
		_menu_item(box, I18n.t("pause.back"), "", active, func() -> void: modal_closed.emit())
	_menu_item(box, I18n.t("pause.quit"), "", active, func() -> void: quit_requested.emit())
	# Konteyner dışındaki etiketlere genişlik verilmezse her harf alt satıra kayar.
	var footer_width := STRIP_WIDTH - 120
	var hint := _label(modal_layer, I18n.t("pause.esc_hint"), "Caption")
	hint.position = Vector2(80, 1010)
	hint.custom_minimum_size = Vector2(footer_width, 0)
	if started:
		var note := _label(modal_layer, I18n.t("menu.auto_save"), "Caption")
		note.position = Vector2(80, 970)
		note.custom_minimum_size = Vector2(footer_width, 0)

func _menu_item(parent: Control, text: String, page: String, active: String, callback: Callable, disabled: bool = false) -> Button:
	var item := Button.new()
	item.theme_type_variation = &"MenuItem"
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.text = (ACTIVE_MARK + text) if page != "" and page == active else text
	item.disabled = disabled
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

## Sağ sütun: seçili sayfanın içeriği.
func _page(kind: String, state: Dictionary) -> void:
	var panel := PanelContainer.new()
	modal_layer.add_child(panel)
	panel.position = PAGE_RECT.position
	panel.custom_minimum_size = Vector2(PAGE_RECT.size.x, 0)
	var box := _vbox(panel, 16)
	var titles := {"settings": "pause.settings", "save": "pause.save", "load": "pause.load", "help": "help.title", "new_game": "pause.new_game", "confirm_new": "confirm.title"}
	_label(box, I18n.t(titles.get(kind, "pause.title")), "Title").add_theme_font_size_override("font_size", 64)
	match kind:
		"settings":
			_button(box, I18n.t("menu.sound_off" if state.get("muted", false) else "menu.sound_on"), func() -> void: sound_toggled.emit())
			_button(box, I18n.t("menu.motion_reduced" if state.get("reduced_motion", false) else "menu.motion_normal"), func() -> void: motion_toggled.emit())
			_button(box, I18n.t("menu.text_speed", {"speed": I18n.t("speed." + str(state.get("speed", "normal")))}), func() -> void: speed_cycled.emit())
			_button(box, I18n.t("menu.fullscreen_on" if state.get("fullscreen", false) else "menu.fullscreen_off"), func() -> void: fullscreen_toggled.emit())
			var window_size: Vector2i = state.get("window_size", Vector2i(1920, 1080))
			var size_button := _button(box, I18n.t("menu.window_size", {"size": "%d×%d" % [window_size.x, window_size.y]}), func() -> void: window_size_cycled.emit())
			size_button.disabled = state.get("fullscreen", false)
		"save":
			_label(box, I18n.t("save.instructions"), "Caption")
			for summary: Dictionary in state.get("slots", []):
				if int(summary.slot) == 0:
					continue
				var slot := int(summary.slot)
				_slot_card(box, summary, func() -> void: save_requested.emit(slot), false)
		"load":
			_label(box, I18n.t("load.instructions"), "Caption")
			for summary: Dictionary in state.get("slots", []):
				var slot := int(summary.slot)
				_slot_card(box, summary, func() -> void: load_requested.emit(slot), summary.get("empty", true))
		"help":
			_label(box, I18n.t("help.body"))
		"new_game":
			_label(box, I18n.t("confirm.body"))
			# Uyarı bu sayfada; ayrıca onay penceresi açılmaz.
			_button(box, I18n.t("button.start_story"), func() -> void: start_requested.emit("new_game", "story"), true)
			_button(box, I18n.t("button.start_endless"), func() -> void: start_requested.emit("new_game", "endless"))
		"confirm_new":
			_label(box, I18n.t("confirm.body"))
			var start_key := "button.start_endless" if state.get("mode", "story") == "endless" else "button.start_story"
			_button(box, I18n.t(start_key), func() -> void: start_requested.emit("new_game", state.get("mode", "story")), true)
			_button(box, I18n.t("button.back"), func() -> void: modal_closed.emit())

func _slot_card(parent: Control, summary: Dictionary, callback: Callable, disabled: bool) -> void:
	var card := Button.new()
	card.theme_type_variation = &"SlotCard"
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.custom_minimum_size = Vector2(0, 150)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.text = _slot_text(summary)
	card.disabled = disabled
	card.pressed.connect(callback)
	parent.add_child(card)

func _slot_text(summary: Dictionary) -> String:
	var slot := int(summary.get("slot", 0))
	var heading := I18n.t("save.auto") if slot == 0 else I18n.t("save.slot", {"slot": slot})
	if summary.get("empty", true):
		return heading + "\n" + I18n.t("save.empty")
	var mode := I18n.t("mode.endless" if summary.mode == "endless" else "mode.story")
	var detail := I18n.t("save.detail", {"day": "%02d" % summary.day, "phase": I18n.t("phase." + str(summary.phase)), "mode": mode})
	var when := I18n.t("save.when", {"served": summary.served, "date": _local_time(int(summary.saved_at))})
	return "%s\n%s\n%s" % [heading, detail, when]

## Kayıt zamanı yerel saatle: 23.10.2026  22:41
static func _local_time(unix: int) -> String:
	if unix <= 0:
		return "—"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var at := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%02d.%02d.%d  %02d:%02d" % [at.day, at.month, at.year, at.hour, at.minute]

func close_modal() -> void:
	modal = ""
	_clear(modal_layer)

# --- Ekranlar --------------------------------------------------------------

func _intro(view: Dictionary) -> void:
	_dim(screen_layer, 0.45)
	var panel := PanelContainer.new()
	screen_layer.add_child(panel)
	panel.position = Vector2(100, 130)
	panel.custom_minimum_size = Vector2(860, 0)
	var box := _vbox(panel, 20)
	_label(box, I18n.t("app.title"), "Title").add_theme_font_size_override("font_size", 120)
	_label(box, I18n.t("app.tagline"), "NameTag")
	_label(box, I18n.t("intro.description"))
	var buttons := _vbox(box, 14)
	buttons.custom_minimum_size = Vector2(520, 0)
	if view.get("has_save", false):
		_button(buttons, I18n.t("button.continue_save"), func() -> void: start_requested.emit("continue", "story"), true)
		_button(buttons, I18n.t("button.new_story"), func() -> void: new_game_requested.emit("story"))
		_button(buttons, I18n.t("button.new_endless"), func() -> void: new_game_requested.emit("endless"))
	else:
		_button(buttons, I18n.t("button.story_mode"), func() -> void: start_requested.emit("new_game", "story"), true)
		_button(buttons, I18n.t("button.endless_mode"), func() -> void: start_requested.emit("new_game", "endless"))
	if _has_slot(view):
		_button(buttons, I18n.t("button.load_game"), func() -> void: page_requested.emit("load"))
	_label(box, I18n.t("intro.modes", {"days": view.get("total_days", 0)}), "Caption")

func _transition(view: Dictionary, fall: bool) -> void:
	var back := ColorRect.new()
	back.color = Color("120e18")
	back.size = Vector2(1920, 1080)
	screen_layer.add_child(back)
	var box := _vbox(screen_layer, 26)
	box.position = Vector2(360, 260)
	box.custom_minimum_size = Vector2(1200, 0)
	_label(box, I18n.t("transition.shift", {"day": "%02d" % view.day}), "NameTag")
	_label(box, I18n.t("transition.fall_title" if fall else "transition.dawn_title"), "Title").add_theme_font_size_override("font_size", 130)
	_label(box, I18n.t("transition.fall_body" if fall else "transition.dawn_body"))
	_label(box, I18n.t("transition.day_to_night" if fall else "transition.night_to_day"), "Caption")
	_button(box, I18n.t("button.open_door" if fall else "button.start_day"), func() -> void: next_requested.emit(), true)

func _ending(view: Dictionary) -> void:
	_dim(screen_layer, 0.8)
	var ending: Dictionary = view.get("ending", {})
	var panel := PanelContainer.new()
	screen_layer.add_child(panel)
	panel.position = Vector2(220, 200)
	panel.custom_minimum_size = Vector2(1480, 0)
	var box := _vbox(panel, 20)
	_label(box, I18n.t("ending.heading", {"number": ending.get("number", ""), "subtitle": ending.get("subtitle", "")}), "NameTag")
	_label(box, ending.get("title", ""), "Title")
	var text: String = ending.get("text", "")
	if ending.get("variant", "") == "errors":
		text += "\n\n" + str(ending.get("errors", ""))
	_label(box, text)
	_label(box, I18n.t("ending.cup_count", {"count": view.get("served", 0)}), "Caption")
	_button(box, I18n.t("button.new_story"), func() -> void: new_game_requested.emit("story"), true)

func _error(view: Dictionary) -> void:
	_dim(screen_layer, 0.95)
	var box := _vbox(screen_layer, 16)
	box.position = Vector2(120, 120)
	box.custom_minimum_size = Vector2(1680, 0)
	_label(box, I18n.t("error.content_heading") + "\n".join(view.content_errors))

# --- Yardımcılar -----------------------------------------------------------

func _has_slot(view: Dictionary) -> bool:
	return view.get("slots", []).any(func(summary: Dictionary) -> bool: return int(summary.slot) > 0 and not summary.get("empty", true))

func _clear(layer: Control) -> void:
	for child: Node in layer.get_children():
		child.queue_free()

func _fade_in(layer: Control) -> void:
	if reduced_motion or layer.get_child_count() == 0:
		layer.modulate.a = 1.0
		return
	layer.modulate.a = 0.0
	create_tween().tween_property(layer, "modulate:a", 1.0, FADE_TIME)

func _dim(layer: Control, alpha: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.03, 0.025, 0.045, alpha)
	rect.size = Vector2(1920, 1080)
	layer.add_child(rect)
	return rect

func _vbox(parent: Control, separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	parent.add_child(box)
	return box

func _label(parent: Control, content: String, variation: StringName = &"") -> Label:
	var label := Label.new()
	label.text = content
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, content: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = content
	button.custom_minimum_size = Vector2(0, 64)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		button.theme_type_variation = &"PrimaryButton"
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
