extends SceneTree
## Gerçek pencere/renderer ile ekranları çalıştırır; kayıt dosyasını değiştirmez.
var screen: Control
var session: Node
var bus: Node
var locale: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	session = root.get_node("Session")
	bus = root.get_node("EventBus")
	locale = root.get_node("I18n")
	session.persistence_enabled = false
	root.content_scale_size = Vector2i(1440, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 800)
	screen = load("res://presentation/cafe.tscn").instantiate()
	root.add_child(screen)
	screen.muted = true
	screen.view.has_save = false
	screen._render()
	await capture("intro")
	await click(locale.t("button.story_mode"))
	if not session.started:
		push_error("POINT_CLICK_START_FAILED")
		quit(1)
		return
	await capture("dialogue")
	await click(locale.t("button.listen"))
	if session.state.line_index != 1:
		push_error("POINT_CLICK_DIALOGUE_FAILED: " + str(session.state.line_index))
		quit(1)
		return
	for i in range(7):
		bus.request("next")
	await capture("brewing")
	screen._toggle_book()
	await capture("book")
	screen._close_modal()
	session.state.day = 2
	session.state.phase = "day"
	session.state.stage = "brewing"
	session.state.visit_index = 0
	session.state.visits = session._generate_visits()
	bus.request("photo")
	screen._toggle_dossier()
	await capture("dossier")
	screen._close_modal()
	session.state.phase = "fall"
	session.state.stage = "transition"
	bus.request("refresh")
	await capture("fall")
	session.state.ending = session.content.endings.fallen_world.duplicate(true)
	session.state.ending["variant"] = "standard"
	session.state.phase = "ending"
	bus.request("refresh")
	await capture("ending")
	screen.queue_free()
	await process_frame
	await process_frame
	print("VISUAL: PASS — /tmp/coffallen-*.png")
	quit()

func capture(label: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("/tmp/coffallen-" + label + ".png")

func click(text: String) -> void:
	var target := find_button(screen, text)
	if target == null:
		push_error("BUTTON_NOT_FOUND: " + text)
		return
	var point := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.is_visible_in_tree() and not node.disabled and node.text == text:
		return node
	for child: Node in node.get_children():
		var found := find_button(child, text)
		if found:
			return found
	return null
