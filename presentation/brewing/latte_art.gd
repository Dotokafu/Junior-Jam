extends Control
## Latte art ekranı (Coffee Talk'taki gibi). Servis sayfasından açılır, aşağıdan kayarak gelir.
## Solda araçlar: süt dök, çiz, akışı çevir. Sağda: servis et, baştan, geri. Fincan üstten görünür;
## köpük latte_fluid simülasyonudur (ekran kartında). Q/E fincanı çevirir (köpük ve kulp birlikte döner).
## Servis: served sinyali → içecek latte art'lı servis edilir. Geri: closed → servis sayfasına dönülür.
signal served
signal closed
const Fluid = preload("res://presentation/brewing/latte_fluid.gd")
const Tools = preload("res://presentation/brewing/latte_tools.gd")
const FLOW_ICON := "res://assets/ui/icons/latte_flow.png"
const FLOW_REVERSE_ICON := "res://assets/ui/icons/latte_flow_reverse.png"
const SLIDE_TIME := 0.6
## Fincan, köpük karesinin ortadaki bu kadarını gösterir: sıvının duvar dairesi (Fluid.WALL_RADIUS), böylece
## süt fincanın kenarına kadar gider. Köpük TextureRect'i fincanın iç dairesinden bu oranda büyüktür.
const VISIBLE := Fluid.WALL_RADIUS * 2.0
const DIM_ALPHA := 0.6
## Derece / saniye (Coffee Talk: omuz tuşu basılıyken kare başına 1°).
const TURN_SPEED := 60.0
var reduced_motion: bool = false
var is_open: bool = false
var busy: bool = false
var tool: String = "pour"
var drink_color: Color = Color.WHITE
var fluid: Fluid
var pour: Tools.Pour
var etch: Tools.Etch
var flow_icons: Array[Texture2D] = []
## Son fare konumu (tuval koordinatı) ve sol tuş durumu; fare olaylarından izlenir.
var mouse_position: Vector2 = Vector2(-1, -1)
var mouse_down: bool = false
## Her açılış/kapanış yeni oturum; eski kayma animasyonu döndüğünde yeni oturumu bozmasın.
var session_id: int = 0
var slide: Tween
@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Panel
@onready var cup: Control = $Panel/Cup
@onready var foam: TextureRect = $Panel/Cup/Foam
@onready var title: Label = $Panel/Title
@onready var pour_button: Button = $Panel/Tools/PourButton
@onready var etch_button: Button = $Panel/Tools/EtchButton
@onready var flow_button: Button = $Panel/Tools/FlowButton
@onready var serve_button: Button = $Panel/Actions/ServeButton
@onready var reset_button: Button = $Panel/Actions/ResetButton
@onready var back_button: Button = $Panel/Actions/BackButton
@onready var info: Label = $Panel/Info
@onready var keys: Label = $Panel/Keys

func _ready() -> void:
	title.text = I18n.t("latte.title")
	pour_button.text = I18n.t("latte.pour")
	etch_button.text = I18n.t("latte.etch")
	flow_button.text = I18n.t("latte.flow")
	serve_button.text = I18n.t("button.serve")
	reset_button.text = I18n.t("latte.reset")
	back_button.text = I18n.t("latte.back")
	keys.text = I18n.t("latte.keys")
	for path: String in [FLOW_ICON, FLOW_REVERSE_ICON]:
		flow_icons.append(load(path) if ResourceLoader.exists(path) else null)
	pour_button.pressed.connect(select_tool.bind("pour"))
	etch_button.pressed.connect(select_tool.bind("etch"))
	flow_button.pressed.connect(toggle_flow)
	reset_button.pressed.connect(reset)
	serve_button.pressed.connect(serve)
	back_button.pressed.connect(back)
	fluid = Fluid.new()
	fluid.name = "Fluid"
	add_child(fluid)
	pour = Tools.Pour.new(fluid)
	etch = Tools.Etch.new(fluid)
	foam.texture = fluid.texture
	# Izgara Coffee Talk'un UV yönünde (u sola doğru artar); görüntü ve fare aynalanır.
	foam.flip_h = true
	hide()
	set_process(false)

func open(color: Color, art_color: Color = Color.WHITE) -> void:
	if is_open:
		return
	is_open = true
	session_id += 1
	var my_session := session_id
	drink_color = color
	pour.set_drink_color(color, art_color)
	pour.reverse = false
	_update_flow_icon()
	reset()
	select_tool("pour")
	show()
	set_process(true)
	if reduced_motion:
		panel.position.y = 0.0
		dim.color.a = DIM_ALPHA
		return
	busy = true
	panel.position.y = size.y
	dim.color.a = 0.0
	_start_slide(0.0, DIM_ALPHA, Tween.EASE_OUT)
	await slide.finished
	if my_session == session_id:
		busy = false

func serve() -> void:
	if await _slide_out():
		served.emit()

func back() -> void:
	if await _slide_out():
		closed.emit()

## Dışarıdan kapatma (sayfa kapanırken): animasyonsuz, sinyalsiz.
func force_close() -> void:
	session_id += 1
	if slide:
		slide.kill()
	is_open = false
	busy = false
	_release_tools()
	set_process(false)
	hide()

## Köpüğü baştan döker ve fincanı düz çevirir (Coffee Talk: simülasyon yeniden kurulur).
func reset() -> void:
	_release_tools()
	fluid.reset(drink_color)
	cup.rotation = 0.0

func select_tool(id: String) -> void:
	_release_tools()
	tool = id
	pour_button.set_pressed_no_signal(id == "pour")
	etch_button.set_pressed_no_signal(id == "etch")
	info.text = I18n.t("latte.pour_info" if id == "pour" else "latte.etch_info")

func toggle_flow() -> void:
	pour.reverse = not pour.reverse
	_update_flow_icon()

## cafe_screen kısayolları buraya yönlendirir. Ele alındıysa true.
func handle_key(key: int) -> bool:
	if not is_open:
		return false
	if busy:
		return true
	match key:
		KEY_1: select_tool("pour")
		KEY_2: select_tool("etch")
		KEY_I: toggle_flow()
		KEY_R: reset()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_F: serve()
		KEY_ESCAPE, KEY_BACKSPACE: back()
		KEY_Q, KEY_E: pass
		_: return false
	return true

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouse:
		mouse_position = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = event.pressed

## Fare fincan maskesinin karesi dışındaysa araç etkisizdir (Coffee Talk'taki gibi). Dönüş: köpük
## ızgarasında 0..1 konum (yatay aynalı, Coffee Talk UV'si), dışarıdaysa (-1, -1).
func pointer_in_cup() -> Vector2:
	var local := foam.get_global_transform_with_canvas().affine_inverse() * mouse_position
	var visible_size := foam.size * VISIBLE
	if not Rect2((foam.size - visible_size) / 2.0, visible_size).has_point(local):
		return Vector2(-1, -1)
	var at := local / foam.size
	return Vector2(1.0 - at.x, at.y)

func _process(delta: float) -> void:
	if busy:
		return
	var turn := float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	cup.rotation += deg_to_rad(turn * TURN_SPEED * delta)
	var pointer := pointer_in_cup()
	var pressed := pointer.x >= 0.0 and mouse_down
	if tool == "pour":
		pour.update(pointer, pressed, delta)
	else:
		etch.update(pointer, pressed, delta)
	fluid.update(delta)

func _slide_out() -> bool:
	if not is_open or busy:
		return false
	_release_tools()
	set_process(false)
	var my_session := session_id
	if not reduced_motion:
		busy = true
		_start_slide(size.y, 0.0, Tween.EASE_IN)
		await slide.finished
		if my_session != session_id:
			return false
		busy = false
	if not is_open:
		return false
	is_open = false
	hide()
	return true

func _start_slide(panel_y: float, dim_alpha: float, ease: Tween.EaseType) -> void:
	if slide:
		slide.kill()
	slide = create_tween().set_parallel(true)
	slide.tween_property(panel, "position:y", panel_y, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	slide.tween_property(dim, "color:a", dim_alpha, SLIDE_TIME)

func _release_tools() -> void:
	mouse_down = false
	pour.release()
	etch.release()

func _update_flow_icon() -> void:
	var icon: Texture2D = flow_icons[1 if pour.reverse else 0]
	if icon != null:
		flow_button.icon = icon
