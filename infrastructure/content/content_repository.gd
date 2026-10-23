class_name ContentRepository
extends RefCounted
## İçerik sınırı. JSON dosyaları yalnızca burada okunur ve doğrulanır.
var ingredients: Array = []
var recipes: Array = []
var characters: Dictionary = {}
var days: Array = []
var endings: Dictionary = {}
var ending_rules: Dictionary = {}
var pools: Dictionary = {}
var errors: Array[String] = []
var translate: Callable

func _message(key: String) -> String:
	return str(translate.call(key)) if translate.is_valid() else "[" + key + "] "

func load_all() -> bool:
	var items := _read("ingredients")
	var drinks := _read("recipes")
	var cast := _read("characters")
	var shifts := _read("days")
	var outcomes := _read("endings")
	pools = _read("encounter_pools")
	ingredients = items.get("ingredients", [])
	recipes = drinks.get("recipes", [])
	days = shifts.get("days", [])
	endings = outcomes.get("endings", {})
	ending_rules = outcomes.get("rules", {})
	for person: Dictionary in cast.get("characters", []):
		if characters.has(person.id):
			errors.append(_message("error.duplicate_character") + str(person.id))
		characters[person.id] = person
	var ingredient_ids: Array = ingredients.map(func(item: Dictionary) -> String: return item.id)
	var recipe_ids: Array = []
	for recipe: Dictionary in recipes:
		recipe_ids.append(recipe.id)
		if recipe.ingredients.size() != 3:
			errors.append(_message("error.recipe_size") + str(recipe.id))
		for ingredient: String in recipe.ingredients:
			if ingredient not in ingredient_ids:
				errors.append(_message("error.unknown_ingredient") + ingredient)
	for day: Dictionary in days:
		for period: String in ["day", "night"]:
			if day.get(period, []).is_empty():
				errors.append(_message("error.empty_shift") + str(day.get("number", "?")))
			for visit: Dictionary in day.get(period, []):
				if not characters.has(visit.character) or visit.order not in recipe_ids:
					errors.append(_message("error.invalid_visit") + str(visit))
	if days.is_empty() or ingredients.is_empty() or recipes.is_empty() or endings.size() != 5:
		errors.append(_message("error.missing_content"))
	for side: String in ["human", "fallen", "portraits"]:
		if pools.get(side, []).is_empty():
			errors.append(_message("error.empty_pool") + side)
		for id: String in pools.get(side, []):
			if not characters.has(id):
				errors.append(_message("error.unknown_character") + id)
			elif side != "portraits" and characters[id].species != side:
				errors.append(_message("error.wrong_species_pool") + id)
	return errors.is_empty()

func catalog() -> Dictionary:
	return {"characters": characters, "recipes": recipes, "days": days, "pools": pools}

func _read(file_name: String) -> Dictionary:
	var path := "res://content/" + file_name + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append(_message("error.file_read") + path)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		errors.append(_message("error.invalid_json") + path + ": " + parser.get_error_message())
		return {}
	return parser.data
