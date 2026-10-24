extends Control
## Dava dosyası: sol altta, fotoğraf makinesinin yanında açık bir manila klasör.
## Sol kanat: polaroid + isim. Sağ kanat: mandalla tutturulmuş kâğıtta gözlem ve sicil.
## Yeni fotoğrafta polaroid makineden uçup bantlanır ve banyo olur; arşivde sekmelerle gezilir,
## teslim edilen dosyaya damga basılır.
signal closed
const PORTRAIT_PATH := "res://assets/characters/%s.png"
const SLIDE_TIME := 0.35
const FLY_TIME := 0.45
const DEVELOP_TIME := 1.6
const UNDEVELOPED := Color(0.16, 0.14, 0.18)
const HIDDEN_OFFSET := 60.0
## Fotoğraf karakter çiziminin üst kısmından kare kırpılır (genişliğe oranla).
const PHOTO_CROP := Rect2(0.1, 0.04, 0.8, 0.8)
var view: Dictionary = {}
var selected_id: String = ""
var reduced_motion: bool = false
var rest_y: float = 0.0
var polaroid_rest: Vector2
var stamped_ids: Array = []
var slide_tween: Tween
@onready var folder: Control = $Folder
@onready var header: Label = $Folder/Tab/Header
@onready var tabs: HBoxContainer = $Folder/Tabs
@onready var polaroid: Control = $Folder/Polaroid
@onready var photo: TextureRect = $Folder/Polaroid/Photo
@onready var tape: TextureRect = $Folder/Polaroid/Tape
@onready var name_label: Label = $Folder/Name
@onready var guess: Label = $Folder/Guess
@onready var hint: Label = $Folder/Hint
@onready var number: Label = $Folder/Paper/Box/Number
@onready var observation: Label = $Folder/Paper/Box/Observation
@onready var record_text: Label = $Folder/Paper/Box/Record
@onready var stamp: Label = $Folder/Stamp

func _ready() -> void:
	rest_y = folder.position.y
	polaroid_rest = polaroid.position
	$Folder/CloseButton.pressed.connect(func() -> void: closed.emit())
	$Folder/CloseButton.text = I18n.t("button.close_x")
	$Folder/CloseButton.tooltip_text = I18n.t("key.close")
	$Folder/Paper/Box/ObservationCaption.text = I18n.t("dossier.observation")
	$Folder/Paper/Box/RecordCaption.text = I18n.t("dossier.record")
	hide()

## Kare fotoğraf: kişinin çiziminden üst kısım. Çizim yoksa null.
static func photo_texture(record: Dictionary) -> Texture2D:
	var portrait: Dictionary = record.get("portrait", {})
	for path: String in [str(portrait.get("portrait_texture", "")), PORTRAIT_PATH % portrait.get("portrait_id", ""), PORTRAIT_PATH % record.get("character", "")]:
		if path.ends_with(".png") and ResourceLoader.exists(path):
			var source: Texture2D = load(path)
			var atlas := AtlasTexture.new()
			atlas.atlas = source
			var width := source.get_width()
			atlas.region = Rect2(PHOTO_CROP.position.x * width, PHOTO_CROP.position.y * source.get_height(), PHOTO_CROP.size.x * width, PHOTO_CROP.size.y * width)
			return atlas
	return null

func open_archive(snapshot: Dictionary, keep_selection: String) -> void:
	selected_id = keep_selection
	refresh(snapshot)
	_settle_photo()
	_slide_in()

## Yeni çekilen fotoğraf: klasör açılır, polaroid from_rect'ten (ekran koordinatı) yerine uçar.
func present_new(snapshot: Dictionary, record_id: String, from_rect: Rect2) -> void:
	selected_id = record_id
	refresh(snapshot)
	if reduced_motion:
		_settle_photo()
		_slide_in()
		return
	photo.modulate = UNDEVELOPED
	tape.modulate.a = 0.0
	polaroid.hide()
	_slide_in()
	await slide_tween.finished
	polaroid.show()
	polaroid.global_position = from_rect.position
	polaroid.scale = from_rect.size / polaroid.size
	var fly := create_tween().set_parallel(true)
	fly.tween_property(polaroid, "position", polaroid_rest, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(polaroid, "scale", Vector2.ONE, FLY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await fly.finished
	var stick := create_tween()
	stick.tween_property(tape, "modulate:a", 1.0, 0.12)
	stick.tween_property(photo, "modulate", Color.WHITE, DEVELOP_TIME).set_trans(Tween.TRANS_SINE)

func dismiss() -> void:
	if not visible:
		return
	if slide_tween:
		slide_tween.kill()
	if reduced_motion:
		hide()
		return
	slide_tween = create_tween()
	slide_tween.tween_property(folder, "position:y", _hidden_y(), SLIDE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	slide_tween.tween_callback(hide)

func refresh(snapshot: Dictionary) -> void:
	view = snapshot
	var ids: Array = view.records.map(func(record: Dictionary) -> String: return record.id)
	if selected_id not in ids:
		selected_id = ids.back() if not ids.is_empty() else ""
	_render_tabs()
	_render_record()

func _hidden_y() -> float:
	return get_viewport_rect().size.y + HIDDEN_OFFSET

func _slide_in() -> void:
	show()
	if slide_tween:
		slide_tween.kill()
	if reduced_motion:
		folder.position.y = rest_y
		return
	folder.position.y = _hidden_y()
	slide_tween = create_tween()
	slide_tween.tween_property(folder, "position:y", rest_y, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _settle_photo() -> void:
	polaroid.show()
	polaroid.position = polaroid_rest
	polaroid.scale = Vector2.ONE
	photo.modulate = Color.WHITE
	tape.modulate.a = 1.0

func _render_tabs() -> void:
	for child: Node in tabs.get_children():
		child.queue_free()
	for record: Dictionary in view.records:
		var tab := Button.new()
		tab.theme_type_variation = &"FileTab"
		tab.toggle_mode = true
		tab.button_pressed = record.id == selected_id
		tab.text = record.name + (I18n.t("dossier.reported_marker") if record.reported_to != "" else "")
		tab.tooltip_text = I18n.t("dossier.record_title", {"name": record.name, "day": record.day})
		tab.pressed.connect(func() -> void:
			selected_id = record.id
			_settle_photo()
			_render_tabs()
			_render_record())
		tabs.add_child(tab)

func _render_record() -> void:
	var current: Dictionary = {}
	var index := 0
	for i in range(view.records.size()):
		if view.records[i].id == selected_id:
			current = view.records[i]
			index = i + 1
	polaroid.visible = not current.is_empty()
	stamp.hide()
	if current.is_empty():
		header.text = I18n.t("dossier.eyebrow")
		number.text = ""
		name_label.text = ""
		guess.text = ""
		hint.text = I18n.t("dossier.empty")
		observation.text = ""
		record_text.text = ""
		return
	photo.texture = photo_texture(current)
	header.text = I18n.t("dossier.case_header", {"number": "%04d" % index})
	number.text = I18n.t("dossier.record_title", {"name": current.name, "day": current.day})
	name_label.text = current.name
	var marks: Array = current.get("marks", [])
	var lines := PackedStringArray([current.appearance, "", I18n.t("dossier.marks") if not marks.is_empty() else I18n.t("dossier.no_marks")])
	for line: String in marks:
		lines.append("• " + line)
	observation.text = "\n".join(lines)
	record_text.text = current.dossier
	var guess_text: String = {"unknown": I18n.t("dossier.guess_unknown"), "human": I18n.t("dossier.guess_human"), "fallen": I18n.t("dossier.guess_fallen")}.get(current.guess, I18n.t("common.unavailable"))
	guess.text = I18n.t("dossier.guess", {"guess": guess_text})
	# Dosyalar yalnızca teslim ekranından (polaroidi teslimatçıya sürükleyerek) verilir.
	hint.text = "" if current.reported_to != "" else I18n.t("dossier.delivery_only")
	if current.reported_to != "":
		_stamp(current)

## Teslim edilen dosyaya kırmızı damga; ilk kez görünürken "basılır".
func _stamp(record: Dictionary) -> void:
	stamp.text = I18n.t("dossier.stamp_defne" if record.reported_to == "human" else "dossier.stamp_vey")
	stamp.show()
	if record.id in stamped_ids or reduced_motion:
		stamp.scale = Vector2.ONE
		stamp.modulate.a = 1.0
		return
	stamped_ids.append(record.id)
	stamp.scale = Vector2(1.8, 1.8)
	stamp.modulate.a = 0.0
	var slam := create_tween().set_parallel(true)
	slam.tween_property(stamp, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(stamp, "modulate:a", 1.0, 0.1)
