extends Node
## Tek yazma noktası: sunum komut gönderir, uygulama domain kurallarını çalıştırır.
const State = preload("res://domain/shift/shift_state.gd")
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const Endings = preload("res://domain/consequences/ending_rules.gd")
const Content = preload("res://infrastructure/content/content_repository.gd")
const Saves = preload("res://infrastructure/persistence/save_repository.gd")
const Director = preload("res://domain/encounters/encounter_director.gd")
var content := Content.new()
var state := State.new()
var started: bool = false
var content_ok: bool = false
## Testler gerçek kullanıcının kaydını değiştirmeden aynı komutları çalıştırabilir.
var persistence_enabled: bool = true
## Kayıt kartlarının özeti; her yayında dosya okumamak için yalnızca kayıt değişince yenilenir.
var save_slots: Array = []

func _ready() -> void:
	content.translate = I18n.t
	content_ok = content.load_all()
	EventBus.command_requested.connect(_on_command)
	save_slots = Saves.summaries()
	if not content_ok:
		push_error("\n".join(content.errors))

func _on_command(action: String, payload: Dictionary) -> void:
	if not content_ok:
		EventBus.feedback.emit(I18n.t("error.content_prefix") + "; ".join(content.errors))
		return
	if action == "new_game":
		state = State.new()
		state.mode = "endless" if payload.get("mode", "story") == "endless" else "story"
		state.run_seed = int(payload.get("seed", Time.get_ticks_usec()))
		started = true
		_restock()
	elif action == "continue" or action == "load_slot":
		var slot := int(payload.get("slot", Saves.AUTO_SLOT)) if action == "load_slot" else Saves.AUTO_SLOT
		if not _load(slot):
			return
	elif action == "refresh":
		_publish()
		return
	elif action == "main_menu":
		# Her komuttan sonra otomatik kayıt yazıldığı için ilerleme kaybolmaz.
		started = false
		save_slots = Saves.summaries()
		_publish()
		return
	elif action == "save_slot":
		_save_slot(int(payload.get("slot", 1)))
		_publish()
		return
	elif not started or state.phase == "ending":
		return
	else:
		match action:
			"next": _next()
			"select": _select(str(payload.get("id", "")))
			"clear":
				if state.stage == "brewing":
					state.selected = []
					state.drink = {}
			"brew": _brew()
			"trash": _trash()
			"serve": _serve()
			"shelf": _switch_shelf()
			"book_tab":
				if state.tutorial == "book_hint":
					state.tutorial = "tab_seen"
			"book_closed":
				if state.tutorial == "tab_seen":
					state.tutorial = "switch_hint"
			"photo": _photograph()
			"report": _report(str(payload.get("id", "")))
	_publish()
	if not started or not persistence_enabled:
		return
	var saved := state.serialize()
	if Saves.write(saved):
		save_slots[Saves.AUTO_SLOT] = Saves.summary_for(Saves.AUTO_SLOT, saved, int(Time.get_unix_time_from_system()))
	else:
		EventBus.feedback.emit(I18n.t("error.save_write"))

func _load(slot: int) -> bool:
	var data := Saves.read(slot)
	if not _valid_save(data):
		EventBus.feedback.emit(I18n.t("error.incompatible_save"))
		return false
	state = State.restore(data)
	if state.phase in ["day", "night"] and state.visits.is_empty():
		state.visits = _generate_visits()
	started = true
	if slot != Saves.AUTO_SLOT:
		EventBus.feedback.emit(I18n.t("feedback.loaded", {"slot": slot}))
	return true

func _save_slot(slot: int) -> void:
	if not started or state.phase == "ending" or slot < 1 or slot > Saves.SLOT_COUNT:
		return
	if Saves.write(state.serialize(), slot):
		EventBus.feedback.emit(I18n.t("feedback.saved", {"slot": slot}))
	else:
		EventBus.feedback.emit(I18n.t("error.save_slot"))
	save_slots = Saves.summaries()

func _valid_save(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	if not data.get("day") is float and not data.get("day") is int:
		return false
	var day := int(data.day)
	if day < 1 or (data.get("mode", "story") != "endless" and day > content.days.size()):
		return false
	if data.get("phase", "") not in ["morning_supplier", "day", "fall", "night", "night_supplier", "dawn", "ending"]:
		return false
	if not data.get("stock") is Dictionary or not data.get("records") is Array:
		return false
	if data.phase in ["day", "night"]:
		var index := int(data.get("visit_index", -1))
		var visits: Array = data.get("visits", [])
		if index < 0 or index >= visits.size():
			return false
	return true

func _restock(side: String = "") -> void:
	for ingredient: Dictionary in content.ingredients:
		if side == "" or ingredient.side == side:
			state.stock[ingredient.id] = 10

func _visit() -> Dictionary:
	if state.phase not in ["day", "night"]:
		return {}
	if state.visit_index >= state.visits.size():
		return {}
	return state.visits[state.visit_index]

func _day_content() -> Dictionary:
	return content.days[mini(state.day - 1, content.days.size() - 1)]

func _generate_visits() -> Array:
	return Director.build_shift({"day": state.day, "period": state.phase, "mode": state.mode, "seed": state.run_seed}, content.catalog())

func _person() -> Dictionary:
	if state.phase == "morning_supplier":
		return content.characters.defne
	if state.phase == "night_supplier":
		return content.characters.vey
	var visit := _visit()
	if visit.has("person"):
		return visit.person
	return content.characters.get(visit.get("character", ""), {})

func _lines() -> Array:
	var day := _day_content()
	if state.phase == "morning_supplier":
		if state.mode == "endless" and state.day > 1:
			return content.pools.endless_morning
		return day.morning
	if state.phase == "night_supplier":
		if state.mode == "endless" and state.day > 1:
			return content.pools.endless_evening
		return day.evening
	return _visit().get("dialogue", [])

func _next() -> void:
	if state.phase == "fall":
		state.phase = "night"
		_reset_visit()
	elif state.phase == "dawn":
		state.day += 1
		state.phase = "morning_supplier"
		state.shelf = "human"
		_restock("human")
		_reset_visit()
	elif state.stage == "dialogue":
		state.line_index += 1
		if state.line_index >= _lines().size():
			if state.phase in ["morning_supplier", "night_supplier"]:
				state.stage = "decision"
			else:
				state.stage = "brewing"
	elif state.stage == "reaction":
		_advance_customer()
	elif state.stage == "decision":
		if state.phase == "morning_supplier":
			state.phase = "day"
			_reset_visit()
		elif state.phase == "night_supplier":
			_check_ending(state.mode == "story" and state.day == content.days.size())
			if state.phase != "ending":
				_restock("fallen")
				state.phase = "dawn"
				state.stage = "transition"

func _reset_visit() -> void:
	state.visit_index = 0
	state.line_index = 0
	state.stage = "dialogue"
	state.selected = []
	state.drink = {}
	state.visits = _generate_visits() if state.phase in ["day", "night"] else []

func _advance_customer() -> void:
	state.visit_index += 1
	state.line_index = 0
	state.stage = "dialogue"
	state.selected = []
	state.drink = {}
	if state.visit_index >= state.visits.size():
		state.visit_index = 0
		if state.phase == "day":
			state.phase = "fall"
			state.stage = "transition"
		else:
			state.phase = "night_supplier"
		state.visits = []

func _select(id: String) -> void:
	if state.stage != "brewing" or not state.drink.is_empty():
		return
	var ingredient: Dictionary = content.ingredient_map.get(id, {})
	if ingredient.is_empty() or ingredient.side != state.shelf:
		return
	if state.selected.count(id) >= int(state.stock.get(id, 0)):
		EventBus.feedback.emit(I18n.t("feedback.no_stock"))
		return
	var problem := Brewing.can_add(state.selected, id, content.ingredient_map)
	if problem in ["not_base", "not_mix"]:
		EventBus.feedback.emit(I18n.t("feedback." + problem, {"name": ingredient.name}))
		return
	if problem == "":
		state.selected.append(id)

func _drink_names() -> Dictionary:
	return {"pure": I18n.t("drink.name_pure"), "double": I18n.t("drink.name_double"),
		"strong": I18n.t("drink.name_strong"), "mix": I18n.t("drink.name_mix")}

func _brew() -> void:
	if state.stage != "brewing" or not state.drink.is_empty():
		return
	if not Brewing.can_consume(state.selected, state.stock):
		EventBus.feedback.emit(I18n.t("feedback.choose_three"))
		return
	var drink := Brewing.brew(state.selected, content.ingredient_map, content.recipes, _drink_names())
	if drink.is_empty():
		return
	for id: String in state.selected:
		state.stock[id] -= 1
	state.drink = drink
	EventBus.feedback.emit(I18n.t("feedback.drink_ready", {"drink": state.drink.name}))

## Demlenmiş fincanı döker; harcanan stok geri gelmez.
func _trash() -> void:
	if state.stage != "brewing" or state.drink.is_empty():
		return
	state.selected = []
	state.drink = {}
	EventBus.feedback.emit(I18n.t("feedback.trashed"))

func _serve() -> void:
	if state.stage != "brewing" or state.drink.is_empty():
		return
	if state.day == 1 and state.phase == "night" and state.tutorial == "locked":
		state.tutorial = "book_hint"
		state.stage = "tutorial"
		state.selected = []
		state.drink = {}
		return
	var person := _person()
	var species_wrong: bool = state.drink.side != person.species
	var recipe_wrong: bool = not Brewing.matches_order(_visit().get("order", ""), state.drink)
	if species_wrong or recipe_wrong:
		state.wrong_serves += 1
	state.served += 1
	state.notes.append({"day": state.day, "name": person.name, "text": person.appearance})
	for record: Dictionary in state.records:
		if record.id == _record_id():
			record.guess = state.drink.side
	state.stage = "reaction"
	if species_wrong:
		state.drink["reaction_key"] = "reaction.wrong_species"
	elif recipe_wrong:
		state.drink["reaction_key"] = "reaction.wrong_recipe"
	else:
		state.drink["reaction_key"] = "reaction.correct"

func _switch_shelf() -> void:
	if state.tutorial not in ["switch_hint", "ready"] or state.phase not in ["day", "night"]:
		return
	if state.stage not in ["brewing", "tutorial"]:
		return
	state.shelf = "fallen" if state.shelf == "human" else "human"
	state.selected = []
	state.drink = {}
	if state.tutorial == "switch_hint":
		state.tutorial = "ready"
		state.stage = "brewing"
		EventBus.feedback.emit(I18n.t("feedback.shelf_discovered"))

func _record_id() -> String:
	return "%d_%s_%d" % [state.day, state.phase, state.visit_index]

func _photograph() -> void:
	if state.day < 2 or state.phase not in ["day", "night"] or state.stage == "reaction":
		return
	for record: Dictionary in state.records:
		if record.id == _record_id():
			EventBus.feedback.emit(I18n.t("feedback.photo_exists"))
			return
	var person := _person()
	state.records.append({"id": _record_id(), "character": person.id, "name": person.name,
		"day": state.day, "dossier": person.dossier, "appearance": person.appearance,
		"portrait": {"portrait_id": person.get("portrait_id", person.id), "portrait_texture": person.get("portrait_texture", "")},
		"truth": person.species, "guess": "unknown", "reported_to": ""})
	EventBus.feedback.emit(I18n.t("feedback.photo_saved"))

func _report(id: String) -> void:
	if state.stage != "decision" or state.day < 2 or state.phase not in ["morning_supplier", "night_supplier"]:
		return
	var recipient := "human" if state.phase == "morning_supplier" else "fallen"
	var target := "fallen" if recipient == "human" else "human"
	for record: Dictionary in state.records:
		if record.id == id and record.reported_to == "":
			# Aynı kişinin farklı fotoğrafları tekrar tekrar ihbar edilemez.
			for previous: Dictionary in state.records:
				if previous.character == record.character and previous.reported_to != "":
					EventBus.feedback.emit(I18n.t("feedback.person_reported"))
					return
			record.reported_to = recipient
			if record.truth != target:
				state.wrong_reports += 1
			elif target == "human":
				state.human_reports += 1
			else:
				state.fallen_reports += 1
			EventBus.feedback.emit(I18n.t("feedback.report_sent"))
			_check_ending(false)
			return

func _check_ending(final_night: bool) -> void:
	var result := Endings.resolve(state.human_reports, state.fallen_reports, state.wrong_reports, state.wrong_serves, final_night, content.ending_rules)
	if result.id != "":
		state.ending = content.endings[result.id].duplicate(true)
		state.ending["id"] = result.id
		state.ending["variant"] = result.variant
		state.phase = "ending"
		state.stage = "ending"

func snapshot() -> Dictionary:
	var view := state.serialize()
	# Gerçek tür ve gizli sonuç sayaçları sunuma gönderilmez.
	for key: String in ["human_reports", "fallen_reports", "wrong_reports", "wrong_serves", "visits"]:
		view.erase(key)
	view["started"] = started
	view["total_days"] = content.days.size()
	view["brew"] = {"stats": Brewing.stats(state.selected, content.ingredient_map)}
	view.brew["tiers"] = Brewing.tiers(view.brew.stats)
	view.brew["color"] = Brewing.color(state.selected, content.ingredient_map).to_html(false) if not state.selected.is_empty() else ""
	view["has_save"] = Saves.exists()
	view["slots"] = save_slots.duplicate(true)
	view["content_errors"] = content.errors.duplicate()
	view["ingredients"] = content.ingredients.duplicate(true)
	view["recipes"] = content.recipes.duplicate(true)
	view["headline"] = _day_content().headline if content_ok else I18n.t("error.content_status")
	var person := _person().duplicate(true) if content_ok else {}
	person.erase("species")
	person.erase("dossier")
	view["person"] = person
	view["visit"] = _visit().duplicate(true) if content_ok else {}
	view.visit.erase("person")
	view["line"] = ""
	if content_ok and state.stage == "dialogue":
		var lines := _lines()
		view.line = lines[mini(state.line_index, lines.size() - 1)] if not lines.is_empty() else ""
	elif state.stage == "brewing":
		# Coffee Talk gibi: demlerken balonda siparişin kendisi durur.
		var lines := _lines()
		view.line = lines[0] if not lines.is_empty() else I18n.t("dialogue.brewing")
	elif state.stage == "tutorial":
		view.line = I18n.t("dialogue.discovery")
	elif state.stage == "reaction":
		view.line = I18n.t(state.drink.reaction_key) if state.drink.has("reaction_key") else ""
	elif state.stage == "decision":
		view.line = I18n.t("dialogue.delivery_decision") if state.day >= 2 else I18n.t("dialogue.delivery_done")
	view.records = []
	for record: Dictionary in state.records:
		var public_record := record.duplicate(true)
		public_record.erase("truth")
		view.records.append(public_record)
	return view

func _publish() -> void:
	EventBus.state_changed.emit(snapshot())
