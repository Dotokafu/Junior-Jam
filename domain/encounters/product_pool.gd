class_name ProductPool
extends RefCounted
## Her türün ayrı ürün kutusu. Fallen müşteriler hem melez (insan+fallen) hem de saf (yalnızca fallen) tarif isteyebilir.
static func draw(species: String, rng: RandomNumberGenerator, recipes: Array, mode: String = "any") -> Dictionary:
	var options: Array = recipes.filter(func(recipe: Dictionary) -> bool: return recipe.side == species)
	if options.is_empty():
		return {}
	if species == "fallen":
		var hybrids: Array = []
		var pures: Array = []
		for r: Dictionary in options:
			var ing: Array = r.get("ingredients", [])
			var has_human: bool = ing.any(func(id: String) -> bool: return id in ["coffee", "matcha", "cocoa", "tea", "milk", "cinnamon", "mint", "spice", "lemon", "honey"])
			var has_fallen: bool = ing.any(func(id: String) -> bool: return id in ["blood", "marrow", "ash", "tissue", "bile", "salt"])
			if has_human and has_fallen:
				hybrids.append(r)
			elif has_fallen:
				pures.append(r)
		if mode == "hybrid" and not hybrids.is_empty():
			return hybrids[rng.randi_range(0, hybrids.size() - 1)].duplicate(true)
		if mode == "pure" and not pures.is_empty():
			return pures[rng.randi_range(0, pures.size() - 1)].duplicate(true)
		if not hybrids.is_empty() and not pures.is_empty():
			var pool: Array = hybrids if rng.randf() < 0.55 else pures
			return pool[rng.randi_range(0, pool.size() - 1)].duplicate(true)
	return options[rng.randi_range(0, options.size() - 1)].duplicate(true)
