class_name BrewingRules
extends RefCounted
## Saf kural: 1. slot baz, sonrakiler karışım. Tat değerleri slot başına okunur ve toplanır.
const STATS: Array[String] = ["warm", "cool", "sweet", "bitter"]
const SLOTS := 3
const FALLEN_IDS: Array[String] = ["blood", "marrow", "ash", "tissue", "bile", "salt"]
## Renk ağırlıkları: baz baskın, son ekleme yalnızca tonu kaydırır.
const COLOR_WEIGHTS: Array[float] = [2.0, 0.3, 0.1]
const DEFAULT_ART_COLOR := "ffffff"

## "" uygunsa; aksi halde hata kodu: full, unknown, not_base, not_mix.
## Aynı raftan iki farklı saf baz (ör. kahve+matcha veya kan+doku) aynı fincana konulamaz;
## ancak melez içecekler için bir insan bazı ile bir fallen bazı (ör. kahve+kan) birleştirilebilir.
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
	if ingredient.get("base", false):
		var side: String = str(ingredient.get("side", ""))
		var first_side: String = str(ingredients.get(selected[0], {}).get("side", ""))
		var has_same_side_base := selected.any(func(s: String) -> bool:
			var item: Dictionary = ingredients.get(s, {})
			return str(item.get("side", "")) == side and bool(item.get("base", false)) and not bool(item.get("mix", false))
		)
		if side != first_side and not has_same_side_base:
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

## Malzemeler hangi sırayla eklenirse eklensin (ör. çay-nane-limon veya çay-limon-nane)
## aynı 3 malzeme eşleşen tarifi oluşturur; sıralama farkı tarifi bozmaz.
static func identify(selected: Array, recipes: Array) -> Dictionary:
	if selected.size() != SLOTS:
		return {}
	var sorted_selected := selected.duplicate()
	sorted_selected.sort()
	for recipe: Dictionary in recipes:
		var sorted_recipe: Array = recipe.ingredients.duplicate()
		sorted_recipe.sort()
		if sorted_recipe == sorted_selected:
			return recipe.duplicate(true)
	return {}

## Latte art için son koyulan malzeme "latte" malzemesi (süt, ilik) olmalı: köpük en üstte kalır.
## Taban dahil başka yuvadaki süt sayılmaz; tarif fark etmez.
static func latte_art_allowed(selected: Array, ingredients: Dictionary) -> bool:
	return not selected.is_empty() and bool(ingredients.get(selected[-1], {}).get("latte", false))

## Latte art'ta dökülen köpüğün rengi: son koyulan "latte" malzemesinin art_color'ı (ör. ilik),
## yoksa beyaz süt köpüğü.
static func art_color(selected: Array, ingredients: Dictionary) -> String:
	if latte_art_allowed(selected, ingredients):
		return str(ingredients[selected[-1]].get("art_color", DEFAULT_ART_COLOR))
	return DEFAULT_ART_COLOR

## names: drink.name_* şablonları (çeviri katmanından gelir, domain metin bilmez).
static func generated_name(selected: Array, ingredients: Dictionary, names: Dictionary) -> String:
	var base: String = ingredients[selected[0]].name
	var mixes := [selected[1], selected[2]]
	mixes.sort()
	var first: String = mixes[0]
	var second: String = mixes[1]
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
	drink["latte_art_allowed"] = latte_art_allowed(selected, ingredients)
	drink["latte_art"] = false
	drink["art_color"] = art_color(selected, ingredients)
	if not recipe.is_empty():
		drink["side"] = str(recipe.get("side", ingredients[selected[0]].side))
	else:
		var has_fallen: bool = selected.any(func(id: String) -> bool: return ingredients.get(id, {}).get("side", "") == "fallen")
		drink["side"] = "fallen" if has_fallen else str(ingredients[selected[0]].side)
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

## Tarif kimliği (String) ya da esnek sipariş sözlüğü (stats, must_have, any_of, hybrid, pure_fallen, recipe, recipes, latte_art).
static func matches_order(order: Variant, drink: Dictionary) -> bool:
	if drink.is_empty():
		return false
	if order is String:
		return drink.get("id", "") == order
	if order is Dictionary:
		if order.has("latte_art") and bool(order.latte_art) != bool(drink.get("latte_art", false)):
			return false
		var drink_id: String = str(drink.get("id", ""))
		if order.has("recipe") and str(order.recipe) != "" and drink_id == str(order.recipe):
			return true
		if order.has("recipes") and order.recipes is Array and drink_id in order.recipes:
			return true
		var drink_ings: Array = drink.get("ingredients", [])
		var has_criteria := false
		if order.has("must_have") and order.must_have is Array:
			var must_have: Array = order.must_have
			if not must_have.is_empty():
				has_criteria = true
				for req_id: String in must_have:
					if req_id not in drink_ings:
						return false
		if order.has("any_of") and order.any_of is Array:
			var any_of: Array = order.any_of
			if not any_of.is_empty():
				has_criteria = true
				if not any_of.any(func(req_id: String) -> bool: return req_id in drink_ings):
					return false
		if bool(order.get("pure_fallen", false)):
			has_criteria = true
			if drink_ings.is_empty() or not drink_ings.all(func(id: String) -> bool: return id in FALLEN_IDS):
				return false
		if bool(order.get("hybrid", false)):
			has_criteria = true
			var has_f := drink_ings.any(func(id: String) -> bool: return id in FALLEN_IDS)
			var has_h := drink_ings.any(func(id: String) -> bool: return id not in FALLEN_IDS)
			if not (has_f and has_h):
				return false
		var wanted: Dictionary = order.get("stats", {})
		if not wanted.is_empty():
			has_criteria = true
			var actual: Dictionary = drink.get("tiers", {})
			for stat: String in wanted:
				if int(actual.get(stat, 0)) < int(wanted[stat]):
					return false
		return has_criteria
	return false

## İçerik doğrulama ve test için: bir siparişi karşılayan ilk geçerli diziyi bulur.
static func find_sequence(order: Variant, side: String, ingredients: Dictionary, recipes: Array) -> Array:
	if order is String:
		for recipe: Dictionary in recipes:
			if recipe.id == order:
				return recipe.ingredients.duplicate()
		return []
	var wants_art: bool = order is Dictionary and bool(order.get("latte_art", false))
	if order is Dictionary and not wants_art:
		if order.has("recipe"):
			for recipe: Dictionary in recipes:
				if recipe.id == str(order.recipe) and recipe.get("side", "") == side:
					return recipe.ingredients.duplicate()
		for recipe: Dictionary in recipes:
			if recipe.get("side", "") != side:
				continue
			var seq: Array = recipe.ingredients
			var sim_drink := {"id": recipe.id, "side": side, "ingredients": seq, "tiers": tiers(stats(seq, ingredients)), "latte_art": false}
			if matches_order(order, sim_drink):
				return seq.duplicate()
	var ids: Array = ingredients.keys().filter(func(id: String) -> bool: return ingredients[id].side == "human") if side == "human" else ingredients.keys()
	for a: String in ids:
		for b: String in ids:
			for c: String in ids:
				var sequence := [a, b, c]
				if not is_valid_sequence(sequence, ingredients):
					continue
				if side == "fallen" and not sequence.any(func(id: String) -> bool: return ingredients.get(id, {}).get("side", "") == "fallen"):
					continue
				var art := wants_art and latte_art_allowed(sequence, ingredients)
				var matched_recipe := identify(sequence, recipes)
				var sim := {"id": matched_recipe.get("id", "custom"), "side": side, "ingredients": sequence, "tiers": tiers(stats(sequence, ingredients)), "latte_art": art}
				if matches_order(order, sim):
					return sequence
	return []
