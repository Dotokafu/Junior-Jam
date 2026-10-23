@tool
extends Control
## Fotoğraf yer tutucusu. portrait_texture varsa gerçek çizimi kullanır.
var portrait: Dictionary = {}
var texture: Texture2D

func setup(data: Dictionary) -> void:
	portrait = data
	var path: String = data.get("portrait_texture", "")
	if path != "" and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("49404d"))
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false)
	else:
		draw_set_transform(Vector2.ZERO, 0, size / Vector2(60, 72))
		draw_rect(Rect2(6, 51, 48, 22), Color(portrait.get("coat", "71717f")))
		draw_rect(Rect2(24, 42, 13, 15), Color(portrait.get("skin", "b79d8c")).darkened(0.15))
		draw_rect(Rect2(14, 12, 33, 37), Color(portrait.get("hair", "382d3d")))
		draw_rect(Rect2(18, 23, 25, 25), Color(portrait.get("skin", "b79d8c")))
		draw_rect(Rect2(18, 18, 27, 9), Color(portrait.get("hair", "382d3d")))
		draw_rect(Rect2(22, 32, 5, 2), Color("302a36"))
		draw_rect(Rect2(34, 32, 5, 2), Color("302a36"))
		draw_rect(Rect2(27, 42, 8, 1), Color("815e64"))
