extends Control
## Sunum orkestrası: snapshot'ı sahnelere dağıtır, girdileri EventBus komutlarına çevirir.
## Domain durumu değiştirmez. Sahneler kalıcıdır; her durumda yeniden kurulmaz.
const Balloon = preload("res://presentation/dialogue/speech_balloon.gd")
const CaseFile = preload("res://presentation/ui/case_file.gd")
const Settings = preload("res://infrastructure/persistence/settings_repository.gd")
## Coffee Talk gibi: arayüz 1920×1080 tasarlanır, pencereye ölçeklenir, oran farklıysa siyah bant.
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)]
## Polaroid makinenin üst yarığından çıkar: yarığın kamera ikonundaki yeri ve çıkış mesafesi.
const EJECT_SLOT := Vector2(82, 24)
const EJECT_RISE := 150.0
const EJECT_TIME := 0.55
const SPEED_ORDER: Array[String] = ["slow", "normal", "fast"]
const TOAST_TIME := 4.0
const AMBIENCE_DB := -18.0
var view: Dictionary = {}
var modal: String = ""
var book_page: String = "human"
var files_selection: String = ""
var photo_busy: bool = false
var pending_mode: String = "story"
var muted: bool = false
var reduced_motion: bool = false
var settings: Dictionary = Settings.DEFAULTS.duplicate()
var record_count: int = 0
## Demleme ekranı (raf ya da çizgi roman sayfası) bir önceki güncellemede açık mıydı.
var was_brewing_ui: bool = false
var toast_tween: Tween
@onready var world: Control = $World
@onready var balloon: Control = $Balloon
@onready var brew_panel: Control = $BrewPanel
@onready var brew_comic: Control = $BrewComic
@onready var delivery: Control = $DeliveryTray
@onready var book: Control = $RecipeBook
@onready var case_file: Control = $CaseFile
@onready var screens: Control = $Screens
@onready var flash: ColorRect = $Flash
@onready var toast: Label = $Toast
@onready var hud: Control = $Hud
@onready var day_text: Label = $Hud/DayText
@onready var top_right: Control = $Hud/TopRight
@onready var auto_button: Button = $Hud/TopRight/AutoButton
@onready var ffwd_button: Button = $Hud/TopRight/FfwdButton
@onready var camera_button: Button = $Hud/BottomLeft/CameraButton
@onready var files_button: Button = $Hud/BottomLeft/FilesButton
@onready var eject_photo: Control = $Hud/EjectPhoto
@onready var book_button: Button = $Hud/BottomRight/BookButton
@onready var menu_button: Button = $Hud/BottomRight/MenuButton
@onready var ambience: AudioStreamPlayer = $Ambience

func _ready() -> void:
	book.hide()
	case_file.hide()
	flash.modulate.a = 0.0
	toast.modulate.a = 0.0
	_setup_hud()
	_setup_ambience()
	_load_settings()
	# Oyun fare + kısayolla oynanır. Tıklanan buton odağı tutarsa Boşluk/Enter konuşmayı
	# ilerletmek yerine o butonu tekrar basar (AUTO kapanır, aynı kavanoz yeniden eklenir).
	get_viewport().gui_focus_changed.connect(func(control: Control) -> void:
		if control is BaseButton:
			control.release_focus())
	balloon.advance_requested.connect(func() -> void: EventBus.request("next"))
	balloon.decision_pressed.connect(func() -> void: EventBus.request("next"))
	balloon.line_started.connect(func() -> void: world.character.bounce())
	balloon.question_pressed.connect(func(index: int) -> void:
		EventBus.request("answer_interrogation" if view.get("stage", "") == "questioning" else "ask", {"index": index}))
	balloon.mark_pressed.connect(func() -> void: EventBus.request("mark"))
	delivery.track(world, balloon.panel)
	delivery.report_requested.connect(func(record_id: String) -> void: EventBus.request("report", {"id": record_id}))
	delivery.finish_requested.connect(func() -> void: EventBus.request("next"))
	book.closed.connect(_close_modal)
	case_file.closed.connect(_close_modal)
	screens.start_requested.connect(_start)
	screens.new_game_requested.connect(_new_game)
	screens.settings_requested.connect(func() -> void: _open_modal("menu"))
	screens.next_requested.connect(func() -> void: EventBus.request("next"))
	screens.modal_closed.connect(_close_modal)
	screens.sound_toggled.connect(_toggle_sound)
	screens.motion_toggled.connect(_toggle_motion)
	screens.speed_cycled.connect(_cycle_speed)
	screens.fullscreen_toggled.connect(func() -> void:
		_toggle_fullscreen()
		_open_modal("settings"))
	screens.window_size_cycled.connect(_cycle_window_size)
	screens.page_requested.connect(_open_modal)
	screens.save_requested.connect(func(slot: int) -> void: EventBus.request("save_slot", {"slot": slot}))
	screens.load_requested.connect(func(slot: int) -> void:
		_close_modal()
		EventBus.request("load_slot", {"slot": slot}))
	screens.main_menu_requested.connect(func() -> void:
		_close_modal()
		EventBus.request("main_menu"))
	screens.quit_requested.connect(func() -> void: get_tree().quit())
	EventBus.state_changed.connect(_on_state)
	EventBus.feedback.connect(_feedback)
	I18n.language_changed.connect(func(_locale: String) -> void: EventBus.request("refresh"))
	EventBus.request("refresh")

func _setup_hud() -> void:
	auto_button.text = I18n.t("hud.auto")
	ffwd_button.text = I18n.t("hud.ffwd")
	camera_button.text = I18n.t("hud.photo")
	files_button.text = I18n.t("hud.files")
	book_button.text = I18n.t("hud.book")
	menu_button.text = I18n.t("hud.menu")
	auto_button.toggled.connect(func(on: bool) -> void: balloon.auto = on)
	ffwd_button.toggled.connect(func(on: bool) -> void: balloon.fast_forward = on)
	camera_button.pressed.connect(_take_photo)
	files_button.pressed.connect(_toggle_files)
	book_button.pressed.connect(_toggle_book)
	menu_button.pressed.connect(func() -> void: _open_modal("pause"))

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
	# Oyun içi pencereler (defter, dosyalar) oyun dışında kapanır; Esc menüsü açık kalabilir.
	if (view.phase == "ending" or not view.started) and modal in ["book", "files"]:
		_close_modal()
	world.set_night(view.phase in ["fall", "night", "night_supplier", "ending"])
	_update_hud()
	if playing:
		var key := "%d|%s|%d|%s" % [view.day, view.phase, view.visit_index, view.person.get("id", "")]
		world.show_person(view.person, key)
	else:
		world.hide_person()
	brew_panel.apply(view if playing else {})
	brew_comic.apply(view if playing else {})
	var brewing_ui: bool = brew_panel.is_open or brew_comic.is_open
	if brewing_ui and not was_brewing_ui and modal == "files" and not photo_busy:
		# Dava dosyası demleme ekranının üstünde çizilir; demlemeye geçilince kapanır.
		_close_modal()
	was_brewing_ui = brewing_ui
	if brew_comic.is_open:
		# Sayfa içeceği zaten gösteriyor; "hazır" bildirimi makine karesinin üstüne binmesin.
		toast.modulate.a = 0.0
	world.focus_brew(brew_panel.is_open)
	_update_balloon(playing)
	delivery.apply(view if playing else {})
	if playing and view.stage == "reaction":
		world.show_cup(view.drink.get("color", ""))
	else:
		world.hide_cup()
	var new_record: bool = view.records.size() > record_count
	record_count = view.records.size()
	if new_record and playing:
		_photo_taken(view.records.back())
	if modal == "book":
		book.refresh(view)
	elif modal == "files" and not photo_busy:
		case_file.refresh(view)
	elif modal in screens.PAGES:
		_render_modal()

func _update_hud() -> void:
	if not view.started:
		return
	var day_key := "header.endless_day" if view.mode == "endless" else "header.story_day"
	var day := I18n.t(day_key, {"day": "%02d" % view.day, "total": "%02d" % view.total_days})
	day_text.text = I18n.t("hud.day_phase", {"day": day, "phase": I18n.t("phase." + view.phase)})
	# Demlerken sol üst köşe sipariş şeridine kalır; AUTO/FFWD her zaman görünür ve erişilebilir.
	var brewing: bool = view.stage in ["brewing", "tutorial"]
	day_text.visible = not brewing
	# Makine tezgâhta durur; yalnızca müşteri karşındayken çekebilirsin.
	camera_button.visible = view.day >= 2
	camera_button.disabled = view.phase not in ["day", "night"] or view.stage == "reaction"
	files_button.visible = view.day >= 2

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
			# Teslim tepsisi açıkken bitirme ve ipucu tepside; balon yalnızca soruyu taşır.
			hint = "" if delivery.wants(view) else (I18n.t("balloon.decision_hint") if view.day >= 2 else "")
		"interview":
			# Kısayol ipucu soru listesinin altında (balloon.questions_left); alt satır yalnızca düğmeler.
			mode = Balloon.Mode.DECISION
		"questioning":
			# Cevap seçilmeden ilerlenmez; düğme yok, yalnızca cevaplar.
			mode = Balloon.Mode.DECISION
	if view.stage == "tutorial":
		speaker = I18n.t("character.barista")
	var key := "%d|%s|%d|%s|%d|%s" % [view.day, view.phase, view.visit_index, view.stage, view.line_index, view.line]
	balloon.docked = mode == Balloon.Mode.STATIC
	balloon.point_at(world.balloon_point())
	var decision_text := ""
	match view.stage:
		"interview": decision_text = I18n.t("button.to_order")
		"decision": decision_text = "" if delivery.wants(view) else I18n.t("button.finish_delivery")
	balloon.say(speaker, view.line, mode, key, hint, decision_text)
	var can_mark: bool = view.phase in ["day", "night"] and view.stage in ["dialogue", "answer", "interview"]
	balloon.set_interview(view.get("questions", []), int(view.get("questions_left", 0)), view.get("marked", false), can_mark)

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
	_render_modal()

func _render_modal() -> void:
	var can_save: bool = view.get("started", false) and view.get("phase", "") != "ending"
	screens.open_modal(modal, {"mode": pending_mode, "muted": muted, "reduced_motion": reduced_motion, "speed": balloon.speed,
		"fullscreen": settings.fullscreen, "window_size": settings.window_size, "started": view.get("started", false),
		"can_save": can_save, "slots": view.get("slots", [])})

func _close_modal() -> void:
	var closing_book := modal == "book"
	if photo_busy:
		return
	if modal == "files":
		files_selection = case_file.selected_id
		case_file.dismiss()
	if modal == "book":
		book_page = book.page
	modal = ""
	book.hide()
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

func _toggle_files() -> void:
	if not view.get("started", false) or view.day < 2 or view.phase == "ending" or photo_busy:
		return
	if modal == "files":
		_close_modal()
		return
	_close_modal()
	modal = "files"
	case_file.open_archive(view, files_selection)

func _take_photo() -> void:
	if photo_busy or modal != "":
		return
	EventBus.request("photo")

## Flaş → polaroid makinenin yarığından çıkar → dava dosyası açılır ve fotoğraf yerine yapışır.
func _photo_taken(record: Dictionary) -> void:
	_close_modal()
	photo_busy = true
	modal = "files"
	files_selection = record.id
	_camera_flash()
	var start := camera_button.global_position + EJECT_SLOT - Vector2(eject_photo.size.x / 2.0, 0)
	eject_photo.get_node("Photo").texture = CaseFile.photo_texture(record)
	eject_photo.get_node("Photo").modulate = CaseFile.UNDEVELOPED
	eject_photo.global_position = start
	eject_photo.show()
	if not reduced_motion:
		var rise := create_tween()
		rise.tween_property(eject_photo, "global_position:y", start.y - EJECT_RISE, EJECT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		rise.tween_interval(0.25)
		await rise.finished
	var from := eject_photo.get_global_rect()
	eject_photo.hide()
	photo_busy = false
	case_file.present_new(view, record.id, from)

# --- Ayarlar -----------------------------------------------------------------

## Testler (persistence kapalı) oyuncunun ayar dosyasını okumaz ve yazmaz.
func _settings_enabled() -> bool:
	return Session.persistence_enabled

func _load_settings() -> void:
	if _settings_enabled():
		settings = Settings.read()
	muted = settings.muted
	balloon.speed = settings.text_speed
	_set_reduced_motion(settings.reduced_motion)
	if _settings_enabled():
		_apply_display()

func _save_settings() -> void:
	settings.muted = muted
	settings.reduced_motion = reduced_motion
	settings.text_speed = balloon.speed
	if _settings_enabled() and not Settings.write(settings):
		_feedback(I18n.t("error.settings_write"))

func _apply_display() -> void:
	var window := get_window()
	if settings.fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return
	window.mode = Window.MODE_WINDOWED
	# Tarayıcıda pencere yok: tuvalin boyutunu sayfa belirler, boyut vermek ölçeklemeyi bozar.
	if OS.has_feature("web"):
		return
	window.size = settings.window_size
	window.move_to_center()

func _toggle_fullscreen() -> void:
	settings.fullscreen = not settings.fullscreen
	_apply_display()
	_save_settings()

func _cycle_window_size() -> void:
	var index := WINDOW_SIZES.find(settings.window_size)
	settings.window_size = WINDOW_SIZES[(index + 1) % WINDOW_SIZES.size()]
	_apply_display()
	_save_settings()
	_open_modal("settings")

func _set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	for node: Node in [world, balloon, brew_panel, brew_comic, screens, case_file]:
		node.reduced_motion = value

func _toggle_sound() -> void:
	muted = not muted
	ambience.stream_paused = muted
	if not muted and ambience.stream and not ambience.playing:
		ambience.play()
	_save_settings()
	_open_modal("settings")

func _toggle_motion() -> void:
	_set_reduced_motion(not reduced_motion)
	_save_settings()
	_open_modal("settings")

func _cycle_speed() -> void:
	balloon.speed = SPEED_ORDER[(SPEED_ORDER.find(balloon.speed) + 1) % SPEED_ORDER.size()]
	_save_settings()
	_open_modal("settings")

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

## Teslim ekranında Boşluk/Enter önce teslimatçının süren cümlesini tamamlar (aşağıdaki genel dal), bitirmez.
func _skips_typing(key: int) -> bool:
	return key in [KEY_SPACE, KEY_ENTER] and balloon.is_typing() and not delivery.confirm.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_F11:
		_toggle_fullscreen()
	elif brew_comic.latte.is_open:
		# Latte art açıkken tuşlar önce ona gider (Esc = geri, Enter = servis).
		if not brew_comic.latte.handle_key(key):
			return
	elif modal == "" and delivery.is_active and not _skips_typing(key) and delivery.handle_key(key):
		pass
	elif key == KEY_ESCAPE:
		# Alt sayfadan menü listesine, listeden oyuna döner.
		if modal in screens.PAGES and modal != "pause" and view.get("started", false):
			_open_modal("pause")
		elif modal != "":
			_close_modal()
		else:
			_open_modal("pause")
	elif brew_comic.is_open:
		# Demleme sayfası açıkken yalnızca seçim yapılır.
		if key == KEY_F:
			brew_comic.choose("serve")
		elif key == KEY_T:
			brew_comic.choose("trash")
		elif key == KEY_L:
			brew_comic.choose("latte_art")
		else:
			return
	elif key == KEY_B:
		_toggle_book()
	elif key == KEY_G:
		_toggle_files()
	elif modal != "" or not view.get("started", false):
		return
	elif key in [KEY_SPACE, KEY_ENTER]:
		if view.stage == "transition":
			EventBus.request("next")
		elif not balloon.try_advance() and view.stage in ["decision", "interview"]:
			EventBus.request("next")
	elif key == KEY_A:
		auto_button.button_pressed = not auto_button.button_pressed
	elif key == KEY_E:
		EventBus.request("brew")
	elif key == KEY_R:
		EventBus.request("clear")
	elif key == KEY_C:
		_take_photo()
	elif key == KEY_M:
		EventBus.request("shelf")
	elif key == KEY_N:
		EventBus.request("mark")
	elif key >= KEY_1 and key <= KEY_9:
		if view.stage == "interview":
			EventBus.request("ask", {"index": key - KEY_1})
		elif view.stage == "questioning":
			EventBus.request("answer_interrogation", {"index": key - KEY_1})
		else:
			brew_panel.select_index(key - KEY_1)
	else:
		return
	get_viewport().set_input_as_handled()
