extends Control
class_name TopdownMenu
## 2.5D HD Barista Tezgâhı Ana Menü Ekranı (Hikâye, Endless, Ayarlar).
## Arka planda hafif blurlu/bokeh barista tezgâhı ve kafe atmosferi,
## Ön planda ultra keskin 2.5D fincanlar ve gövdeye basılı etiketler.
## DDD mimarisi: Seçim durumları ve kuralları MenuDirector / MenuCup tarafından yönetilir.

signal start_requested(action: String, mode: String)
signal new_game_requested(mode: String)
signal settings_requested()
signal save_select_requested()

const MenuDirectorScript = preload("res://domain/menu/menu_director.gd")
const TopdownCupScene = preload("res://presentation/menu/topdown_cup.tscn")
const KettleCursorScript = preload("res://presentation/menu/kettle_cursor.gd")

var director: RefCounted = null
var view_state: Dictionary = {}
var has_save: bool = false
var pouring_cup_id: String = ""
var is_holding_pour: bool = false
var selection_locked: bool = false
## Mıknatıs: fare bir bardağın kenarına bu kadar yaklaşınca demlik o bardağın üstüne hizalanır.
## Bardak arası 120 px; alanlar çakışmaz, çakışırsa en yakın bardak kazanır.
const SNAP_MARGIN := 50.0
## Demliğin ağzı bardak ağzının tam üstünde, bu kadar yukarıda durur: akış dümdüz iner ve
## demliğin gövdesi (ağzın ~200 px altına uzanır) fincanın kenarına pek binmez.
const SNAP_SPOUT_OFFSET := Vector2(0, -150)
var snapped_cup_id: String = ""

@onready var story_cup: TopdownCup = $Cups/StoryCup
@onready var endless_cup: TopdownCup = $Cups/EndlessCup
@onready var settings_cup: TopdownCup = $Cups/SettingsCup
@onready var kettle: KettleCursor = $KettleCursor
@onready var hint_label: Label = $Footer/HintLabel
@onready var title_label: Label = $Header/TitleLabel
@onready var tagline_label: Label = $Header/TaglineLabel

# Blurlu arka plan bokeh ışıkları (Hafif alan derinliği simülasyonu)
const BOKEH_LIGHTS: Array[Dictionary] = [
	{"pos": Vector2(240, 150), "r": 70.0, "color": Color(1.0, 0.72, 0.38, 0.14)},
	{"pos": Vector2(460, 230), "r": 48.0, "color": Color(1.0, 0.85, 0.48, 0.12)},
	{"pos": Vector2(700, 130), "r": 92.0, "color": Color(1.0, 0.68, 0.30, 0.16)},
	{"pos": Vector2(960, 210), "r": 58.0, "color": Color(1.0, 0.88, 0.52, 0.15)},
	{"pos": Vector2(1220, 140), "r": 82.0, "color": Color(1.0, 0.70, 0.32, 0.15)},
	{"pos": Vector2(1480, 240), "r": 52.0, "color": Color(1.0, 0.82, 0.44, 0.13)},
	{"pos": Vector2(1720, 160), "r": 78.0, "color": Color(1.0, 0.75, 0.36, 0.15)},
	{"pos": Vector2(360, 310), "r": 36.0, "color": Color(0.9, 0.65, 0.35, 0.10)},
	{"pos": Vector2(1580, 310), "r": 40.0, "color": Color(0.9, 0.65, 0.35, 0.10)},
]

## Arka plan resmi (fincanlar bu resmin içinde çizili; konumları menü sahnesinde).
const MENU_BG_PATHS := ["res://assets/menu/background.png", "res://assets/menu/background.jpg"]
var custom_bg_texture: Texture2D = null

func _ready() -> void:
	director = MenuDirectorScript.new()
	_check_custom_background()
	# Yazılar resmin boyalı dokusuna uysun: başlık eski duvar boyası, diğerleri hafif aşınmış.
	title_label.material = PaintMaterial.make(0.32, 0.22)
	tagline_label.material = PaintMaterial.make(0.22, 0.08)
	hint_label.material = PaintMaterial.make(0.15, 0.04)
	_setup_ui_strings()
	_connect_cup(story_cup, "story")
	_connect_cup(endless_cup, "endless")
	_connect_cup(settings_cup, "settings")
	set_kettle_active(true)

func _check_custom_background() -> void:
	custom_bg_texture = null
	for path: String in MENU_BG_PATHS:
		if ResourceLoader.exists(path):
			custom_bg_texture = load(path)
			return

func _setup_ui_strings() -> void:
	title_label.text = I18n.t("app.title")
	tagline_label.text = I18n.t("app.tagline")
	hint_label.text = I18n.t("menu.pour_hint")

	var story_title: String = I18n.t("menu.story")
	var story_sub: String = I18n.t("menu.save_select")
	story_cup.set_cup_data("story", story_title, story_sub)
	endless_cup.set_cup_data("endless", I18n.t("menu.endless"), I18n.t("menu.endless_sub"))
	settings_cup.set_cup_data("settings", I18n.t("menu.settings"), I18n.t("menu.settings_sub"))

func setup_view(view: Dictionary) -> void:
	view_state = view
	has_save = view.get("has_save", false)
	_setup_ui_strings()

func _connect_cup(cup: TopdownCup, id: String) -> void:
	cup.cup_id = id
	cup.pour_started.connect(func(c: TopdownCup) -> void: _start_pouring(c.cup_id))
	cup.pour_ended.connect(func(c: TopdownCup) -> void: _stop_pouring(c.cup_id))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and kettle:
		kettle.pointer = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Bardağın kendisine değil, çevresindeki mıknatıs alanına basıldıysa da dökmeye başla.
			if not is_holding_pour and snapped_cup_id != "":
				_start_pouring(snapped_cup_id)
		elif is_holding_pour:
			_stop_pouring(pouring_cup_id)

## Fareye en yakın, mıknatıs alanı içindeki bardağı seçer ve demliği ona kilitler.
## Alandan çıkınca dökme durur (bardağın kendi düğmesinden çıkmak artık durdurmaz).
func _update_snap() -> void:
	var mouse: Vector2 = kettle.pointer if kettle else get_global_mouse_position()
	var nearest: TopdownCup = null
	for cup: TopdownCup in [story_cup, endless_cup, settings_cup]:
		if cup and cup.get_global_rect().grow(SNAP_MARGIN).has_point(mouse):
			if nearest == null or _cup_mouth(cup).distance_to(mouse) < _cup_mouth(nearest).distance_to(mouse):
				nearest = cup
	snapped_cup_id = nearest.cup_id if nearest else ""
	if is_holding_pour and pouring_cup_id != snapped_cup_id:
		_stop_pouring(pouring_cup_id)
	if kettle:
		kettle.snap_spout = (_cup_mouth(nearest) + SNAP_SPOUT_OFFSET) if nearest else Vector2.INF

func _cup_mouth(cup: TopdownCup) -> Vector2:
	return cup.global_position + cup.get_cup_center()

func _start_pouring(cup_id: String) -> void:
	if selection_locked:
		return
	pouring_cup_id = cup_id
	is_holding_pour = true
	var active_cup: TopdownCup = _get_cup_by_id(cup_id)
	if active_cup:
		active_cup.is_pouring = true
	if active_cup and kettle:
		kettle.is_pouring = true
		kettle.target_cup_pos = active_cup.global_position + active_cup.get_pour_point()

func _stop_pouring(cup_id: String) -> void:
	if pouring_cup_id == cup_id:
		is_holding_pour = false
		pouring_cup_id = ""
	if kettle:
		kettle.is_pouring = false
	var cup: TopdownCup = _get_cup_by_id(cup_id)
	if cup:
		cup.is_pouring = false

func _process(delta: float) -> void:
	if selection_locked or director == null:
		return
	_update_snap()
	# Akış yükselen kahve yüzeyine düşer.
	var pouring_cup: TopdownCup = _get_cup_by_id(pouring_cup_id)
	if pouring_cup and kettle:
		kettle.target_cup_pos = pouring_cup.global_position + pouring_cup.get_pour_point()

	# Doldurma ve boşalma durumunu domain servisinde güncelle
	var resolution: Dictionary = director.update_pouring(pouring_cup_id, is_holding_pour, delta, has_save)

	# Fincanların görsel ilerlemesini domain modelinden senkronize et
	for cup_obj: RefCounted in director.get_all_cups():
		var ui_cup: TopdownCup = _get_cup_by_id(cup_obj.id)
		if ui_cup:
			ui_cup.fill_progress = cup_obj.get_progress()

	# Seçim tamamlandı mı?
	if not resolution.is_empty():
		_handle_selection_completed(resolution)

func _handle_selection_completed(resolution: Dictionary) -> void:
	selection_locked = true
	is_holding_pour = false
	if kettle:
		kettle.is_pouring = false

	# Tamamlanma geri bildirimi: fincanı parlat
	var chosen_cup: TopdownCup = _get_cup_by_id(pouring_cup_id)
	if chosen_cup:
		chosen_cup.is_pouring = false
		chosen_cup.fill_progress = 1.0

	# 0.25 saniye tatmin edici gecikme ile komutu fırlat
	await get_tree().create_timer(0.25).timeout

	match resolution.get("type", ""):
		"save_select":
			save_select_requested.emit()
			selection_locked = false
			reset_menu()
		"start":
			var action: String = resolution.get("action", "new_game")
			var mode: String = resolution.get("mode", "story")
			if action == "new_game" and mode == "endless":
				new_game_requested.emit("endless")
			else:
				start_requested.emit(action, mode)
		"modal":
			settings_requested.emit()
			selection_locked = false
			reset_menu()

func reset_menu() -> void:
	selection_locked = false
	is_holding_pour = false
	pouring_cup_id = ""
	if director:
		director.reset_all()
	for cup: TopdownCup in [story_cup, endless_cup, settings_cup]:
		if cup:
			cup.fill_progress = 0.0
			cup.is_pouring = false
	if kettle:
		kettle.is_pouring = false

func _get_cup_by_id(id: String) -> TopdownCup:
	match id:
		"story": return story_cup
		"endless": return endless_cup
		"settings": return settings_cup
	return null

func set_kettle_active(active: bool) -> void:
	if kettle:
		kettle.active = active
	if active:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and visible and kettle and kettle.active:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

# --- Blurlu Barista Tezgâhı Çizimi ------------------------------------------

func _draw() -> void:
	# 0. Harici özel arka plan çizimi varsa doğrudan onu kullan
	if custom_bg_texture:
		draw_texture_rect(custom_bg_texture, Rect2(Vector2.ZERO, size), false)
		return

	# 1. Uzak Kafe Derinliği (Üst alan - y: 0 ile 420 arası)
	draw_rect(Rect2(0, 0, size.x, 430), Color("100b0e"))

	# Blurlu kafe rafları silueti
	draw_rect(Rect2(0, 160, size.x, 14), Color("181216"))
	draw_rect(Rect2(0, 260, size.x, 12), Color("181216"))
	# Şişe ve fincan siluetleri (Hafif alan derinliğinde odak dışı)
	for bx in [280, 310, 335, 780, 810, 1340, 1370, 1400]:
		draw_rect(Rect2(bx, 195, 20, 65), Color("1e161c", 0.6))
	# Espresso makinesi silueti (Ortada odak dışı siluet)
	draw_rect(Rect2(860, 250, 200, 170), Color("171115"))
	draw_circle(Vector2(930, 320), 18.0, Color("e89a42", 0.15)) # Basınç göstergesi parıltısı

	# 2. Optik Lens Bokeh Işıkları (Creamy bokeh discs)
	for b in BOKEH_LIGHTS:
		var bp: Vector2 = b.pos
		var br: float = b.r
		var bc: Color = b.color
		for l in range(3):
			var step_r: float = br * (1.0 - float(l) * 0.28)
			var step_a: float = bc.a * (0.5 + float(l) * 0.3)
			draw_circle(bp, step_r, Color(bc.r, bc.g, bc.b, step_a))

	# 3. Tezgâh Kenarı / Ufuk Çizgisi (Sıcak ışık sızıntısı)
	draw_rect(Rect2(0, 418, size.x, 12), Color("38241b", 0.5))
	draw_line(Vector2(0, 424), Vector2(size.x, 424), Color("c87e42", 0.35), 2.0)

	# 4. Barista Ahşap Tezgâhı (y: 424 ile 1080 arası)
	draw_rect(Rect2(0, 424, size.x, size.y - 424), Color("140e0b"))

	# Ahşap kalaslar ve vernik yansımaları
	var plank_h: float = 130.0
	var start_y: float = 424.0
	var plank_idx: int = 0
	while start_y < size.y:
		var p_col: Color = Color("17100d") if plank_idx % 2 == 0 else Color("140e0b")
		draw_rect(Rect2(0, start_y, size.x, plank_h - 2), p_col)
		# Kalas ayrım derzi
		draw_line(Vector2(0, start_y + plank_h - 1), Vector2(size.x, start_y + plank_h - 1), Color("090605", 0.9), 2.0)
		# İnce ahşap damarları (Odak derinliğine uygun yumuşaklık)
		draw_line(Vector2(0, start_y + 4), Vector2(size.x, start_y + 4), Color("241712", 0.35), 1.2)
		start_y += plank_h
		plank_idx += 1

	# Tavan lambalarının ahşap tezgâhtaki düşey vernik yansımaları
	for vx in [460.0, 960.0, 1460.0]:
		for vr in range(4):
			var w: float = 120.0 + float(vr) * 50.0
			var a: float = 0.04 - float(vr) * 0.009
			draw_rect(Rect2(vx - w * 0.5, 424, w, size.y - 424), Color(1.0, 0.78, 0.45, maxf(a, 0.0)))

	# 5. Fincanların Altındaki Barista Matı (Deri / Kauçuk Servis Matı)
	var mat_rect := Rect2(200, 560, size.x - 400, 260)
	draw_rect(mat_rect, Color("0c0a0d", 0.72))
	# Mat dikiş / kenar çizgisi
	draw_rect(mat_rect, Color("282026", 0.5), false, 2.0)

	# Fincanlara odaklanan sıcak tezgâh spot ışığı
	var center_spot := Vector2(size.x * 0.5, 680.0)
	for r in range(5):
		var radius: float = 340.0 + float(r) * 160.0
		var alpha: float = 0.08 - float(r) * 0.015
		draw_circle(center_spot, radius, Color(1.0, 0.78, 0.45, maxf(alpha, 0.0)))

	# 6. Tezgâhta Serpili Kavrulmuş Kahve Çekirdekleri (Detay)
	_draw_coffee_bean(Vector2(180, 520), 0.3)
	_draw_coffee_bean(Vector2(210, 535), -0.5)
	_draw_coffee_bean(Vector2(1740, 510), 0.7)
	_draw_coffee_bean(Vector2(1710, 540), -0.2)

	# 7. Sinematik Kenar Vinyeti
	draw_rect(Rect2(0, 0, size.x, 80), Color(0.04, 0.03, 0.05, 0.75))
	draw_rect(Rect2(0, size.y - 80, size.x, 80), Color(0.04, 0.03, 0.05, 0.75))

## 2.5D Kavrulmuş kahve çekirdeği çizimi
func _draw_coffee_bean(pos: Vector2, angle: float) -> void:
	var rx: float = 9.0
	var ry: float = 6.0
	var bean_col := Color("22140e")
	var crease_col := Color("0d0604")
	# Gölge
	draw_circle(pos + Vector2(2, 4), rx * 0.9, Color(0, 0, 0, 0.4))
	# Gövde
	var points := PackedVector2Array()
	for i in range(24):
		var a: float = (TAU * float(i)) / 24.0
		var p: Vector2 = Vector2(rx * cos(a), ry * sin(a)).rotated(angle)
		points.append(pos + p)
	draw_colored_polygon(points, bean_col)
	# Çekirdek ortasındaki kıvrımlı yarık çizgisi
	var c_start: Vector2 = pos + Vector2(-rx * 0.75, 0).rotated(angle)
	var c_mid: Vector2 = pos + Vector2(0, 1.5).rotated(angle)
	var c_end: Vector2 = pos + Vector2(rx * 0.75, 0).rotated(angle)
	draw_polyline(PackedVector2Array([c_start, c_mid, c_end]), crease_col, 1.5)
