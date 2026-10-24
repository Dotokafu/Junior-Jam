extends Control
class_name TopdownCup
## 2.5D HD Kuşbakışı kahve bardağı / fincanı.
## Gerçekçi seramik gövde, açılı derinlik (2.5D), sıvı yansıması ve gövdeye basılı etiket.

signal pour_started(cup: TopdownCup)
signal pour_ended(cup: TopdownCup)

@export var cup_id: String = "story"
@export var title_text: String = "HİKÂYE"
@export var subtitle_text: String = ""
@export var custom_texture: Texture2D = null

var custom_texture_loaded: Texture2D = null

var fill_progress: float = 0.0:
	set(value):
		fill_progress = clampf(value, 0.0, 1.0)
		queue_redraw()

var is_hovered: bool = false
var is_pouring: bool = false
var ripple_time: float = 0.0
var steam_time: float = 0.0
var pulse_time: float = 0.0

# Kahve sıvı renkleri (Zengin ve gerçekçi espresso tonları)
const COLOR_TABLE_SHADOW := Color(0.02, 0.015, 0.03, 0.58)
const COLOR_COFFEE_DEEP := Color(0.12, 0.05, 0.02)
const COLOR_COFFEE_CREMA := Color(0.78, 0.54, 0.28, 0.92)
const COLOR_COFFEE_FOAM := Color(0.88, 0.68, 0.44, 0.8)
const COLOR_ACCENT_GOLD := Color(0.96, 0.82, 0.48)

@onready var button: Button = $Button
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

func _ready() -> void:
	custom_minimum_size = Vector2(280, 290)
	size = Vector2(280, 290)
	_check_custom_texture()
	_apply_palette()
	button.text = title_text
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)

func _check_custom_texture() -> void:
	if custom_texture != null:
		custom_texture_loaded = custom_texture
		return
	var path: String = "res://assets/menu/cup_%s.png" % cup_id
	if ResourceLoader.exists(path):
		custom_texture_loaded = load(path)
	else:
		custom_texture_loaded = null

func _process(delta: float) -> void:
	if is_pouring:
		ripple_time += delta * 6.0
		queue_redraw()
	if fill_progress > 0.05:
		steam_time += delta * 2.5
		queue_redraw()
	if is_hovered or is_pouring:
		pulse_time += delta * 4.0
		queue_redraw()

func _get_palette() -> Dictionary:
	match cup_id:
		"story":
			return {
				"body": Color("242028"),        # Döküm demir / mat obsidiyen seramik
				"rim_accent": Color("c87242"),  # Sıcak terakota ağız kenarı
				"saucer": Color("2a2530"),      # Koyu füme tabak
				"text_color": Color("fae2a8"),  # Sıcak altın varak baskı
				"highlight": Color("655b70")
			}
		"endless":
			return {
				"body": Color("483226"),        # Kavrulmuş fındık / mocha stoneware
				"rim_accent": Color("ede4d4"),  # Krem beyaz daldırma sır ağız
				"saucer": Color("3b281e"),      # Taş seramik tabak
				"text_color": Color("ffd78e"),  # Parlak altın baskı
				"highlight": Color("82604c")
			}
		"settings":
			return {
				"body": Color("202c30"),        # İskandinav arduvaz petrol yeşili
				"rim_accent": Color("d8b262"),  # Parlatılmış pirinç kenar
				"saucer": Color("1b2428"),      # Arduvaz tabak
				"text_color": Color("f4d89a"),  # Pirinç sarısı baskı
				"highlight": Color("48626c")
			}
		_:
			return {
				"body": Color("28242c"),
				"rim_accent": Color("c8a882"),
				"saucer": Color("26222a"),
				"text_color": Color("fae4b8"),
				"highlight": Color("585060")
			}

func _apply_palette() -> void:
	var pal: Dictionary = _get_palette()
	if title_label:
		title_label.text = title_text
		title_label.modulate = pal.text_color
	if subtitle_label:
		subtitle_label.text = subtitle_text
		subtitle_label.modulate = pal.text_color.lerp(Color.WHITE, 0.3)
	if button:
		button.text = title_text

func set_cup_data(p_id: String, p_title: String, p_subtitle: String = "") -> void:
	cup_id = p_id
	title_text = p_title
	subtitle_text = p_subtitle
	_check_custom_texture()
	_apply_palette()
	queue_redraw()

func get_cup_center() -> Vector2:
	# 2.5D fincan ağız elipsinin merkezi
	return Vector2(140.0, 95.0)

func _on_mouse_entered() -> void:
	is_hovered = true
	var pal: Dictionary = _get_palette()
	title_label.modulate = pal.text_color.lightened(0.25)
	queue_redraw()

func _on_mouse_exited() -> void:
	is_hovered = false
	# Dökmeyi menü durdurur: mıknatıs alanı bardaktan geniştir, düğmeden çıkmak alandan çıkmak değildir.
	var pal: Dictionary = _get_palette()
	title_label.modulate = pal.text_color
	queue_redraw()

func _on_button_down() -> void:
	is_pouring = true
	pour_started.emit(self)
	queue_redraw()

func _on_button_up() -> void:
	is_pouring = false
	pour_ended.emit(self)
	queue_redraw()

# --- 2.5D Çizim Yardımcıları -----------------------------------------------

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, segments: int = 36) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = (TAU * float(i)) / float(segments)
		points.append(center + Vector2(rx * cos(angle), ry * sin(angle)))
	draw_colored_polygon(points, color)

func _draw_ellipse_arc(center: Vector2, rx: float, ry: float, from_angle: float, to_angle: float, color: Color, width: float = 2.0, segments: int = 24) -> void:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(from_angle, to_angle, t)
		points.append(center + Vector2(rx * cos(angle), ry * sin(angle)))
	draw_polyline(points, color, width)

# --- 2.5D HD Çizim ---------------------------------------------------------

func _draw() -> void:
	var pal: Dictionary = _get_palette()
	var center_rim: Vector2 = Vector2(140.0, 95.0)
	var rx_rim: float = 72.0
	var ry_rim: float = 32.0

	var center_base: Vector2 = Vector2(140.0, 205.0)
	var rx_base: float = 54.0
	var ry_base: float = 24.0

	var center_saucer: Vector2 = Vector2(140.0, 218.0)
	var rx_saucer: float = 112.0
	var ry_saucer: float = 38.0

	# Harici özel fincan çizimi (assets/menu/cup_<id>.png) varsa onu kullan
	if custom_texture_loaded:
		draw_texture_rect(custom_texture_loaded, Rect2(Vector2.ZERO, size), false)
		_draw_liquid_and_progress(center_rim, rx_rim, ry_rim, center_saucer, rx_saucer, ry_saucer)
		return

	# 1. Tabak Gölgesi (Tezgâh üstünde 2.5D eliptik yumuşak gölge)
	_draw_ellipse(center_saucer + Vector2(0, 10), rx_saucer + 10.0, ry_saucer + 8.0, COLOR_TABLE_SHADOW)

	# 2. Tabak (2.5D Saucer)
	var saucer_col: Color = pal.saucer
	if is_hovered or is_pouring:
		saucer_col = saucer_col.lightened(0.08)
	_draw_ellipse(center_saucer, rx_saucer, ry_saucer, saucer_col)
	# Tabak iç çukuru ve kenar parıltısı
	_draw_ellipse(center_saucer - Vector2(0, 2), rx_saucer * 0.78, ry_saucer * 0.75, saucer_col.darkened(0.18))
	_draw_ellipse_arc(center_saucer, rx_saucer - 2.0, ry_saucer - 2.0, -PI * 0.85, -PI * 0.15, pal.highlight * 0.7, 1.8)

	# 3. Kulp (2.5D Perspektif Seramik Kulp - Sağ Taraf)
	var handle_outer := PackedVector2Array([
		center_rim + Vector2(62, 18),
		center_rim + Vector2(90, 32),
		center_base + Vector2(86, -32),
		center_base + Vector2(46, -16)
	])
	# Kulp gölgesi
	draw_polyline(handle_outer, Color(0.03, 0.02, 0.04, 0.4), 10.0)
	# Kulp gövdesi
	draw_polyline(handle_outer, pal.body.darkened(0.15), 8.5)
	draw_polyline(handle_outer, pal.body, 6.5)
	# Kulp üst ışık vurgusu
	draw_polyline(handle_outer, pal.highlight, 2.0)

	# 4. Fincan Gövdesi (3D Hacimli Silindir - 18 Düşey Işık Dilimi)
	var slices: int = 18
	for i in range(slices):
		var t0: float = float(i) / float(slices)
		var t1: float = float(i + 1) / float(slices)
		var a0: float = PI * (1.0 - t0)
		var a1: float = PI * (1.0 - t1)

		var top0: Vector2 = center_rim + Vector2(rx_rim * cos(a0), ry_rim * sin(a0))
		var top1: Vector2 = center_rim + Vector2(rx_rim * cos(a1), ry_rim * sin(a1))
		var bot1: Vector2 = center_base + Vector2(rx_base * cos(a1), ry_base * sin(a1))
		var bot0: Vector2 = center_base + Vector2(rx_base * cos(a0), ry_base * sin(a0))

		var quad := PackedVector2Array([top0, top1, bot1, bot0])

		# Işıklandırma (Sol üstten gelen tezgâh ışığı)
		var mid_a: float = (a0 + a1) * 0.5
		var norm_x: float = cos(mid_a)
		var shade: float = 0.82 + 0.28 * norm_x
		# Sol-orta parlak seramik sır yansıması
		var spec: float = pow(maxf(0.0, 1.0 - abs(norm_x - (-0.25)) * 3.5), 3.0) * 0.42
		# Sağ kenar yansıma ışığı (Bounce light)
		var bounce: float = maxf(0.0, norm_x - 0.45) * 0.22

		var slice_color: Color = pal.body * clampf(shade + bounce, 0.42, 1.35)
		slice_color = slice_color.lerp(Color.WHITE, spec)
		draw_colored_polygon(quad, slice_color)

	# 5. Fincanın Ağız Kenarı (Rim) ve İç Derinliği
	# Ağız dış kenar halkası
	_draw_ellipse(center_rim, rx_rim, ry_rim, pal.rim_accent)
	# Ağız iç boşluk seramik derinliği
	_draw_ellipse(center_rim, rx_rim - 6.0, ry_rim - 4.5, Color("141018"))
	# Ağız üst parıltı çizgisi (Specular lip reflection)
	_draw_ellipse_arc(center_rim, rx_rim - 2.0, ry_rim - 2.0, -PI * 0.88, -PI * 0.12, Color(1, 1, 1, 0.65), 2.2)

	# 6. Kahve Sıvısı (2.5D derinlikte yükselen zengin espresso)
	if fill_progress > 0.01:
		var liquid_y: float = lerpf(182.0, 102.0, fill_progress)
		var liquid_rx: float = lerpf(46.0, 63.0, fill_progress)
		var liquid_ry: float = lerpf(20.0, 27.0, fill_progress)
		var liquid_center: Vector2 = Vector2(140.0, liquid_y)

		# Koyu kavrulmuş espresso tabanı
		_draw_ellipse(liquid_center, liquid_rx, liquid_ry, COLOR_COFFEE_DEEP)

		# Fındık kabuğu krema / köpük halkası
		if fill_progress > 0.12:
			var crema_rx: float = maxf(liquid_rx - 2.5, 4.0)
			var crema_ry: float = maxf(liquid_ry - 1.5, 2.0)
			_draw_ellipse_arc(liquid_center, crema_rx, crema_ry, 0.0, TAU, COLOR_COFFEE_CREMA, 3.5)

		# Mikroköpük detayları
		if fill_progress > 0.35:
			draw_circle(liquid_center + Vector2(12, -4), 2.8, COLOR_COFFEE_FOAM)
			draw_circle(liquid_center + Vector2(-14, 3), 2.2, COLOR_COFFEE_FOAM)
			draw_circle(liquid_center + Vector2(4, 5), 1.8, COLOR_COFFEE_FOAM)

		# Sıvı yüzeyindeki tavan ışığı yansıması (Glossy specular reflection)
		_draw_ellipse_arc(liquid_center + Vector2(-8, -3), liquid_rx * 0.45, liquid_ry * 0.45, -PI * 0.85, -PI * 0.15, Color(1, 1, 1, 0.55), 2.0)

		# Dökülürken 2.5D konsantrik dalgalanmalar (Ripples)
		if is_pouring:
			for i in range(2):
				var r: float = fmod(ripple_time + float(i) * 9.0, 32.0)
				var alpha: float = clampf(1.0 - (r / 32.0), 0.0, 0.75)
				if r < 34.0:
					var rip_rx: float = r
					var rip_ry: float = r * (liquid_ry / liquid_rx)
					_draw_ellipse_arc(liquid_center, rip_rx, rip_ry, 0.0, TAU, Color(COLOR_ACCENT_GOLD.r, COLOR_ACCENT_GOLD.g, COLOR_ACCENT_GOLD.b, alpha), 1.5)

	# 7. Sıcak Kahve Buharı (2.5D sıvı yüzeyinden yükselen buhar)
	if fill_progress > 0.18:
		var steam_alpha: float = clampf(fill_progress * 0.45, 0.0, 0.4)
		for i in range(3):
			var offset_x: float = sin(steam_time + float(i) * 1.8) * 6.0
			var start_p: Vector2 = Vector2(140.0 + offset_x - 14.0 + float(i) * 14.0, lerpf(182.0, 102.0, fill_progress) - 8.0)
			var end_p: Vector2 = start_p + Vector2(sin(steam_time * 1.5 + float(i)) * 10.0, -32.0)
			draw_line(start_p, end_p, Color(0.92, 0.90, 0.98, steam_alpha), 2.0)

	# 8. İlerleme Çemberi (2.5D Tabak Kenarında Eliptik Çember)
	_draw_ellipse_arc(center_saucer, rx_saucer + 2.0, ry_saucer + 2.0, 0.0, TAU, Color(1, 1, 1, 0.08), 3.0)
	if fill_progress > 0.005:
		var start_angle: float = -PI * 0.5
		var sweep: float = TAU * fill_progress
		var ring_color: Color = COLOR_ACCENT_GOLD
		if fill_progress >= 0.99:
			var pulse: float = 0.5 + 0.5 * sin(pulse_time * 3.0)
			ring_color = ring_color.lerp(Color.WHITE, pulse * 0.5)
		_draw_ellipse_arc(center_saucer, rx_saucer + 2.0, ry_saucer + 2.0, start_angle, start_angle + sweep, ring_color, 4.0)

	# 9. Vurgu / Seçim Parıltısı
	if is_hovered or is_pouring:
		var highlight_alpha: float = 0.35 + 0.18 * sin(pulse_time)
		_draw_ellipse_arc(center_saucer, rx_saucer + 6.0, ry_saucer + 4.0, 0.0, TAU, Color(COLOR_ACCENT_GOLD.r, COLOR_ACCENT_GOLD.g, COLOR_ACCENT_GOLD.b, highlight_alpha), 1.8)

func _draw_liquid_and_progress(center_rim: Vector2, rx_rim: float, ry_rim: float, center_saucer: Vector2, rx_saucer: float, ry_saucer: float) -> void:
	if fill_progress > 0.01:
		var liquid_y: float = lerpf(182.0, 102.0, fill_progress)
		var liquid_rx: float = lerpf(46.0, 63.0, fill_progress)
		var liquid_ry: float = lerpf(20.0, 27.0, fill_progress)
		var liquid_center: Vector2 = Vector2(140.0, liquid_y)
		_draw_ellipse(liquid_center, liquid_rx, liquid_ry, COLOR_COFFEE_DEEP)
		if fill_progress > 0.12:
			_draw_ellipse_arc(liquid_center, maxf(liquid_rx - 2.5, 4.0), maxf(liquid_ry - 1.5, 2.0), 0.0, TAU, COLOR_COFFEE_CREMA, 3.5)
	if fill_progress > 0.005:
		var start_angle: float = -PI * 0.5
		var sweep: float = TAU * fill_progress
		_draw_ellipse_arc(center_saucer, rx_saucer + 2.0, ry_saucer + 2.0, start_angle, start_angle + sweep, COLOR_ACCENT_GOLD, 4.0)
