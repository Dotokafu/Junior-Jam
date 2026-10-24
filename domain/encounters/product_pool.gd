class_name ProductPool
extends RefCounted
## Her türün ayrı ürün kutusu. Rastgele sipariş servis edilebilir bir tarif olmalıdır.
static func draw(species: String, rng: RandomNumberGenerator, recipes: Array) -> Dictionary:
	var options: Array = recipes.filter(func(recipe: Dictionary) -> bool: return recipe.side == species)
	if options.is_empty():
		return {}
	return options[rng.randi_range(0, options.size() - 1)].duplicate(true)
