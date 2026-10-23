extends SceneTree
## Latte art: köpük simülasyonu (ekran kartında), araçlar ve panel kısayolları.
## Pencereli çalışır: godot --path . -s tests/latte_test.gd
const Fluid = preload("res://presentation/brewing/latte_fluid.gd")
const Tools = preload("res://presentation/brewing/latte_tools.gd")
const COFFEE := Color("7a5236")
const DT := 1.0 / 60.0
const STEP := 1.0 / 25.0
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await fluid_tests()
	await panel_tests()
	print("LATTE: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func fluid_tests() -> void:
	var fluid := Fluid.new()
	root.add_child(fluid)
	fluid.reset(COFFEE)
	await RenderingServer.frame_post_draw
	var center := Vector2i(128, 128)
	check(near(fluid.color_at(center), COFFEE), "Köpük içeceğin rengiyle başlar: " + str(fluid.color_at(center)))
	var pour := Tools.Pour.new(fluid)
	await steps(fluid, 25, func() -> void: pour.update(Vector2(0.5, 0.5), true, STEP))
	var image := fluid.passes[-1].get_texture().get_image()
	check(image.get_pixelv(center).r > 0.85, "Basılı tutulan süt ortayı beyazlatır")
	check(near(image.get_pixel(128, 40), COFFEE), "Uzaktaki köpük değişmez")
	check(pour.milk.build_up > pour.milk.init_size and pour.tint.build_up > pour.tint.init_size, "Basılı tuttukça akış birikir")
	pour.update(Vector2(-1, -1), false, STEP)
	check(not pour.milk.brush.active and pour.milk.build_up == pour.milk.init_size, "Bırakınca akış durur ve sıfırlanır")
	var up := milk_center(image)
	await steps(fluid, 10, func() -> void: pass)
	check(milk_center(fluid.passes[-1].get_texture().get_image()) > up, "Varsayılan akış sütü oyuncuya doğru (aşağı) taşır")
	await steps(fluid, 75, func() -> void: pass)
	image = fluid.passes[-1].get_texture().get_image()
	check(milky_share(image) < 0.25, "Dökülen süt bütün kahveye yayılmaz: " + str(milky_share(image)))
	check(near(image.get_pixel(6, 6), COFFEE), "Fincan dairesinin dışı duvardır, köpük oraya geçmez")
	fluid.reset(COFFEE)
	await RenderingServer.frame_post_draw
	check(near(fluid.color_at(center), COFFEE), "Baştan: köpük yeniden dökülür")
	pour.reverse = true
	await steps(fluid, 25, func() -> void: pour.update(Vector2(0.5, 0.5), true, STEP))
	pour.update(Vector2(-1, -1), false, STEP)
	var down := milk_center(fluid.passes[-1].get_texture().get_image())
	await steps(fluid, 10, func() -> void: pass)
	check(milk_center(fluid.passes[-1].get_texture().get_image()) < down, "Ters akış sütü fincanın üstüne taşır")
	var etch := Tools.Etch.new(fluid)
	var before := whiteness(fluid.passes[-1].get_texture().get_image())
	var frame := [0]
	await steps(fluid, 25, func() -> void:
		etch.update(Vector2(0.3 + frame[0] * 0.016, 0.55), true, STEP)
		frame[0] += 1)
	check(whiteness(fluid.passes[-1].get_texture().get_image()) <= before * 1.02, "İğne renk eklemez")
	etch.update(Vector2(0.5, 0.5), true, STEP)
	etch.update(Vector2(0.5, 0.5), true, STEP)
	check(etch.needle.collision_size == 0.0 and etch.needle.velocity == Vector2.ZERO, "Duran iğne etkisizdir")
	fluid.queue_free()

func panel_tests() -> void:
	var latte: Control = load("res://presentation/brewing/latte_art.tscn").instantiate()
	root.add_child(latte)
	latte.reduced_motion = true
	var events: Array[String] = []
	latte.served.connect(func() -> void: events.append("served"))
	latte.closed.connect(func() -> void: events.append("closed"))
	latte.open(COFFEE)
	check(latte.is_open and latte.visible and latte.tool == "pour", "Panel süt dökme aracıyla açılır")
	check(latte.handle_key(KEY_2) and latte.tool == "etch", "2 çizim aracını seçer")
	check(latte.handle_key(KEY_I) and latte.pour.reverse, "I akışı ters çevirir")
	check(latte.handle_key(KEY_E), "Q/E fincan çevirme tuşları panelde kalır")
	latte.cup.rotation = 1.0
	latte.handle_key(KEY_R)
	check(latte.cup.rotation == 0.0, "Baştan fincanı da düzeltir")
	check(not latte.handle_key(KEY_M), "İlgisiz tuş panelde tutulmaz")
	latte.handle_key(KEY_ESCAPE)
	await process_frame
	check(events == ["closed"] and not latte.is_open, "Esc geri döner")
	latte.open(COFFEE)
	check(not latte.pour.reverse and latte.tool == "pour", "Yeniden açılınca araçlar varsayılana döner")
	latte.handle_key(KEY_ENTER)
	await process_frame
	check(events == ["closed", "served"] and not latte.visible, "Enter latte art'lı servis eder")
	# Kayarken dışarıdan kapatılıp yeniden açılırsa eski animasyon yeni oturumu bozmamalı.
	latte.reduced_motion = false
	latte.open(COFFEE)
	latte.force_close()
	latte.open(COFFEE)
	await create_timer(0.3).timeout
	check(latte.busy and latte.is_open, "Yeni açılış animasyonu sürerken panel kilitli kalmalı")
	await create_timer(0.5).timeout
	check(not latte.busy and latte.panel.position.y == 0.0, "Yeniden açılan panel tam yerine oturmalı")
	latte.back()
	await create_timer(0.2).timeout
	latte.force_close()
	latte.open(COFFEE)
	await create_timer(0.9).timeout
	check(latte.is_open and latte.visible and events.size() == 2, "Eski kapanış yeni oturumu kapatmamalı, sinyal vermemeli")
	latte.queue_free()

## Her karede bir simülasyon adımı (adımlar ekran kartında kare çizilirken işlenir).
func steps(fluid: Fluid, count: int, each: Callable) -> void:
	for i in range(count):
		each.call()
		fluid.update(STEP)
		await RenderingServer.frame_post_draw

func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02

## Sütün (kahveden açık hücrelerin) dikey ağırlık merkezi, 0 = üst.
func milk_center(image: Image) -> float:
	var total := 0.0
	var weighted := 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var amount := maxf(image.get_pixel(x, y).r - COFFEE.r, 0.0)
			total += amount
			weighted += amount * y
	return weighted / maxf(total, 0.0001) / image.get_height()

## Belirgin biçimde sütle açılmış hücrelerin, görünen fincan alanındaki oranı.
func milky_share(image: Image) -> float:
	var milky := 0
	var cells := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(128, 128)) > 94.0:
				continue
			cells += 1
			if image.get_pixel(x, y).r - COFFEE.r > 0.1:
				milky += 1
	return float(milky) / cells

func whiteness(image: Image) -> float:
	var total := 0.0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			total += maxf(image.get_pixel(x, y).r - COFFEE.r, 0.0)
	return total

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
