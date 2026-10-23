class_name CustomerPool
extends RefCounted
## Önce tür, sonra karakter, ardından görünüş. Görünüş gerçek türü belirlemez.
static func draw(period: String, rng: RandomNumberGenerator, catalog: Dictionary, excluded: Array = []) -> Dictionary:
	var pools: Dictionary = catalog.pools
	var chance: float = float(pools.get("fallen_chance_at_night", 0.5)) if period == "night" else 0.0
	var species := "fallen" if rng.randf() < chance else "human"
	var candidates: Array = pools.get(species, []).filter(func(id: String) -> bool: return id not in excluded)
	if candidates.is_empty():
		candidates = pools.get(species, []).duplicate()
	if candidates.is_empty():
		return {}
	var id: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var character: Dictionary = catalog.characters[id].duplicate(true)
	var portraits: Array = pools.get("portraits", [])
	if not portraits.is_empty():
		var visual_rng := RandomNumberGenerator.new()
		visual_rng.seed = int(catalog.get("appearance_seed", 0)) + id.hash()
		var portrait_id: String = portraits[visual_rng.randi_range(0, portraits.size() - 1)]
		var portrait: Dictionary = catalog.characters[portrait_id]
		character["portrait_id"] = portrait_id
		for field: String in ["skin", "hair", "coat"]:
			character[field] = portrait[field]
		character["portrait_texture"] = portrait.get("portrait_texture", "")
	return character
