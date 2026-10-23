extends Control
## Tam ekran katmanlar: giriş, Fall/şafak geçişi, son, içerik hatası ve menü/yardım/onay pencereleri.
## Hepsi temadan stil alır; düzen bilinçli olarak sade tutuldu (tasarım gelince sahneye taşınabilir).
signal start_requested(action: String, mode: String)
signal new_game_requested(mode: String)
signal next_requested
signal modal_closed
signal sound_toggled
signal motion_toggled
signal speed_cycled
const FADE_TIME := 0.25
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
	var key := wanted + str(view.get("has_save", false)) + str(view.get("day", 0))
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
	var dim := _dim(modal_layer, 0.9)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	modal_layer.add_child(panel)
	panel.position = Vector2(560, 150)
	panel.custom_minimum_size = Vector2(800, 0)
	var box := _vbox(panel, 18)
	_label(box, {"menu": I18n.t("menu.title"), "help": I18n.t("help.title"), "confirm_new": I18n.t("confirm.title")}.get(kind, ""), "Title")
	match kind:
		"help":
			_label(box, I18n.t("help.body"))
		"confirm_new":
			_label(box, I18n.t("confirm.body"))
			var start_key := "button.start_endless" if state.get("mode", "story") == "endless" else "button.start_story"
			_button(box, I18n.t(start_key), func() -> void: start_requested.emit("new_game", state.get("mode", "story")), true)
		_:
			_label(box, I18n.t("menu.auto_save"), "Caption")
			_button(box, I18n.t("menu.sound_off" if state.get("muted", false) else "menu.sound_on"), func() -> void: sound_toggled.emit())
			_button(box, I18n.t("menu.motion_reduced" if state.get("reduced_motion", false) else "menu.motion_normal"), func() -> void: motion_toggled.emit())
			_button(box, I18n.t("menu.text_speed", {"speed": I18n.t("speed." + str(state.get("speed", "normal")))}), func() -> void: speed_cycled.emit())
			_button(box, I18n.t("button.new_story"), func() -> void: new_game_requested.emit("story"))
			_button(box, I18n.t("button.new_endless"), func() -> void: new_game_requested.emit("endless"))
	_button(box, I18n.t("button.back"), func() -> void: modal_closed.emit(), kind != "confirm_new")

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
