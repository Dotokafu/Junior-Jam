class_name EncounterDirector
extends RefCounted
const Customers = preload("res://domain/encounters/customer_pool.gd")
const Products = preload("res://domain/encounters/product_pool.gd")
## Tek giriş noktası. Hikâye taşlarını korur, kalan yerleri üç havuzdan üretir.
## Aynı seed + gün + dönem + içerik → aynı ziyaretler. Global RNG kullanmaz.
static func build_shift(request: Dictionary, catalog: Dictionary) -> Array:
	var day := int(request.get("day", 1))
	var period: String = request.get("period", "night")
	var mode: String = request.get("mode", "story")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(request.get("seed", 0)) + day * 10007 + (7919 if period == "night" else 0)
	var run_catalog := catalog.duplicate()
	run_catalog["appearance_seed"] = int(request.get("seed", 0))
	var story: Array = []
	# Endless de aynı ilk gün öğreticisiyle başlar; sonra sınırsız üretime geçer.
	if mode == "story" or day == 1:
		if day <= catalog.days.size():
			story = catalog.days[day - 1].get(period, []).duplicate(true)
	for visit: Dictionary in story:
		visit["kind"] = "story"
		visit["mandatory"] = true
	var settings: Dictionary = catalog.pools.get("endless_visits" if mode == "endless" and day > 1 else "story_random_visits", {})
	var count: int = int(settings.get(period, 0))
	var result: Array = []
	var excluded: Array = story.map(func(visit: Dictionary) -> String: return visit.character)
	for i in range(maxi(story.size(), count)):
		# İlk sırada daima hikâye taşı vardır; rastgele müşteri öğreticiyi bölemez.
		if i < story.size():
			result.append(story[i])
		if i < count:
			var generated := _random_visit(period, rng, run_catalog, excluded)
			if not generated.is_empty():
				result.append(generated)
				excluded.append(generated.character)
	return result

static func _random_visit(period: String, rng: RandomNumberGenerator, catalog: Dictionary, excluded: Array) -> Dictionary:
	var person := Customers.draw(period, rng, catalog, excluded)
	if person.is_empty():
		return {}
	var product := Products.draw(person.species, rng, catalog.recipes)
	if product.is_empty():
		return {}
	var templates: Array = person.get("smalltalk", catalog.pools.default_smalltalk)
	var line: String = templates[rng.randi_range(0, templates.size() - 1)]
	return {"character": person.id, "person": person, "order": product.id, "kind": "random", "mandatory": false,
		"dialogue": [catalog.pools.order_template.format({"drink": product.name}), line, person.appearance]}
