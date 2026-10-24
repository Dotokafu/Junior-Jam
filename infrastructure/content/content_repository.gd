class_name ContentRepository
extends RefCounted
## İçerik sınırı. JSON dosyaları yalnızca burada okunur ve doğrulanır.
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const MAX_QUESTIONS := 4
var ingredients: Array = []
var ingredient_map: Dictionary = {}
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
	_validate_ingredients()
	var recipe_ids := _validate_recipes()
	validate_visits(recipe_ids)
	validate_suspicion()
	if days.is_empty() or ingredients.is_empty() or recipes.is_empty() or endings.is_empty():
		errors.append(_message("error.missing_content"))
	for side: String in ["human", "fallen", "portraits"]:
		if pools.get(side, []).is_empty():
			errors.append(_message("error.empty_pool") + side)
		for id: String in pools.get(side, []):
			if not characters.has(id):
				errors.append(_message("error.unknown_character") + id)
			elif side != "portraits" and characters[id].species != side:
				errors.append(_message("error.wrong_species_pool") + id)
	for side: String in pools.get("stat_orders", {}):
		for order: Dictionary in pools.stat_orders[side]:
			if not _valid_order(order, side, recipe_ids):
				errors.append(_message("error.unreachable_order") + str(order))
	return errors.is_empty()

## Hikâye ziyaretleri: karakter, sipariş ve (varsa) sorgu alanları. Testler içeriği bozup tekrar çağırabilir.
func validate_visits(recipe_ids: Array = []) -> void:
	if recipe_ids.is_empty():
		recipe_ids = recipes.map(func(recipe: Dictionary) -> String: return recipe.id)
	for day: Dictionary in days:
		for period: String in ["day", "night"]:
			if day.get(period, []).is_empty():
				errors.append(_message("error.empty_shift") + str(day.get("number", "?")))
			for visit: Dictionary in day.get(period, []):
				if not characters.has(visit.character) or not _valid_order(visit.get("order"), characters[visit.character].species, recipe_ids):
					errors.append(_message("error.invalid_visit") + str(visit))
				elif not _valid_questions(visit):
					errors.append(_message("error.invalid_questions") + str(visit.character))

## Şüphe metinleri: her taraf için tavır satırları ve kapı notu (wary, threat), 2–4 cevaplı bir sorgu.
func validate_suspicion() -> void:
	for side: String in ["state", "order"]:
		for level: String in ["wary", "threat"]:
			var lines: Variant = pools.get("suspicion_lines", {}).get(side, {}).get(level, [])
			if not lines is Array or lines.is_empty() or str(pools.get("door_notes", {}).get(side, {}).get(level, "")) == "":
				errors.append(_message("error.invalid_suspicion") + side + "/" + level)
		var interrogation: Variant = pools.get("interrogations", {}).get(side, {})
		var answers: Variant = interrogation.get("answers", []) if interrogation is Dictionary else []
		if not interrogation is Dictionary or str(interrogation.get("line", "")) == "" or not answers is Array or answers.size() < 2 or answers.size() > MAX_QUESTIONS:
			errors.append(_message("error.invalid_suspicion") + side)
			continue
		for answer: Variant in answers:
			if not answer is Dictionary or str(answer.get("text", "")) == "" or str(answer.get("reply", "")) == "" or not (answer.get("effect") is float or answer.get("effect") is int):
				errors.append(_message("error.invalid_suspicion") + side)
				break

## questions: en fazla MAX_QUESTIONS; her soru havuzdaki bir kimlik ve boş olmayan cevap satırları.
func _valid_questions(visit: Dictionary) -> bool:
	if visit.has("order_line") and not visit.order_line is String:
		return false
	var questions: Variant = visit.get("questions", [])
	if not questions is Array or questions.size() > MAX_QUESTIONS:
		return false
	for question: Variant in questions:
		if not question is Dictionary or not pools.get("questions", {}).has(question.get("id", "")):
			return false
		var answer: Variant = question.get("answer", [])
		if not answer is Array or answer.is_empty():
			return false
	return true

func _validate_ingredients() -> void:
	for item: Dictionary in ingredients:
		ingredient_map[item.id] = item
		var item_stats: Dictionary = item.get("stats", {})
		for stat: String in Brewing.STATS:
			if item_stats.get(stat, []).size() != Brewing.SLOTS:
				errors.append(_message("error.ingredient_stats") + str(item.id))
				break

func _validate_recipes() -> Array:
	var recipe_ids: Array = []
	for recipe: Dictionary in recipes:
		recipe_ids.append(recipe.id)
		if recipe.ingredients.size() != Brewing.SLOTS:
			errors.append(_message("error.recipe_size") + str(recipe.id))
			continue
		var known := true
		for ingredient: String in recipe.ingredients:
			if not ingredient_map.has(ingredient):
				errors.append(_message("error.unknown_ingredient") + ingredient)
				known = false
		if known and not Brewing.is_valid_sequence(recipe.ingredients, ingredient_map):
			errors.append(_message("error.recipe_order") + str(recipe.id))
	return recipe_ids

func _valid_order(order: Variant, side: String, recipe_ids: Array) -> bool:
	if order is String:
		return order in recipe_ids
	if order is Dictionary and order.get("stats") is Dictionary:
		for stat: String in order.stats:
			if stat not in Brewing.STATS:
				return false
		return not Brewing.find_sequence(order, side, ingredient_map, recipes).is_empty()
	return false

func catalog() -> Dictionary:
	return {"characters": characters, "recipes": recipes, "days": days, "pools": pools, "ingredients": ingredient_map}

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
