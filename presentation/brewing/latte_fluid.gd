extends Node
## Latte art köpüğü: Coffee Talk'un FluidSim simülasyonunun aynısı, ekran kartında (sharedassets5'teki
## FluidSimObject ayarları): 256×256 half-float ızgara, saniyede 25 adım, simStrength 10, 10 basınç adımı,
## renk sönümü yok, hız sönümü 0,25 (Start'ta oldVelocityDissipation'a döner), fincan dairesi biçimli duvar
## (ui_LatteCupFluidMask: çap %73,4).
## Her adımın geçişleri sırayla çizilen kardeş SubViewport'lardır (Godot kardeşleri yukarıdan aşağı çizer):
## engel → itme → renk taşı → hız taşı → diverjans → 10× basınç → gradyan → fırça rengi.
## Izgara Coffee Talk'un UV yönündedir: u ekranın soluna doğru artar (sunumda yatay çevrilir), v aşağı.
const SIZE := 256
const STEP_TIME := 1.0 / 25.0
const TIME_STEP := 0.02
const SIM_STRENGTH := 10.0
const PRESSURE_ITERATIONS := 10
## Her adım hız × lerp(1, 0.5, velocityDissipation 0.25).
const VELOCITY_KEEP := 0.875
## Duvar dairesinin yarıçapı (kare genişliğinin oranı); sunumdaki fincan dairesi de bu.
const WALL_RADIUS := 94.0 / 256.0
const MAX_BRUSHES := 4
## Fincan düzleminin Coffee Talk birimindeki genişliği (Plane mesh, 10 × 10).
const WORLD := 10.0
const EDGE := 150.0
## Engel hızı bu süreden eski bir konuma göre hesaplanmaz (Coffee Talk: 0,5 sn).
const MOTION_MEMORY := 0.5
const SHADERS := "res://presentation/brewing/fluid/"

## Sıvıyı etkileyen nokta: süt sürahisinin ucu ya da çizim iğnesi. Konum ve boyutlar kare genişliğinin
## oranıdır (0..1), ızgaranın UV yönünde.
class Brush:
	var active: bool = false
	var position: Vector2 = Vector2(0.5, 0.5)
	## Engel hızı için son engel güncellemesindeki konum ve zamanı.
	var last_position: Vector2 = Vector2(0.5, 0.5)
	var last_time: float = -10.0
	## a = karışma gücü; 0 ise renk bırakmaz (çizim iğnesi).
	var color: Color = Color.WHITE
	var color_size: float = 0.0
	var color_falloff: float = 0.5
	## Birim yön × güç.
	var velocity: Vector2 = Vector2.ZERO
	var velocity_size: float = 0.0
	var velocity_falloff: float = 0.5
	var collision_size: float = 0.0
	var collision_falloff: float = 0.8
	var collision_strength: float = 1.0
	## Engel hareket ederken sıvıyı ne kadar sürükler.
	var move_multiplier: float = 1.0

	func activate(at: Vector2) -> void:
		position = at
		active = true

var base_color: Color = Color.WHITE
var brushes: Array[Brush] = []
## Görüntülenecek köpük (son geçişin çıktısı).
var texture: Texture2D
var accumulator: float = 0.0
var clock: float = 0.0
var passes: Array[SubViewport] = []
var materials: Dictionary = {}
var pending_clear: bool = true

func _init() -> void:
	_build()

func add_brush() -> Brush:
	var brush := Brush.new()
	brushes.append(brush)
	return brush

## Köpüğü baştan döker: her yer içeceğin rengi, hareketsiz (bu karede çizilir).
func reset(color: Color = base_color) -> void:
	base_color = color
	accumulator = 0.0
	pending_clear = true
	materials.advect_color.set_shader_parameter("base_color", _byte_color(color))
	_step()

## Sabit adımla ilerler. Adım atıldıysa true (texture bu karede güncellenir).
func update(delta: float) -> bool:
	clock += delta
	accumulator = minf(accumulator + delta, STEP_TIME * 2.0)
	if accumulator < STEP_TIME:
		return false
	accumulator -= STEP_TIME
	_step()
	return true

## Test için: son adımın bir hücresinin rengi (ekran kartından okur; ızgara UV yönünde).
func color_at(cell: Vector2i) -> Color:
	return passes[-1].get_texture().get_image().get_pixel(cell.x, cell.y)

func _step() -> void:
	var active: Array[Brush] = []
	for brush: Brush in brushes:
		if brush.active:
			active.append(brush)
	_set_collision(active)
	var shapes: Array[Vector4] = []
	var pushes := PackedVector2Array()
	for brush: Brush in active:
		if brush.velocity != Vector2.ZERO and brush.velocity_size > 0.0:
			shapes.append(_shape(brush.position, brush.velocity_size, brush.velocity_falloff))
			pushes.append(_byte_direction(brush.velocity))
	_send("impulse", shapes, "push", pushes)
	shapes = []
	var tints := PackedColorArray()
	for brush: Brush in active:
		if brush.color.a > 0.0 and brush.color_size > 0.0:
			shapes.append(_shape(brush.position, brush.color_size, brush.color_falloff))
			tints.append(_byte_color(brush.color))
	_send("paint", shapes, "tint", tints)
	materials.impulse.set_shader_parameter("clear", pending_clear)
	materials.advect_color.set_shader_parameter("clear", pending_clear)
	pending_clear = false
	for viewport: SubViewport in passes:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

## Engel fırçaları: hız = (şimdiki − önceki konum) × WORLD × çarpan (Coffee Talk'ta dünya ekseni UV'nin
## tersi olduğu için önceki − şimdiki yazılır), bayta kodlanıp açılır (−4,98 kayması dahil).
## Konum en fazla 0,5 sn hatırlanır.
func _set_collision(active: Array[Brush]) -> void:
	var shapes: Array[Vector4] = []
	var motions := PackedColorArray()
	for brush: Brush in active:
		if brush.collision_size <= 0.0:
			continue
		var moved := Vector2.ZERO
		if clock - brush.last_time < MOTION_MEMORY:
			moved = (brush.position - brush.last_position) * WORLD * brush.move_multiplier
		brush.last_position = brush.position
		brush.last_time = clock
		var coded := Vector2(_byte(clampf((moved.x + 5.0) / 10.0, 0.0, 1.0)), _byte(clampf((moved.y + 5.0) / 10.0, 0.0, 1.0))) * 10.0 - Vector2.ONE * 4.98
		shapes.append(_shape(brush.position, brush.collision_size, brush.collision_falloff))
		motions.append(Color(coded.x, coded.y, brush.collision_strength, 0.0))
	_send("collision", shapes, "motion", motions)

func _send(pass_name: String, shapes: Array[Vector4], extra: String, extras: Variant) -> void:
	var material: ShaderMaterial = materials[pass_name]
	var packed := PackedVector4Array(shapes)
	material.set_shader_parameter("count", mini(packed.size(), MAX_BRUSHES))
	packed.resize(MAX_BRUSHES)
	extras.resize(MAX_BRUSHES)
	material.set_shader_parameter("shape", packed)
	material.set_shader_parameter(extra, extras)

## Konum, yarıçap, düşüş: Coffee Talk düşüşü bayta keser (×255, aşağı yuvarlar), shader'da ×150.
func _shape(at: Vector2, size: float, falloff: float) -> Vector4:
	return Vector4(at.x, at.y, size, _byte(falloff) * EDGE)

## Coffee Talk itme yönünü bileşen başına bayta kodlar: (x + 5) / 10 × 255 → açınca küçük kayma kalır.
func _byte_direction(value: Vector2) -> Vector2:
	var strength := value.length()
	var direction := value / strength
	var coded := Vector2(_byte((direction.x + 5.0) / 10.0), _byte((direction.y + 5.0) / 10.0)) * 10.0 - Vector2.ONE * 5.0
	return coded * strength

func _byte(value: float) -> float:
	return floorf(value * 255.0) / 255.0

func _byte_color(color: Color) -> Color:
	return Color(roundf(color.r * 255.0) / 255.0, roundf(color.g * 255.0) / 255.0, roundf(color.b * 255.0) / 255.0, roundf(color.a * 255.0) / 255.0)

# --- Geçiş zinciri -----------------------------------------------------------

func _build() -> void:
	var texel := 1.0 / SIZE
	var step_scale := TIME_STEP * SIM_STRENGTH
	var collision := _pass("collision", {"texel": texel, "wall_radius": WALL_RADIUS})
	var impulse := _pass("impulse", {})
	var advect_color := _pass("advect_color", {"step_scale": step_scale, "dissipation": 0.0})
	var advect_velocity := _pass("advect_velocity", {"step_scale": step_scale, "keep": VELOCITY_KEEP})
	var divergence := _pass("divergence", {"texel": texel})
	var pressure: Array[SubViewport] = []
	for i in range(PRESSURE_ITERATIONS):
		pressure.append(_pass("jacobi", {"texel": texel, "first": i == 0}, "jacobi_%d" % i))
	var gradient := _pass("gradient", {"texel": texel})
	var paint := _pass("paint", {})
	materials.impulse.set_shader_parameter("velocity_tex", gradient.get_texture())
	for key: String in ["advect_color", "advect_velocity"]:
		materials[key].set_shader_parameter("velocity_tex", impulse.get_texture())
		materials[key].set_shader_parameter("collision_tex", collision.get_texture())
	materials.advect_color.set_shader_parameter("color_tex", paint.get_texture())
	materials.divergence.set_shader_parameter("velocity_tex", advect_velocity.get_texture())
	materials.divergence.set_shader_parameter("collision_tex", collision.get_texture())
	for i in range(PRESSURE_ITERATIONS):
		var material: ShaderMaterial = materials["jacobi_%d" % i]
		material.set_shader_parameter("divergence_tex", divergence.get_texture())
		material.set_shader_parameter("collision_tex", collision.get_texture())
		if i > 0:
			material.set_shader_parameter("pressure_tex", pressure[i - 1].get_texture())
	materials.gradient.set_shader_parameter("velocity_tex", advect_velocity.get_texture())
	materials.gradient.set_shader_parameter("pressure_tex", pressure[-1].get_texture())
	materials.gradient.set_shader_parameter("collision_tex", collision.get_texture())
	materials.paint.set_shader_parameter("color_tex", advect_color.get_texture())
	texture = paint.get_texture()

func _pass(shader_name: String, parameters: Dictionary, key: String = shader_name) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = key
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.use_hdr_2d = true
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	var material := ShaderMaterial.new()
	material.shader = load(SHADERS + shader_name + ".gdshader")
	for parameter: String in parameters:
		material.set_shader_parameter(parameter, parameters[parameter])
	rect.material = material
	viewport.add_child(rect)
	add_child(viewport)
	passes.append(viewport)
	materials[key] = material
	return viewport
