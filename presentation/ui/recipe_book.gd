extends Control
const UI = preload("res://presentation/ui/ui.gd")
var view: Dictionary
var page: String = "human"
var on_close: Callable

func setup(snapshot: Dictionary, close_callback: Callable, selected_page: String) -> void:
	view = snapshot
	on_close = close_callback
	page = selected_page
	_render()

func _render() -> void:
	UI.clear(self)
	UI.box(self, Rect2(0, 0, 1440, 900), Color(0.035, 0.026, 0.05, 0.94), Color.TRANSPARENT)
	var dark := page == "fallen"
	var paper := Color("30232f") if dark else Color("d6c6a4")
	var ink := Color("d7b7bf") if dark else Color("463b36")
	var faded := Color("a38691") if dark else Color("807160")
	UI.box(self, Rect2(106, 78, 1228, 744), Color("18151e"), Color("756151"))
	UI.box(self, Rect2(124, 96, 590, 708), paper, paper)
	UI.box(self, Rect2(718, 96, 598, 708), paper.darkened(0.025), paper)
	UI.box(self, Rect2(711, 97, 9, 706), paper.darkened(0.15), paper.darkened(0.15))
	UI.label(self, I18n.t("book.eyebrow"), Rect2(158, 120, 460, 24), 14, faded, UI.MONO)
	UI.label(self, I18n.t("book.fallen_title") if dark else I18n.t("book.human_title"), Rect2(158, 164, 500, 70), 44, ink, UI.ITALIC)
	UI.label(self, I18n.t("book.instructions"), Rect2(158, 248, 494, 80), 21, ink, UI.BODY, true)
	UI.label(self, I18n.t("book.fallen_quote") if dark else I18n.t("book.human_quote"), Rect2(158, 366, 484, 118), 32, ink, UI.ITALIC, true)
	UI.label(self, I18n.t("book.fallen_note" if dark else "book.human_note"), Rect2(158, 602, 492, 94), 19, faded, UI.BODY, true)
	UI.label(self, I18n.t("book.fallen_page") if dark else I18n.t("book.human_page"), Rect2(158, 744, 460, 28), 14, faded, UI.MONO)
	var recipes: Array = view.recipes.filter(func(recipe: Dictionary) -> bool: return recipe.side == page)
	for i in range(recipes.size()):
		var recipe: Dictionary = recipes[i]
		var y := 142 + i * 145
		UI.label(self, "%02d" % (i + 1), Rect2(758, y, 40, 35), 14, faded, UI.MONO)
		UI.label(self, recipe.name, Rect2(809, y - 8, 448, 46), 32, ink, UI.TITLE)
		var names: Array[String] = []
		for id: String in recipe.ingredients:
			for ingredient: Dictionary in view.ingredients:
				if ingredient.id == id:
					names.append(ingredient.name)
		UI.label(self, I18n.t("format.ingredient_join").join(names), Rect2(809, y + 39, 442, 28), 20, ink, UI.BODY)
		UI.label(self, recipe.description, Rect2(809, y + 72, 440, 55), 17, faded, UI.BODY, true)
	UI.button(self, I18n.t("book.human_tab"), Rect2(1334, 128, 94, 52), func() -> void: _change_page("human"))
	if view.tutorial != "locked":
		UI.button(self, I18n.t("book.hidden_tab") if view.tutorial == "book_hint" else I18n.t("transition.fall_title"), Rect2(1334, 192, 94, 64), func() -> void: _change_page("fallen"), true)
	UI.button(self, I18n.t("button.close_book"), Rect2(1037, 746, 249, 42), on_close)

func _change_page(target: String) -> void:
	page = target
	if target == "fallen":
		EventBus.request("book_tab")
	_render()
