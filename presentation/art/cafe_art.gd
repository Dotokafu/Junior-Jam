@tool
extends Control
const UI = preload("res://presentation/ui/ui.gd")
## Özgün, kodla çizilen piksel dekor. Hikâye/oyun kuralları içermez.
var night: bool = false
var fallen_shelf: bool = false
var reduced_motion: bool = false
var person: Dictionary = {}
var clock_time: float = 0.0
var frame_time: float = 0.0
var shutter: float = 0.0
var shutter_tween: Tween
var character_texture: Texture2D
var character_texture_path: String = ""
var background_texture: Texture2D
var counter_texture: Texture2D
var title_font: Font = preload("res://assets/fonts/LiberationSerif-Italic.ttf")
var mono_font: Font = preload("res://assets/fonts/LiberationMono-Regular.ttf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or reduced_motion:
		return
	clock_time += delta
	frame_time += delta
	if frame_time >= 0.05:
		frame_time = 0
		queue_redraw()

func set_scene(is_night: bool, is_fallen: bool, character: Dictionary) -> void:
	night = is_night
	person = character
	var path: String = character.get("portrait_texture", "")
	if path != character_texture_path:
		character_texture_path = path
		character_texture = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	if fallen_shelf != is_fallen and not reduced_motion:
		if shutter_tween:
			shutter_tween.kill()
		shutter_tween = create_tween()
		shutter_tween.tween_property(self, "shutter", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		shutter_tween.tween_callback(func() -> void: fallen_shelf = is_fallen)
		shutter_tween.tween_property(self, "shutter", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		fallen_shelf = is_fallen
	queue_redraw()

func r(x: float, y: float, w: float, h: float, color: String) -> void:
	draw_rect(Rect2(x, y, w, h), Color(color))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(size.x / 680.0, size.y / 190.0))
	r(0, 0, 680, 190, "28222e")
	if background_texture:
		draw_texture_rect(background_texture, Rect2(0, 0, 680, 190), false)
	else:
		_wall()
		_window()
		_shelves()
		_machines()
		_lamps()
	if not person.is_empty():
		if character_texture:
			draw_texture_rect(character_texture, Rect2(308, 22, 107, 148), false)
		else:
			_portrait(Vector2(360, 29), 1.32)
	if counter_texture:
		draw_texture_rect(counter_texture, Rect2(0, 0, 680, 190), false)
	elif not background_texture:
		_counter()
	# Camdaki küçük çizikler ve analog dokusu.
	for y in range(0, 190, 3):
		draw_rect(Rect2(0, y, 680, 1), Color(0.01, 0.01, 0.02, 0.08))
	r(0, 0, 680, 2, "17151e")
	r(0, 188, 680, 2, "17151e")

func _wall() -> void:
	r(0, 0, 191, 158, "39303a")
	for y in range(12, 158, 15):
		r(0, y, 191, 1, "302933")
		for x in range(-20 if y % 2 == 0 else 5, 191, 36):
			r(x, y, 1, 14, "302933")
	r(492, 0, 188, 159, "3e3039")
	for y in range(10, 155, 16):
		r(492, y, 188, 1, "332932")
	r(0, 2, 680, 8, "211e28")
	r(9, 10, 3, 146, "56404a")
	# Duvardaki küçük çerçeve.
	r(504, 24, 44, 54, "211e27")
	r(507, 27, 38, 48, "9d8a77")
	r(511, 31, 30, 35, "2f3940")
	r(523, 36, 7, 12, "ad9381")
	r(516, 48, 21, 18, "545060")
	r(519, 69, 15, 2, "685949")

func _window() -> void:
	r(190, 10, 303, 149, "1a1d2c")
	var sky := Color("32364b") if night else Color("776675")
	for i in range(8):
		draw_rect(Rect2(196, 14 + i * 17, 290, 17), sky.darkened(i * 0.045))
	# Skyline en drie lagen, deterministisch.
	for i in range(20):
		var x := 194 + i * 16
		var h := 22 + (i * 37 % 57)
		r(x, 139 - h, 18, h, "474154" if not night else "272c40")
		r(x + 2, 136 - h, 2, 3, "535064")
	for i in range(12):
		var x := 198 + i * 25
		var h := 27 + (i * 29 % 51)
		r(x, 147 - h, 23, h, "363448" if not night else "202637")
		for row in range(3, h - 5, 9):
			for col in range(3, 21, 7):
				if (i * 3 + row + col) % 4 != 0:
					r(x + col, 147 - h + row, 3, 4, "a38975" if not night else "b6976b")
	# Tramvay kabloları ve uzaktaki neon.
	draw_line(Vector2(196, 63), Vector2(486, 81), Color("373042"), 1)
	draw_line(Vector2(196, 69), Vector2(486, 87), Color("373042"), 1)
	r(235, 105, 19, 28, "74516f")
	r(240, 108, 2, 22, "d599a0")
	r(246, 109, 3, 3, "d599a0")
	r(246, 116, 3, 3, "d599a0")
	r(246, 123, 3, 3, "d599a0")
	# Yağmur, camda kayan çizgiler.
	for i in range(63):
		var x := 199 + (i * 71 % 280)
		var y := 17 + fmod(i * 31 + clock_time * (11 + i % 9), 130)
		draw_line(Vector2(x, y), Vector2(x - 2, y + 7 + i % 6), Color(0.69, 0.73, 0.8, 0.17), 1)
	r(190, 10, 6, 151, "211f2b")
	r(486, 10, 7, 151, "211f2b")
	r(329, 10, 5, 151, "272330")
	r(194, 20, 295, 4, "28232e")
	r(194, 143, 295, 6, "332b36")
	r(189, 150, 307, 9, "5c4447")
	r(191, 150, 302, 2, "927264")
	# Asılı OPEN kartı.
	draw_line(Vector2(457, 32), Vector2(442, 48), Color("9e8b80"))
	draw_line(Vector2(457, 32), Vector2(475, 48), Color("9e8b80"))
	r(435, 47, 46, 18, "292535")
	draw_string(mono_font, Vector2(442, 59), UI.text("decor.open"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("c7ad84"))

func _shelves() -> void:
	r(23, 27, 149, 116, "211e28")
	for row in range(2):
		var y := 37 + row * 53
		r(25, y, 145, 42, "302832")
		for i in range(6):
			var x := 32 + i * 23
			var color: String = ["997351", "dbccb0", "6b4850", "8f986c", "c09250", "7d9ba3"][i]
			if fallen_shelf:
				color = ["853c53", "bfaa91", "878190", "a56c78", "92935f", "a9abbc"][i]
			r(x + 3, y + 4, 10, 4, "1c1c26")
			r(x + 1, y + 8, 14, 28, "55505a")
			r(x + 2, y + 13, 12, 22, color)
			r(x + 2, y + 23, 12, 8, "c8b99c" if not fallen_shelf else "6c4a5a")
			r(x + 5, y + 25, 6, 1, "655149")
			r(x + 3, y + 10, 2, 10, "9b9190")
		r(22, y + 39, 153, 5, "6d4f4e")
		r(22, y + 39, 153, 1, "ab7c62")
	r(18, 25, 5, 124, "4b3640")
	r(173, 25, 5, 124, "4b3640")
	if shutter > 0:
		var h := 120 * shutter
		r(22, 27, 153, h, "4c4752")
		for y in range(28, int(27 + h), 6):
			r(22, y, 153, 2, "312e3d")
		r(22, 25 + h, 153, 3, "b0a3a0")
	# Çuval ve saksı.
	r(20, 139, 32, 21, "85715a")
	r(23, 135, 26, 6, "a18a6d")
	r(31, 145, 10, 6, "4b3b38")
	r(157, 139, 20, 22, "a56e57")
	r(155, 137, 24, 4, "c38e67")
	for i in range(7):
		var x := 156 + i * 3
		r(x, 119 - i % 3 * 5, 4, 19, "737c59")
		r(x - 3, 116 - i % 3 * 5, 7, 5, "8b9569")

func _lamps() -> void:
	for x in [102, 292, 569]:
		r(x, 0, 2, 22, "171923")
		draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 34), Vector2(x - 6, 22), Vector2(x + 8, 22), Vector2(x + 15, 34)]), Color("29242c"))
		r(x - 12, 34, 27, 3, "ba8c63")
		draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 37), Vector2(x + 13, 37), Vector2(x + 65, 154), Vector2(x - 60, 154)]), Color(0.91, 0.69, 0.43, 0.045))

func _machines() -> void:
	# Espresso makinesi: krom, sıcak ışık, bardaklar.
	r(558, 105, 101, 51, "22242e")
	r(562, 109, 93, 35, "666575")
	r(564, 112, 88, 5, "9a9394")
	r(568, 121, 80, 21, "353541")
	r(572, 145, 76, 4, "a59c98")
	r(576, 149, 68, 5, "46424b")
	for x in [579, 606, 632]:
		r(x, 123, 3, 11, "b3a8a1")
		r(x - 5, 127, 15, 3, "252431")
		r(x - 4, 137, 11, 8, "d5c4ae")
		r(x - 2, 137, 7, 2, "725b51")
	for x in [572, 589, 606, 623, 640]:
		r(x, 96, 11, 9, "bcae9e")
		r(x + 1, 95, 9, 2, "e5d4b9")
	r(650, 119, 2, 3, "bba26d")
	# Kahve öğütücü.
	r(505, 125, 32, 31, "49444e")
	r(510, 104, 22, 23, "867e82")
	r(511, 107, 20, 15, "5b423f")
	r(509, 102, 24, 3, "252330")
	r(516, 127, 10, 15, "aaa09b")
	r(512, 150, 19, 4, "272430")

func _portrait(origin: Vector2, factor: float) -> void:
	draw_set_transform(origin * Vector2(size.x / 680.0, size.y / 190.0), 0, Vector2(size.x / 680.0, size.y / 190.0) * factor)
	var skin := Color(person.get("skin", "b9a08f"))
	var hair := Color(person.get("hair", "382e3d"))
	var coat := Color(person.get("coat", "747081"))
	var id: String = person.get("portrait_id", person.get("id", ""))
	# Silhouette en trapvormige randen geven echte pixelcontouren.
	draw_colored_polygon(PackedVector2Array([Vector2(-30, 106), Vector2(-30, 75), Vector2(-23, 75), Vector2(-23, 65), Vector2(-13, 65), Vector2(-13, 59), Vector2(17, 59), Vector2(17, 65), Vector2(26, 65), Vector2(26, 74), Vector2(32, 74), Vector2(36, 106)]), coat.darkened(0.33))
	draw_rect(Rect2(-22, 69, 47, 37), coat)
	draw_rect(Rect2(-27, 78, 8, 28), coat.darkened(0.15))
	draw_rect(Rect2(25, 78, 7, 28), coat.darkened(0.2))
	draw_rect(Rect2(-7, 57, 15, 14), skin.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 64), Vector2(-6, 70), Vector2(0, 94), Vector2(-16, 78)]), coat.lightened(0.17))
	draw_colored_polygon(PackedVector2Array([Vector2(15, 64), Vector2(7, 70), Vector2(0, 94), Vector2(18, 77)]), coat.lightened(0.1))
	draw_rect(Rect2(-3, 74, 8, 31), Color("39333e"))
	# Başın arkasındaki saç.
	draw_rect(Rect2(-17, 17, 37, 43), hair.darkened(0.15))
	draw_rect(Rect2(-21, 24, 8, 24), hair)
	draw_rect(Rect2(18, 24, 5, 26), hair)
	draw_rect(Rect2(-13, 26, 29, 29), skin)
	draw_rect(Rect2(-17, 34, 4, 13), skin.darkened(0.16))
	draw_rect(Rect2(16, 34, 4, 12), skin.darkened(0.2))
	draw_rect(Rect2(-9, 52, 21, 9), skin.darkened(0.08))
	draw_rect(Rect2(-5, 59, 12, 3), skin.darkened(0.17))
	draw_rect(Rect2(11, 30, 5, 24), skin.darkened(0.15))
	draw_rect(Rect2(-10, 29, 8, 5), skin.lightened(0.1))
	draw_rect(Rect2(-2, 38, 5, 10), skin.darkened(0.17))
	draw_rect(Rect2(-1, 39, 2, 7), skin.lightened(0.15))
	# Saç tutamları ve kaşlar.
	draw_rect(Rect2(-14, 17, 29, 10), hair)
	draw_rect(Rect2(-19, 24, 18, 8), hair)
	draw_rect(Rect2(7, 24, 12, 7), hair)
	draw_rect(Rect2(-10, 15, 19, 3), hair.lightened(0.12))
	draw_rect(Rect2(-13, 35, 9, 2), hair.lightened(0.1))
	draw_rect(Rect2(5, 35, 9, 2), hair.lightened(0.1))
	draw_rect(Rect2(-12, 39, 8, 3), Color("d5c4b6"))
	draw_rect(Rect2(5, 39, 8, 3), Color("d5c4b6"))
	draw_rect(Rect2(-9, 39, 3, 3), Color("443d48"))
	draw_rect(Rect2(7, 39, 3, 3), Color("443d48"))
	draw_rect(Rect2(-11, 43, 7, 2), skin.darkened(0.2))
	draw_rect(Rect2(6, 43, 7, 2), skin.darkened(0.2))
	draw_rect(Rect2(-4, 53, 10, 2), Color("805d61"))
	if id in ["defne", "mira", "saye", "narin"]:
		draw_rect(Rect2(-21, 30, 7, 36), hair)
		draw_rect(Rect2(16, 27, 8, 40), hair)
		draw_rect(Rect2(21, 40, 4, 22), hair.lightened(0.1))
	if id == "ada":
		draw_rect(Rect2(-17, 18, 38, 8), Color("c3c7b7"))
		r(-2, 18, 3, 8, "976064")
		r(-5, 21, 9, 2, "976064")
	if id == "atlas":
		r(6, 39, 6, 3, "bba76e")
		r(8, 39, 2, 3, "ebe1bf")
		r(-7, 64, 18, 5, "d7c9b3")
	if id == "ilya":
		draw_rect(Rect2(-14, 37, 12, 8), Color("494453"), false, 1)
		draw_rect(Rect2(4, 37, 12, 8), Color("494453"), false, 1)
	if id == "vey":
		r(-18, 14, 38, 7, "25232d")
		r(-26, 21, 54, 5, "25232d")
	if id == "eren" and night:
		r(-9, 39, 2, 2, "be8c8b")
		r(8, 39, 2, 2, "be8c8b")
	# Cep, dikişler, eller.
	draw_rect(Rect2(13, 89, 10, 2), coat.darkened(0.3))
	draw_rect(Rect2(-25, 101, 15, 5), skin.darkened(0.05))
	draw_rect(Rect2(20, 101, 14, 5), skin.darkened(0.1))
	draw_set_transform(Vector2.ZERO, 0, Vector2(size.x / 680.0, size.y / 190.0))

func _counter() -> void:
	r(0, 157, 680, 5, "b78b71")
	r(0, 162, 680, 8, "70504c")
	r(0, 170, 680, 20, "49343c")
	r(0, 170, 680, 2, "322934")
	for i in range(16):
		r(i * 47, 173 + i % 4 * 3, 29, 1, "573e42")
	# Fincan ve tabağı.
	r(287, 160, 29, 3, "bfa48a")
	r(293, 148, 17, 12, "ded0b6")
	r(309, 150, 6, 7, "ded0b6")
	r(310, 151, 3, 4, "6c5050")
	r(294, 147, 15, 3, "80604e")
	for i in range(3):
		var x: float = 297 + i * 4 + sin(clock_time * 1.2 + i) * 1.6
		draw_line(Vector2(x, 142), Vector2(x + 2, 131 - i * 3), Color(0.84, 0.8, 0.76, 0.25), 1)
	# Defter, radyo ve ıslak pencerenin yansıması.
	r(57, 161, 44, 4, "322a34")
	r(60, 157, 38, 4, "b5a58b")
	r(61, 155, 35, 3, "7e6e6e")
	r(601, 154, 47, 11, "453b43")
	for x in range(605, 634, 3):
		r(x, 157, 1, 5, "9a8477")
	r(639, 157, 5, 5, "b49b77")
	draw_string(title_font, Vector2(435, 182), UI.text("decor.counter_motto"), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("a3847b"))
