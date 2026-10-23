extends Control
## GBT terminali (yer tutucu telefon). Fotoğraflanan müşteriler ve tedarikçiye ihbar.
signal closed
const PORTRAIT_PATH := "res://assets/characters/%s.png"
var view: Dictionary = {}
var selected_id: String = ""
@onready var title: Label = $Frame/Screen/Box/Title
@onready var intro: Label = $Frame/Screen/Box/Intro
@onready var list: VBoxContainer = $Frame/Screen/Box/List/Items
@onready var detail: VBoxContainer = $Frame/Screen/Box/Detail
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	close_button.pressed.connect(func() -> void: closed.emit())
	close_button.text = I18n.t("button.close_dossier")
	title.text = I18n.t("dossier.title")
	intro.text = I18n.t("dossier.instructions")

func open(snapshot: Dictionary, keep_selection: String) -> void:
	selected_id = keep_selection
	refresh(snapshot)

func refresh(snapshot: Dictionary) -> void:
	view = snapshot
	var ids: Array = view.records.map(func(record: Dictionary) -> String: return record.id)
	if selected_id not in ids:
		selected_id = ids.back() if not ids.is_empty() else ""
	_render()

func _render() -> void:
	for container: VBoxContainer in [list, detail]:
		for child: Node in container.get_children():
			child.queue_free()
	for record: Dictionary in view.records:
		var title_text := I18n.t("dossier.record_title", {"name": record.name, "day": record.day})
		if record.reported_to != "":
			title_text += I18n.t("dossier.reported_marker")
		var entry := Button.new()
		entry.text = title_text
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.custom_minimum_size = Vector2(0, 52)
		if record.id == selected_id:
			entry.theme_type_variation = &"PrimaryButton"
		entry.pressed.connect(func() -> void: selected_id = record.id; _render())
		list.add_child(entry)
	var current: Dictionary = {}
	for record: Dictionary in view.records:
		if record.id == selected_id:
			current = record
	if current.is_empty():
		_line(detail, I18n.t("dossier.empty"))
		return
	var photo := TextureRect.new()
	photo.custom_minimum_size = Vector2(128, 176)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait: Dictionary = current.get("portrait", {})
	for path: String in [str(portrait.get("portrait_texture", "")), PORTRAIT_PATH % portrait.get("portrait_id", ""), PORTRAIT_PATH % current.get("character", "")]:
		if path.ends_with(".png") and ResourceLoader.exists(path):
			photo.texture = load(path)
			break
	detail.add_child(photo)
	_line(detail, current.name, 34)
	_line(detail, I18n.t("dossier.observation"), 18)
	_line(detail, current.appearance)
	_line(detail, I18n.t("dossier.record"), 18)
	_line(detail, current.dossier)
	var guess: String = {"unknown": I18n.t("dossier.guess_unknown"), "human": I18n.t("dossier.guess_human"), "fallen": I18n.t("dossier.guess_fallen")}.get(current.guess, I18n.t("common.unavailable"))
	_line(detail, I18n.t("dossier.guess", {"guess": guess}), 20)
	var can_report: bool = view.stage == "decision" and view.phase in ["morning_supplier", "night_supplier"] and current.reported_to == ""
	if current.reported_to != "":
		_line(detail, I18n.t("dossier.reported_to_defne" if current.reported_to == "human" else "dossier.reported_to_vey"))
	elif can_report:
		var recipient := I18n.t("dossier.defne_request") if view.phase == "morning_supplier" else I18n.t("dossier.vey_request")
		var report := Button.new()
		report.theme_type_variation = &"PrimaryButton"
		report.text = I18n.t("button.report", {"recipient": recipient.replace("\n", " ")})
		report.custom_minimum_size = Vector2(0, 60)
		report.pressed.connect(func() -> void: EventBus.request("report", {"id": current.id}))
		detail.add_child(report)
	else:
		_line(detail, I18n.t("dossier.delivery_only"), 20)

func _line(parent: Control, content: String, font_size: int = 24) -> void:
	var label := Label.new()
	label.theme_type_variation = &"PhoneText"
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
