class_name BrewingRules
extends RefCounted
## Saf kural: üç malzemenin sırası önemli değil, tekrarları önemlidir.
static func identify(ingredients: Array, recipes: Array) -> Dictionary:
	if ingredients.size() != 3:
		return {}
	var chosen := ingredients.duplicate()
	chosen.sort()
	for recipe: Dictionary in recipes:
		var expected: Array = recipe.ingredients.duplicate()
		expected.sort()
		if chosen == expected:
			return recipe.duplicate(true)
	return {}

static func can_consume(ingredients: Array, stock: Dictionary) -> bool:
	var needed: Dictionary = {}
	for ingredient: String in ingredients:
		needed[ingredient] = int(needed.get(ingredient, 0)) + 1
	for ingredient: String in needed:
		if int(stock.get(ingredient, 0)) < needed[ingredient]:
			return false
	return ingredients.size() == 3
