extends SceneTree
## Gerçek pencere/renderer ile ekranları gezer ve görüntü alır; kayıt dosyasını değiştirmez.
## Çalıştır: godot --path . -s tests/visual_smoke.gd -- <çıktı klasörü>
var screen: Control
var session: Node
var bus: Node
var locale: Node
var out_dir: String = "/tmp"
var failures: int = 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	call_deferred("run")

func run() -> void:
	session = root.get_node("Session")
	bus = root.get_node("EventBus")
	locale = root.get_node("I18n")
	session.persistence_enabled = false
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1920, 1080)
	screen = load("res://presentation/cafe.tscn").instantiate()
	root.add_child(screen)
	screen.muted = true
	await settle(0.3)
	await capture("intro")
	# Kayıt varsa "Yeni hikâye" onay penceresi açar; ikisinde de gerçek fare tıklaması oyunu başlatmalı.
	if find_button(screen, locale.t("menu.story")):
		await click(locale.t("menu.story"))
	elif find_button(screen, locale.t("button.story_mode")):
		await click(locale.t("button.story_mode"))
	else:
		await click(locale.t("button.new_story"))
		await settle(0.2)
		await click(locale.t("button.start_story"))
	check(session.started, "Giriş butonuna tıklamak oyunu başlatmalı")
	if not session.started:
		bus.request("new_game", {"mode": "story", "seed": 4217})
	await settle(0.6)
	await capture("dialogue")
	var before: int = session.state.line_index
	await click_point(Vector2(300, 500))
	await click_point(Vector2(300, 500))
	await settle(0.2)
	check(session.state.line_index > before, "Sahneye tıklamak konuşmayı ilerletmeli")
	# Buton odak tutmamalı: AUTO'ya tıkladıktan sonra Boşluk konuşmayı ilerletir, AUTO'yu kapatmaz.
	# Tek basış: odak düğmede kalsaydı Boşluk AUTO'yu geri kapatırdı.
	await click(locale.t("hud.auto"))
	await press(KEY_SPACE)
	check(screen.auto_button.button_pressed, "Boşluk, tıklanan AUTO butonunu kapatmamalı")
	screen.auto_button.button_pressed = false
	for i in range(8):
		if session.state.stage == "interview":
			break
		bus.request("next")
	await settle(0.6)
	check(session.state.stage == "interview", "Konuşma bitince sorgu açılmalı")
	await capture("interview")
	var first_question: String = locale.t("balloon.question", {"number": 1, "text": session.snapshot().questions[0].text})
	await click(first_question)
	await settle(0.3)
	check(session.state.stage == "answer" and session.state.asked == [0], "Soru düğmesine tıklamak soruyu sormalı")
	await press(KEY_N)
	check(session.state.marks.get(session._record_id(), []).size() == 1, "N cevabı işaretlemeli")
	await capture("answer")
	for i in range(8):
		if session.state.stage == "brewing":
			break
		bus.request("next")
	await settle(0.8)
	check(screen.brew_panel.is_open, "Sipariş gelince makine açılmalı")
	for id: String in ["coffee", "milk", "milk"]:
		bus.request("select", {"id": id})
	await settle(0.2)
	await capture("brewing")
	bus.request("brew")
	await settle(0.9)
	check(screen.brew_comic.is_open and screen.brew_comic.busy, "Demleyince çizgi roman sayfası açılmalı, seçim animasyon bitene kadar kilitli")
	await settle(1.6)
	await capture("comic_steps")
	await settle(2.4)
	check(screen.brew_comic.steps_page.visible == false and screen.brew_comic.serve_page.visible, "Hazırlık kapanıp servis sayfası tam ekran gelmeli")
	await capture("brewed")
	# Latte art: sütlü içecekte üçüncü seçenek. Gerçek tıklama ve gerçek fare sürüklemesiyle çizilir.
	check(screen.brew_comic.latte_button.visible, "Sütlü içecekte Latte art seçeneği görünmeli")
	await click(locale.t("button.latte_art"))
	await settle(0.9)
	var latte: Control = screen.brew_comic.latte
	check(latte.is_open and not latte.busy, "Latte art paneli aşağıdan gelmeli")
	var foam: Control = latte.foam
	var center: Vector2 = foam.get_global_rect().get_center()
	await drag([center + Vector2(0, -60), center + Vector2(0, -40), center + Vector2(0, 40)], [1.4, 0.5, 0.3])
	await settle(0.4)
	check(milk_peak(latte.fluid) > 0.8, "Basılı fare süt dökmeli: " + str(milk_peak(latte.fluid)))
	await capture("latte_pour")
	await press(KEY_2)
	check(latte.tool == "etch", "2 çizim aracını seçmeli")
	var line: Array[Vector2] = []
	var waits: Array[float] = []
	for i in range(16):
		line.append(center + Vector2(0, -200 + i * 22))
		waits.append(0.04)
	await drag(line, waits)
	await settle(0.5)
	await capture("latte_art")
	await press(KEY_ESCAPE)
	await settle(0.8)
	check(not latte.is_open and screen.brew_comic.is_open and screen.modal == "", "Esc latte art'tan servis sayfasına dönmeli")
	await press(KEY_L)
	await settle(0.9)
	check(latte.is_open and milk_peak(latte.fluid) < latte.fluid.base_color.r + 0.02, "L latte art'ı temiz köpükle yeniden açmalı")
	await drag([center, center + Vector2(0, 30)], [1.0, 0.3])
	await press(KEY_ENTER)
	await settle(1.2)
	check(session.state.stage == "reaction" and not screen.brew_comic.is_open, "Latte art'tan servis tepkiye geçmeli")
	check(session.state.drink.get("latte_art", false), "İçecek latte art'lı servis edilmeli")
	await capture("reaction")
	screen._open_modal("pause")
	await settle(0.3)
	await capture("menu")
	await click(locale.t("pause.save"))
	await settle(0.3)
	check(screen.modal == "save", "Esc menüsünden kaydet sayfası açılmalı")
	await capture("menu_save")
	screen._close_modal()
	screen._toggle_book()
	await settle(0.2)
	await capture("book")
	screen._close_modal()
	session.state.day = 2
	session.state.phase = "night"
	session.state.stage = "dialogue"
	session.state.shelf = "fallen"
	session.state.tutorial = "ready"
	session.state.visit_index = 0
	session.state.visits = session._generate_visits()
	bus.request("refresh")
	await settle(0.6)
	await capture("night")
	# Çek: polaroid makineden çıkar, dava dosyası alttan açılır, fotoğraf yerine yapışır.
	await click(locale.t("hud.photo"))
	await settle(0.4)
	await capture("photo_eject")
	await settle(2.4)
	check(screen.case_file.visible and session.state.records.size() == 1, "Çekince dava dosyası açılmalı")
	await capture("case_new")
	screen._close_modal()
	await settle(0.5)
	screen._toggle_files()
	await settle(0.5)
	await capture("files")
	screen._close_modal()
	await settle(0.5)
	session.state.phase = "fall"
	session.state.stage = "transition"
	bus.request("refresh")
	await settle(2.3)
	await capture("fall_bat")
	await settle(1.1)
	await capture("fall_walk")
	await settle(2.6)
	await capture("fall")
	session.state.ending = session.content.endings.fallen_world.duplicate(true)
	session.state.ending["variant"] = "standard"
	session.state.phase = "ending"
	bus.request("refresh")
	await settle(0.4)
	await capture("ending")
	screen.queue_free()
	await process_frame
	print("VISUAL: ", "PASS" if failures == 0 else "FAIL", " — ", out_dir, "/coffallen-*.png")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle(seconds: float) -> void:
	await create_timer(seconds).timeout

func capture(label: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/coffallen-" + label + ".png")

func click(text: String) -> void:
	var target := find_button(screen, text)
	if target == null:
		push_error("BUTTON_NOT_FOUND: " + text)
		return
	await click_point(target.get_global_rect().get_center())

## Tasarım koordinatı (1920×1080) → pencere koordinatı (ölçek + letterbox dahil).
func click_point(point: Vector2) -> void:
	# Gerçek pencere olayı gibi gönder: Godot ölçek/letterbox dönüşümünü kendisi geri alır.
	var window_point: Vector2 = root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = window_point
	root.push_input(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = window_point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func press(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame

## Basılı fareyle noktalar arasında gezinir; her noktada verilen süre bekler. Input üzerinden gönderilir
## ki Input.is_mouse_button_pressed da basılı görsün.
func drag(points: Array[Vector2], waits: Array[float]) -> void:
	var transform: Transform2D = root.get_final_transform()
	for i in range(points.size()):
		var motion := InputEventMouseMotion.new()
		motion.position = transform * points[i]
		motion.global_position = motion.position
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		if i == 0:
			var down := InputEventMouseButton.new()
			down.position = motion.position
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			Input.parse_input_event(down)
		await settle(waits[i])
	var up := InputEventMouseButton.new()
	up.position = transform * points[-1]
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame

## Köpüğün orta bölgesindeki en açık hücrenin kırmızı kanalı (süt beyazdır).
func milk_peak(fluid: Node) -> float:
	var image: Image = fluid.texture.get_image()
	var peak := 0.0
	for y in range(40, 216, 4):
		for x in range(40, 216, 4):
			peak = maxf(peak, image.get_pixel(x, y).r)
	return peak

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text == text:
		return node
	for child: Node in node.get_children():
		var found := find_button(child, text)
		if found:
			return found
	return null
