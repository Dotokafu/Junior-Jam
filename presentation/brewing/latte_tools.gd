extends RefCounted
## Latte art araçları: Coffee Talk'taki süt dökme ve çizme. Bütün sayılar oyunun LatteArt sahnesindeki
## Influencer(Milk), Influencer(Milk+BaseColor) ve Influencer(Etch) nesnelerinden alındı.
## Boyutlar Coffee Talk biriminde yazılır; fincan düzlemi Fluid.WORLD (10) birim genişliğindedir.
const Fluid = preload("res://presentation/brewing/latte_fluid.gd")

## Basılı tutuldukça birikip büyüyen, hızlı hareketle küçülen bir dökme fırçası (PourMilkLatteArt).
class Stream:
	const MOVE_DIVIDER := 50.0
	var brush: Fluid.Brush
	var init_size: float
	var rate: float
	var max_size: float
	var color_mult: float
	var velocity_mult: float
	var collision_mult: float
	var build_up: float

	func _init(target: Fluid.Brush, values: Dictionary) -> void:
		brush = target
		init_size = values.init
		rate = values.rate
		max_size = values.max
		color_mult = values.color_mult
		velocity_mult = values.velocity_mult
		collision_mult = values.collision_mult
		build_up = init_size

	func update(pointer: Vector2, moved: float, delta: float) -> void:
		build_up = minf(build_up + rate * delta, max_size)
		build_up = maxf(build_up - moved, init_size)
		var size := build_up / Fluid.WORLD
		brush.activate(pointer)
		brush.color_size = size * color_mult
		brush.velocity_size = size * velocity_mult
		brush.collision_size = size * collision_mult

	func release() -> void:
		brush.active = false
		build_up = init_size

## Süt dökme: iki fırça aynı noktada. Beyaz süt sıvıyı akış yönünde iter ve zayıf bir engel olur;
## "süt + içecek rengi" yalnızca yarı saydam ve çok yumuşak kenarlı bir hale bırakır.
## Varsayılan akış oyuncuya doğrudur (ekranın altı); ters çevrilince fincanın üstüne.
class Pour:
	const MILK := {"init": 0.3, "rate": 0.3, "max": 1.0, "color_mult": 0.75, "velocity_mult": 1.5, "collision_mult": 1.5}
	const TINT := {"init": 0.5, "rate": 0.6, "max": 1.75, "color_mult": 0.6, "velocity_mult": 1.25, "collision_mult": 1.5}
	const FLOW_STRENGTH := 0.025
	var tint: Stream
	var milk: Stream
	var reverse: bool = false
	var last_pointer: Vector2 = Vector2(-1, -1)

	func _init(fluid: Fluid) -> void:
		var tint_brush := fluid.add_brush()
		tint_brush.color_falloff = 0.025
		tint_brush.collision_strength = 0.0
		var milk_brush := fluid.add_brush()
		milk_brush.color = Color.WHITE
		milk_brush.color_falloff = 0.25
		milk_brush.velocity_falloff = 0.05
		milk_brush.collision_strength = 0.75
		milk_brush.collision_falloff = 0.01
		milk_brush.move_multiplier = 2.0
		tint = Stream.new(tint_brush, TINT)
		milk = Stream.new(milk_brush, MILK)
		set_drink_color(fluid.base_color)

	## Coffee Talk: hale rengi içecek ile beyazın ortalaması, yarı saydam.
	func set_drink_color(drink: Color) -> void:
		tint.brush.color = Color((drink.r + 1.0) / 2.0, (drink.g + 1.0) / 2.0, (drink.b + 1.0) / 2.0, 0.5)

	func flow_direction() -> Vector2:
		return Vector2.UP if reverse else Vector2.DOWN

	func update(pointer: Vector2, pressed: bool, delta: float) -> void:
		if not pressed:
			release()
			return
		var moved := 0.0
		if last_pointer.x >= 0.0:
			moved = (pointer - last_pointer).length() * Fluid.WORLD / Stream.MOVE_DIVIDER
		last_pointer = pointer
		tint.update(pointer, moved, delta)
		milk.update(pointer, moved, delta)
		# Hale sıvıyı itmez ve engel olmaz (oyunda dynamicCollision ve addVelocity kapalı).
		tint.brush.velocity_size = 0.0
		tint.brush.collision_size = 0.0
		milk.brush.velocity = flow_direction() * FLOW_STRENGTH

	func release() -> void:
		tint.release()
		milk.release()
		last_pointer = Vector2(-1, -1)

## Çizim iğnesi (EtchLatteArt): renk bırakmaz; hareket ederken küçük bir engel olup köpüğü hareket
## yönünde iter ve biraz sürükler. Dururken etkisizdir.
class Etch:
	const SIZE := 0.3
	const STRENGTH := 0.1
	const DRAG := 0.1
	const TURN_THRESHOLD := deg_to_rad(0.3)
	var needle: Fluid.Brush
	var direction: Vector2 = Vector2.UP
	var last_pointer: Vector2 = Vector2(-1, -1)

	func _init(fluid: Fluid) -> void:
		needle = fluid.add_brush()
		needle.color = Color(1, 1, 1, 0)
		needle.velocity_falloff = 0.1
		needle.collision_strength = 1.0
		needle.collision_falloff = 0.02

	func update(pointer: Vector2, pressed: bool, _delta: float) -> void:
		if not pressed:
			release()
			return
		var step := pointer - last_pointer if last_pointer.x >= 0.0 else Vector2.ZERO
		last_pointer = pointer
		needle.activate(pointer)
		if step == Vector2.ZERO:
			needle.collision_size = 0.0
			needle.velocity_size = 0.0
			needle.move_multiplier = 0.0
			needle.velocity = Vector2.ZERO
			return
		if absf(direction.angle_to(step)) >= TURN_THRESHOLD:
			direction = step.normalized()
		needle.collision_size = SIZE / Fluid.WORLD
		needle.velocity_size = SIZE / Fluid.WORLD
		needle.move_multiplier = DRAG
		needle.velocity = direction * STRENGTH

	func release() -> void:
		needle.active = false
		last_pointer = Vector2(-1, -1)
