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
	var order: Variant
	var request: String
	var stat_orders: Array = catalog.pools.get("stat_orders", {}).get(person.species, [])
	if not stat_orders.is_empty() and rng.randf() < float(catalog.pools.get("stat_order_chance", 0.0)):
		order = stat_orders[rng.randi_range(0, stat_orders.size() - 1)].duplicate(true)
		request = _describe_stats(order.stats, catalog.pools)
	else:
		var product := Products.draw(person.species, rng, catalog.recipes)
		if product.is_empty():
			return {}
		order = product.id
		var hint_phrase: String = ""
		if product.has("description"):
			var desc: String = product.description
			var dot_idx := desc.find(". ")
			if dot_idx != -1:
				hint_phrase = desc.substr(dot_idx + 2).strip_edges().trim_suffix(".")
		if not hint_phrase.is_empty() and catalog.pools.has("order_template_hint"):
			request = catalog.pools.order_template_hint.format({"drink": product.name, "hint": hint_phrase})
		else:
			request = catalog.pools.order_template.format({"drink": product.name})
	var templates: Array = person.get("smalltalk", catalog.pools.default_smalltalk)
	var line: String = templates[rng.randi_range(0, templates.size() - 1)]
	return {"character": person.id, "person": person, "order": order, "kind": "random", "mandatory": false,
		"dialogue": [request, line, person.appearance]}

## {"warm": 2, "sweet": 1} → "sıcak ve biraz tatlı bir şey alabilir miyim?"
static func _describe_stats(wanted: Dictionary, pools: Dictionary) -> String:
	var words: Array[String] = []
	for stat: String in wanted:
		var options: Array = pools.stat_words.get(stat, [stat, stat, stat])
		words.append(str(options[clampi(int(wanted[stat]), 1, 3) - 1]))
	var text: String = str(pools.order_stat_template).format({"stats": str(pools.get("stat_join", ", ")).join(words)})
	return text.substr(0, 1).to_upper() + text.substr(1)
