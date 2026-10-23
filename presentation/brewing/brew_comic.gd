extends Control
## Demle'ye basınca açılan iki tam ekran çizgi roman sayfası:
## 1) Hazırlık: üstte makine göstergesi, altta her malzeme için bir adım karesi sırayla açılır.
## 2) Servis: hazırlık kapanır, içecek elde gelir; seçim burada yapılır: Çöpe at / Servis et.
## (Latte art servis sayfasına üçüncü seçenek olarak eklenebilir.)
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const Readout = preload("res://presentation/brewing/machine_readout.gd")
const FADE_TIME := 0.18
const STEP_GAP := 0.08
const HOLD_TIME := 0.5
const SWAP_TIME := 0.25
const SERVE_RISE := 80.0
var view: Dictionary = {}
var reduced_motion: bool = false
var is_open: bool = false
var busy: bool = false
var sequence_id: int = 0
var hand_rest: float = 0.0
@onready var steps_page: Control = $Steps
@onready var machine_frame: Control = $Steps/MachineFrame
@onready var readout: Control = $Steps/MachineFrame/Machine/Box/Readout
@onready var machine_liquid: TextureRect = $Steps/MachineFrame/Machine/Box/Cup/Liquid
@onready var steps: Array[Control] = [$Steps/Step1, $Steps/Step2, $Steps/Step3]
@onready var serve_page: Control = $Serve
@onready var title: Label = $Serve/Title
@onready var summary: Label = $Serve/Summary
@onready var hand: Control = $Serve/HandCup
@onready var hand_liquid: TextureRect = $Serve/HandCup/Liquid
@onready var trash_button: Button = $Serve/TrashChoice
@onready var serve_button: Button = $Serve/ServeChoice
@onready var leaders: Control = $Serve/Leaders

func _ready() -> void:
	trash_button.text = I18n.t("button.trash")
	serve_button.text = I18n.t("button.serve")
	trash_button.tooltip_text = "[T]"
	serve_button.tooltip_text = "[F]"
	trash_button.pressed.connect(func() -> void: choose("trash"))
	serve_button.pressed.connect(func() -> void: choose("serve"))
	hand_rest = hand.position.y
	hide()

func apply(snapshot: Dictionary) -> void:
	view = snapshot
	var want: bool = view.get("started", false) and view.get("stage", "") == "brewing" and not view.get("drink", {}).is_empty()
	if want and not is_open:
		_open()
	elif not want and is_open:
		_close()

## Seçim yalnızca servis sayfası tamamen geldiğinde kabul edilir.
func choose(action: String) -> void:
	if busy or not is_open:
		return
	EventBus.request(action)

func _ingredient_map() -> Dictionary:
	var map := {}
	for item: Dictionary in view.get("ingredients", []):
		map[item.id] = item
	return map

func _fill(drink: Dictionary) -> void:
	var map := _ingredient_map()
	var selected: Array = drink.get("ingredients", [])
	readout.show_slots(selected, map)
	readout.show_stats(drink.get("stats", {}), drink.get("stats", {}))
	var drink_color := Color(str(drink.get("color", "ffffff")))
	machine_liquid.modulate = drink_color
	hand_liquid.modulate = drink_color
	title.text = drink.get("name", "")
	summary.text = Readout.tier_summary(drink.get("tiers", {}))
	for i in range(steps.size()):
		var item: Dictionary = map.get(selected[i], {}) if i < selected.size() else {}
		steps[i].setup(item, i, Brewing.color(selected.slice(0, i + 1), map))

func _open() -> void:
	is_open = true
	sequence_id += 1
	var my_sequence := sequence_id
	_fill(view.drink)
	show()
	modulate.a = 1.0
	if reduced_motion:
		hand.position.y = hand_rest
		steps_page.hide()
		serve_page.show()
		serve_page.modulate.a = 1.0
		_set_busy(false)
		return
	_set_busy(true)
	# 1) Hazırlık sayfası
	steps_page.show()
	steps_page.modulate.a = 1.0
	serve_page.hide()
	machine_frame.modulate.a = 0.0
	for step: Control in steps:
		step.reset()
	modulate.a = 0.0
	var intro := create_tween()
	intro.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	intro.tween_property(machine_frame, "modulate:a", 1.0, FADE_TIME)
	await intro.finished
	for step: Control in steps:
		if my_sequence != sequence_id:
			return
		await step.play().finished
		await get_tree().create_timer(STEP_GAP).timeout
	await get_tree().create_timer(HOLD_TIME).timeout
	if my_sequence != sequence_id:
		return
	# 2) Hazırlık kapanır, servis sayfası tam ekran gelir
	var swap := create_tween()
	swap.tween_property(steps_page, "modulate:a", 0.0, SWAP_TIME)
	swap.tween_callback(func() -> void:
		steps_page.hide()
		serve_page.show()
		serve_page.modulate.a = 0.0)
	swap.set_parallel(true)
	swap.chain().tween_property(serve_page, "modulate:a", 1.0, SWAP_TIME)
	hand.position.y = hand_rest + SERVE_RISE
	swap.tween_property(hand, "position:y", hand_rest, SWAP_TIME * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await swap.finished
	if my_sequence == sequence_id:
		_set_busy(false)

func _close() -> void:
	is_open = false
	sequence_id += 1
	_set_busy(false)
	if reduced_motion:
		hide()
		return
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	out.tween_callback(func() -> void:
		if not is_open:
			hide())

func _set_busy(value: bool) -> void:
	busy = value
	trash_button.disabled = value
	serve_button.disabled = value
	leaders.visible = not value
