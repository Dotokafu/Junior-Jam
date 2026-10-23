extends Control
## Coffee Talk tarzı konuşma kutusu: karakterin yanında küçük koyu kutu, daktilo metni,
## tıkla-atla, AUTO ve FFWD. Demlerken sol üstte krem "sipariş şeridi" olur.
signal advance_requested
signal decision_pressed
signal line_started
enum Mode { ADVANCE, STATIC, DECISION }
const SPEEDS := {"slow": 22.0, "normal": 45.0, "fast": 95.0}
const SCREEN_MARGIN := 24.0
## Kutunun sol kenarı çapanın biraz soluna biner (karakterin koluyla çakışır, Coffee Talk gibi).
const ANCHOR_OVERLAP := 40.0
const AUTO_DELAY := 1.1
const AUTO_PER_CHAR := 0.03
const FFWD_DELAY := 0.25
const TEXT_WIDTH := 520.0
const DOCK_POSITION := Vector2(24, 24)
const DOCK_TEXT_WIDTH := 680.0
const LIGHT_TEXT := Color("efe3c8")
const DARK_TEXT := Color("2b2228")
var speed: String = "normal"
var auto: bool = false
var fast_forward: bool = false
var reduced_motion: bool = false
var mode: Mode = Mode.ADVANCE
var line_key: String = ""
var anchor := Vector2(1000, 760)
var typed: float = 0.0
var waited: float = 0.0
var awaiting_next: bool = false
var docked: bool = false:
	set(value):
		if value == docked:
			return
		docked = value
		if is_node_ready():
			_apply_dock()
@onready var panel: PanelContainer = $Panel
@onready var box: VBoxContainer = $Panel/Box
@onready var name_tag: Label = $Panel/Box/NameTag
@onready var text_label: RichTextLabel = $Panel/Box/Text
@onready var hint: Label = $Panel/Box/Footer/Hint
@onready var decision_button: Button = $Panel/Box/Footer/DecisionButton
@onready var arrow: Label = $Panel/Box/Footer/Arrow

func _ready() -> void:
	panel.gui_input.connect(_on_panel_input)
	panel.resized.connect(_place)
	decision_button.pressed.connect(func() -> void: decision_pressed.emit())
	_apply_dock()
	hide()

func say(speaker: String, line: String, new_mode: Mode, key: String, hint_text: String = "", decision_text: String = "") -> void:
	show()
	mode = new_mode
	hint.text = hint_text
	hint.visible = hint_text != ""
	decision_button.text = decision_text
	decision_button.visible = mode == Mode.DECISION and decision_text != ""
	if key != line_key:
		line_key = key
		awaiting_next = false
		name_tag.text = speaker
		name_tag.visible = speaker != "" and not docked
		text_label.text = line
		typed = 0.0
		waited = 0.0
		text_label.visible_characters = 0
		if fast_forward or line == "":
			_finish()
		line_started.emit()
		_pop()
	_update_arrow()
	# Kutu metne göre küçülsün: önce minimuma indir, yerleşimi bir kare sonra yap.
	panel.reset_size()
	_place()
	_place.call_deferred()

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

func _apply_dock() -> void:
	var width := DOCK_TEXT_WIDTH if docked else TEXT_WIDTH
	panel.theme_type_variation = &"BalloonDocked" if docked else &"BalloonPanel"
	text_label.add_theme_color_override("default_color", DARK_TEXT if docked else LIGHT_TEXT)
	text_label.custom_minimum_size.x = width
	box.custom_minimum_size.x = width
	name_tag.visible = not docked and name_tag.text != ""
	panel.reset_size()

func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if try_advance():
			accept_event()

func _pop() -> void:
	if reduced_motion:
		return
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)

## Kutuyu çapanın sağına, dikeyde ortalı koyar; ekran dışına taşarsa içeri çeker.
func _place() -> void:
	if not is_node_ready():
		return
	if docked:
		panel.global_position = DOCK_POSITION
		return
	var screen := get_viewport_rect().size
	var size_now := panel.size
	var target := Vector2(anchor.x - ANCHOR_OVERLAP, anchor.y - size_now.y * 0.5)
	target.x = clampf(target.x, SCREEN_MARGIN, screen.x - size_now.x - SCREEN_MARGIN)
	target.y = clampf(target.y, SCREEN_MARGIN, screen.y - size_now.y - SCREEN_MARGIN)
	panel.global_position = target
