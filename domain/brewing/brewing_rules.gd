class_name BrewingRules
extends RefCounted
## Saf kural: 1. slot baz, sonrakiler karışım. Tat değerleri slot başına okunur ve toplanır.
const STATS: Array[String] = ["warm", "cool", "sweet", "bitter"]
const SLOTS := 3
## Renk ağırlıkları: baz baskın, son ekleme yalnızca tonu kaydırır.
const COLOR_WEIGHTS: Array[float] = [2.0, 0.3, 0.1]

## "" uygunsa; aksi halde hata kodu: full, unknown, not_base, not_mix.
static func can_add(selected: Array, id: String, ingredients: Dictionary) -> String:
	if selected.size() >= SLOTS:
		return "full"
	if not ingredients.has(id):
		return "unknown"
	var ingredient: Dictionary = ingredients[id]
	if selected.is_empty():
		return "" if ingredient.get("base", false) else "not_base"
	if ingredient.get("mix", false) or id == selected[0]:
		return ""
	return "not_mix"

static func is_valid_sequence(sequence: Array, ingredients: Dictionary) -> bool:
	var built: Array = []
	for id: String in sequence:
		if can_add(built, id, ingredients) != "":
			return false
		built.append(id)
	return true

static func stats(selected: Array, ingredients: Dictionary) -> Dictionary:
	var total := {"warm": 0, "cool": 0, "sweet": 0, "bitter": 0}
	for slot in range(selected.size()):
		var ingredient: Dictionary = ingredients.get(selected[slot], {})
		for stat: String in STATS:
			var values: Array = ingredient.get("stats", {}).get(stat, [])
			if slot < values.size():
				total[stat] += int(values[slot])
	return total

static func tier(value: int) -> int:
	if value <= 0:
		return 0
	if value <= 3:
		return 1
	if value <= 5:
		return 2
	return 3

static func tiers(totals: Dictionary) -> Dictionary:
	var result := {}
	for stat: String in STATS:
		result[stat] = tier(int(totals.get(stat, 0)))
	return result

static func color(selected: Array, ingredients: Dictionary) -> Color:
	var sum := Color(0, 0, 0, 0)
	var weight := 0.0
	for slot in range(selected.size()):
		var value := Color(str(ingredients.get(selected[slot], {}).get("color", "ffffff")))
		sum += value * COLOR_WEIGHTS[slot]
		weight += COLOR_WEIGHTS[slot]
	if weight == 0.0:
		return Color.TRANSPARENT
	var mixed := sum / weight
	mixed.a = 1.0
	return mixed

## Baz aynı olmalı; karışım malzemelerinin sırası önemsiz, tekrarları önemli.
static func identify(selected: Array, recipes: Array) -> Dictionary:
	if selected.size() != SLOTS:
		return {}
	var mix := selected.slice(1)
	mix.sort()
	for recipe: Dictionary in recipes:
		var expected: Array = recipe.ingredients
		if expected.size() != SLOTS or expected[0] != selected[0]:
			continue
		var expected_mix := expected.slice(1)
		expected_mix.sort()
		if expected_mix == mix:
			return recipe.duplicate(true)
	return {}

## Coffee Talk kuralı: tarifli içecekte tarifin "latte_art" bayrağı belirler; tarifsizde "latte" malzemesi
## (süt) dizide ilk kez 2. ya da 3. yuvada geçmelidir. Süt bazdaysa sonraki sütler sayılmaz.
static func latte_art_allowed(selected: Array, ingredients: Dictionary, recipe: Dictionary) -> bool:
	if not recipe.is_empty():
		return bool(recipe.get("latte_art", false))
	for slot in range(selected.size()):
		if ingredients.get(selected[slot], {}).get("latte", false):
			return slot > 0
	return false

## names: drink.name_* şablonları (çeviri katmanından gelir, domain metin bilmez).
static func generated_name(selected: Array, ingredients: Dictionary, names: Dictionary) -> String:
	var base: String = ingredients[selected[0]].name
	var first: String = selected[1]
	var second: String = selected[2]
	var adjective := func(id: String) -> String: return str(ingredients[id].get("adjective", ingredients[id].name))
	if first == second:
		if first == selected[0]:
			return str(names.pure).format({"base": base})
		return str(names.double).format({"adj": adjective.call(first), "base": base})
	if first == selected[0] or second == selected[0]:
		var other := second if first == selected[0] else first
		return str(names.strong).format({"adj": adjective.call(other), "base": base})
	return str(names.mix).format({"first": adjective.call(first), "second": adjective.call(second), "base": base})

static func brew(selected: Array, ingredients: Dictionary, recipes: Array, names: Dictionary) -> Dictionary:
	if selected.size() != SLOTS or not is_valid_sequence(selected, ingredients):
		return {}
	var totals := stats(selected, ingredients)
	var recipe := identify(selected, recipes)
	var drink := recipe.duplicate() if not recipe.is_empty() else {"id": "custom", "name": generated_name(selected, ingredients, names)}
	drink["latte_art_allowed"] = latte_art_allowed(selected, ingredients, recipe)
	drink["latte_art"] = false
	drink["side"] = ingredients[selected[0]].side
	drink["ingredients"] = selected.duplicate()
	drink["stats"] = totals
	drink["tiers"] = tiers(totals)
	drink["color"] = color(selected, ingredients).to_html(false)
	return drink

static func can_consume(selected: Array, stock: Dictionary) -> bool:
	var needed: Dictionary = {}
	for ingredient: String in selected:
		needed[ingredient] = int(needed.get(ingredient, 0)) + 1
	for ingredient: String in needed:
		if int(stock.get(ingredient, 0)) < needed[ingredient]:
			return false
	return selected.size() == SLOTS

## Tarif kimliği (String) ya da {"stats": {...}} tat isteği. Tat isteği "latte_art": true/false da
## isteyebilir (Coffee Talk'taki latte_art kuralı: çizimin varlığı istenenle aynı olmalı).
static func matches_order(order: Variant, drink: Dictionary) -> bool:
	if drink.is_empty():
		return false
	if order is String:
		return drink.get("id", "") == order
	if order is Dictionary:
		if order.has("latte_art") and bool(order.latte_art) != bool(drink.get("latte_art", false)):
			return false
		var wanted: Dictionary = order.get("stats", {})
		var actual: Dictionary = drink.get("tiers", {})
		for stat: String in wanted:
			if int(actual.get(stat, 0)) < int(wanted[stat]):
				return false
		return not wanted.is_empty()
	return false

## İçerik doğrulama ve test için: bir siparişi karşılayan ilk geçerli diziyi bulur.
static func find_sequence(order: Variant, side: String, ingredients: Dictionary, recipes: Array) -> Array:
	if order is String:
		for recipe: Dictionary in recipes:
			if recipe.id == order:
				return recipe.ingredients.duplicate()
		return []
	var ids: Array = ingredients.keys().filter(func(id: String) -> bool: return ingredients[id].side == side)
	var wants_art: bool = order is Dictionary and bool(order.get("latte_art", false))
	for a: String in ids:
		for b: String in ids:
			for c: String in ids:
				var sequence := [a, b, c]
				if not is_valid_sequence(sequence, ingredients):
					continue
				var art := wants_art and latte_art_allowed(sequence, ingredients, identify(sequence, recipes))
				if matches_order(order, {"tiers": tiers(stats(sequence, ingredients)), "latte_art": art}):
					return sequence
	return []
