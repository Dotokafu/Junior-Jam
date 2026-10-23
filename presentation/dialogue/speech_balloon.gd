extends Control
## Karakterin yanında konumlanan konuşma balonu: daktilo metni, tıkla-atla, AUTO ve FFWD.
signal advance_requested
signal line_started
enum Mode { ADVANCE, STATIC, DECISION }
const SPEEDS := {"slow": 22.0, "normal": 45.0, "fast": 95.0}
const SCREEN_MARGIN := 24.0
const ANCHOR_GAP := Vector2(28, -70)
const TAIL_HALF := 16.0
const AUTO_DELAY := 1.1
const AUTO_PER_CHAR := 0.03
const FFWD_DELAY := 0.25
const TEXT_WIDTH := 600.0
## Demlerken balon makineyle çakışmasın diye sol üste "sipariş fişi" olarak yapışır.
const DOCK_POSITION := Vector2(28, 770)
const DOCK_TEXT_WIDTH := 520.0
var speed: String = "normal"
var auto: bool = false
var fast_forward: bool = false
var reduced_motion: bool = false
var mode: Mode = Mode.ADVANCE
var line_key: String = ""
var anchor := Vector2(900, 380)
var typed: float = 0.0
var waited: float = 0.0
var awaiting_next: bool = false
var docked: bool = false:
	set(value):
		if value == docked:
			return
		docked = value
		if is_node_ready():
			var width := DOCK_TEXT_WIDTH if docked else TEXT_WIDTH
			text_label.custom_minimum_size.x = width
			$Panel/Box.custom_minimum_size.x = width
			panel.reset_size()
@onready var panel: PanelContainer = $Panel
@onready var name_tag: Label = $Panel/Box/NameTag
@onready var text_label: RichTextLabel = $Panel/Box/Text
@onready var hint: Label = $Panel/Box/Footer/Hint
@onready var arrow: Label = $Panel/Box/Footer/Arrow
@onready var tail: Polygon2D = $Tail

func _ready() -> void:
	panel.gui_input.connect(_on_panel_input)
	panel.resized.connect(_place)
	hide()

func say(speaker: String, line: String, new_mode: Mode, key: String, hint_text: String = "") -> void:
	show()
	mode = new_mode
	hint.text = hint_text
	if key != line_key:
		line_key = key
		awaiting_next = false
		name_tag.text = speaker
		name_tag.visible = speaker != ""
		text_label.text = line
		typed = 0.0
		waited = 0.0
		text_label.visible_characters = 0
		if fast_forward or line == "":
			_finish()
		line_started.emit()
		_pop()
	_update_arrow()
	_place()

func close() -> void:
	line_key = ""
	hide()

func point_at(point: Vector2) -> void:
	anchor = point
	_place()

func is_typing() -> bool:
	return text_label.visible_characters >= 0 and text_label.visible_characters < text_label.get_total_character_count()

## Tıklama/Boşluk: önce metni tamamlar, sonra ilerletir. İşlendiyse true.
func try_advance() -> bool:
	if not visible:
		return false
	if is_typing():
		_finish()
		return true
	if mode != Mode.ADVANCE or awaiting_next:
		return false
	awaiting_next = true
	advance_requested.emit()
	return true

func _process(delta: float) -> void:
	if not visible:
		return
	if is_typing():
		typed += delta * float(SPEEDS.get(speed, 45.0))
		text_label.visible_characters = int(typed)
		if not is_typing():
			_finish()
		return
	if mode == Mode.ADVANCE and not awaiting_next and (auto or fast_forward):
		waited += delta
		var delay := FFWD_DELAY if fast_forward else AUTO_DELAY + AUTO_PER_CHAR * text_label.get_total_character_count()
		if waited >= delay:
			try_advance()

func _finish() -> void:
	text_label.visible_characters = -1
	waited = 0.0
	_update_arrow()

func _update_arrow() -> void:
	arrow.visible = mode == Mode.ADVANCE and not is_typing()

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if try_advance():
			accept_event()

func _pop() -> void:
	if reduced_motion:
		return
	panel.pivot_offset = Vector2(0, panel.size.y)
	panel.scale = Vector2(0.96, 0.96)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Balonu çapanın sağına koyar, ekran dışına taşarsa içeri çeker; kuyruk çapayı gösterir.
func _place() -> void:
	if not is_node_ready():
		return
	if docked:
		panel.global_position = DOCK_POSITION
		tail.hide()
		return
	var screen := get_viewport_rect().size
	var box := panel.size
	var target := anchor + ANCHOR_GAP
	target.x = clampf(target.x, SCREEN_MARGIN, screen.x - box.x - SCREEN_MARGIN)
	target.y = clampf(target.y, SCREEN_MARGIN, screen.y - box.y - SCREEN_MARGIN)
	panel.global_position = target
	var left_edge := target.x
	tail.visible = anchor.x < left_edge - 4.0
	if not tail.visible:
		return
	var base_y := clampf(anchor.y, target.y + TAIL_HALF + 8.0, target.y + box.y - TAIL_HALF - 8.0)
	tail.global_position = Vector2.ZERO
	tail.polygon = PackedVector2Array([
		Vector2(left_edge + 3.0, base_y - TAIL_HALF),
		Vector2(left_edge + 3.0, base_y + TAIL_HALF),
		anchor + Vector2(10, 0)])
