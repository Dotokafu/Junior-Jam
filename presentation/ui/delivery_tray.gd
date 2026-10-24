extends Control
## Teslim ekranı: teslimatçı dosya isteyince (2. günden sonra, decision aşaması) ekran kararır; teslimatçı ve
## konuşma kutusu aydınlık kalır. Altta fotoğrafı çekilmiş, henüz verilmemiş kişilerin polaroidleri durur;
## biri teslimatçıya sürüklenip onaylanınca report_requested yayılır. Bitirme düğmesi finish_requested yayar.
signal report_requested(record_id: String)
signal finish_requested
const Card = preload("res://presentation/ui/delivery_card.gd")
const CaseFile = preload("res://presentation/ui/case_file.gd")
const HOLE_MARGIN := 18.0
var is_active: bool = false
var view: Dictionary = {}
var pending: String = ""
var cards_key: String = ""
## Delikler her karede izlenir: teslimatçı ve konuşma kutusu hareket edebilir.
var world: Control
var balloon_panel: Control
@onready var shade: ColorRect = $Shade
@onready var drop_zone: Control = $DropZone
@onready var tray: HBoxContainer = $Tray
@onready var hint: Label = $Hint
@onready var confirm: PanelContainer = $Confirm
@onready var confirm_text: Label = $Confirm/Box/Text
@onready var give_button: Button = $Confirm/Box/Buttons/GiveButton
@onready var cancel_button: Button = $Confirm/Box/Buttons/CancelButton
@onready var finish_button: Button = $FinishButton

func _ready() -> void:
	give_button.text = I18n.t("delivery.give")
	cancel_button.text = I18n.t("delivery.cancel")
	give_button.pressed.connect(_give)
	cancel_button.pressed.connect(_cancel)
	finish_button.pressed.connect(func() -> void: finish_requested.emit())
	drop_zone.dropped.connect(_pick)
	hide()
	set_process(false)

## Teslimatçı soruyu sorduğunda tepsi açılır. 1. günde yalnızca verilecek fotoğraf varsa (öğretici sabah boş kalır).
static func wants(snapshot: Dictionary) -> bool:
	return bool(snapshot.get("started", false)) and snapshot.get("stage", "") == "decision" \
		and snapshot.get("phase", "") in ["morning_supplier", "night_supplier"] \
		and (int(snapshot.get("day", 1)) >= 2 or not snapshot.get("records", []).is_empty())

func track(world_node: Control, panel: Control) -> void:
	world = world_node
	balloon_panel = panel

func apply(snapshot: Dictionary) -> void:
	view = snapshot
	if not wants(view):
		if is_active:
			is_active = false
			pending = ""
			hide()
			set_process(false)
		return
	is_active = true
	show()
	set_process(true)
	_process(0.0)
	finish_button.text = I18n.t("delivery.finish" if view.get("delivery_reported", false) else "delivery.nobody")
	var eligible := _eligible()
	hint.text = I18n.t("delivery.hint" if not eligible.is_empty() else "delivery.empty")
	_render_cards(eligible)
	if pending != "" and not eligible.any(func(record: Dictionary) -> bool: return record.id == pending):
		pending = ""
	confirm.visible = pending != ""

## 1–9 polaroid seçer, Enter verir, Esc onayı kapatır, Boşluk bitirir. Ele alındıysa true.
func handle_key(key: int) -> bool:
	if not is_active:
		return false
	if confirm.visible:
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			_give()
		elif key == KEY_ESCAPE:
			_cancel()
		return true
	if key >= KEY_1 and key <= KEY_9:
		var index := key - KEY_1
		if index < tray.get_child_count():
			_pick(tray.get_child(index).record_id)
		return true
	if key == KEY_SPACE:
		finish_requested.emit()
		return true
	return false

func _process(_delta: float) -> void:
	if world == null or balloon_panel == null:
		return
	var person: Rect2 = world.character_rect()
	drop_zone.position = person.position
	drop_zone.size = person.size
	var shade_material := shade.material as ShaderMaterial
	shade_material.set_shader_parameter("hole_a", _hole(person))
	shade_material.set_shader_parameter("hole_b", _hole(balloon_panel.get_global_rect()))

func _hole(rect: Rect2) -> Vector4:
	var grown := rect.grow(HOLE_MARGIN)
	return Vector4(grown.position.x, grown.position.y, grown.size.x, grown.size.y)

## Henüz verilmemiş ve kişisi daha önce verilmemiş kayıtlar (mevcut teslim kuralıyla aynı).
func _eligible() -> Array:
	var given: Array = []
	for record: Dictionary in view.get("records", []):
		if record.reported_to != "":
			given.append(record.character)
	return view.get("records", []).filter(func(record: Dictionary) -> bool: return record.reported_to == "" and record.character not in given)

func _render_cards(records: Array) -> void:
	var key := str(records.map(func(record: Dictionary) -> String: return record.id))
	if key == cards_key:
		return
	cards_key = key
	for child: Node in tray.get_children():
		tray.remove_child(child)
		child.queue_free()
	for i in range(records.size()):
		var card := Card.new()
		tray.add_child(card)
		card.setup(records[i], i, CaseFile.photo_texture(records[i]))
		card.picked.connect(_pick)

func _pick(record_id: String) -> void:
	for record: Dictionary in view.get("records", []):
		if record.id == record_id:
			pending = record_id
			confirm_text.text = I18n.t("delivery.confirm", {"name": record.name})
			confirm.show()
			return

func _give() -> void:
	if pending == "":
		return
	var record_id := pending
	pending = ""
	confirm.hide()
	report_requested.emit(record_id)

func _cancel() -> void:
	pending = ""
	confirm.hide()
