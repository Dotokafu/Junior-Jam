extends Node
## Tek yazma noktası: sunum komut gönderir, uygulama domain kurallarını çalıştırır.
const State = preload("res://domain/shift/shift_state.gd")
const Brewing = preload("res://domain/brewing/brewing_rules.gd")
const Endings = preload("res://domain/consequences/ending_rules.gd")
const Content = preload("res://infrastructure/content/content_repository.gd")
const Saves = preload("res://infrastructure/persistence/save_repository.gd")
const Director = preload("res://domain/encounters/encounter_director.gd")
const Interrogation = preload("res://domain/interrogation/interrogation_rules.gd")
const Suspicion = preload("res://domain/consequences/suspicion_rules.gd")
## Soru hatası → bildirim anahtarı.
const ASK_ERRORS := {"unknown": "feedback.ask_unknown", "asked": "feedback.ask_asked", "limit": "feedback.ask_limit"}
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
			"serve": _serve(bool(payload.get("latte_art", false)))
			"shelf": _switch_shelf()
			"book_tab":
				if state.tutorial == "book_hint":
					state.tutorial = "tab_seen"
			"book_closed":
				if state.tutorial == "tab_seen":
					state.tutorial = "switch_hint"
			"photo": _photograph()
			"report": _report(str(payload.get("id", "")))
			"ask": _ask(int(payload.get("index", -1)))
			"mark": _mark()
			"answer_interrogation": _answer_interrogation(int(payload.get("index", -1)))
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
	_upgrade_ingredients()
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

## Eski kayıtlar: raflara sonradan eklenen malzemelerin stoğu açılır; artık olmayan malzemeyle yarım
## kalmış seçim temizlenir.
func _upgrade_ingredients() -> void:
	for ingredient: Dictionary in content.ingredients:
		if not state.stock.has(ingredient.id):
			state.stock[ingredient.id] = 10
	for id: String in state.selected:
		if not content.ingredient_map.has(id):
			state.selected = []
			state.drink = {}
			return

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
		var morning: Array = content.pools.endless_morning if state.mode == "endless" and state.day > 1 else day.morning
		return _with_suspicion_line(morning, "state")
	if state.phase == "night_supplier":
		var evening: Array = content.pools.endless_evening if state.mode == "endless" and state.day > 1 else day.evening
		return _with_suspicion_line(evening, "order")
	if state.stage == "answer":
		var questions: Array = _visit().get("questions", [])
		if state.answering >= 0 and state.answering < questions.size():
			return questions[state.answering].get("answer", [])
		return []
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
		state.delivery_reported = false
		_check_bad_ending("state")
	elif state.stage == "dialogue":
		state.line_index += 1
		if state.line_index >= _lines().size():
			if state.phase in ["morning_supplier", "night_supplier"]:
				_start_delivery_decision()
			elif _visit().get("questions", []).is_empty():
				state.stage = "brewing"
			else:
				state.stage = "interview"
	elif state.stage == "answer":
		state.line_index += 1
		if state.line_index >= _lines().size():
			state.answering = -1
			state.stage = "interview"
	elif state.stage == "interview":
		state.stage = "brewing"
	elif state.stage == "reaction":
		_advance_customer()
	elif state.stage == "verdict":
		state.verdict = ""
		state.stage = "decision"
	elif state.stage == "decision":
		_finish_delivery()

func _reset_visit() -> void:
	state.visit_index = 0
	state.line_index = 0
	state.stage = "dialogue"
	state.selected = []
	state.drink = {}
	state.asked = []
	state.answering = -1
	state.visits = _generate_visits() if state.phase in ["day", "night"] else []

func _advance_customer() -> void:
	state.visit_index += 1
	state.line_index = 0
	state.stage = "dialogue"
	state.selected = []
	state.drink = {}
	state.asked = []
	state.answering = -1
	if state.visit_index >= state.visits.size():
		state.visit_index = 0
		if state.phase == "day":
			state.phase = "fall"
			state.stage = "transition"
		else:
			state.phase = "night_supplier"
			state.delivery_reported = state.reported_day == state.day
			_check_bad_ending("order")
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
	if drink.id != "custom" and drink.id not in state.discovered:
		state.discovered.append(drink.id)
		EventBus.feedback.emit(I18n.t("feedback.recipe_found", {"drink": drink.name}))
	EventBus.feedback.emit(I18n.t("feedback.drink_ready", {"drink": state.drink.name}))

## Demlenmiş fincanı döker; harcanan stok geri gelmez.
func _trash() -> void:
	if state.stage != "brewing" or state.drink.is_empty():
		return
	state.selected = []
	state.drink = {}
	EventBus.feedback.emit(I18n.t("feedback.trashed"))

## latte_art: içecek latte art ekranından servis edildi (yalnızca izinli içecekte işaretlenir).
func _serve(latte_art: bool = false) -> void:
	if state.stage != "brewing" or state.drink.is_empty():
		return
	state.drink["latte_art"] = latte_art and bool(state.drink.get("latte_art_allowed", false))
	if state.day == 1 and state.phase == "night" and state.tutorial == "locked":
		state.tutorial = "book_hint"
		state.stage = "tutorial"
		state.selected = []
		state.drink = {}
		return
	var person := _person()
	var species_wrong: bool = state.drink.side != person.species
	var visit := _visit()
	var order_matched := Brewing.matches_order(visit.get("order", ""), state.drink) or (visit.has("flexible_order") and Brewing.matches_order(visit.get("flexible_order", {}), state.drink))
	var recipe_wrong: bool = not order_matched
	state.suspicion = Suspicion.after_serve(state.suspicion, state.drink.side, person.species, not recipe_wrong, _suspicion_rules())
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

## Sorgu: soru sorulur, cevap satırları okunur, sonra soru listesine dönülür.
func _ask(index: int) -> void:
	if state.stage != "interview":
		return
	var problem := Interrogation.can_ask(_visit().get("questions", []), state.asked, index)
	if problem != "":
		EventBus.feedback.emit(I18n.t(ASK_ERRORS[problem]))
		return
	state.asked.append(index)
	state.answering = index
	state.line_index = 0
	state.stage = "answer"

## Balonda o an görünen cümleyi bu ziyaretin notlarına ekler ya da notlardan çıkarır.
func _mark() -> void:
	if state.day < 2 or state.phase not in ["day", "night"] or state.stage not in ["dialogue", "answer", "interview"]:
		return
	var id := _record_id()
	var line := _current_line()
	var was_marked: bool = line in state.marks.get(id, [])
	state.marks[id] = Interrogation.toggle_mark(state.marks.get(id, []), line)
	if was_marked:
		EventBus.feedback.emit(I18n.t("feedback.unmarked"))
	else:
		EventBus.feedback.emit(I18n.t("feedback.marked"))

## Sipariş cümlesi: ziyaretin order_line alanı; yoksa (eski içerik) ilk konuşma satırı.
func _order_line() -> String:
	var visit := _visit()
	if visit.get("order_line", "") != "":
		return visit.order_line
	var dialogue: Array = visit.get("dialogue", [])
	return dialogue[0] if not dialogue.is_empty() else I18n.t("dialogue.brewing")

func _current_line() -> String:
	match state.stage:
		"dialogue", "answer":
			var lines := _lines()
			return lines[mini(state.line_index, lines.size() - 1)] if not lines.is_empty() else ""
		"interview", "brewing":
			return _order_line()
	return ""

func _switch_shelf() -> void:
	if state.tutorial not in ["switch_hint", "ready"] or state.phase not in ["day", "night"]:
		return
	if state.stage not in ["brewing", "tutorial"]:
		return
	state.shelf = "fallen" if state.shelf == "human" else "human"
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
	if state.reported_day == state.day:
		EventBus.feedback.emit(I18n.t("feedback.already_reported_today"))
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
			state.reported_day = state.day
			state.delivery_reported = true
			if record.truth != target:
				state.wrong_reports += 1
			elif target == "human":
				state.human_reports += 1
			else:
				state.fallen_reports += 1
			var side := "state" if recipient == "human" else "order"
			state.give_streak = state.give_streak + 1 if state.last_given == side else 0
			state.last_given = side
			state.suspicion = Suspicion.after_report(state.suspicion, side, state.give_streak, record.truth == target, _suspicion_rules())
			EventBus.feedback.emit(I18n.t("feedback.report_sent"))
			_check_ending(false)
			return

func _check_ending(final_night: bool) -> void:
	var result := Endings.resolve(state.human_reports, state.fallen_reports, state.wrong_reports, state.wrong_serves, final_night, content.ending_rules)
	if result.id != "":
		_end(result.id)

## Tedarikçinin satırları bitti. O tarafın şüphesi tehdit seviyesindeyse ve daha önce sorgulanmadıysan
## önce sorgu gelir; sonra dosya teslimi.
func _start_delivery_decision() -> void:
	var side := _supplier_side()
	var rules := _suspicion_rules()
	if state.day >= 2 and side not in state.interrogated and Suspicion.level(int(state.suspicion[side]), rules) == "threat":
		state.interrogated.append(side)
		state.interrogation = side
		state.stage = "questioning"
		return
	state.stage = "decision"

func _answer_interrogation(index: int) -> void:
	if state.stage != "questioning":
		return
	var answers: Array = content.pools.interrogations[state.interrogation].answers
	if index < 0 or index >= answers.size():
		return
	state.suspicion = Suspicion.after_answer(state.suspicion, state.interrogation, int(answers[index].effect), _suspicion_rules())
	state.verdict = str(answers[index].reply)
	state.interrogation = ""
	state.stage = "verdict"

## Tedarikçinin satırlarına, o tarafın şüphe seviyesine göre bir tavır satırı eklenir (sakinse eklenmez).
func _with_suspicion_line(lines: Array, side: String) -> Array:
	var level := Suspicion.level(int(state.suspicion[side]), _suspicion_rules())
	if level == "calm" or state.day < 2:
		return lines
	var variants: Array = content.pools.get("suspicion_lines", {}).get(side, {}).get(level, [])
	if variants.is_empty():
		return lines
	var result := lines.duplicate()
	result.append(variants[state.day % variants.size()])
	return result

## Şafakta kepengin altından gelen not: şüphesi en yüksek tarafın seviyesine göre; ikisi de sakinse yok.
func _door_note() -> String:
	var rules := _suspicion_rules()
	var side := "state" if int(state.suspicion.state) >= int(state.suspicion.order) else "order"
	var level := Suspicion.level(int(state.suspicion[side]), rules)
	if level == "calm":
		return ""
	return str(content.pools.get("door_notes", {}).get(side, {}).get(level, ""))

## Teslimat biter: sorulup dosya verilmediyse soran işkillenir; o tarafın şüphesi dolduysa kötü son
## bu teslimatın sonunda gelir; yoksa gün ilerler.
func _finish_delivery() -> void:
	var side := _supplier_side()
	if state.day >= 2 and not state.delivery_reported:
		state.suspicion = Suspicion.after_decline(state.suspicion, side, _suspicion_rules())
	_check_bad_ending(side)
	if state.phase == "ending":
		return
	if state.phase == "morning_supplier":
		state.phase = "day"
		_reset_visit()
	elif state.phase == "night_supplier":
		_check_ending(state.mode == "story" and state.day == content.days.size())
		if state.phase != "ending":
			_restock("fallen")
			state.phase = "dawn"
			state.stage = "transition"

## Şüphe dolduysa o tarafın kötü sonu (yalnızca o tarafın teslimatında çağrılır).
func _check_bad_ending(side: String) -> void:
	if Suspicion.reached(state.suspicion, side, _suspicion_rules()):
		_end(Suspicion.ENDINGS[side])

func _end(id: String) -> void:
	state.ending = content.endings[id].duplicate(true)
	state.ending["id"] = id
	state.ending["variant"] = Endings.variant(state.wrong_reports, state.wrong_serves)
	state.phase = "ending"
	state.stage = "ending"

func _supplier_side() -> String:
	return "state" if state.phase == "morning_supplier" else "order"

func _suspicion_rules() -> Dictionary:
	return content.ending_rules.get("suspicion", {})

func snapshot() -> Dictionary:
	var view := state.serialize()
	# Gerçek tür ve gizli sonuç sayaçları sunuma gönderilmez.
	for key: String in ["human_reports", "fallen_reports", "wrong_reports", "wrong_serves", "visits",
			"suspicion", "give_streak", "last_given", "interrogated", "interrogation"]:
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
	# Defterde yalnızca demlenerek bulunan tarifler görünür.
	view["recipes"] = content.recipes.filter(func(recipe: Dictionary) -> bool: return recipe.id in state.discovered).duplicate(true)
	view["headline"] = _day_content().headline if content_ok else I18n.t("error.content_status")
	var person := _person().duplicate(true) if content_ok else {}
	person.erase("species")
	person.erase("dossier")
	view["person"] = person
	view["visit"] = _visit().duplicate(true) if content_ok else {}
	view.visit.erase("person")
	view["line"] = ""
	if content_ok and state.stage in ["dialogue", "answer", "interview", "brewing"]:
		# Demlerken ve sorgu sırasında balonda siparişin kendisi durur.
		view.line = _current_line()
	elif state.stage == "tutorial":
		view.line = I18n.t("dialogue.discovery")
	elif state.stage == "reaction":
		view.line = I18n.t(state.drink.reaction_key) if state.drink.has("reaction_key") else ""
	elif state.stage == "questioning" and content_ok:
		view.line = str(content.pools.interrogations[state.interrogation].line)
	elif state.stage == "verdict":
		view.line = state.verdict
	elif state.stage == "decision":
		var ask := "dialogue.ask_state" if state.phase == "morning_supplier" else "dialogue.ask_order"
		view.line = I18n.t(ask) if state.day >= 2 else I18n.t("dialogue.delivery_done")
	# Cevaplar yalnızca sorulunca "line" olarak gelir; ziyaretin soru listesi sunuma gitmez.
	view.visit.erase("questions")
	view["questions"] = []
	if content_ok and state.stage == "interview":
		var questions: Array = _visit().get("questions", [])
		for i in range(questions.size()):
			view.questions.append({"text": str(content.pools.get("questions", {}).get(questions[i].get("id", ""), "")), "asked": i in state.asked})
	if content_ok and state.stage == "questioning":
		for answer: Dictionary in content.pools.interrogations[state.interrogation].answers:
			view.questions.append({"text": str(answer.text), "asked": false})
	# Sorguda kalan hak satırı gösterilmez (-1).
	view["questions_left"] = -1 if state.stage == "questioning" else Interrogation.questions_left(state.asked)
	view["door_note"] = _door_note() if content_ok and state.phase == "dawn" else ""
	view["marked"] = view.line != "" and view.line in state.marks.get(_record_id(), [])
	view.records = []
	for record: Dictionary in state.records:
		var public_record := record.duplicate(true)
		public_record.erase("truth")
		public_record["marks"] = state.marks.get(record.id, []).duplicate()
		view.records.append(public_record)
	return view

func _publish() -> void:
	EventBus.state_changed.emit(snapshot())
