extends SceneTree
## Yer tutucu çizimleri ve temayı üretir. Var olan dosyaya dokunmaz; --force ile yeniden yazar.
## Çalıştır: godot --headless --path . -s tools/generate_mock_assets.gd
## Çizimler 640×360 ölçeğinde üretilir, oyunda ×3 büyütülür (nearest filtre).
const ART_SCALE := 3
var force := false
var written: Array[String] = []

func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	for folder: String in ["res://assets/cafe", "res://assets/characters", "res://assets/ui/ingredients", "res://presentation/theme"]:
		DirAccess.make_dir_recursive_absolute(folder)
	_save(_background(false), "res://assets/cafe/background_day.png")
	_save(_background(true), "res://assets/cafe/background_night.png")
	_save(_counter(), "res://assets/cafe/counter.png")
	_save(_cup(), "res://assets/cafe/cup.png")
	_save(_cup_liquid(), "res://assets/cafe/cup_liquid.png")
	var characters: Array = _json("res://content/characters.json").get("characters", [])
	for person: Dictionary in characters:
		_save(_character(person), "res://assets/characters/%s.png" % person.id)
	for item: Dictionary in _json("res://content/ingredients.json").get("ingredients", []):
		_save(_ingredient(item), "res://assets/ui/ingredients/%s.png" % item.id)
	if force or not FileAccess.file_exists("res://presentation/theme/cafe_theme.tres"):
		ResourceSaver.save(_theme(), "res://presentation/theme/cafe_theme.tres")
		written.append("cafe_theme.tres")
	print("MOCK ASSETS: ", written.size(), " dosya yazıldı")
	quit()

func _json(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}

func _save(image: Image, path: String) -> void:
	if not force and FileAccess.file_exists(path):
		return
	image.save_png(path)
	written.append(path.get_file())

func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, image.get_size())), color)

func _background(night: bool) -> Image:
	var image := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	var brick := Color("3a2a36") if night else Color("6b4436")
	var mortar := brick.darkened(0.25)
	image.fill(brick)
	for row in range(0, 360, 9):
		_rect(image, 0, row, 640, 1, mortar)
		var offset := 0 if (row / 9) % 2 == 0 else 12
		for column in range(offset, 640, 24):
			_rect(image, column, row, 1, 9, mortar)
	# Pencere ve şehir
	_rect(image, 372, 34, 240, 222, Color("231b26"))
	var glass := Color("1b2140") if night else Color("9bb4c2")
	_rect(image, 380, 42, 224, 206, glass)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(14):
		var w := rng.randi_range(12, 26)
		var h := rng.randi_range(40, 150)
		var x := 380 + i * 16
		_rect(image, x, 248 - h, w, h, Color("141831") if night else Color("7b93a3"))
		if night:
			for wy in range(248 - h + 6, 244, 9):
				if rng.randf() < 0.45:
					_rect(image, x + 4, wy, 3, 3, Color("e9c46a"))
	_rect(image, 488, 42, 6, 206, Color("231b26"))
	_rect(image, 380, 140, 224, 5, Color("231b26"))
	if night:
		for i in range(60):
			var rx := rng.randi_range(380, 600)
			var ry := rng.randi_range(42, 230)
			_rect(image, rx, ry, 1, 6, Color(0.7, 0.75, 0.9, 0.35))
	# Neon tabela
	_rect(image, 520, 60, 64, 22, Color("2a1d2b"))
	_rect(image, 524, 64, 56, 14, Color("e07a9a") if night else Color("8a6f78"))
	# Raflar ve kavanozlar
	for shelf_y: int in [92, 152, 212]:
		_rect(image, 28, shelf_y, 300, 6, Color("4a3428"))
		_rect(image, 28, shelf_y + 6, 300, 2, Color("2b1f19"))
		for jar in range(9):
			var jar_color := Color.from_hsv(rng.randf(), 0.35, 0.75 if not night else 0.5)
			var jh := rng.randi_range(18, 30)
			_rect(image, 38 + jar * 32, shelf_y - jh, 20, jh, jar_color)
			_rect(image, 38 + jar * 32, shelf_y - jh, 20, 4, jar_color.darkened(0.4))
			_rect(image, 42 + jar * 32, shelf_y - jh + 10, 12, 6, Color("efe3c8"))
	# Lamba
	_rect(image, 300, 0, 2, 40, Color("1a1418"))
	_rect(image, 284, 40, 34, 10, Color("2a2024"))
	_rect(image, 290, 50, 22, 3, Color("f3d48b"))
	if not night:
		return image
	# Gece: lambanın altında sıcak ışık
	for y in range(53, 300):
		var alpha := 0.10 * (1.0 - float(y - 53) / 247.0)
		for x in range(301 - (y - 53) / 2, 301 + (y - 53) / 2):
			if x >= 0 and x < 640:
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(Color("f3d48b"), alpha))
	return image

func _counter() -> Image:
	var image := Image.create(640, 110, false, Image.FORMAT_RGBA8)
	image.fill(Color("2e2226"))
	_rect(image, 0, 0, 640, 12, Color("8c6b55"))
	_rect(image, 0, 12, 640, 3, Color("5e4638"))
	for x in range(0, 640, 80):
		_rect(image, x + 6, 24, 68, 78, Color("3a2b30"))
		_rect(image, x + 6, 24, 68, 2, Color("4a3940"))
	return image

func _cup() -> Image:
	var image := Image.create(32, 28, false, Image.FORMAT_RGBA8)
	_rect(image, 4, 6, 20, 18, Color("f1e9dc"))
	_rect(image, 6, 8, 16, 4, Color(0, 0, 0, 0))
	_rect(image, 24, 10, 5, 8, Color("f1e9dc"))
	_rect(image, 26, 12, 2, 4, Color(0, 0, 0, 0))
	_rect(image, 0, 24, 30, 4, Color("d8cbbb"))
	return image

func _cup_liquid() -> Image:
	var image := Image.create(32, 28, false, Image.FORMAT_RGBA8)
	_rect(image, 6, 8, 16, 4, Color.WHITE)
	return image

## 160×224 çizim alanı; figür 128×176 ızgarada tanımlı, 1.25 ile yerleşir.
func _character(person: Dictionary) -> Image:
	var image := Image.create(160, 224, false, Image.FORMAT_RGBA8)
	var figure := Image.create(128, 176, false, Image.FORMAT_RGBA8)
	_figure(figure, person)
	figure.resize(160, 220, Image.INTERPOLATE_NEAREST)
	image.blit_rect(figure, Rect2i(0, 0, 160, 220), Vector2i(0, 4))
	return image

func _figure(image: Image, person: Dictionary) -> void:
	var skin := Color(str(person.get("skin", "b79d8c")))
	var hair := Color(str(person.get("hair", "382d3d")))
	var coat := Color(str(person.get("coat", "71717f")))
	var outline := Color("1a1420")
	# Gövde ve kollar (tezgâha dayalı)
	_rect(image, 18, 86, 92, 90, outline)
	_rect(image, 20, 88, 88, 88, coat)
	_rect(image, 52, 88, 24, 26, coat.lightened(0.15))
	_rect(image, 58, 88, 12, 40, coat.darkened(0.3))
	_rect(image, 10, 150, 40, 18, coat.darkened(0.15))
	_rect(image, 78, 150, 40, 18, coat.darkened(0.15))
	_rect(image, 44, 152, 12, 12, skin)
	_rect(image, 72, 152, 12, 12, skin)
	# Boyun ve kafa
	_rect(image, 54, 74, 20, 16, skin.darkened(0.15))
	_rect(image, 34, 14, 60, 66, outline)
	_rect(image, 36, 16, 56, 62, hair)
	_rect(image, 40, 28, 48, 48, skin)
	_rect(image, 38, 18, 52, 14, hair)
	_rect(image, 36, 30, 6, 30, hair)
	_rect(image, 86, 30, 6, 30, hair)
	# Yüz
	_rect(image, 48, 46, 8, 4, outline)
	_rect(image, 72, 46, 8, 4, outline)
	_rect(image, 50, 46, 3, 2, Color("e9e2d6"))
	_rect(image, 74, 46, 3, 2, Color("e9e2d6"))
	_rect(image, 62, 52, 4, 8, skin.darkened(0.2))
	_rect(image, 58, 64, 12, 2, skin.darkened(0.35))

func _ingredient(item: Dictionary) -> Image:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	var tint := Color(str(item.get("color", "aaaaaa")))
	_rect(image, 5, 2, 14, 4, Color("4a3a33"))
	_rect(image, 4, 6, 16, 17, Color("1a1420"))
	_rect(image, 5, 7, 14, 15, tint)
	_rect(image, 6, 8, 3, 12, tint.lightened(0.35))
	_rect(image, 7, 12, 10, 5, Color("efe3c8"))
	return image

## Tasarımcılar bu dosyayı Godot'da açıp renk ve yazı tiplerini değiştirebilir.
func _theme() -> Theme:
	var theme := Theme.new()
	var body: Font = load("res://assets/fonts/LiberationSans-Regular.ttf")
	var serif: Font = load("res://assets/fonts/LiberationSerif-Italic.ttf")
	var mono: Font = load("res://assets/fonts/LiberationMono-Regular.ttf")
	theme.default_font = body
	theme.default_font_size = 28
	var ink := Color("efe3c8")
	var dark := Color("1c1620")
	theme.set_color("font_color", "Label", ink)
	theme.set_color("default_color", "RichTextLabel", ink)
	theme.set_font_size("normal_font_size", "RichTextLabel", 32)
	theme.set_stylebox("panel", "Panel", _box(Color("231c27"), Color("6b5763"), 3, 6))
	theme.set_stylebox("panel", "PanelContainer", _box(Color("231c27"), Color("6b5763"), 3, 6, 20))
	_button(theme, "Button", Color("2c2430"), Color("6b5763"), ink)
	_button(theme, "PrimaryButton", Color("d9b47a"), Color("f0d6a2"), dark)
	_button(theme, "IconButton", Color("1c1620cc"), Color("efe3c8"), ink)
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_type_variation("IconButton", "Button")
	theme.set_font_size("font_size", "IconButton", 22)
	# Konuşma balonu
	theme.set_type_variation("BalloonPanel", "PanelContainer")
	theme.set_stylebox("panel", "BalloonPanel", _box(Color("17121bee"), Color("efe3c8"), 3, 10, 26))
	theme.set_type_variation("NameTag", "Label")
	theme.set_color("font_color", "NameTag", Color("f0c987"))
	theme.set_font_size("font_size", "NameTag", 26)
	theme.set_font("font", "NameTag", mono)
	theme.set_type_variation("Caption", "Label")
	theme.set_color("font_color", "Caption", Color("b8a6a8"))
	theme.set_font_size("font_size", "Caption", 22)
	theme.set_font("font", "Caption", mono)
	theme.set_type_variation("Title", "Label")
	theme.set_font("font", "Title", serif)
	theme.set_font_size("font_size", "Title", 72)
	# Demleme makinesi
	theme.set_type_variation("MachinePanel", "PanelContainer")
	theme.set_stylebox("panel", "MachinePanel", _box(Color("e4d6bd"), Color("3b2f2c"), 4, 8, 22))
	theme.set_type_variation("MachineLabel", "Label")
	theme.set_color("font_color", "MachineLabel", Color("3b2f2c"))
	theme.set_font("font", "MachineLabel", mono)
	theme.set_font_size("font_size", "MachineLabel", 24)
	theme.set_type_variation("SlotPanel", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanel", _box(Color("f6eddc"), Color("3b2f2c"), 3, 4, 10))
	theme.set_type_variation("ShelfPanel", "PanelContainer")
	theme.set_stylebox("panel", "ShelfPanel", _box(Color("3a2a26"), Color("1c1620"), 4, 6, 18))
	# Defter ve telefon
	theme.set_type_variation("BookPage", "PanelContainer")
	theme.set_stylebox("panel", "BookPage", _box(Color("e8dcc0"), Color("8a6f55"), 3, 4, 36))
	theme.set_type_variation("BookText", "Label")
	theme.set_color("font_color", "BookText", Color("3d322c"))
	theme.set_type_variation("PhoneFrame", "PanelContainer")
	theme.set_stylebox("panel", "PhoneFrame", _box(Color("16131c"), Color("4e4658"), 10, 36, 30))
	theme.set_type_variation("PhoneScreen", "PanelContainer")
	theme.set_stylebox("panel", "PhoneScreen", _box(Color("d9e4df"), Color("0f0d12"), 4, 14, 22))
	theme.set_type_variation("PhoneText", "Label")
	theme.set_color("font_color", "PhoneText", Color("1f2a2a"))
	theme.set_font_size("font_size", "PhoneText", 24)
	return theme

func _box(fill: Color, border: Color, width: int, radius: int, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style

func _button(theme: Theme, type: String, fill: Color, border: Color, text: Color) -> void:
	theme.set_stylebox("normal", type, _box(fill, border, 3, 6, 12))
	theme.set_stylebox("hover", type, _box(fill.lightened(0.12), Color("f0c987"), 3, 6, 12))
	theme.set_stylebox("pressed", type, _box(fill.darkened(0.15), border, 3, 6, 12))
	theme.set_stylebox("disabled", type, _box(fill.darkened(0.35), border.darkened(0.5), 3, 6, 12))
	theme.set_stylebox("focus", type, _box(Color.TRANSPARENT, Color("f0c987"), 3, 6, 12))
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, type, text)
	theme.set_color("font_disabled_color", type, text.darkened(0.5) if text.v > 0.5 else text.lightened(0.4))
