extends Control
## Tarif defteri (yer tutucu). Sol sayfa raf, sağ sayfa tarifler. Gece sekmesi öğreticiyle açılır.
signal closed
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
var view: Dictionary = {}
var page: String = "human"
@onready var left_page: VBoxContainer = $Book/LeftPage/Box
## Tarifler çoğaldıkça sağ sayfa kaydırılır.
@onready var right_page: VBoxContainer = $Book/RightPage/Scroll/Box
@onready var human_tab: Button = $Tabs/HumanTab
@onready var fallen_tab: Button = $Tabs/FallenTab
@onready var close_button: Button = $CloseButton

func _ready() -> void:
	human_tab.pressed.connect(func() -> void: _change_page("human"))
	fallen_tab.pressed.connect(func() -> void: _change_page("fallen"))
	close_button.pressed.connect(func() -> void: closed.emit())
	close_button.text = I18n.t("button.close_book")
	human_tab.text = I18n.t("book.human_tab")

func open(snapshot: Dictionary, start_page: String) -> void:
	page = start_page if snapshot.tutorial != "locked" else "human"
	refresh(snapshot)

func refresh(snapshot: Dictionary) -> void:
	view = snapshot
	fallen_tab.visible = view.tutorial != "locked"
	fallen_tab.text = I18n.t("book.hidden_tab") if view.tutorial == "book_hint" else I18n.t("transition.fall_title")
	fallen_tab.theme_type_variation = &"PrimaryButton" if view.tutorial == "book_hint" else &""
	_render()

func _change_page(target: String) -> void:
	page = target
	if target == "fallen":
		EventBus.request("book_tab")
	_render()

func _render() -> void:
	for container: VBoxContainer in [left_page, right_page]:
		for child: Node in container.get_children():
			child.queue_free()
	var dark := page == "fallen"
	_text(left_page, I18n.t("book.eyebrow"), 20, true)
	_text(left_page, I18n.t("book.fallen_title" if dark else "book.human_title"), 48)
	_text(left_page, I18n.t("book.instructions"), 22)
	_text(left_page, I18n.t("book.ingredients_title"), 26, true)
	for item: Dictionary in view.get("ingredients", []):
		if item.side == page:
			var role := I18n.t("book.base_tag") if item.get("base", false) else I18n.t("book.mix_tag")
			if item.get("base", false) and item.get("mix", false):
				role = I18n.t("book.both_tag")
			_text(left_page, "%s — %s · %s" % [item.name, role, item.description], 22)
	_text(left_page, I18n.t("book.fallen_note" if dark else "book.human_note"), 20, true)
	_text(right_page, I18n.t("book.recipes_title"), 26, true)
	var names := {}
	for item: Dictionary in view.get("ingredients", []):
		names[item.id] = item.name
	if not view.get("recipes", []).any(func(recipe: Dictionary) -> bool: return recipe.side == page):
		_text(right_page, I18n.t("book.no_recipes"), 22, true)
	for recipe: Dictionary in view.get("recipes", []):
		if recipe.side != page:
			continue
		_text(right_page, recipe.name, 34)
		_text(right_page, I18n.t("format.ingredient_join").join(recipe.ingredients.map(func(id: String) -> String: return names.get(id, id))), 22)
		_text(right_page, recipe.description, 20, true)
	_text(right_page, I18n.t("book.fallen_page" if dark else "book.human_page"), 20, true)

func _text(parent: Control, content: String, font_size: int, faded: bool = false) -> void:
	var label := Label.new()
	label.theme_type_variation = &"BookText"
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if faded:
		label.modulate = Color(1, 1, 1, 0.65)
	parent.add_child(label)
