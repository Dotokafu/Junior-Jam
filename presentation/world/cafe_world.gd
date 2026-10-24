extends Control
## Mekân: arka plan, karakter, tezgâh ve servis edilen fincan.
## Çizimler: res://assets/cafe/ (background_day/night, counter, cup, cup_liquid).
const BREW_CAMERA_SHIFT := -300.0
const CAMERA_TIME := 0.45
const CUP_DROP := 40.0
@export var day_background: Texture2D
@export var night_background: Texture2D
var reduced_motion: bool = false:
	set(value):
		reduced_motion = value
		if is_node_ready():
			character.reduced_motion = value
var camera_tween: Tween
var brew_focus: bool = false
var camera_target: float = 0.0
@onready var background: TextureRect = $Background
@onready var character: Control = $Character
@onready var cup: Control = $Cup
@onready var liquid: TextureRect = $Cup/Liquid

func _ready() -> void:
	cup.hide()

func set_night(night: bool) -> void:
	var target := night_background if night else day_background
	if target and background.texture != target:
		background.texture = target

func show_person(person: Dictionary, key: String) -> void:
	character.show_person(person, key)

func hide_person() -> void:
	character.hide_person()

## Karşıdaki kişinin ekrandaki dikdörtgeni (teslim ekranında aydınlık kalan ve polaroidin bırakıldığı yer).
func character_rect() -> Rect2:
	return character.art_rect()

## Kamera kayarken bile kameranın varacağı yere göre hesaplanır.
func balloon_point() -> Vector2:
	return character.balloon_point() + Vector2(camera_target - position.x, 0)

## Coffee Talk'taki gibi: makine açılınca sahne sola kayar.
func focus_brew(open: bool) -> void:
	if open == brew_focus:
		return
	brew_focus = open
	var target := BREW_CAMERA_SHIFT if open else 0.0
	camera_target = target
	if camera_tween:
		camera_tween.kill()
	if reduced_motion:
		position.x = target
		return
	camera_tween = create_tween()
	camera_tween.tween_property(self, "position:x", target, CAMERA_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func show_cup(color_html: String) -> void:
	if cup.visible:
		return
	liquid.modulate = Color(color_html) if color_html != "" else Color.WHITE
	cup.show()
	if reduced_motion:
		return
	var rest := cup.position.y
	cup.position.y = rest - CUP_DROP
	cup.modulate.a = 0.0
	var drop := create_tween().set_parallel(true)
	drop.tween_property(cup, "position:y", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	drop.tween_property(cup, "modulate:a", 1.0, 0.15)

func hide_cup() -> void:
	cup.hide()
