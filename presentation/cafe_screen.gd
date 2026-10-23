extends Control
## Sunum orkestrası: snapshot'ı sahnelere dağıtır, girdileri EventBus komutlarına çevirir.
## Domain durumu değiştirmez. Sahneler kalıcıdır; her durumda yeniden kurulmaz.
const Balloon = preload("res://presentation/dialogue/speech_balloon.gd")
const SPEED_ORDER: Array[String] = ["slow", "normal", "fast"]
const TOAST_TIME := 4.0
const AMBIENCE_DB := -18.0
var view: Dictionary = {}
var modal: String = ""
var book_page: String = "human"
var phone_selection: String = ""
var pending_mode: String = "story"
var muted: bool = false
var reduced_motion: bool = false
var record_count: int = 0
var toast_tween: Tween
@onready var world: Control = $World
@onready var balloon: Control = $Balloon
@onready var brew_panel: Control = $BrewPanel
@onready var book: Control = $RecipeBook
@onready var phone: Control = $Phone
@onready var screens: Control = $Screens
@onready var flash: ColorRect = $Flash
@onready var toast: Label = $Toast
@onready var hud: Control = $Hud
@onready var day_text: Label = $Hud/DayText
@onready var top_right: Control = $Hud/TopRight
@onready var auto_button: Button = $Hud/TopRight/AutoButton
@onready var ffwd_button: Button = $Hud/TopRight/FfwdButton
@onready var phone_button: Button = $Hud/BottomLeft/PhoneButton
@onready var photo_button: Button = $Hud/BottomLeft/PhotoButton
@onready var book_button: Button = $Hud/BottomRight/BookButton
@onready var menu_button: Button = $Hud/BottomRight/MenuButton
@onready var ambience: AudioStreamPlayer = $Ambience

func _ready() -> void:
	book.hide()
	phone.hide()
	flash.modulate.a = 0.0
	toast.modulate.a = 0.0
	_setup_hud()
	_setup_ambience()
	# Oyun fare + kısayolla oynanır. Tıklanan buton odağı tutarsa Boşluk/Enter konuşmayı
	# ilerletmek yerine o butonu tekrar basar (AUTO kapanır, aynı kavanoz yeniden eklenir).
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control is BaseButton:
			control.release_focus())
	balloon.advance_requested.connect(func() -> void: EventBus.request("next"))
	balloon.decision_pressed.connect(func() -> void: EventBus.request("next"))
	balloon.line_started.connect(func() -> void: world.character.bounce())
	book.closed.connect(_close_modal)
	phone.closed.connect(_close_modal)
	screens.start_requested.connect(_start)
	screens.new_game_requested.connect(_new_game)
	screens.next_requested.connect(func() -> void: EventBus.request("next"))
	screens.modal_closed.connect(_close_modal)
	screens.sound_toggled.connect(_toggle_sound)
	screens.motion_toggled.connect(_toggle_motion)
	screens.speed_cycled.connect(_cycle_speed)
	EventBus.state_changed.connect(_on_state)
	EventBus.feedback.connect(_feedback)
	I18n.language_changed.connect(func(_locale: String) -> void: EventBus.request("refresh"))
	EventBus.request("refresh")

func _setup_hud() -> void:
	auto_button.text = I18n.t("hud.auto")
	ffwd_button.text = I18n.t("hud.ffwd")
	photo_button.text = I18n.t("hud.photo")
	phone_button.text = I18n.t("hud.phone")
	book_button.text = I18n.t("hud.book")
	menu_button.text = I18n.t("hud.menu")
	auto_button.toggled.connect(func(on: bool) -> void: balloon.auto = on)
	ffwd_button.toggled.connect(func(on: bool) -> void: balloon.fast_forward = on)
	photo_button.pressed.connect(func() -> void: EventBus.request("photo"))
	phone_button.pressed.connect(_toggle_phone)
	book_button.pressed.connect(_toggle_book)
	menu_button.pressed.connect(func() -> void: _open_modal("menu"))

func _setup_ambience() -> void:
	if not ResourceLoader.exists("res://assets/audio/rain.wav"):
		return
	ambience.stream = load("res://assets/audio/rain.wav")
	if ambience.stream is AudioStreamWAV:
		ambience.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambience.stream.loop_end = int(ambience.stream.get_length() * ambience.stream.mix_rate)
	ambience.volume_db = AMBIENCE_DB

# --- Snapshot → sahneler ---------------------------------------------------

func _on_state(snapshot: Dictionary) -> void:
	view = snapshot
	var covered: bool = screens.apply(view)
	var playing: bool = view.started and not covered
	hud.visible = playing
	if view.phase == "ending" or not view.started:
		_close_modal()
	world.set_night(view.phase in ["fall", "night", "night_supplier", "ending"])
	_update_hud()
	if playing:
		var key := "%d|%s|%d|%s" % [view.day, view.phase, view.visit_index, view.person.get("id", "")]
		world.show_person(view.person, key)
	else:
		world.hide_person()
	brew_panel.apply(view if playing else {})
	world.focus_brew(brew_panel.is_open)
	_update_balloon(playing)
	if playing and view.stage == "reaction":
		world.show_cup(view.drink.get("color", ""))
	else:
		world.hide_cup()
	if view.records.size() > record_count:
		_camera_flash()
	record_count = view.records.size()
	if modal == "book":
		book.refresh(view)
	elif modal == "phone":
		phone.refresh(view)

func _update_hud() -> void:
	if not view.started:
		return
	var day_key := "header.endless_day" if view.mode == "endless" else "header.story_day"
	var day := I18n.t(day_key, {"day": "%02d" % view.day, "total": "%02d" % view.total_days})
	day_text.text = I18n.t("hud.day_phase", {"day": day, "phase": I18n.t("phase." + view.phase)})
	# Demlerken üst köşeler sipariş şeridine ve makineye kalır.
	var brewing: bool = view.stage in ["brewing", "tutorial"]
	day_text.visible = not brewing
	top_right.visible = not brewing
	photo_button.visible = view.day >= 2 and view.phase in ["day", "night"]
	photo_button.disabled = view.stage == "reaction"
	phone_button.visible = view.day >= 2

func _update_balloon(playing: bool) -> void:
	if not playing or view.line == "":
		balloon.close()
		return
	var speaker: String = view.person.get("name", I18n.t("character.barista"))
	var mode: int = Balloon.Mode.ADVANCE
	var hint := ""
	match view.stage:
		"brewing", "tutorial":
			mode = Balloon.Mode.STATIC
		"decision":
			mode = Balloon.Mode.DECISION
			hint = I18n.t("balloon.decision_hint") if view.day >= 2 else ""
	if view.stage == "tutorial":
		speaker = I18n.t("character.barista")
	var key := "%d|%s|%d|%s|%d|%s" % [view.day, view.phase, view.visit_index, view.stage, view.line_index, view.line]
	balloon.docked = mode == Balloon.Mode.STATIC
	balloon.point_at(world.balloon_point())
	balloon.say(speaker, view.line, mode, key, hint, I18n.t("button.finish_delivery"))

# --- Komutlar ve pencereler -------------------------------------------------

func _start(action: String, mode: String) -> void:
	_close_modal()
	if not muted and ambience.stream and not ambience.playing:
		ambience.play()
	EventBus.request(action, {"mode": mode})

func _new_game(mode: String) -> void:
	pending_mode = mode
	if view.get("has_save", false):
		_open_modal("confirm_new")
	else:
		_start("new_game", mode)

func _open_modal(kind: String) -> void:
	_close_modal()
	modal = kind
	screens.open_modal(kind, {"mode": pending_mode, "muted": muted, "reduced_motion": reduced_motion, "speed": balloon.speed})

func _close_modal() -> void:
	var closing_book := modal == "book"
	if modal == "phone":
		phone_selection = phone.selected_id
	if modal == "book":
		book_page = book.page
	modal = ""
	book.hide()
	phone.hide()
	screens.close_modal()
	if closing_book:
		EventBus.request("book_closed")

func _toggle_book() -> void:
	if not view.get("started", false) or view.phase in ["ending", "fall", "dawn"]:
		return
	if modal == "book":
		_close_modal()
		return
	_close_modal()
	modal = "book"
	book.show()
	book.open(view, book_page)

func _toggle_phone() -> void:
	if not view.get("started", false) or view.day < 2 or view.phase == "ending":
		return
	if modal == "phone":
		_close_modal()
		return
	_close_modal()
	modal = "phone"
	phone.show()
	phone.open(view, phone_selection)

func _toggle_sound() -> void:
	muted = not muted
	ambience.stream_paused = muted
	if not muted and ambience.stream and not ambience.playing:
		ambience.play()
	_open_modal("menu")

func _toggle_motion() -> void:
	reduced_motion = not reduced_motion
	for node: Node in [world, balloon, brew_panel, screens]:
		node.reduced_motion = reduced_motion
	_open_modal("menu")

func _cycle_speed() -> void:
	balloon.speed = SPEED_ORDER[(SPEED_ORDER.find(balloon.speed) + 1) % SPEED_ORDER.size()]
	_open_modal("menu")

func _camera_flash() -> void:
	if reduced_motion:
		return
	flash.modulate.a = 0.85
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.3)

func _feedback(message: String) -> void:
	toast.text = message
	if toast_tween:
		toast_tween.kill()
	toast.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_interval(TOAST_TIME)
	toast_tween.tween_property(toast, "modulate:a", 0.0, 0.25)

# --- Girdi -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Coffee Talk gibi: sahnenin herhangi bir yerine tıklamak konuşmayı ilerletir.
		if modal == "" and balloon.try_advance():
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_ESCAPE:
		if modal != "":
			_close_modal()
		else:
			_open_modal("menu")
	elif key == KEY_B:
		_toggle_book()
	elif key == KEY_G:
		_toggle_phone()
	elif modal != "" or not view.get("started", false):
		return
	elif key in [KEY_SPACE, KEY_ENTER]:
		if view.stage == "transition":
			EventBus.request("next")
		elif not balloon.try_advance() and view.stage == "decision":
			EventBus.request("next")
	elif key == KEY_A:
		auto_button.button_pressed = not auto_button.button_pressed
	elif brew_panel.busy:
		return
	elif key == KEY_E:
		EventBus.request("brew")
	elif key == KEY_F:
		EventBus.request("serve")
	elif key == KEY_T:
		EventBus.request("trash")
	elif key == KEY_R:
		EventBus.request("clear")
	elif key == KEY_C:
		EventBus.request("photo")
	elif key == KEY_M:
		EventBus.request("shelf")
	elif key >= KEY_1 and key <= KEY_9:
		brew_panel.select_index(key - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
