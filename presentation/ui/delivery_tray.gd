extends Control
## Teslim ekranı: teslimatçı dosya isteyince (2. günden sonra, decision aşaması) ekran kararır; teslimatçı ve
## konuşma kutusu aydınlık kalır. Sol tarafta incelenen kişinin tam dava dosyası (gözlem, sicil, polaroid, karar)
## açık durur; fare tekerleğiyle veya ok tuşlarıyla dosyalar arasında gezilebilir.
## Sağ altta polaroid tepsisi durur; teslimatçıya sürüklenip onaylanınca veya doğrudan "Bu Dosyayı Teslim Et"e
## tıklanınca report_requested yayılır. Bitirme düğmesi finish_requested yayar.
signal report_requested(record_id: String)
signal finish_requested
const Card = preload("res://presentation/ui/delivery_card.gd")
const CaseFile = preload("res://presentation/ui/case_file.gd")
const HOLE_MARGIN := 18.0
## Onay, Vey'in/Defne'nin sözünün devamı gibi konuşma kutusunun hemen altında durur.
const CONFIRM_GAP := 14.0
const CARD_GAP := 24.0
var is_active: bool = false
var view: Dictionary = {}
var pending: String = ""
var cards_key: String = ""
var selected_index: int = 0
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

# Dava dosyası bileşenleri
@onready var folder: Control = $Folder
@onready var folder_header: Label = $Folder/Tab/Header
@onready var folder_polaroid: Control = $Folder/Polaroid
@onready var folder_photo: TextureRect = $Folder/Polaroid/Photo
@onready var folder_name: Label = $Folder/Name
@onready var folder_guess: Label = $Folder/Guess
@onready var folder_give_btn: Button = $Folder/GiveDossierButton
@onready var folder_scroll_hint: Label = $Folder/ScrollHint
@onready var folder_number: Label = $Folder/Paper/Box/Number
@onready var folder_obs_caption: Label = $Folder/Paper/Box/ObservationCaption
@onready var folder_obs: Label = $Folder/Paper/Box/Observation
@onready var folder_rec_caption: Label = $Folder/Paper/Box/RecordCaption
@onready var folder_rec: Label = $Folder/Paper/Box/Record
@onready var folder_stamp: Label = $Folder/Stamp
@onready var nav_prev: Button = $Folder/NavPrev
@onready var nav_count: Label = $Folder/NavCount
@onready var nav_next: Button = $Folder/NavNext

func _ready() -> void:
	give_button.text = I18n.t("delivery.give")
	cancel_button.text = I18n.t("delivery.cancel")
	give_button.pressed.connect(_give)
	cancel_button.pressed.connect(_cancel)
	finish_button.pressed.connect(func() -> void: finish_requested.emit())
	drop_zone.dropped.connect(_pick)
	
	folder_obs_caption.text = I18n.t("dossier.observation")
	folder_rec_caption.text = I18n.t("dossier.record")
	folder_give_btn.pressed.connect(_on_give_dossier_pressed)
	nav_prev.pressed.connect(_prev_dossier)
	nav_next.pressed.connect(_next_dossier)
	
	# Fare tekerleği girişini yakalamak için panellerin gui_input'una bağlan
	for node: Control in [self, folder, shade, tray]:
		node.gui_input.connect(_handle_scroll_input)
		
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

func _can_report_today() -> bool:
	var rep_day: int = int(view.get("reported_day", 0))
	var cur_day: int = int(view.get("day", 1))
	return rep_day != cur_day

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
	var can_report := _can_report_today()
	finish_button.text = I18n.t("delivery.finish" if (not can_report or view.get("delivery_reported", false)) else "delivery.nobody")
	var eligible := _eligible()
	if not can_report:
		hint.text = I18n.t("delivery.already_reported_today")
	else:
		hint.text = I18n.t("delivery.hint" if not eligible.is_empty() else "delivery.empty")
	_render_cards(eligible)
	
	if pending != "" and not eligible.any(func(record: Dictionary) -> bool: return record.id == pending):
		pending = ""
	confirm.visible = pending != ""
	hint.visible = pending == ""
	
	_render_dossier()
	_update_tray_highlight()

## Fare tekerleğiyle veya ok tuşlarıyla dosyalar arasında gezinme
func _handle_scroll_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_next_dossier()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_prev_dossier()
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_next_dossier()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_prev_dossier()
			get_viewport().set_input_as_handled()

## Dosya listesi (öncelikle teslim edilebilirler, yoksa tüm kayıtlar)
func _records_list() -> Array:
	var eligible := _eligible()
	if not eligible.is_empty():
		return eligible
	return view.get("records", [])

func _next_dossier() -> void:
	var list := _records_list()
	if list.size() <= 1:
		return
	selected_index = (selected_index + 1) % list.size()
	_render_dossier()
	_update_tray_highlight()

func _prev_dossier() -> void:
	var list := _records_list()
	if list.size() <= 1:
		return
	selected_index = (selected_index - 1 + list.size()) % list.size()
	_render_dossier()
	_update_tray_highlight()

func _select_id(record_id: String) -> void:
	var list := _records_list()
	for i in range(list.size()):
		if list[i].id == record_id:
			selected_index = i
			_render_dossier()
			_update_tray_highlight()
			return

## Seçili dosyanın detaylarını manila klasöründe gösterir
func _render_dossier() -> void:
	var list := _records_list()
	if list.is_empty():
		folder.hide()
		return
	folder.show()
	selected_index = clampi(selected_index, 0, list.size() - 1)
	var current: Dictionary = list[selected_index]
	
	folder_photo.texture = CaseFile.photo_texture(current)
	folder_header.text = I18n.t("dossier.case_header", {"number": "%04d" % (selected_index + 1)})
	folder_number.text = I18n.t("dossier.record_title", {"name": current.get("name", ""), "day": current.get("day", 1)})
	folder_name.text = current.get("name", "")
	
	var marks: Array = current.get("marks", [])
	var lines := PackedStringArray([current.get("appearance", ""), "", I18n.t("dossier.marks") if not marks.is_empty() else I18n.t("dossier.no_marks")])
	for line: String in marks:
		lines.append("• " + line)
	folder_obs.text = "\n".join(lines)
	folder_rec.text = current.get("dossier", "")
	
	var guess_key: String = str(current.get("guess", "unknown"))
	var guess_text: String = {"unknown": I18n.t("dossier.guess_unknown"), "human": I18n.t("dossier.guess_human"), "fallen": I18n.t("dossier.guess_fallen")}.get(guess_key, I18n.t("common.unavailable"))
	folder_guess.text = I18n.t("dossier.guess", {"guess": guess_text})
	
	nav_count.text = "%d / %d" % [selected_index + 1, list.size()]
	nav_prev.visible = list.size() > 1
	nav_next.visible = list.size() > 1
	
	var is_eligible: bool = current.id in _eligible().map(func(r: Dictionary) -> String: return r.id)
	if current.get("reported_to", "") != "":
		folder_stamp.text = I18n.t("dossier.stamp_defne" if current.reported_to == "human" else "dossier.stamp_vey")
		folder_stamp.show()
		folder_give_btn.text = "Teslim Edildi"
		folder_give_btn.disabled = true
	elif not _can_report_today():
		folder_stamp.hide()
		folder_give_btn.text = I18n.t("delivery.daily_delivered")
		folder_give_btn.disabled = true
	else:
		folder_stamp.hide()
		folder_give_btn.text = "Bu Dosyayı Teslim Et"
		folder_give_btn.disabled = not is_eligible

func _update_tray_highlight() -> void:
	var list := _records_list()
	if selected_index < 0 or selected_index >= list.size():
		return
	var current_id: String = list[selected_index].id
	for i in range(tray.get_child_count()):
		var child: Control = tray.get_child(i)
		if child.get("record_id") == current_id:
			child.modulate = Color(1.22, 1.22, 1.22)
			child.scale = Vector2(1.04, 1.04)
		else:
			child.modulate = Color(0.85, 0.85, 0.85)
			child.scale = Vector2.ONE

func _on_give_dossier_pressed() -> void:
	if not _can_report_today():
		EventBus.feedback.emit(I18n.t("feedback.already_reported_today"))
		return
	var list := _records_list()
	if selected_index >= 0 and selected_index < list.size():
		var current: Dictionary = list[selected_index]
		if current.id in _eligible().map(func(r: Dictionary) -> String: return r.id):
			_pick(current.id)

## 1–9 polaroid seçer, sol/sağ oklar dosyayı değiştirir, Enter verir, Esc onayı kapatır, Boşluk bitirir.
func handle_key(key: int) -> bool:
	if not is_active:
		return false
	if confirm.visible:
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			_give()
		elif key == KEY_ESCAPE:
			_cancel()
		return true
	if key in [KEY_LEFT, KEY_A]:
		_prev_dossier()
		return true
	if key in [KEY_RIGHT, KEY_D]:
		_next_dossier()
		return true
	if key >= KEY_1 and key <= KEY_9:
		var index := key - KEY_1
		if index < tray.get_child_count():
			_pick(tray.get_child(index).record_id)
		return true
	if key == KEY_SPACE:
		finish_requested.emit()
		return true
	# Seçim yokken Enter yutulur: genel dala düşüp teslimatı dosyasız bitirmesin.
	return key in [KEY_ENTER, KEY_KP_ENTER]

func _process(_delta: float) -> void:
	if world == null or balloon_panel == null:
		return
	var person: Rect2 = world.character_rect()
	drop_zone.position = person.position
	drop_zone.size = person.size
	var shade_material := shade.material as ShaderMaterial
	shade_material.set_shader_parameter("hole_a", _hole(person))
	var balloon_rect := balloon_panel.get_global_rect()
	shade_material.set_shader_parameter("hole_b", _hole(balloon_rect))
	confirm.position = Vector2(balloon_rect.position.x, balloon_rect.end.y + CONFIRM_GAP)

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
	# Kart sığmazsa aralık eksiye düşer, polaroidler yelpaze gibi üst üste biner.
	var spare: float = tray.size.x - records.size() * Card.SIZE.x
	tray.add_theme_constant_override("separation", int(minf(CARD_GAP, spare / maxi(records.size() - 1, 1))))
	for i in range(records.size()):
		var card := Card.new()
		tray.add_child(card)
		card.setup(records[i], i, CaseFile.photo_texture(records[i]))
		card.picked.connect(_pick)
	_update_tray_highlight()

func _pick(record_id: String) -> void:
	_select_id(record_id)
	if not _can_report_today():
		EventBus.feedback.emit(I18n.t("feedback.already_reported_today"))
		return
	for record: Dictionary in view.get("records", []):
		if record.id == record_id:
			pending = record_id
			confirm_text.text = I18n.t("delivery.confirm", {"name": record.name})
			confirm.reset_size()
			confirm.show()
			hint.hide()
			return

func _give() -> void:
	if pending == "":
		return
	var record_id := pending
	pending = ""
	confirm.hide()
	hint.show()
	report_requested.emit(record_id)

func _cancel() -> void:
	pending = ""
	confirm.hide()
	hint.show()
