extends Control
class_name KettleCursor
## Ana menünün fare imleci: yandan görünen bakır kuğu boyunlu demlik, arka plan resminin
## mürekkep kontur + boya üslubuyla çizilir. Fareyi takip eder; fincana basılınca eğilir ve kahve akıtır.
## assets/menu/kettle.png varsa (240×210, ağız ucu SPOUT_OFFSET'te) çizim yerine o kullanılır.

@export var is_pouring: bool = false
@export var target_cup_pos: Vector2 = Vector2.ZERO

var stream_time: float = 0.0
var tilt_angle: float = 0.0
var active: bool = true
## Mıknatıs: menü fareyi bir bardağın yakınında görünce ağzı bu noktaya kilitler (INF = fareyi izle).
## Kilit kalkınca demlik fareye kayarak döner, ışınlanmaz.
var snap_spout: Vector2 = Vector2.INF:
	set(value):
		if value == Vector2.INF and snap_spout != Vector2.INF:
			gliding = true
		snap_spout = value
var gliding: bool = false
## Farenin son konumu; menü fare hareketi olaylarından günceller (test olayları da aynı yoldan gelir).
var pointer: Vector2 = Vector2.ZERO
const SIZE := Vector2(240, 210)
## Ağız ucu (akışın çıktığı nokta) ve gövde merkezi (dönme ekseni), yerel koordinat.
const SPOUT_OFFSET := Vector2(228, 46)
const BODY_CENTER := Vector2(100, 140)
const SNAP_SPEED := 18.0
## Sahnedeki iri fincanların yanında oyuncak gibi durmasın.
const DRAW_SCALE := 1.4

const INK := Color(0.10, 0.07, 0.05)
const COPPER := Color(0.49, 0.29, 0.19)
const COPPER_DARK := Color(0.32, 0.19, 0.12)
const COPPER_LIGHT := Color(0.71, 0.48, 0.32)
const SHINE := Color(0.96, 0.88, 0.74, 0.55)
const WOOD := Color(0.36, 0.22, 0.14)
const SHADOW := Color(0.02, 0.02, 0.04, 0.35)
const STREAM := Color(0.17, 0.09, 0.05)
const STREAM_LIGHT := Color(0.47, 0.29, 0.16)
const SPLASH := Color(0.62, 0.42, 0.25, 0.7)
const KETTLE_PATH := "res://assets/menu/kettle.png"
var custom_kettle_texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = BODY_CENTER
	scale = Vector2.ONE * DRAW_SCALE
	z_index = 50  # Her zaman fincanların ve arayüzün üstünde
	material = PaintMaterial.make(0.18)
	_check_custom_kettle()
	pointer = get_global_mouse_position()

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

	if is_pouring:
		stream_time += delta * 12.0
		# Hedef fincana doğru eğim (ağız aşağı)
		var dir := (target_cup_pos - get_spout_global_pos()).angle()
		tilt_angle = lerpf(tilt_angle, clampf(dir * 0.3, -0.35, 0.35), delta * 10.0)
	else:
		tilt_angle = lerpf(tilt_angle, 0.0, delta * 8.0)
	# Önce eğim: kilitliyken konum, bu karenin eğimine göre ağzı yerinde tutacak şekilde hesaplanır.
	rotation = tilt_angle

	# Ağız ucu farenin ucunda durur.
	var follow := _position_for_spout(pointer)
	if snap_spout != Vector2.INF or gliding:
		var target := follow if snap_spout == Vector2.INF else _position_for_spout(snap_spout)
		global_position = global_position.lerp(target, minf(1.0, delta * SNAP_SPEED))
		gliding = snap_spout == Vector2.INF and global_position.distance_to(target) > 4.0
	else:
		global_position = follow
	queue_redraw()

## Ağız ucu, demlik eğilmiş ve ölçeklenmiş olsa da point'te dursun diye gereken konum. Dönüşün nereye
## göre uygulandığını varsaymaz: güncel dönüşüm matrisinden ağzın konuma göre kaymasını okur.
func _position_for_spout(point: Vector2) -> Vector2:
	var xform := get_global_transform()
	return point - (xform.origin - global_position) - xform.basis_xform(SPOUT_OFFSET)

## Global koordinatı bu Control düğümünün yerel koordinatına çevirir (Node2D.to_local alternatifi)
func to_local_pos(p_global: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * p_global

## Demliğin ağız ucunun (dökülen nokta) global pozisyonunu döner
func get_spout_global_pos() -> Vector2:
	return get_global_transform() * SPOUT_OFFSET

func _draw() -> void:
	if is_pouring and target_cup_pos != Vector2.ZERO:
		_draw_stream()
	if custom_kettle_texture:
		draw_texture_rect(custom_kettle_texture, Rect2(Vector2.ZERO, size), false)
		return
	_draw_kettle()

func _draw_kettle() -> void:
	var body := _body_polygon(BODY_CENTER, Vector2(58, 52))
	# Tezgâha düşen gölge
	draw_colored_polygon(_body_polygon(BODY_CENTER + Vector2(10, 16), Vector2(56, 46)), SHADOW)
	# Kulp: önce mürekkep, sonra ahşap
	var handle := PackedVector2Array([Vector2(56, 100), Vector2(26, 106), Vector2(14, 138), Vector2(26, 170), Vector2(54, 176)])
	draw_polyline(handle, INK, 17.0, true)
	draw_polyline(handle, WOOD, 10.0, true)
	# Kuğu boynu ağız
	var spout := PackedVector2Array([Vector2(146, 166), Vector2(176, 158), Vector2(192, 128), Vector2(200, 94), Vector2(212, 62), SPOUT_OFFSET])
	draw_polyline(spout, INK, 14.0, true)
	draw_polyline(spout, COPPER, 8.0, true)
	draw_polyline(_offset(spout, Vector2(-2, -1)), COPPER_LIGHT, 2.5, true)
	# Gövde: taban rengi, sağda gölge, solda ışık, parlama çizgileri
	draw_colored_polygon(body, COPPER)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(body, _body_polygon(BODY_CENTER + Vector2(30, 6), Vector2(52, 56))):
		draw_colored_polygon(part, COPPER_DARK)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(body, _body_polygon(BODY_CENTER + Vector2(-26, -8), Vector2(26, 40))):
		draw_colored_polygon(part, COPPER_LIGHT)
	draw_line(BODY_CENTER + Vector2(-34, -24), BODY_CENTER + Vector2(-40, 14), SHINE, 4.0, true)
	draw_line(BODY_CENTER + Vector2(-24, -32), BODY_CENTER + Vector2(-27, -18), SHINE, 3.0, true)
	draw_polyline(_closed(body), INK, 3.5, true)
	# Kapak: kubbe, ağız halkası, ahşap topuz
	var dome := PackedVector2Array()
	for i in range(17):
		var a := PI + PI * i / 16.0
		dome.append(Vector2(100, 92) + Vector2(cos(a) * 30.0, sin(a) * 16.0))
	draw_colored_polygon(dome, COPPER_DARK)
	draw_polyline(dome, INK, 3.0, true)
	var rim := _ellipse(Vector2(100, 92), Vector2(36, 9))
	draw_colored_polygon(rim, COPPER_LIGHT)
	draw_polyline(_closed(rim), INK, 3.0, true)
	draw_circle(Vector2(100, 70), 9.0, INK)
	draw_circle(Vector2(100, 70), 6.5, WOOD)
	draw_circle(Vector2(98, 68), 2.0, SHINE)
	# Ağız ucu deliği
	draw_circle(SPOUT_OFFSET, 4.5, INK)

## Ağızdan yükselen kahve yüzeyine düşen, hafif dalgalı akış ve düştüğü yerde sıçrama.
func _draw_stream() -> void:
	var start := SPOUT_OFFSET
	var end := to_local_pos(target_cup_pos)
	var points := PackedVector2Array()
	var steps := 14
	var side := (end - start).orthogonal().normalized()
	for k in range(steps + 1):
		var t := float(k) / steps
		points.append(start.lerp(end, t) + side * sin(stream_time * 0.9 + t * 9.0) * 1.6 * t)
	draw_polyline(points, STREAM, 7.0, true)
	draw_polyline(_offset(points, side * -1.2), STREAM_LIGHT, 2.2, true)
	for i in range(3):
		var t := fmod(stream_time * 0.25 + float(i) * 0.33, 1.0)
		draw_circle(start.lerp(end, t) + side * 3.5, 1.8, STREAM_LIGHT)
	var splash := 0.5 + 0.5 * sin(stream_time * 1.7)
	draw_arc(end, 6.0 + splash * 3.0, PI * 1.1, PI * 1.9, 10, SPLASH, 2.0, true)
	draw_circle(end, 3.0, STREAM_LIGHT)

## Tabanı geniş, omuzları yuvarlak demlik gövdesi.
func _body_polygon(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(40):
		var a := TAU * i / 40.0
		var c := cos(a)
		var s := sin(a)
		var x := signf(c) * pow(absf(c), 0.75) * radii.x * (1.0 + 0.12 * s)
		var y := signf(s) * pow(absf(s), 0.9) * radii.y
		points.append(center + Vector2(x, y))
	return points

func _ellipse(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(28):
		var a := TAU * i / 28.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result

func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + by)
	return result
