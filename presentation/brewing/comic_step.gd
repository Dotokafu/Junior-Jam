extends Control
## Demleme sayfasındaki tek adım karesi: kavanoz eğilir, akış fincana iner, ses efekti patlar.
## Tarçın rendeden geçirilir; limon ve bal yatay kuvvetle çapraz konumdan sıkılarak kahveye dökülür; diğer malzemeler fincana dökülür.
## res://assets/comic/<malzeme id>.png varsa kare kodla kurulmaz, o çizim gösterilir.
const ART_PATH := "res://assets/comic/%s.png"
const ICON_PATH := "res://assets/ui/ingredients/%s.png"
const POP_TIME := 0.18
const POUR_TIME := 0.3
## Yerleşim kare boyutuna göre hesaplanır (oranlar karenin yüksekliğine göre).
const JAR_TOP := 0.08
const COUNTER_TOP := 0.8
const SFX_TOP := 0.4
const LIQUID_DEPTH := 56.0
## Her demlemede kare biraz farklı çizilir (yalnızca görsel; oyun durumunu etkilemez).
const JAR_TILT := Vector2(-2.45, -1.95)
const SFX_TILT := Vector2(-0.3, 0.25)
const SFX_SCALE := Vector2(0.85, 1.25)
const SFX_DRIFT := 70.0
const CAPTION_MARGIN := 12.0
var stream_length: float = 0.0
var action_type: String = "pour"
var current_item_id: String = ""
var jar_base_pos := Vector2.ZERO
var jar_base_rot := 0.0
var jar_base_scale := Vector2.ONE

@onready var art: TextureRect = $Art
@onready var jar: TextureRect = $Jar
@onready var stream: TextureRect = $Stream
@onready var cup: Control = $Cup
@onready var liquid: TextureRect = $Cup/Liquid
@onready var caption: Label = $Caption/Text
@onready var sfx: Label = $Sfx

var grater_node: Control = null
var flakes_node: Control = null
var juice_node: Control = null

var sfx_offset := Vector2.ZERO
var sfx_size := 1.0
var caption_bottom: bool = false

class GraterVisual extends Control:
	func _draw() -> void:
		var plate_color := Color("929ba6")
		var highlight_color := Color("c5d0dc")
		var border_color := Color("2c333a")
		var hole_color := Color("1c2126")
		var handle_color := Color("4a3020")
		var handle_highlight := Color("6c4832")
		
		# Sap
		draw_rect(Rect2(Vector2(29, 2), Vector2(22, 26)), handle_color)
		draw_rect(Rect2(Vector2(31, 4), Vector2(6, 22)), handle_highlight)
		draw_rect(Rect2(Vector2(29, 2), Vector2(22, 26)), border_color, false, 2.0)
		
		# Bağlantı boynu
		draw_rect(Rect2(Vector2(33, 28), Vector2(14, 8)), border_color)
		
		# Rende metal gövdesi
		var body_rect := Rect2(Vector2(12, 36), Vector2(56, 96))
		draw_rect(body_rect, plate_color)
		draw_rect(Rect2(Vector2(14, 38), Vector2(8, 92)), highlight_color)
		draw_rect(body_rect, border_color, false, 2.5)
		
		# Rende delikleri / dişleri
		for row in range(6):
			var y := 46.0 + row * 14.0
			for col in range(3):
				var x := 23.0 + col * 14.0 + (4.0 if row % 2 == 1 else 0.0)
				draw_rect(Rect2(Vector2(x, y), Vector2(6, 3)), hole_color)
				draw_line(Vector2(x, y + 3), Vector2(x + 6, y + 3), highlight_color, 1.0)

class FlakesVisual extends Control:
	var progress: float = 0.0:
		set(v):
			progress = v
			queue_redraw()
	var flakes: Array[Dictionary] = []
	
	func _init() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337
		for i in range(32):
			flakes.append({
				"offset_x": rng.randf_range(-24.0, 24.0),
				"speed": rng.randf_range(0.85, 1.35),
				"delay": rng.randf_range(0.0, 0.4),
				"radius": rng.randf_range(2.0, 4.0),
				"color": Color("8c4a22") if rng.randf() > 0.45 else (Color("b0632d") if rng.randf() > 0.3 else Color("deb887"))
			})
			
	func _draw() -> void:
		if progress <= 0.0:
			return
		var center_x := size.x / 2.0
		for f in flakes:
			var p: float = clampf((progress - f.delay) * f.speed, 0.0, 1.0)
			if p > 0.0:
				var y: float = p * size.y
				var sway: float = sin(p * 9.0 + f.offset_x) * 6.0
				var x: float = center_x + f.offset_x + sway
				var alpha: float = 1.0 if p < 0.8 else (1.0 - (p - 0.8) / 0.2)
				var c: Color = f.color
				c.a = alpha
				draw_circle(Vector2(x, y), f.radius, c)

class JuiceVisual extends Control:
	var squirt_progress: float = 0.0:
		set(v):
			squirt_progress = v
			queue_redraw()
	var squirt_power: float = 1.0:
		set(v):
			squirt_power = v
			queue_redraw()
	var start_pt := Vector2.ZERO
	var end_pt := Vector2.ZERO
	var drops: Array[Dictionary] = []
	var main_color := Color("fae14b")
	var highlight_color := Color("fffca8")
	
	func setup_path(start: Vector2, target: Vector2, color: Color, highlight: Color, seed_val: int) -> void:
		start_pt = start
		end_pt = target
		main_color = color
		highlight_color = highlight
		drops.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		for i in range(24):
			drops.append({
				"spread": rng.randf_range(-14.0, 14.0),
				"speed": rng.randf_range(0.9, 1.4),
				"delay": rng.randf_range(0.0, 0.3),
				"radius": rng.randf_range(2.5, 4.5),
				"color": main_color if rng.randf() > 0.35 else highlight_color
			})
		queue_redraw()
			
	func _draw() -> void:
		if squirt_progress <= 0.0 or start_pt == Vector2.ZERO or end_pt == Vector2.ZERO:
			return
		var tip := start_pt.lerp(end_pt, squirt_progress)
		var stream_w := 7.0 * squirt_power
		
		# Çapraz ana akış (doğrudan fincandaki kahvenin merkezine)
		draw_line(start_pt, tip, main_color, stream_w, true)
		draw_line(start_pt, tip, highlight_color, maxf(2.5, stream_w * 0.45), true)
		
		# Çapraz hatta dik normal vektör (damlacık yayılımı için)
		var dir := (end_pt - start_pt).normalized()
		var normal := Vector2(-dir.y, dir.x)
		
		# Çapraz hat boyunca fincana süzülen damlacıklar
		for d in drops:
			var p: float = clampf((squirt_progress - d.delay) * d.speed, 0.0, 1.0)
			if p > 0.0:
				var drop_pos: Vector2 = start_pt.lerp(end_pt, p) + normal * (d.spread * sin(p * PI))
				draw_circle(drop_pos, d.radius, d.color)
				
		# Sıvı kahveye ulaştığında oluşan hafif dalgalanma halkası
		if squirt_progress > 0.7:
			var splash_p: float = (squirt_progress - 0.7) / 0.3
			var splash_radius: float = 14.0 * splash_p * squirt_power
			var splash_color := highlight_color
			splash_color.a = 1.0 - splash_p
			draw_circle(end_pt, splash_radius, splash_color)

func _ready() -> void:
	grater_node = GraterVisual.new()
	add_child(grater_node)
	move_child(grater_node, jar.get_index())
	
	flakes_node = FlakesVisual.new()
	add_child(flakes_node)
	move_child(flakes_node, cup.get_index() + 1)
	
	juice_node = JuiceVisual.new()
	add_child(juice_node)
	move_child(juice_node, cup.get_index() + 1)
	
	grater_node.visible = false
	flakes_node.visible = false
	juice_node.visible = false
	
	liquid.pivot_offset = liquid.size / 2.0
	resized.connect(_layout)
	_layout()

## Kavanoz eğimi, ses efektinin yeri/açısı/boyutu ve anlatım kutusunun köşesi rastgele.
func randomize_look(rng: RandomNumberGenerator) -> void:
	if action_type == "pour":
		jar.rotation = rng.randf_range(JAR_TILT.x, JAR_TILT.y)
	sfx.rotation = rng.randf_range(SFX_TILT.x, SFX_TILT.y)
	sfx_size = rng.randf_range(SFX_SCALE.x, SFX_SCALE.y)
	sfx_offset = Vector2(rng.randf_range(-SFX_DRIFT, SFX_DRIFT), rng.randf_range(-SFX_DRIFT, SFX_DRIFT) * 0.6)
	caption_bottom = rng.randf() < 0.35
	_layout()

## Kavanoz üstte eğik, akış ortadan iner, fincan tezgâhın üstünde durur.
func _layout() -> void:
	var center_x := size.x / 2.0
	for node: Control in [$Backdrop, $Dots, art, $Frame]:
		node.position = Vector2.ZERO
		node.size = size
	cup.position = Vector2(center_x - cup.size.x / 2.0, size.y * COUNTER_TOP + 12.0 - cup.size.y)
	var cup_top_y := cup.position.y
	
	match action_type:
		"grate":
			if grater_node:
				grater_node.size = Vector2(80, 140)
				grater_node.pivot_offset = Vector2(40, 70)
				grater_node.position = Vector2(center_x - 35.0, cup_top_y - 130.0)
				grater_node.rotation_degrees = -26.0
			if flakes_node:
				flakes_node.position = Vector2(center_x - 50.0, cup_top_y - 85.0)
				flakes_node.size = Vector2(100.0, 110.0)
			jar.position = Vector2(center_x - 15.0, cup_top_y - 170.0)
			jar.pivot_offset = jar.size / 2.0
			jar.rotation_degrees = 38.0
			jar_base_scale = Vector2(1.15, 1.15)
			jar.scale = jar_base_scale
			jar_base_pos = jar.position
			jar_base_rot = jar.rotation
			stream.visible = false
		"squeeze":
			# Hedef: fincandaki kahvenin tam merkezi
			var target_pos := Vector2(center_x, cup_top_y + LIQUID_DEPTH)
			
			# Sağdan sola çapraz açı (26 derece) ve döküm hattı
			var angle_deg := 26.0
			var angle_rad := deg_to_rad(angle_deg)
			var stream_dist := 145.0
			# stream_dir: sağ üstten sol alta doğru (-x, +y)
			var stream_dir := Vector2(-sin(angle_rad), cos(angle_rad))
			
			# Spout: kahvenin merkezinden sağ-yukarı geriye doğru hesaplanır
			var spout := target_pos - stream_dir * stream_dist
			
			# Şişe/Limon konumu: ağzı spout noktasında olacak şekilde sağ-üst çapraza yerleştirilir
			var jar_center := spout - stream_dir * 70.0
			jar.position = jar_center - jar.size / 2.0
			jar.pivot_offset = jar.size / 2.0
			# PNG boyutu biraz büyütüldü (daha belirgin ve net görünüm)
			jar_base_scale = Vector2(1.28, 1.28)
			jar.scale = jar_base_scale
			
			# Bal başlangıçta düz durur (sıkarken 180° dönecek), limon doğrudan sağdan sola çapraz açıyla başlar
			if current_item_id == "honey":
				jar.rotation_degrees = 0.0
			else:
				jar.rotation_degrees = angle_deg
				
			jar_base_pos = jar.position
			jar_base_rot = jar.rotation
			
			if juice_node:
				juice_node.position = Vector2.ZERO
				juice_node.size = size
				juice_node.rotation = 0.0
				var color := Color("e0a030") if current_item_id == "honey" else Color("fae14b")
				var highlight := Color("ffd55e") if current_item_id == "honey" else Color("fffca8")
				var seed_v := 7777 if current_item_id == "honey" else 2026
				juice_node.setup_path(spout, target_pos, color, highlight, seed_v)
				
			stream.visible = false
		_:
			jar.position = Vector2(center_x - 12.0, size.y * JAR_TOP)
			jar.pivot_offset = Vector2(64, 80)
			jar_base_scale = Vector2.ONE
			jar.scale = jar_base_scale
			jar_base_pos = jar.position
			jar_base_rot = jar.rotation
			stream.position = Vector2(center_x - stream.size.x / 2.0, jar.position.y + 160.0)
			stream_length = cup.position.y + LIQUID_DEPTH - stream.position.y
			stream.size.y = stream_length
			stream.visible = not art.visible
			
	sfx.position = Vector2(center_x - sfx.size.x / 2.0, size.y * SFX_TOP) + sfx_offset
	var caption_box: Control = $Caption
	caption_box.position = Vector2(CAPTION_MARGIN, size.y - caption_box.size.y - CAPTION_MARGIN if caption_bottom else CAPTION_MARGIN)
	pivot_offset = size / 2.0
	sfx.pivot_offset = sfx.size / 2.0

## mixed_color: bu adıma kadar eklenenlerin karışım rengi (fincandaki sıvı).
func setup(item: Dictionary, index: int, mixed_color: Color) -> void:
	var item_id := str(item.get("id", ""))
	current_item_id = item_id
	if item_id == "cinnamon":
		action_type = "grate"
	elif item_id in ["lemon", "honey"]:
		action_type = "squeeze"
	else:
		action_type = "pour"
		
	caption.text = "%d · %s" % [index + 1, str(item.get("name", "")).to_upper()]
	sfx.text = str(item.get("sfx", ""))
	var art_path := ART_PATH % item_id
	var has_art := ResourceLoader.exists(art_path)
	art.visible = has_art
	if has_art:
		art.texture = load(art_path)
	for node: CanvasItem in [jar, stream, cup]:
		node.visible = not has_art
		
	if grater_node:
		grater_node.visible = not has_art and action_type == "grate"
	if flakes_node:
		flakes_node.visible = not has_art and action_type == "grate"
	if juice_node:
		juice_node.visible = not has_art and action_type == "squeeze"
		
	var icon_path := "res://assets/custom/coffee_pot.png" if item_id == "coffee" and ResourceLoader.exists("res://assets/custom/coffee_pot.png") else ICON_PATH % item_id
	jar.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	stream.modulate = Color(str(item.get("color", "ffffff")))
	liquid.modulate = mixed_color
	_layout()

func reset() -> void:
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)
	sfx.modulate.a = 0.0
	liquid.scale = Vector2.ONE
	jar.position = jar_base_pos
	jar.rotation = jar_base_rot
	jar.scale = jar_base_scale
	
	if grater_node:
		grater_node.visible = not art.visible and action_type == "grate"
	if flakes_node:
		flakes_node.visible = not art.visible and action_type == "grate"
		flakes_node.progress = 0.0
	if juice_node:
		juice_node.visible = not art.visible and action_type == "squeeze"
		juice_node.squirt_progress = 0.0
		juice_node.squirt_power = 1.0
		
	if action_type == "pour":
		stream.size.y = 0.0
		stream.visible = not art.visible
	else:
		stream.visible = false

func show_instantly() -> void:
	modulate.a = 1.0
	scale = Vector2.ONE
	sfx.modulate.a = 1.0
	sfx.scale = Vector2.ONE * sfx_size
	match action_type:
		"grate":
			if grater_node: grater_node.visible = not art.visible
			if flakes_node:
				flakes_node.visible = not art.visible
				flakes_node.progress = 1.0
			stream.visible = false
		"squeeze":
			if juice_node:
				juice_node.visible = not art.visible
				juice_node.squirt_progress = 1.0
			if current_item_id == "honey":
				jar.rotation_degrees = -154.0
			else:
				jar.rotation_degrees = 26.0
			jar.scale = jar_base_scale * Vector2(0.70, 1.14)
			stream.visible = false
		_:
			stream.visible = not art.visible
			stream.size.y = stream_length

## Kare belirir → akış/rende/sıkma animasyonu oynar → ses efekti patlar. Bekleyebilmek için tween döner.
func play() -> Tween:
	reset()
	var chain := create_tween()
	chain.set_parallel(true)
	chain.tween_property(self, "modulate:a", 1.0, POP_TIME)
	chain.tween_property(self, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chain.set_parallel(false)
	
	match action_type:
		"grate":
			_animate_grate(chain)
		"squeeze":
			_animate_squeeze(chain)
		_:
			_animate_pour(chain)
			
	return chain

func _animate_grate(chain: Tween) -> void:
	var stroke_vec := Vector2(20.0, 26.0)
	var pos1 := jar_base_pos + stroke_vec
	var pos0 := jar_base_pos
	
	# Rende vuruşları (ileri geri sürtme hareketi)
	chain.tween_property(jar, "position", pos1, 0.07).set_trans(Tween.TRANS_SINE)
	chain.parallel().tween_property(flakes_node, "progress", 0.3, 0.07)
	chain.tween_property(jar, "position", pos0, 0.06).set_trans(Tween.TRANS_SINE)
	
	chain.tween_property(jar, "position", pos1, 0.07).set_trans(Tween.TRANS_SINE)
	chain.parallel().tween_property(flakes_node, "progress", 0.65, 0.07)
	chain.tween_property(jar, "position", pos0, 0.05).set_trans(Tween.TRANS_SINE)
	
	chain.tween_property(jar, "position", pos1 * 1.05, 0.08).set_trans(Tween.TRANS_QUAD)
	chain.parallel().tween_property(flakes_node, "progress", 1.0, 0.08)
	
	chain.tween_callback(func() -> void:
		sfx.scale = Vector2(1.6, 1.6)
	)
	chain.set_parallel(true)
	chain.tween_property(sfx, "modulate:a", 1.0, 0.08)
	chain.tween_property(sfx, "scale", Vector2.ONE * sfx_size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chain.parallel().tween_property(liquid, "scale", Vector2(1.06, 1.06), 0.1)
	chain.set_parallel(false)
	chain.tween_property(liquid, "scale", Vector2.ONE, 0.1)

func _animate_squeeze(chain: Tween) -> void:
	if current_item_id == "honey":
		# Bal şişesini önce 180 derece çevirip sağdan sola çapraz döküm açısına (-154°) getir
		chain.tween_property(jar, "rotation", deg_to_rad(-154.0), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		# Limon için sağdan sola çapraz akış açısına (26°) yumuşak yerleşme
		chain.tween_property(jar, "rotation", deg_to_rad(26.0), 0.10).set_trans(Tween.TRANS_SINE)
		
	# Yatay sıkma kuvveti (horizontal compression: X ekseninde iki yandan bastırılır, Y ekseninde uzar)
	# 1. İlk sıkma baskısı
	chain.tween_property(jar, "scale", jar_base_scale * Vector2(0.74, 1.16), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	chain.parallel().tween_property(juice_node, "squirt_power", 0.85, 0.09)
	chain.parallel().tween_property(juice_node, "squirt_progress", 0.45, 0.09)
	
	# Yatay sıkma baskısı altında hafif titreme
	chain.tween_property(jar, "position:x", jar_base_pos.x - 3.0, 0.03)
	chain.tween_property(jar, "position:x", jar_base_pos.x + 3.0, 0.03)
	chain.tween_property(jar, "position:x", jar_base_pos.x, 0.02)
	
	# Hafif gevşeme
	chain.tween_property(jar, "scale", jar_base_scale * Vector2(0.88, 1.08), 0.06)
	
	# 2. Güçlü ikinci yatay sıkma (derin yatay baskı, sağdan sola çapraz fışkırıp doğrudan kahveye dökülme)
	chain.tween_property(jar, "scale", jar_base_scale * Vector2(0.55, 1.28), 0.11).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	chain.parallel().tween_property(juice_node, "squirt_power", 1.4, 0.11)
	chain.parallel().tween_property(juice_node, "squirt_progress", 1.0, 0.11)
	
	chain.tween_callback(func() -> void:
		sfx.scale = Vector2(1.7, 1.7)
	)
	chain.set_parallel(true)
	chain.tween_property(sfx, "modulate:a", 1.0, 0.08)
	chain.tween_property(sfx, "scale", Vector2.ONE * sfx_size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	chain.parallel().tween_property(liquid, "scale", Vector2(1.08, 1.08), 0.1)
	chain.set_parallel(false)
	chain.tween_property(liquid, "scale", Vector2.ONE, 0.1)
	# Sıkılmış halde kalması (remains horizontally compressed)
	chain.tween_property(jar, "scale", jar_base_scale * Vector2(0.70, 1.14), 0.08)

func _animate_pour(chain: Tween) -> void:
	chain.tween_property(stream, "size:y", stream_length, POUR_TIME).set_ease(Tween.EASE_IN)
	chain.tween_callback(func() -> void: sfx.scale = Vector2(1.6, 1.6))
	chain.set_parallel(true)
	chain.tween_property(sfx, "modulate:a", 1.0, 0.08)
	chain.tween_property(sfx, "scale", Vector2.ONE * sfx_size, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
