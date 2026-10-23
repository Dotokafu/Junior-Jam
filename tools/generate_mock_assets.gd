extends SceneTree
## Yer tutucu çizimleri ve temayı üretir. Var olan dosyaya dokunmaz; --force ile yeniden yazar.
## Çalıştır: godot --headless --path . -s tools/generate_mock_assets.gd
## Mekân ve arayüz piksel: 640×360 ölçeğinde çizilir, ×3 büyütülür (nearest).
## Karakterler el çizimi: yüksek çözünürlük, yumuşak filtre (bkz. assets/README.md).
const UP := 3
const CHARACTER_SIZE := Vector2i(540, 780)
const OUTLINE := Color("1a1420")
const CREAM := Color("e6dcc2")
const INK := Color("2b2228")
var force := false
var written: Array[String] = []

func _initialize() -> void:
	force = "--force" in OS.get_cmdline_user_args()
	for folder: String in ["res://assets/cafe", "res://assets/characters", "res://assets/ui/ingredients", "res://assets/ui/icons", "res://assets/ui/chrome", "res://presentation/theme"]:
		DirAccess.make_dir_recursive_absolute(folder)
	_save(_background(false), "res://assets/cafe/background_day.png")
	_save(_background(true), "res://assets/cafe/background_night.png")
	_save(_counter(), "res://assets/cafe/counter.png")
	_save(_cup(), "res://assets/cafe/cup.png")
	_save(_cup_liquid(), "res://assets/cafe/cup_liquid.png")
	_save(_brew_shelf(), "res://assets/cafe/brew_shelf.png")
	for person: Dictionary in _json("res://content/characters.json").get("characters", []):
		_save(_character(person), "res://assets/characters/%s.png" % person.id)
	for item: Dictionary in _json("res://content/ingredients.json").get("ingredients", []):
		_save(_jar(item), "res://assets/ui/ingredients/%s.png" % item.id)
	_chrome()
	_icons()
	var wants_theme := force or not FileAccess.file_exists("res://presentation/theme/cafe_theme.tres")
	# Tema çerçeve dokularına bağlı; dokular içe aktarılmadan kurulursa çerçeveler boş kalır.
	if wants_theme and not ResourceLoader.exists("res://assets/ui/chrome/panel.png"):
		print("TEMA ATLANDI: önce 'godot --headless --path . --import' çalıştır, sonra bu scripti tekrar çalıştır.")
	elif wants_theme:
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

## Arayüz parçaları 1:1 kullanılır; piksel ızgarası korunsun diye kayıttan önce ×3 büyütülür.
func _save_up(image: Image, path: String) -> void:
	image.resize(image.get_width() * UP, image.get_height() * UP, Image.INTERPOLATE_NEAREST)
	_save(image, path)

func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, image.get_size())), color)

func _blank(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)

# --- Mekân (piksel) --------------------------------------------------------

func _background(night: bool) -> Image:
	var image := _blank(640, 360)
	var brick := Color("3a2a36") if night else Color("6b4436")
	var mortar := brick.darkened(0.25)
	image.fill(brick)
	for row in range(0, 360, 9):
		_rect(image, 0, row, 640, 1, mortar)
		var offset := 0 if (row / 9) % 2 == 0 else 12
		for column in range(offset, 640, 24):
			_rect(image, column, row, 1, 9, mortar)
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
			_rect(image, rng.randi_range(380, 600), rng.randi_range(42, 230), 1, 6, Color(0.7, 0.75, 0.9, 0.35))
	_rect(image, 520, 60, 64, 22, Color("2a1d2b"))
	_rect(image, 524, 64, 56, 14, Color("e07a9a") if night else Color("8a6f78"))
	for shelf_y: int in [92, 152, 212]:
		_rect(image, 28, shelf_y, 300, 6, Color("4a3428"))
		_rect(image, 28, shelf_y + 6, 300, 2, Color("2b1f19"))
		for jar in range(9):
			var jar_color := Color.from_hsv(rng.randf(), 0.35, 0.75 if not night else 0.5)
			var jh := rng.randi_range(18, 30)
			_rect(image, 38 + jar * 32, shelf_y - jh, 20, jh, jar_color)
			_rect(image, 38 + jar * 32, shelf_y - jh, 20, 4, jar_color.darkened(0.4))
			_rect(image, 42 + jar * 32, shelf_y - jh + 10, 12, 6, Color("efe3c8"))
	_rect(image, 300, 0, 2, 40, Color("1a1418"))
	_rect(image, 284, 40, 34, 10, Color("2a2024"))
	_rect(image, 290, 50, 22, 3, Color("f3d48b"))
	return image

func _counter() -> Image:
	var image := _blank(740, 80)
	image.fill(Color("4f6466"))
	_rect(image, 0, 0, 740, 3, Color("7a9294"))
	_rect(image, 0, 14, 740, 2, Color("3a4a4c"))
	_rect(image, 0, 16, 740, 64, Color("2a3133"))
	for x in range(0, 740, 80):
		_rect(image, x + 6, 26, 68, 50, Color("323b3d"))
	# Tezgâhta yapışkan notlar
	for i in range(3):
		_rect(image, 470 + i * 26, 4, 20, 9, Color("9ed39a").darkened(i * 0.08))
	return image

func _cup() -> Image:
	var image := _blank(32, 28)
	_rect(image, 4, 6, 20, 18, Color("f1e9dc"))
	_rect(image, 6, 8, 16, 4, Color(0, 0, 0, 0))
	_rect(image, 24, 10, 5, 8, Color("f1e9dc"))
	_rect(image, 26, 12, 2, 4, Color(0, 0, 0, 0))
	_rect(image, 0, 24, 30, 4, Color("d8cbbb"))
	return image

func _cup_liquid() -> Image:
	var image := _blank(32, 28)
	_rect(image, 6, 8, 16, 4, Color.WHITE)
	return image

## Demleme ekranının arka planı: yakından raf. Kavanozlar kodla üst rafa dizilir.
func _brew_shelf() -> Image:
	var image := _blank(380, 300)
	image.fill(Color("2c2026"))
	for row in range(0, 300, 10):
		_rect(image, 0, row, 380, 1, Color("231920"))
		var offset := 0 if (row / 10) % 2 == 0 else 14
		for column in range(offset, 380, 28):
			_rect(image, column, row, 1, 10, Color("231920"))
	for shelf_y: int in [100, 210]:
		_rect(image, 0, shelf_y, 380, 8, Color("6a4a36"))
		_rect(image, 0, shelf_y, 380, 2, Color("8a6448"))
		_rect(image, 0, shelf_y + 8, 380, 3, Color("1c1418"))
	# Alt rafta dekor
	_rect(image, 16, 180, 22, 30, Color("44524a"))
	_rect(image, 44, 192, 30, 18, Color("7c5a3a"))
	_rect(image, 22, 168, 10, 12, Color("5c8a52"))
	return image

func _jar(item: Dictionary) -> Image:
	var image := _blank(32, 40)
	var tint := Color(str(item.get("color", "aaaaaa")))
	_rect(image, 8, 0, 16, 6, Color("5a463c"))
	_rect(image, 8, 0, 16, 1, Color("7a6050"))
	_rect(image, 4, 6, 24, 34, OUTLINE)
	_rect(image, 5, 7, 22, 32, tint)
	_rect(image, 7, 9, 4, 26, tint.lightened(0.35))
	_rect(image, 8, 18, 16, 10, Color("efe3c8"))
	_rect(image, 10, 21, 12, 1, INK)
	_rect(image, 10, 24, 8, 1, INK)
	return image

# --- Karakter (el çizimi yer tutucusu, yumuşak hatlar) -------------------------

func _character(person: Dictionary) -> Image:
	var size := CHARACTER_SIZE
	var image := _blank(size.x, size.y)
	var skin := Color(str(person.get("skin", "b79d8c")))
	var hair := Color(str(person.get("hair", "382d3d")))
	var coat := Color(str(person.get("coat", "71717f")))
	var cx := size.x / 2.0
	# Gövde: omuzlardan aşağı yuvarlatılmış kütle
	_soft_ellipse(image, Vector2(cx, 760), Vector2(250, 330), OUTLINE)
	_soft_ellipse(image, Vector2(cx, 764), Vector2(242, 322), coat)
	_soft_ellipse(image, Vector2(cx, 560), Vector2(60, 70), skin.darkened(0.12))
	_soft_ellipse(image, Vector2(cx, 640), Vector2(36, 150), coat.darkened(0.25))
	# Baş ve saç
	_soft_ellipse(image, Vector2(cx, 300), Vector2(150, 175), hair)
	_soft_ellipse(image, Vector2(cx, 340), Vector2(118, 148), skin)
	_soft_ellipse(image, Vector2(cx, 225), Vector2(135, 70), hair)
	# Yüz
	for side: float in [-1.0, 1.0]:
		_soft_ellipse(image, Vector2(cx + side * 46, 340), Vector2(13, 16), OUTLINE)
		_soft_ellipse(image, Vector2(cx + side * 46 - 4, 335), Vector2(4, 4), Color("f4eee4"))
		_soft_ellipse(image, Vector2(cx + side * 46, 312), Vector2(24, 5), hair.darkened(0.2))
	_soft_ellipse(image, Vector2(cx, 405), Vector2(26, 6), skin.darkened(0.35))
	return image

## Kenarı yumuşatılmış elips (tek piksellik geçiş).
func _soft_ellipse(image: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var x0 := maxi(0, int(center.x - radius.x - 1))
	var x1 := mini(w - 1, int(center.x + radius.x + 1))
	var y0 := maxi(0, int(center.y - radius.y - 1))
	var y1 := mini(h - 1, int(center.y + radius.y + 1))
	var edge := 1.5 / minf(radius.x, radius.y)
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5 - center.y) / radius.y
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5 - center.x) / radius.x
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0 + edge:
				continue
			var alpha := clampf((1.0 + edge - d) / edge, 0.0, 1.0) * color.a
			var under := image.get_pixel(x, y)
			var mixed := under.lerp(Color(color, 1.0), alpha) if under.a > 0.0 else Color(color, alpha)
			mixed.a = maxf(under.a, alpha)
			image.set_pixel(x, y, mixed)

# --- Arayüz çerçeveleri (piksel 9-slice) ----------------------------------------

## 12×12 çerçeve: köşeler bir piksel kırık, dış hat + iç parlak hat + dolgu.
func _frame(fill: Color, outline: Color, light: Color, shade: Color = Color.TRANSPARENT, size: int = 12) -> Image:
	var image := _blank(size, size)
	_rect(image, 1, 0, size - 2, size, outline)
	_rect(image, 0, 1, size, size - 2, outline)
	_rect(image, 1, 1, size - 2, size - 2, light)
	_rect(image, 2, 2, size - 4, size - 4, fill)
	if shade.a > 0.0:
		_rect(image, 2, size - 3, size - 4, 1, shade)
		_rect(image, size - 3, 2, 1, size - 4, shade)
	return image

func _chrome() -> void:
	var dir := "res://assets/ui/chrome/"
	_save_up(_frame(Color(0.09, 0.07, 0.11, 0.94), Color("0b080e"), Color("3d3446")), dir + "balloon.png")
	_save_up(_frame(Color("efe6d2"), INK, Color("fbf6ea"), Color("cfc3a8")), dir + "balloon_docked.png")
	_save_up(_frame(Color("201a26"), Color("0b080e"), Color("4e4256")), dir + "panel.png")
	_save_up(_frame(CREAM, INK, Color("f6efdd"), Color("b8aa8c"), 16), dir + "machine.png")
	_save_up(_frame(Color("f3efe4"), INK, Color("cfc7b5")), dir + "lcd.png")
	_save_up(_frame(CREAM, INK, Color("f6efdd"), Color("a89a7c")), dir + "button.png")
	_save_up(_frame(CREAM.lightened(0.08), Color("6b5a3a"), Color("fffaf0"), Color("a89a7c")), dir + "button_hover.png")
	_save_up(_frame(CREAM.darkened(0.12), INK, CREAM.darkened(0.2)), dir + "button_pressed.png")
	_save_up(_frame(Color("9d968a"), Color("4a4448"), Color("aaa397")), dir + "button_disabled.png")
	_save_up(_frame(CREAM, Color("3f8f3a"), Color("8fd27f"), Color("a89a7c")), dir + "button_primary.png")
	_save_up(_frame(Color("e8dcc0"), Color("6a5440"), Color("f3ead2")), dir + "book_page.png")
	_save_up(_frame(Color("16131c"), Color("05040a"), Color("4e4658"), Color.TRANSPARENT, 16), dir + "phone_frame.png")
	_save_up(_frame(Color("d9e4df"), Color("0f0d12"), Color("eef5f1")), dir + "phone_screen.png")
	var brew_frame := _blank(12, 12)
	_rect(brew_frame, 0, 0, 12, 12, Color("0b080e"))
	_rect(brew_frame, 3, 3, 6, 6, Color(0, 0, 0, 0))
	_save_up(brew_frame, dir + "brew_frame.png")

# --- İkonlar (24×24, beyaz + koyu hat) ------------------------------------------

func _icons() -> void:
	var dir := "res://assets/ui/icons/"
	var white := Color("f4eee4")
	var phone := _blank(24, 24)
	_rect(phone, 6, 1, 12, 22, OUTLINE)
	_rect(phone, 7, 2, 10, 20, white)
	_rect(phone, 8, 4, 8, 14, Color("6f8f9a"))
	_rect(phone, 11, 19, 2, 2, OUTLINE)
	_save_up(phone, dir + "phone.png")
	var camera := _blank(24, 24)
	_rect(camera, 2, 6, 20, 15, OUTLINE)
	_rect(camera, 3, 7, 18, 13, white)
	_rect(camera, 8, 4, 8, 3, OUTLINE)
	_rect(camera, 9, 9, 6, 6, OUTLINE)
	_rect(camera, 10, 10, 4, 4, Color("6f8f9a"))
	_save_up(camera, dir + "camera.png")
	var book := _blank(24, 24)
	_rect(book, 2, 3, 20, 18, OUTLINE)
	_rect(book, 3, 4, 8, 16, white)
	_rect(book, 13, 4, 8, 16, white)
	for y in [7, 10, 13]:
		_rect(book, 5, y, 5, 1, OUTLINE)
		_rect(book, 14, y, 5, 1, OUTLINE)
	_save_up(book, dir + "book.png")
	var menu := _rounded_tile(white)
	for y in [7, 11, 15]:
		_rect(menu, 6, y, 12, 2, OUTLINE)
	_save_up(menu, dir + "menu.png")
	var auto := _rounded_tile(white)
	_triangle(auto, 8, 12, 9)
	_save_up(auto, dir + "auto.png")
	var ffwd := _rounded_tile(white)
	_triangle(ffwd, 5, 12, 7)
	_triangle(ffwd, 12, 12, 7)
	_save_up(ffwd, dir + "ffwd.png")

## Sağa bakan dolu üçgen: x0'dan başlar, center_y etrafında, length piksel uzunluğunda.
func _triangle(image: Image, x0: int, center_y: int, length: int) -> void:
	for column in range(length):
		var half := length - 1 - column
		_rect(image, x0 + column, center_y - half / 2 - 1, 1, half + 2, OUTLINE)

func _rounded_tile(fill: Color) -> Image:
	var image := _blank(24, 24)
	_rect(image, 2, 1, 20, 22, OUTLINE)
	_rect(image, 1, 2, 22, 20, OUTLINE)
	_rect(image, 3, 2, 18, 20, fill)
	_rect(image, 2, 3, 20, 18, fill)
	return image

# --- Tema ---------------------------------------------------------------------

## Tasarımcılar bu dosyayı Godot'da açıp renk, çerçeve ve yazı tiplerini değiştirebilir.
func _theme() -> Theme:
	var theme := Theme.new()
	var pixel := FontVariation.new()
	pixel.base_font = load("res://assets/fonts/PixelifySans.ttf")
	pixel.fallbacks = [load("res://assets/fonts/LiberationSans-Regular.ttf")]
	theme.default_font = pixel
	theme.default_font_size = 32
	var cream := Color("efe3c8")
	theme.set_color("font_color", "Label", cream)
	theme.set_color("default_color", "RichTextLabel", cream)
	theme.set_font_size("normal_font_size", "RichTextLabel", 32)
	theme.set_stylebox("panel", "Panel", _nine("panel.png", 12))
	theme.set_stylebox("panel", "PanelContainer", _nine("panel.png", 12, 24))
	_buttons(theme, "Button", "button.png")
	_buttons(theme, "PrimaryButton", "button_primary.png")
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_type_variation("IconButton", "Button")
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		theme.set_stylebox(state, "IconButton", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, "IconButton", cream)
	theme.set_color("font_pressed_color", "IconButton", Color("f0c987"))
	theme.set_color("icon_pressed_color", "IconButton", Color("f0c987"))
	theme.set_color("icon_hover_color", "IconButton", Color("fff6dc"))
	theme.set_color("icon_disabled_color", "IconButton", Color(1, 1, 1, 0.3))
	theme.set_color("font_disabled_color", "IconButton", Color(1, 1, 1, 0.3))
	theme.set_color("font_outline_color", "IconButton", Color("0b080e"))
	theme.set_constant("outline_size", "IconButton", 9)
	theme.set_font_size("font_size", "IconButton", 22)
	_variation(theme, "BalloonPanel", "PanelContainer", {"panel": _nine("balloon.png", 12, 22)})
	_variation(theme, "BalloonDocked", "PanelContainer", {"panel": _nine("balloon_docked.png", 12, 22)})
	_label(theme, "NameTag", Color("c7b6dc"), 26)
	_label(theme, "Caption", Color("b8a6a8"), 22)
	_label(theme, "Title", cream, 96)
	_label(theme, "MachineLabel", INK, 26)
	_label(theme, "BookText", Color("3d322c"), 26)
	_label(theme, "PhoneText", Color("1f2a2a"), 24)
	_label(theme, "HudText", cream, 26)
	theme.set_color("font_outline_color", "HudText", Color("0b080e"))
	theme.set_constant("outline_size", "HudText", 9)
	_variation(theme, "MachinePanel", "PanelContainer", {"panel": _nine("machine.png", 15, 24)})
	_variation(theme, "SlotPanel", "PanelContainer", {"panel": _nine("lcd.png", 12, 10)})
	_variation(theme, "BookPage", "PanelContainer", {"panel": _nine("book_page.png", 12, 36)})
	_variation(theme, "PhoneFrame", "PanelContainer", {"panel": _nine("phone_frame.png", 15, 30)})
	_variation(theme, "PhoneScreen", "PanelContainer", {"panel": _nine("phone_screen.png", 12, 22)})
	_variation(theme, "BrewFrame", "Panel", {"panel": _nine("brew_frame.png", 12, 0, false)})
	return theme

func _nine(file: String, margin: int, content: int = -1, center: bool = true) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/chrome/" + file)
	style.set_texture_margin_all(margin)
	style.set_content_margin_all(content if content >= 0 else margin)
	style.draw_center = center
	return style

func _buttons(theme: Theme, type: String, normal: String) -> void:
	theme.set_stylebox("normal", type, _nine(normal, 12, 14))
	theme.set_stylebox("hover", type, _nine("button_hover.png" if type == "Button" else normal, 12, 14))
	theme.set_stylebox("pressed", type, _nine("button_pressed.png", 12, 14))
	theme.set_stylebox("disabled", type, _nine("button_disabled.png", 12, 14))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, type, INK)
	theme.set_color("font_disabled_color", type, Color("5a5458"))
	theme.set_font_size("font_size", type, 28)

func _variation(theme: Theme, type: String, base: String, styles: Dictionary) -> void:
	theme.set_type_variation(type, base)
	for key: String in styles:
		theme.set_stylebox(key, type, styles[key])

func _label(theme: Theme, type: String, color: Color, font_size: int) -> void:
	theme.set_type_variation(type, "Label")
	theme.set_color("font_color", type, color)
	theme.set_font_size("font_size", type, font_size)
