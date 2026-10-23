@tool
extends RefCounted
## Editör için örnek görüntü verisi. Oturum başlatmaz, RNG ve kayıt kullanmaz.
const Content = preload("res://infrastructure/content/content_repository.gd")
const UI = preload("res://presentation/ui/ui.gd")

static func build(screen: String, character_id: String = "ada") -> Dictionary:
	var content := Content.new()
	content.translate = UI.text
	content.load_all()
	var person: Dictionary = content.characters.get(character_id, content.characters.get("ada", {})).duplicate(true)
	person.erase("species")
	person.erase("dossier")
	var stock: Dictionary = {}
	for ingredient: Dictionary in content.ingredients:
		stock[ingredient.id] = 10
	var view := {
		"started": screen != "intro", "has_save": false, "content_errors": content.errors,
		"mode": "story", "day": 2 if screen == "dossier" else 1,
		"total_days": content.days.size(), "phase": "night" if screen in ["night", "book_fallen"] else "day",
		"stage": "brewing", "shelf": "fallen" if screen in ["night", "book_fallen"] else "human",
		"tutorial": "ready" if screen != "intro" else "locked", "person": person,
		"line": UI.text("dialogue.brewing"), "recipes": content.recipes,
		"ingredients": content.ingredients, "stock": stock, "selected": [], "drink": {},
		"records": [], "served": 19, "ending": {}, "visit": {}, "notes": []
	}
	if screen == "dossier" and not person.is_empty():
		var identity: Dictionary = content.characters.get(character_id, content.characters.ada)
		view.records = [{"id": "preview", "character": identity.id, "name": identity.name,
			"day": 2, "dossier": identity.dossier, "appearance": identity.appearance,
			"guess": "unknown", "reported_to": "", "portrait": {
				"skin": identity.skin, "hair": identity.hair, "coat": identity.coat,
				"portrait_texture": identity.get("portrait_texture", "")}}]
	if screen == "fall":
		view.phase = "fall"
		view.stage = "transition"
	if screen == "ending":
		view.phase = "ending"
		view.ending = content.endings.get("fallen_world", {}).duplicate(true)
		view.ending["variant"] = "standard"
	return view
