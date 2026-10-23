extends Control
const UI = preload("res://presentation/ui/ui.gd")
const Portrait = preload("res://presentation/art/portrait_view.gd")
var view: Dictionary
var on_close: Callable
var selected_id: String = ""

func setup(snapshot: Dictionary, close_callback: Callable) -> void:
	view = snapshot
	on_close = close_callback
	if not view.records.is_empty():
		selected_id = view.records.back().id
	_render()

func _render() -> void:
	UI.clear(self)
	UI.box(self, Rect2(0, 0, 1440, 900), Color(0.035, 0.03, 0.05, 0.96), Color.TRANSPARENT)
	UI.box(self, Rect2(102, 78, 1236, 744), Color("211f2b"), Color("726778"))
	UI.label(self, I18n.t("dossier.eyebrow"), Rect2(138, 104, 650, 26), 15, UI.GOLD, UI.MONO)
	UI.label(self, I18n.t("dossier.title"), Rect2(138, 147, 980, 65), 43, UI.INK, UI.ITALIC)
	UI.label(self, I18n.t("dossier.instructions"), Rect2(138, 219, 1110, 50), 20, UI.MUTED, UI.BODY, true)
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.position = Vector2(138, 299)
	scroll.size = Vector2(337, 410)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	for record: Dictionary in view.records:
		var title := I18n.t("dossier.record_title", {"name": record.name, "day": record.day})
		if record.reported_to != "":
			title += I18n.t("dossier.reported_marker")
		var entry := UI.button(list, title, Rect2(0, 0, 310, 52), func() -> void: selected_id = record.id; _render(), record.id == selected_id)
		entry.custom_minimum_size = Vector2(310, 52)
	var current: Dictionary = {}
	for record: Dictionary in view.records:
		if record.id == selected_id:
			current = record
	if current.is_empty():
		UI.label(self, I18n.t("dossier.empty"), Rect2(531, 325, 697, 130), 28, UI.INK, UI.TITLE, true)
	else:
		_draw_record(current)
	UI.button(self, I18n.t("button.close_dossier"), Rect2(1000, 746, 295, 43), on_close)

func _draw_record(record: Dictionary) -> void:
	var photo := Portrait.new()
	add_child(photo)
	photo.position = Vector2(1192, 287)
	photo.size = Vector2(66, 79)
	photo.setup(record.get("portrait", {}))
	UI.label(self, record.name, Rect2(529, 294, 670, 55), 42, UI.INK, UI.TITLE)
	UI.label(self, I18n.t("dossier.observation"), Rect2(531, 365, 650, 25), 14, UI.GOLD, UI.MONO)
	UI.label(self, record.appearance, Rect2(531, 398, 687, 74), 22, UI.INK, UI.BODY, true)
	UI.label(self, I18n.t("dossier.record"), Rect2(531, 491, 650, 25), 14, UI.GOLD, UI.MONO)
	UI.label(self, record.dossier, Rect2(531, 525, 687, 70), 22, UI.INK, UI.BODY, true)
	var guess: String = {"unknown": I18n.t("dossier.guess_unknown"), "human": I18n.t("dossier.guess_human"), "fallen": I18n.t("dossier.guess_fallen")}.get(record.guess, I18n.t("common.unavailable"))
	UI.label(self, I18n.t("dossier.guess", {"guess": guess}), Rect2(531, 610, 710, 30), 17, UI.MUTED, UI.BODY)
	var can_report: bool = view.stage == "decision" and view.phase in ["morning_supplier", "night_supplier"] and record.reported_to == ""
	if record.reported_to != "":
		UI.label(self, I18n.t("dossier.reported_to_defne" if record.reported_to == "human" else "dossier.reported_to_vey"), Rect2(531, 666, 685, 47), 20, UI.PINK)
	elif can_report:
		var recipient := I18n.t("dossier.defne_request") if view.phase == "morning_supplier" else I18n.t("dossier.vey_request")
		UI.button(self, I18n.t("button.report", {"recipient": recipient}), Rect2(531, 662, 720, 50), func() -> void: EventBus.request("report", {"id": record.id}), true)
	else:
		UI.label(self, I18n.t("dossier.delivery_only"), Rect2(531, 666, 705, 50), 18, UI.MUTED, UI.BODY, true)
