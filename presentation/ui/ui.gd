class_name CafeUI
extends RefCounted
const INK := Color("e5d7bd")
const MUTED := Color("a89b9e")
const GOLD := Color("cfab77")
const PINK := Color("bb8799")
const TITLE: Font = preload("res://assets/fonts/LiberationSerif-Regular.ttf")
const ITALIC: Font = preload("res://assets/fonts/LiberationSerif-Italic.ttf")
const BODY: Font = preload("res://assets/fonts/LiberationSans-Regular.ttf")
const MONO: Font = preload("res://assets/fonts/LiberationMono-Regular.ttf")

static func box(parent: Node, bounds: Rect2, fill: Color = Color("201c28"), border: Color = Color("49404b")) -> Panel:
	var node := Panel.new()
	parent.add_child(node)
	node.position = bounds.position
	node.size = bounds.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", style)
	return node

static func label(parent: Node, text: String, bounds: Rect2, font_size: int = 20, color: Color = INK, font: Font = BODY, wrap: bool = false) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.position = bounds.position
	node.size = bounds.size
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func button(parent: Node, text: String, bounds: Rect2, callback: Callable, primary: bool = false, disabled: bool = false) -> Button:
	var node := Button.new()
	parent.add_child(node)
	node.position = bounds.position
	node.size = bounds.size
	node.text = text
	node.disabled = disabled
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font", BODY)
	node.add_theme_font_size_override("font_size", 19)
	for entry: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("c6a371") if primary else Color("2e2735")
		style.border_color = Color("cfab77") if primary else Color("5a4b5b")
		style.set_border_width_all(1)
		if entry == "hover":
			style.bg_color = style.bg_color.lightened(0.12)
			style.border_color = GOLD
		if entry == "pressed":
			style.bg_color = style.bg_color.darkened(0.12)
		if entry == "disabled":
			style.bg_color = Color("25212c")
			style.border_color = Color("38313f")
		if entry == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = INK
			style.set_border_width_all(2)
		node.add_theme_stylebox_override(entry, style)
	node.add_theme_color_override("font_color", Color("251e28") if primary else INK)
	node.add_theme_color_override("font_hover_color", Color("251e28") if primary else INK)
	node.add_theme_color_override("font_pressed_color", Color("251e28") if primary else INK)
	node.add_theme_color_override("font_disabled_color", Color("655e6c"))
	node.pressed.connect(callback)
	return node

static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child is CanvasItem:
			child.hide()
		child.queue_free()
