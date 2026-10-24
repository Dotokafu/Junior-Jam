extends Control
class_name TopdownCup
## Ana menü fincanı: fincanın kendisi arka plan resminde (assets/menu/background.jpg) çizili.
## Bu düğüm onun üstüne oturur: görünmez düğme, ağızda yükselen kahve ve gövdeye kazınmış yazı.
## Ölçüler (ağız elipsi, gövde halkası) yerel koordinatta, menü sahnesinde fincan başına verilir.

signal pour_started(cup: TopdownCup)
signal pour_ended(cup: TopdownCup)

@export var cup_id: String = "story"
@export var title_text: String = "HİKÂYE"
@export var subtitle_text: String = ""
## İç ağız elipsi (resimdeki fincanın açıklığı).
@export var mouth_center: Vector2 = Vector2(140, 60)
@export var mouth_radii: Vector2 = Vector2(110, 38)
## Boşken kahve yüzeyinin ağız merkezinden ne kadar aşağıda göründüğü.
@export var depth: float = 40.0
## Kazıma yazının gövde halkası: ortadaki taban çizgisi, yarıçap, dikey yarıçap, yazı boyu.
@export var label_y: float = 150.0
@export var body_radius: float = 130.0
@export var label_curve: float = 22.0
@export var title_size: int = 34
@export var subtitle_size: int = 16

var fill_progress: float = 0.0:
	set(value):
		fill_progress = clampf(value, 0.0, 1.0)

var is_hovered: bool = false
var is_pouring: bool = false
## Görünen seviye fill_progress'i yaylı izler: akış durunca hafifçe çalkalanır.
var level: float = 0.0
var level_speed: float = 0.0
## Dalga gücü dökerken artar, sonra söner; halkalar dökme sürdükçe yayılır.
var wave_energy: float = 0.0
var time: float = 0.0
var ripple_time: float = 0.0

const COFFEE_DEEP := Color(0.16, 0.09, 0.05)
const COFFEE_BODY := Color(0.29, 0.17, 0.10)
const CREMA := Color(0.62, 0.42, 0.25, 0.6)
const SHINE := Color(0.93, 0.85, 0.72, 0.2)
const INK := Color(0.10, 0.07, 0.05, 0.85)
const GLOW := Color(1.0, 0.85, 0.62)
const STEAM := Color(0.92, 0.88, 0.80, 0.12)
const LEVEL_SPRING := 60.0
const LEVEL_DAMPING := 9.0
const RIM_SEGMENTS := 56

@onready var button: Button = $Button
@onready var engraving: Control = $Engraving

func _ready() -> void:
	material = PaintMaterial.make(0.16)
	button.text = title_text
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	engraving.center_x = mouth_center.x
	engraving.baseline_y = label_y
	engraving.radius = body_radius
	engraving.curve = label_curve
	engraving.title_size = title_size
	engraving.subtitle_size = subtitle_size
	engraving.setup(title_text, subtitle_text)

func _process(delta: float) -> void:
	time += delta
	level_speed += ((fill_progress - level) * LEVEL_SPRING - level_speed * LEVEL_DAMPING) * delta
	level = clampf(level + level_speed * delta, 0.0, 1.0)
	wave_energy = move_toward(wave_energy, 1.0 if is_pouring else 0.25, delta * (2.5 if is_pouring else 0.6))
	if is_pouring:
		ripple_time += delta
	queue_redraw()

func set_cup_data(p_id: String, p_title: String, p_subtitle: String = "") -> void:
	cup_id = p_id
	title_text = p_title
	subtitle_text = p_subtitle
	if button:
		button.text = title_text
	if engraving:
		engraving.setup(title_text, subtitle_text)

## Demliğin ağzının hizalandığı nokta: fincan ağzının merkezi.
func get_cup_center() -> Vector2:
	return mouth_center

## Akışın düştüğü nokta: o anki kahve yüzeyinin merkezi (boşken fincanın dibi).
func get_pour_point() -> Vector2:
	return _surface_center()

func _surface_center() -> Vector2:
	return mouth_center + Vector2(0.0, lerpf(depth, 3.0, ease(level, 0.7)))

func _on_mouse_entered() -> void:
	is_hovered = true

func _on_mouse_exited() -> void:
	is_hovered = false
	# Dökmeyi menü durdurur: mıknatıs alanı fincandan geniştir, düğmeden çıkmak alandan çıkmak değildir.

func _on_button_down() -> void:
	is_pouring = true
	pour_started.emit(self)

func _on_button_up() -> void:
	is_pouring = false
	pour_ended.emit(self)

func _draw() -> void:
	var mouth := _ellipse(mouth_center, mouth_radii * 0.97, 0.0)
	if level > 0.01:
		_draw_coffee(mouth)
	if is_hovered or is_pouring or fill_progress >= 0.99:
		var full := fill_progress >= 0.99
		var alpha := (0.45 if full else 0.22) + 0.12 * sin(time * 4.0)
		draw_polyline(_closed(_ellipse(mouth_center, mouth_radii * 1.07, 0.0)), Color(GLOW, alpha), 3.0, true)
	if level > 0.85:
		_draw_steam()

func _draw_coffee(mouth: PackedVector2Array) -> void:
	var center := _surface_center()
	var radii := mouth_radii * lerpf(0.62, 0.95, level)
	var wobble := 0.012 + 0.03 * wave_energy
	var surface := _ellipse(center, radii, wobble)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(surface, mouth):
		draw_colored_polygon(part, COFFEE_DEEP)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(_ellipse(center + Vector2(0, -radii.y * 0.08), radii * 0.82, wobble), mouth):
		draw_colored_polygon(part, COFFEE_BODY)
	# Köpük kenarı ve ön duvarla birleşim çizgisi yalnızca görünen kısımda.
	for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(_closed(_ellipse(center, radii * 0.93, wobble)), mouth):
		draw_polyline(line, CREMA, 4.0, true)
	for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(_closed(surface), mouth):
		draw_polyline(line, INK, 1.6, true)
	# Akışın düştüğü yerden yayılan halkalar.
	if is_pouring:
		for i in range(3):
			var t := fmod(ripple_time * 0.9 + i / 3.0, 1.0)
			var ring := _ellipse(center, radii * lerpf(0.08, 0.75, t), 0.0)
			for line: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(_closed(ring), mouth):
				draw_polyline(line, Color(CREMA, 0.5 * (1.0 - t)), 2.0, true)
	for part: PackedVector2Array in Geometry2D.intersect_polygons(_ellipse(center + Vector2(-radii.x * 0.35, -radii.y * 0.35), radii * Vector2(0.28, 0.16), 0.0), mouth):
		draw_colored_polygon(part, SHINE)

func _draw_steam() -> void:
	for i in range(3):
		var x := mouth_center.x + (i - 1) * mouth_radii.x * 0.35
		var points := PackedVector2Array()
		for k in range(12):
			var y := mouth_center.y - 10.0 - k * 7.0
			points.append(Vector2(x + sin(time * 1.6 + k * 0.55 + i * 2.0) * 6.0, y))
		draw_polyline(points, Color(STEAM, STEAM.a * (level - 0.85) / 0.15), 3.0, true)

## Elips çokgeni; wobble > 0 ise kenar zamanla dalgalanır (iki dalga üst üste).
func _ellipse(center: Vector2, radii: Vector2, wobble: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(RIM_SEGMENTS):
		var a := TAU * i / RIM_SEGMENTS
		var r := 1.0 + wobble * (sin(a * 3.0 + time * 2.3) + 0.6 * sin(a * 5.0 - time * 3.4))
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y) * r)
	return points

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result
