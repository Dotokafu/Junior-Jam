@tool
extends Control
## Sunum: snapshot okur ve EventBus'a komut yollar. Domain durumu değiştirmez.
const UI = preload("res://presentation/ui/ui.gd")
const CafeArt = preload("res://presentation/art/cafe_art.gd")
const RecipeBook = preload("res://presentation/ui/recipe_book.gd")
const DossierPanel = preload("res://presentation/ui/dossier_panel.gd")
const Preview = preload("res://presentation/editor/preview_snapshot.gd")
@export var cafe_background: Texture2D:
	set(value):
		cafe_background = value
		_queue_editor_preview()
@export var cafe_counter: Texture2D:
	set(value):
		cafe_counter = value
		_queue_editor_preview()
@export_enum("day", "night", "book_human", "book_fallen", "dossier", "intro", "fall", "ending") var editor_preview: String = "day":
	set(value):
		editor_preview = value
		_queue_editor_preview()
@export var editor_character: String = "ada":
	set(value):
		editor_character = value
		_queue_editor_preview()
@export var refresh_preview: bool = false:
	set(value):
		if value:
			UI.preview_messages = {}
			_queue_editor_preview()
var preview_pending: bool = false
var view: Dictionary = {}
var art: Control
var main: Control
var overlay: Control
var toast: Label
var toast_tween: Tween
var modal: String = ""
var book_page: String = "human"
var book: Control
var dossier: Control
var dossier_selection: String = ""
var reduced_motion: bool = false
var muted: bool = false
var new_mode: String = "story"
var ambience: AudioStreamPlayer

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("15131d")
	background.size = Vector2(1440, 900)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	art = CafeArt.new()
	add_child(art)
	art.position = Vector2(40, 146)
	art.size = Vector2(1360, 380)
	art.background_texture = cafe_background
	art.counter_texture = cafe_counter
	main = Control.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	toast = UI.label(self, "", Rect2(280, 850, 880, 38), 19, UI.GOLD, UI.BODY)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	if Engine.is_editor_hint():
		_refresh_editor_preview()
		return
	ambience = AudioStreamPlayer.new()
	add_child(ambience)
	if ResourceLoader.exists("res://assets/audio/rain.wav"):
		ambience.stream = load("res://assets/audio/rain.wav")
		if ambience.stream is AudioStreamWAV:
			ambience.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			ambience.stream.loop_end = int(ambience.stream.get_length() * ambience.stream.mix_rate)
		ambience.volume_db = -18
	EventBus.state_changed.connect(_on_state)
	EventBus.feedback.connect(_feedback)
	I18n.language_changed.connect(func(_locale: String) -> void: EventBus.request("refresh"))
	EventBus.request("refresh")

func _queue_editor_preview() -> void:
	if Engine.is_editor_hint() and is_node_ready() and not preview_pending:
		preview_pending = true
		_refresh_editor_preview.call_deferred()

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()

func _refresh_editor_preview() -> void:
	preview_pending = false
	reduced_motion = true
	art.reduced_motion = true
	art.background_texture = cafe_background
	art.counter_texture = cafe_counter
	view = Preview.build(editor_preview, editor_character)
	book_page = "fallen" if editor_preview == "book_fallen" else "human"
	modal = "book" if editor_preview.begins_with("book_") else ("dossier" if editor_preview == "dossier" else "")
	_render()

func _on_state(snapshot: Dictionary) -> void:
	if modal == "book" and is_instance_valid(book):
		book_page = book.page
	if modal == "dossier" and is_instance_valid(dossier):
		dossier_selection = dossier.selected_id
	view = snapshot
	if view.phase == "ending":
		modal = ""
	_render()

func _render() -> void:
	UI.clear(main)
	var is_night: bool = view.phase in ["fall", "night", "night_supplier", "ending"]
	art.set_scene(is_night, view.shelf == "fallen", view.person)
	_header()
	if not view.content_errors.is_empty():
		UI.label(main, UI.text("error.content_heading") + "\n".join(view.content_errors), Rect2(70, 560, 1280, 260), 24, UI.PINK, UI.BODY, true)
	elif not view.started:
		_intro()
	elif view.phase == "ending":
		_ending()
	elif view.phase in ["fall", "dawn"]:
		_transition()
	else:
		_dialogue()
		_brewing()
	_footer()
	_render_modal()

func _header() -> void:
	UI.label(main, UI.text("app.title"), Rect2(40, 23, 470, 77), 66, UI.INK, UI.ITALIC)
	UI.label(main, UI.text("app.tagline"), Rect2(44, 102, 530, 23), 13, UI.GOLD, UI.MONO)
	if view.started:
		var phase_name: String = {"morning_supplier": UI.text("phase.morning_supplier"), "day": UI.text("phase.day"), "night": UI.text("phase.night"), "night_supplier": UI.text("phase.night_supplier"), "fall": UI.text("phase.fall"), "dawn": UI.text("phase.dawn"), "ending": UI.text("phase.ending")}.get(view.phase, "")
		var day_label := UI.text("header.endless_day" if view.mode == "endless" else "header.story_day", {"day": "%02d" % view.day, "total": "%02d" % view.total_days})
		UI.label(main, day_label, Rect2(700, 40, 320, 28), 16, UI.GOLD, UI.MONO)
		UI.label(main, phase_name, Rect2(700, 79, 340, 30), 23, UI.INK, UI.BODY)
	else:
		UI.label(main, UI.text("header.intro"), Rect2(700, 47, 500, 28), 14, UI.MUTED, UI.MONO)
	UI.button(main, UI.text("button.help"), Rect2(1240, 43, 50, 46), func() -> void: modal = "help"; _render_modal())
	UI.button(main, UI.text("button.menu"), Rect2(1302, 43, 98, 46), func() -> void: modal = "menu"; _render_modal())
	UI.label(main, UI.text("decor.district"), Rect2(58, 162, 530, 24), 12, Color("c1afa4"), UI.MONO)
	UI.label(main, UI.text("decor.mock"), Rect2(1146, 162, 240, 22), 11, Color("b9a9a4"), UI.MONO)
	UI.box(main, Rect2(40, 534, 1360, 1), Color("50404c"), Color.TRANSPARENT)

func _intro() -> void:
	UI.label(main, UI.text("intro.chapter"), Rect2(43, 557, 750, 25), 14, UI.GOLD, UI.MONO)
	UI.label(main, UI.text("intro.title"), Rect2(40, 590, 750, 126), 50, UI.INK, UI.TITLE)
	UI.label(main, UI.text("intro.description"), Rect2(44, 733, 700, 78), 22, UI.MUTED, UI.BODY, true)
	UI.box(main, Rect2(866, 565, 534, 269))
	UI.label(main, UI.text("intro.shift_log"), Rect2(896, 585, 430, 28), 14, UI.GOLD, UI.MONO)
	UI.label(main, UI.text("intro.keep_lights"), Rect2(896, 627, 430, 48), 34, UI.INK, UI.ITALIC)
	if view.has_save:
		UI.button(main, UI.text("button.continue_save"), Rect2(896, 697, 474, 51), func() -> void: _start("continue"), true)
		UI.button(main, UI.text("button.new_story"), Rect2(896, 763, 231, 44), _new_game)
		UI.button(main, UI.text("button.new_endless"), Rect2(1139, 763, 231, 44), func() -> void: _new_game("endless"))
	else:
		UI.button(main, UI.text("button.story_mode"), Rect2(896, 697, 231, 51), func() -> void: _start("new_game"), true)
		UI.button(main, UI.text("button.endless_mode"), Rect2(1139, 697, 231, 51), func() -> void: _start("new_game", "endless"))
		UI.label(main, UI.text("intro.modes", {"days": view.total_days}), Rect2(896, 769, 480, 28), 13, UI.MUTED, UI.MONO)

func _start(action: String, mode: String = "story") -> void:
	modal = ""
	if not muted and ambience.stream and not ambience.playing:
		ambience.play()
	EventBus.request(action, {"mode": mode})

func _new_game(mode: String = "story") -> void:
	new_mode = mode
	if view.has_save:
		modal = "confirm_new"
		_render_modal()
	else:
		_start("new_game", new_mode)

func _dialogue() -> void:
	UI.box(main, Rect2(40, 552, 800, 286))
	var person: Dictionary = view.person
	UI.label(main, person.get("name", UI.text("character.barista")), Rect2(66, 570, 425, 46), 34, UI.INK, UI.TITLE)
	UI.label(main, person.get("role", ""), Rect2(66, 618, 690, 27), 15, UI.GOLD, UI.MONO)
	UI.label(main, view.line, Rect2(66, 658, 741, 96), 23, UI.INK, UI.BODY, true)
	var text: String = {"dialogue": UI.text("button.listen"), "reaction": UI.text("button.next_customer"), "decision": UI.text("button.finish_delivery"), "brewing": UI.text("button.book"), "tutorial": UI.text("button.old_book")}.get(view.stage, UI.text("button.next"))
	var callback := func() -> void: EventBus.request("next")
	if view.stage in ["brewing", "tutorial"]:
		callback = _toggle_book
	UI.button(main, text, Rect2(561, 775, 252, 42), callback, true)
	if view.day >= 2 and view.phase in ["day", "night"]:
		UI.button(main, UI.text("button.photo"), Rect2(66, 775, 231, 42), func() -> void: EventBus.request("photo"), false, view.stage == "reaction")
	elif view.stage == "decision" and view.day >= 2:
		UI.button(main, UI.text("button.records"), Rect2(66, 775, 240, 42), _toggle_dossier)
	else:
		UI.label(main, UI.text("dialogue.listen_unspoken"), Rect2(66, 778, 455, 32), 18, UI.MUTED, UI.ITALIC)

func _brewing() -> void:
	UI.box(main, Rect2(864, 552, 536, 286))
	var active: bool = view.stage == "brewing"
	var can_switch: bool = view.tutorial in ["switch_hint", "ready"] and view.stage in ["brewing", "tutorial"]
	UI.label(main, UI.text("shelf.fallen") if view.shelf == "fallen" else UI.text("shelf.human"), Rect2(888, 570, 240, 27), 14, UI.PINK if view.shelf == "fallen" else UI.GOLD, UI.MONO)
	UI.button(main, UI.text("button.shelf_discovery") if view.tutorial == "switch_hint" else UI.text("button.shelf"), Rect2(1163, 565, 214, 38), func() -> void: EventBus.request("shelf"), view.tutorial == "switch_hint", not can_switch)
	if not view.drink.is_empty():
		UI.label(main, view.drink.name, Rect2(891, 611, 466, 32), 25, UI.GOLD, UI.ITALIC)
	else:
		for i in range(3):
			var text := UI.text("shelf.slot", {"index": i + 1})
			if i < view.selected.size():
				text = _ingredient_name(view.selected[i])
			UI.box(main, Rect2(889 + i * 165, 611, 158, 32), Color("282330"), Color("4c3f4b"))
			var slot := UI.label(main, text, Rect2(893 + i * 165, 613, 150, 27), 16, UI.INK if i < view.selected.size() else UI.MUTED, UI.BODY)
			slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ingredients: Array = view.ingredients.filter(func(item: Dictionary) -> bool: return item.side == view.shelf)
	for i in range(ingredients.size()):
		var ingredient: Dictionary = ingredients[i]
		var count: int = int(view.stock.get(ingredient.id, 0)) - view.selected.count(ingredient.id)
		var button := UI.button(main, UI.text("format.stock", {"name": ingredient.name, "count": count}), Rect2(889 + (i % 3) * 165, 654 + (i / 3) * 49, 158, 41), func() -> void: EventBus.request("select", {"id": ingredient.id}), false, not active or not view.drink.is_empty() or view.selected.size() >= 3 or count <= 0)
		button.tooltip_text = ingredient.description
	UI.button(main, UI.text("button.clear"), Rect2(889, 766, 112, 51), func() -> void: EventBus.request("clear"), false, not active or (view.selected.is_empty() and view.drink.is_empty()))
	UI.button(main, UI.text("button.brew"), Rect2(1012, 766, 170, 51), func() -> void: EventBus.request("brew"), false, not active or view.selected.size() != 3 or not view.drink.is_empty())
	UI.button(main, UI.text("button.serve"), Rect2(1193, 766, 184, 51), func() -> void: EventBus.request("serve"), true, not active or view.drink.is_empty())

func _ingredient_name(id: String) -> String:
	for ingredient: Dictionary in view.ingredients:
		if ingredient.id == id:
			return ingredient.name
	return id

func _footer() -> void:
	if view.started and view.phase != "ending":
		UI.button(main, UI.text("button.book"), Rect2(40, 853, 218, 31), _toggle_book)
		UI.button(main, UI.text("button.dossier"), Rect2(1150, 853, 250, 31), _toggle_dossier, false, view.day < 2)
	else:
		UI.label(main, UI.text("footer.prototype"), Rect2(43, 858, 500, 25), 12, UI.MUTED, UI.MONO)
		UI.label(main, UI.text("footer.save"), Rect2(1020, 858, 390, 25), 12, UI.MUTED, UI.MONO)

func _transition() -> void:
	var fall: bool = view.phase == "fall"
	var page := Control.new()
	main.add_child(page)
	page.size = Vector2(1440, 900)
	UI.box(page, Rect2(0, 0, 1440, 900), Color("17131f"), Color.TRANSPARENT)
	UI.label(page, UI.text("transition.shift", {"day": "%02d" % view.day}), Rect2(352, 191, 900, 27), 15, UI.GOLD, UI.MONO)
	UI.label(page, UI.text("transition.fall_title") if fall else UI.text("transition.dawn_title"), Rect2(344, 266, 960, 150), 110, UI.INK, UI.ITALIC)
	UI.box(page, Rect2(352, 448, 730, 1), Color("6d4d61"), Color.TRANSPARENT)
	UI.label(page, UI.text("transition.fall_body") if fall else UI.text("transition.dawn_body"), Rect2(352, 482, 730, 94), 27, UI.MUTED, UI.BODY, true)
	UI.label(page, UI.text("transition.day_to_night") if fall else UI.text("transition.night_to_day"), Rect2(352, 622, 730, 30), 15, UI.PINK, UI.MONO)
	UI.button(page, UI.text("button.open_door") if fall else UI.text("button.start_day"), Rect2(352, 697, 730, 59), func() -> void: EventBus.request("next"), true)
	if not reduced_motion:
		page.modulate.a = 0.0
		page.create_tween().tween_property(page, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _ending() -> void:
	var ending: Dictionary = view.ending
	UI.box(main, Rect2(40, 552, 1360, 286), Color("211b28"), Color("795567"))
	UI.label(main, UI.text("ending.heading", {"number": ending.get("number", ""), "subtitle": ending.get("subtitle", "")}), Rect2(74, 570, 1210, 28), 14, UI.GOLD, UI.MONO)
	UI.label(main, ending.get("title", ""), Rect2(71, 604, 1170, 58), 46, UI.INK, UI.ITALIC)
	var text: String = ending.get("text", "")
	if ending.get("variant", "") == "errors":
		text += "\n" + ending.get("errors", "")
	UI.label(main, text, Rect2(76, 672, 1280, 104), 21, UI.INK, UI.BODY, true)
	UI.button(main, UI.text("button.new_story"), Rect2(1127, 781, 231, 39), _new_game, true)
	UI.label(main, UI.text("ending.cup_count", {"count": view.served}), Rect2(76, 786, 870, 27), 17, UI.MUTED, UI.BODY)

func _toggle_book() -> void:
	if not view.started or view.phase in ["ending", "fall", "dawn"]:
		return
	if modal == "book":
		_close_modal()
	else:
		modal = "book"
		_render_modal()

func _toggle_dossier() -> void:
	if not view.started or view.day < 2 or view.phase == "ending":
		return
	if modal == "dossier":
		_close_modal()
	else:
		modal = "dossier"
		_render_modal()

func _close_modal() -> void:
	var closing_book := modal == "book"
	modal = ""
	UI.clear(overlay)
	if closing_book:
		EventBus.request("book_closed")

func _render_modal() -> void:
	UI.clear(overlay)
	if modal.is_empty():
		return
	if modal == "book":
		book = RecipeBook.new()
		overlay.add_child(book)
		book.size = Vector2(1440, 900)
		book.setup(view, _close_modal, book_page)
	elif modal == "dossier":
		dossier = DossierPanel.new()
		overlay.add_child(dossier)
		dossier.size = Vector2(1440, 900)
		dossier.setup(view, _close_modal)
		if dossier_selection != "":
			dossier.selected_id = dossier_selection
			dossier._render()
	else:
		_simple_modal()

func _simple_modal() -> void:
	var blocker := ColorRect.new()
	blocker.color = Color(0.03, 0.025, 0.045, 0.93)
	blocker.size = Vector2(1440, 900)
	overlay.add_child(blocker)
	UI.box(overlay, Rect2(345, 154, 750, 593), Color("231e2c"), Color("7d6674"))
	UI.label(overlay, {"menu": UI.text("menu.title"), "help": UI.text("help.title"), "confirm_new": UI.text("confirm.title")}.get(modal, ""), Rect2(388, 189, 660, 69), 46, UI.INK, UI.ITALIC)
	if modal == "help":
		UI.label(overlay, UI.text("help.body"), Rect2(390, 280, 660, 366), 22, UI.INK, UI.BODY, true)
	elif modal == "confirm_new":
		UI.label(overlay, UI.text("confirm.body"), Rect2(390, 300, 650, 150), 26, UI.INK, UI.BODY, true)
		UI.button(overlay, UI.text("button.start_endless") if new_mode == "endless" else UI.text("button.start_story"), Rect2(390, 491, 660, 54), func() -> void: _start("new_game", new_mode), true)
	else:
		UI.label(overlay, UI.text("menu.auto_save"), Rect2(390, 286, 650, 35), 22, UI.MUTED)
		UI.button(overlay, UI.text("menu.sound_off" if muted else "menu.sound_on"), Rect2(390, 346, 660, 53), _toggle_sound)
		UI.button(overlay, UI.text("menu.motion_reduced" if reduced_motion else "menu.motion_normal"), Rect2(390, 414, 660, 53), _toggle_motion)
		UI.button(overlay, UI.text("button.new_story"), Rect2(390, 482, 660, 53), _new_game)
		UI.button(overlay, UI.text("button.new_endless"), Rect2(390, 550, 660, 53), func() -> void: _new_game("endless"))
	UI.button(overlay, UI.text("button.back"), Rect2(390, 664, 660, 48), _close_modal, true)

func _toggle_sound() -> void:
	muted = not muted
	ambience.stream_paused = muted
	if not muted and not ambience.playing and ambience.stream:
		ambience.play()
	_render_modal()

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	art.reduced_motion = reduced_motion
	art.queue_redraw()
	_render_modal()

func _feedback(message: String) -> void:
	toast.text = message
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(4.5)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.2)

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		if modal != "":
			_close_modal()
		else:
			modal = "menu"
			_render_modal()
	elif key == KEY_B:
		_toggle_book()
	elif key == KEY_G:
		_toggle_dossier()
	elif modal != "" or not view.started:
		return
	elif key in [KEY_SPACE, KEY_ENTER] and view.stage in ["dialogue", "reaction", "decision", "transition"]:
		EventBus.request("next")
	elif key == KEY_E:
		EventBus.request("brew")
	elif key == KEY_F:
		EventBus.request("serve")
	elif key == KEY_R:
		EventBus.request("clear")
	elif key == KEY_C:
		EventBus.request("photo")
	elif key == KEY_M:
		EventBus.request("shelf")
	elif key >= KEY_1 and key <= KEY_6:
		var ingredients: Array = view.ingredients.filter(func(item: Dictionary) -> bool: return item.side == view.shelf)
		EventBus.request("select", {"id": ingredients[key - KEY_1].id})
	else:
		return
	get_viewport().set_input_as_handled()
