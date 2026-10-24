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
	var pools: Dictionary = catalog.pools
	var order: Variant
	var request: String = ""
	var db: Dictionary = pools.get("order_database", {})
	if not db.is_empty():
		var built := _compose_dynamic_order(period, person.species, rng, pools, db)
		if not built.is_empty():
			order = built.order
			request = built.request
	if request == "":
		var stat_orders: Array = pools.get("stat_orders", {}).get(person.species, [])
		if not stat_orders.is_empty() and rng.randf() < float(pools.get("stat_order_chance", 0.0)):
			order = stat_orders[rng.randi_range(0, stat_orders.size() - 1)].duplicate(true)
			request = _describe_stats(order.stats, pools)
		else:
			var product := Products.draw(person.species, rng, catalog.recipes)
			if product.is_empty():
				return {}
			order = product.id
			request = pools.get("order_template", "Bir {drink} alabilir miyim?").format({"drink": product.name})
	var templates: Array = person.get("smalltalk", pools.get("default_smalltalk", ["..."]))
	var line: String = templates[rng.randi_range(0, templates.size() - 1)]
	var arrival := _pick_arrival(period, person.species, rng, pools)
	var dialogue: Array = []
	if arrival != "":
		dialogue.append(arrival)
	dialogue.append(line)
	dialogue.append(person.appearance)
	dialogue.append(request)
	return {"character": person.id, "person": person, "order": order, "kind": "random", "mandatory": false,
		"dialogue": dialogue, "order_line": request}

static func _pick_arrival(period: String, species: String, rng: RandomNumberGenerator, pools: Dictionary) -> String:
	var arrivals: Dictionary = pools.get("arrival_lines", {})
	var key := "night_fallen" if species == "fallen" else ("night_human" if period == "night" else "day_human")
	var list: Array = arrivals.get(key, [])
	if list.is_empty():
		return ""
	return str(list[rng.randi_range(0, list.size() - 1)])

static func _compose_dynamic_order(period: String, species: String, rng: RandomNumberGenerator, pools: Dictionary, db: Dictionary) -> Dictionary:
	var pool_key := "human"
	var hook_key := "human_night" if period == "night" else "human_day"
	if species == "fallen":
		var use_hybrid := rng.randf() < 0.60
		pool_key = "fallen_hybrid" if use_hybrid else "fallen_pure"
		hook_key = pool_key
	var entries: Array = db.get(pool_key, [])
	if entries.is_empty():
		return {}
	var entry: Dictionary = entries[rng.randi_range(0, entries.size() - 1)]
	var lines: Array = entry.get("lines", [])
	if lines.is_empty():
		return {}
	var craving: String = str(lines[rng.randi_range(0, lines.size() - 1)])
	var hooks: Array = pools.get("order_hooks", {}).get(hook_key, [])
	var closers: Array = pools.get("order_closers", {}).get(species, [])
	var parts: Array[String] = []
	if not hooks.is_empty():
		parts.append(str(hooks[rng.randi_range(0, hooks.size() - 1)]))
	parts.append(craving)
	if not closers.is_empty():
		parts.append(str(closers[rng.randi_range(0, closers.size() - 1)]))
	return {"order": entry.get("order", {}).duplicate(true), "request": " ".join(parts)}

## {"warm": 2, "sweet": 1} → "sıcak ve biraz tatlı bir şey alabilir miyim?"
static func _describe_stats(wanted: Dictionary, pools: Dictionary) -> String:
	var words: Array[String] = []
	for stat: String in wanted:
		var options: Array = pools.stat_words.get(stat, [stat, stat, stat])
		words.append(str(options[clampi(int(wanted[stat]), 1, 3) - 1]))
	var text: String = str(pools.order_stat_template).format({"stats": str(pools.get("stat_join", ", ")).join(words)})
	return text.substr(0, 1).to_upper() + text.substr(1)
