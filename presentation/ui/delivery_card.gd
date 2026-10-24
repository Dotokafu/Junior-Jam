extends Control
## Teslim tepsisindeki polaroid: teslimatçıya sürüklenir ya da tıklanınca seçilir.
## Çerçeve assets/ui/polaroid.png (ortası şeffaf), fotoğraf kişinin çiziminden (CaseFile.photo_texture).
signal picked(record_id: String)
const POLAROID := "res://assets/ui/polaroid.png"
const SIZE := Vector2(160, 236)
const FRAME := Vector2(160, 192)
const PHOTO := Rect2(16, 16, 128, 128)
var record_id: String = ""
var photo_texture: Texture2D

func setup(record: Dictionary, index: int, photo: Texture2D) -> void:
	record_id = record.id
	photo_texture = photo
	custom_minimum_size = SIZE
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var picture := TextureRect.new()
	picture.texture = photo
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = PHOTO.position
	picture.size = PHOTO.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	var frame := TextureRect.new()
	if ResourceLoader.exists(POLAROID):
		frame.texture = load(POLAROID)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = FRAME
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var label := Label.new()
	label.theme_type_variation = &"HudText"
	label.text = I18n.t("delivery.card", {"number": index + 1, "name": record.get("name", "")})
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, FRAME.y + 4)
	label.size = Vector2(SIZE.x, SIZE.y - FRAME.y - 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = photo_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = PHOTO.size
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"record": record_id}

func _gui_input(event: InputEvent) -> void:
	# Sürüklemeden bırakılan tıklama da seçer (fare ile kısayol).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not get_viewport().gui_is_dragging():
		picked.emit(record_id)
		accept_event()
