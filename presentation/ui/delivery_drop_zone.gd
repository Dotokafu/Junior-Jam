extends Control
## Teslimatçının alanı: polaroid buraya bırakılınca dropped yayar. Sürükleme sürerken sarı parlar.
signal dropped(record_id: String)
const GLOW := Color(1.0, 0.83, 0.29)
var dragging: bool = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("record")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(str(data.record))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END:
		dragging = what == NOTIFICATION_DRAG_BEGIN
		queue_redraw()

func _draw() -> void:
	if not dragging:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(GLOW, 0.1))
	draw_rect(Rect2(Vector2.ZERO, size), GLOW, false, 4.0)
