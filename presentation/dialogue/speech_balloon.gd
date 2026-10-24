extends Control
## Coffee Talk tarzı konuşma kutusu: karakterin yanında küçük koyu kutu, daktilo metni,
## tıkla-atla, AUTO ve FFWD. Demlerken sol üstte krem "sipariş şeridi" olur.
signal advance_requested
signal decision_pressed
signal line_started
signal question_pressed(index: int)
signal mark_pressed
enum Mode { ADVANCE, STATIC, DECISION }
const SPEEDS := {"slow": 22.0, "normal": 45.0, "fast": 95.0}
const SCREEN_MARGIN := 24.0
## Kutunun sol kenarı çapanın biraz soluna biner (karakterin koluyla çakışır, Coffee Talk gibi).
const ANCHOR_OVERLAP := 40.0
## Kutunun üst kenarı çapanın bu kadar üstünde durur; en uzun sorgu kutusu (3 soru) ekrana sığar.
const ANCHOR_RISE := 210.0
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
var interview_key: String = ""
## Aynı konuşmacı konuşurken kutunun ulaştığı en yüksek üst kenar (-1: henüz yok).
var held_top: float = -1.0
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
@onready var questions_box: VBoxContainer = $Panel/Box/Questions
@onready var mark_button: Button = $Panel/Box/Footer/MarkButton

func _ready() -> void:
	panel.gui_input.connect(_on_panel_input)
	panel.resized.connect(_place)
	decision_button.pressed.connect(func() -> void: decision_pressed.emit())
	mark_button.pressed.connect(func() -> void: mark_pressed.emit())
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
		if speaker != name_tag.text:
			held_top = -1.0
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

## Sorgu: soru düğmeleri (sorulanlar ve hak bitince kapalı), kalan hak; İşaretle düğmesi.
## questions: [{text, asked}]. Liste değişmedikçe düğmeler yeniden kurulmaz.
func set_interview(questions: Array, left: int, marked: bool, can_mark: bool) -> void:
	mark_button.visible = can_mark
	mark_button.text = I18n.t("balloon.marked" if marked else "balloon.mark")
	var key := "%s|%d" % [str(questions), left]
	if key == interview_key:
		return
	interview_key = key
	for child: Node in questions_box.get_children():
		child.queue_free()
	questions_box.visible = not questions.is_empty()
	for i in range(questions.size()):
		var button := Button.new()
		button.text = I18n.t("balloon.question", {"number": i + 1, "text": questions[i].text})
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = TEXT_WIDTH
		button.disabled = questions[i].asked or left <= 0
		button.pressed.connect(func() -> void: question_pressed.emit(i))
		questions_box.add_child(button)
	if not questions.is_empty():
		var remaining := Label.new()
		remaining.theme_type_variation = &"Caption"
		remaining.text = I18n.t("balloon.questions_left", {"count": left})
		questions_box.add_child(remaining)
	panel.reset_size()
	_place.call_deferred()

func close() -> void:
	line_key = ""
	held_top = -1.0
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

## Kutuyu çapanın sağına koyar. Üst kenar sabittir, kutu aşağı doğru büyür; ekrana sığmazsa yukarı itilir.
## Aynı konuşmacı konuşurken kutu yalnızca yukarı çıkar, aşağı inmez: satır uzunluğu değişince ya da soru
## listesi açılıp kapanınca metin yerinde kalır (eskiden dikeyde ortalıydı ve her boy değişiminde zıplıyordu).
func _place() -> void:
	if not is_node_ready():
		return
	if docked:
		held_top = -1.0
		panel.global_position = DOCK_POSITION
		return
	var screen := get_viewport_rect().size
	var size_now := panel.size
	var top := minf(anchor.y - ANCHOR_RISE, screen.y - size_now.y - SCREEN_MARGIN)
	if held_top >= 0.0:
		top = minf(top, held_top)
	top = maxf(top, SCREEN_MARGIN)
	held_top = top
	var left := clampf(anchor.x - ANCHOR_OVERLAP, SCREEN_MARGIN, screen.x - size_now.x - SCREEN_MARGIN)
	panel.global_position = Vector2(left, top)
