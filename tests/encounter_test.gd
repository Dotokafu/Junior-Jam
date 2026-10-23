extends SceneTree
const Director = preload("res://domain/encounters/encounter_director.gd")
var failures: int = 0

func _initialize() -> void:
	var content := ContentRepository.new()
	check(content.load_all(), "Katalog okunmalı")
	var catalog := content.catalog()
	var request := {"day": 2, "period": "night", "mode": "story", "seed": 12345}
	var first := Director.build_shift(request, catalog)
	check(first == Director.build_shift(request, catalog), "Aynı seed aynı vardiyayı üretmeli")
	var first_night := Director.build_shift({"day": 1, "period": "night", "seed": 9}, catalog)
	check(first_night[0].character == "eren" and first_night[0].mandatory, "İlk Fallen hikâye taşı ilk sırada kalmalı")
	var varied := false
	var humans := 0
	var fallen := 0
	for seed_value in range(100):
		request.seed = seed_value
		var shift := Director.build_shift(request, catalog)
		check(shift.any(func(visit: Dictionary) -> bool: return visit.character == "ada" and visit.mandatory), "Ada hikâye taşı kaybolmamalı")
		check(shift.any(func(visit: Dictionary) -> bool: return visit.character == "saye" and visit.mandatory), "Saye hikâye taşı kaybolmamalı")
		if shift != first:
			varied = true
		for visit: Dictionary in shift:
			if visit.kind != "random":
				continue
			var recipe: Dictionary = content.recipes.filter(func(item: Dictionary) -> bool: return item.id == visit.order)[0]
			check(recipe.side == visit.person.species, "Ürün doğru tür havuzundan seçilmeli")
			check(visit.person.has("portrait_id"), "Görünüş ayrı havuzdan gelmeli")
			if visit.person.species == "human":
				humans += 1
			else:
				fallen += 1
	check(varied and humans > 20 and fallen > 20, "Farklı seedler iki türü de üretmeli")
	var endless := Director.build_shift({"day": 23, "period": "night", "mode": "endless", "seed": 42}, catalog)
	check(endless.size() == 4 and endless.all(func(visit: Dictionary) -> bool: return visit.kind == "random"), "Endless sınırsız gün üretmeli")
	var daytime := Director.build_shift({"day": 8, "period": "day", "mode": "endless", "seed": 42}, catalog)
	check(daytime.size() == 3 and daytime.all(func(visit: Dictionary) -> bool: return visit.person.species == "human"), "Rastgele gündüz havuzu insan olmalı")
	print("ENCOUNTERS: ", "PASS" if failures == 0 else "FAIL", " (", humans, " insan / ", fallen, " Fallen)")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
