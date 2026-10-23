extends Control
class_name KettleCursor
## Kuşbakışı (top-down) kahve demliği / kettle fare imleci.
## Fareyi takip eder; bardağa basıldığında eğilir ve kahve akıtır.

@export var is_pouring: bool = false
@export var target_cup_pos: Vector2 = Vector2.ZERO

var stream_time: float = 0.0
var tilt_angle: float = 0.0
var active: bool = true

# Renkler
const COLOR_KETTLE_SHADOW := Color(0.03, 0.02, 0.04, 0.45)
const COLOR_BODY_BASE := Color(0.22, 0.20, 0.25)
const COLOR_BODY_METAL := Color(0.35, 0.32, 0.38)
const COLOR_BODY_HIGHLIGHT := Color(0.55, 0.52, 0.60, 0.7)
const COLOR_LID := Color(0.28, 0.25, 0.32)
const COLOR_KNOB := Color(0.78, 0.60, 0.36)  # Pirinç / Ahşap kapak kulpu
const COLOR_HANDLE := Color(0.14, 0.12, 0.16)
const COLOR_COFFEE_STREAM := Color(0.20, 0.10, 0.05)
const COLOR_COFFEE_STREAM_LIGHT := Color(0.68, 0.48, 0.28, 0.85)
const KETTLE_PATH := "res://assets/menu/kettle.png"
var custom_kettle_texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(160, 160)
	size = Vector2(160, 160)
	pivot_offset = Vector2(80, 80)
	z_index = 50  # Her zaman fincanların ve arayüzün üstünde
	_check_custom_kettle()

func _check_custom_kettle() -> void:
	if ResourceLoader.exists(KETTLE_PATH):
		custom_kettle_texture = load(KETTLE_PATH)
	else:
		custom_kettle_texture = null

func _process(delta: float) -> void:
	if not active:
		visible = false
		return
	visible = true

	# Fare pozisyonuna hizalan
	var mouse_pos := get_global_mouse_position()
	# Demliğin ağzı (spout) fare ucuna yakın olacak şekilde hafif ofset
	global_position = mouse_pos - Vector2(120, 40)

	if is_pouring:
		stream_time += delta * 12.0
		# Hedef bardağa doğru hafif eğim
		var dir := (target_cup_pos - (global_position + Vector2(120, 40))).angle()
		tilt_angle = lerpf(tilt_angle, clampf(dir * 0.3, -0.35, 0.35), delta * 10.0)
	else:
		tilt_angle = lerpf(tilt_angle, 0.0, delta * 8.0)

	rotation = tilt_angle
	queue_redraw()

## Global koordinatı bu Control düğümünün yerel koordinatına çevirir (Node2D.to_local alternatifi)
func to_local_pos(p_global: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p_global

## Demliğin ağız ucunun (dökülen nokta) global pozisyonunu döner
func get_spout_global_pos() -> Vector2:
	return get_global_transform() * Vector2(128, 46)

func _draw() -> void:
	# Demliğin gövde merkezi ve ağız ucu
	var body_center := Vector2(65, 80)
	var spout_tip := body_center + Vector2(63, -34)

	# Harici özel demlik çizimi (assets/menu/kettle.png) varsa onu kullan
	if custom_kettle_texture:
		draw_texture_rect(custom_kettle_texture, Rect2(Vector2.ZERO, size), false)
	else:
		# 1. Gölge
		draw_circle(body_center + Vector2(6, 12), 34.0, COLOR_KETTLE_SHADOW)

		# 2. Arka Kulp (Handle)
		var handle_base := body_center + Vector2(-32, 0)
		draw_line(handle_base, handle_base + Vector2(-22, -14), COLOR_HANDLE, 8.0)
		draw_line(handle_base + Vector2(-22, -14), handle_base + Vector2(-22, 14), COLOR_HANDLE, 8.0)
		draw_line(handle_base + Vector2(-22, 14), handle_base, COLOR_HANDLE, 8.0)

		# 3. Kuğu Boyunlu İnce Ağız (Gooseneck Spout)
		var spout_points := PackedVector2Array([
			body_center + Vector2(26, -10),
			body_center + Vector2(48, -24),
			body_center + Vector2(58, -32),
			body_center + Vector2(63, -34)
		])
		draw_polyline(spout_points, COLOR_BODY_METAL, 8.0)
		draw_polyline(spout_points, COLOR_BODY_HIGHLIGHT, 2.5)
		draw_circle(spout_tip, 3.5, COLOR_BODY_BASE)

		# 4. Ana Gövde (Metal kettle body)
		draw_circle(body_center, 32.0, COLOR_BODY_BASE)
		draw_circle(body_center, 30.0, COLOR_BODY_METAL)
		draw_arc(body_center, 26.0, -PI * 0.75, -PI * 0.15, 24, COLOR_BODY_HIGHLIGHT, 3.5)

		# 5. Kapak (Lid)
		draw_circle(body_center, 18.0, COLOR_LID)
		draw_arc(body_center, 18.0, 0.0, TAU, 24, COLOR_BODY_BASE, 2.0)

		# 6. Kapak Kulpu (Brass knob)
		draw_circle(body_center, 6.0, COLOR_KNOB)
		draw_circle(body_center + Vector2(-1, -1), 2.0, Color(1, 1, 1, 0.6))

	# 7. Kahve Akışı (Kahve Dökülürken)
	if is_pouring and target_cup_pos != Vector2.ZERO:
		var stream_end_local: Vector2 = to_local_pos(target_cup_pos)
		var spout_local: Vector2 = spout_tip

		# Ana kahve akış çizgisi
		draw_line(spout_local, stream_end_local, COLOR_COFFEE_STREAM, 6.5)
		draw_line(spout_local, stream_end_local, COLOR_COFFEE_STREAM_LIGHT, 2.5)

		# Akış üzerindeki damlacıklar
		for i in range(3):
			var t: float = fmod((stream_time * 0.25) + float(i) * 0.33, 1.0)
			var drop_pos: Vector2 = spout_local.lerp(stream_end_local, t)
			draw_circle(drop_pos, 2.5, COLOR_COFFEE_STREAM_LIGHT)

		# Fincandaki çarpma / sıçrama noktası
		draw_circle(stream_end_local, 5.0, COLOR_COFFEE_STREAM_LIGHT)
		draw_circle(stream_end_local, 2.5, Color.WHITE)
