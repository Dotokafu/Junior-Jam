extends SceneTree
## Gerçek EventBus üzerinden dört gün ve dört son. Kullanıcı kaydına yazmaz.
var session: Node
var bus: Node
var failures: int = 0
var tutorial_checked: bool = false
var latte_seen: bool = false
var interviewed: bool = false
var questioned: bool = false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	session = root.get_node("Session")
	bus = root.get_node("EventBus")
	session.persistence_enabled = false
	for strategy: String in ["silent", "balanced", "give_humans", "give_fallen", "mistakes"]:
		simulate(strategy)
	simulate("silent", "endless")
	check(latte_seen, "Akışta en az bir latte art'lı içecek denenmeli")
	check(interviewed, "Akışta en az bir müşteri sorgulanmalı")
	check(questioned, "Şüphe yükselince en az bir sorgu sahnesi yaşanmalı")
	print("FLOW: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func command(action: String, payload: Dictionary = {}) -> void:
	bus.request(action, payload)

func simulate(strategy: String, mode: String = "story") -> void:
	command("new_game", {"mode": mode, "seed": 4217})
	check(session.snapshot().recipes.is_empty(), "Tarif defteri boş başlamalı")
	var guard := 0
	while session.state.phase != "ending" and guard < 1500:
		guard += 1
		var state: RefCounted = session.state
		if mode == "endless" and state.day > 6:
			break
		var snapshot: Dictionary = session.snapshot()
		check(not snapshot.has("wrong_serves"), "Gizli sayaç sızmamalı")
		for hidden: String in ["suspicion", "give_streak", "last_given", "interrogated", "interrogation"]:
			check(not snapshot.has(hidden), "Gizli şüphe sızmamalı: " + hidden)
		check(not snapshot.person.has("species"), "Gerçek tür sızmamalı")
		for record: Dictionary in snapshot.records:
			check(not record.has("truth"), "GBT gerçek türü söylememeli")
		if state.phase in ["fall", "dawn"]:
			command("next")
		elif state.stage == "dialogue":
			if state.day >= 2:
				command("photo")
			command("next")
		elif state.stage == "brewing":
			var visit: Dictionary = session._visit()
			var wanted: Variant = visit.order
			var side: String = session._person().species
			if state.day == 1 and state.phase == "night" and state.tutorial == "locked":
				wanted = "latte"
				side = "human"
			elif strategy == "mistakes":
				wanted = "latte" if side == "fallen" else "red"
				side = "human" if side == "fallen" else "fallen"
			var sequence: Array = BrewingRules.find_sequence(wanted, side, session.content.ingredient_map, session.content.recipes)
			check(not sequence.is_empty(), "Sipariş yapılabilir olmalı: " + str(wanted))
			if strategy == "mistakes" and not BrewingRules.can_consume(sequence, state.stock):
				# Yanlış rafın stoğu tükendiyse doğru içecek: stok sınırı stratejiyi kilitlemesin.
				sequence = BrewingRules.find_sequence(visit.order, session._person().species, session.content.ingredient_map, session.content.recipes)
			if session.content.ingredient_map[sequence[0]].side != state.shelf:
				command("shelf")
			# İlk günün gündüzünde gizli menüye zorla erişilemez.
			if session.content.ingredient_map[sequence[0]].side != state.shelf:
				sequence = session.content.recipes[1].ingredients
			for ingredient: String in sequence:
				if session.content.ingredient_map[ingredient].side != state.shelf and state.tutorial in ["switch_hint", "ready"]:
					command("shelf")
				command("select", {"id": ingredient})
			command("brew")
			if state.drink.get("id", "custom") != "custom":
				check(session.snapshot().recipes.any(func(recipe: Dictionary) -> bool: return recipe.id == state.drink.id), "Demlenen tarif deftere yazılmalı")
			check(not state.drink.is_empty(), "Karışım hazırlanmalı")
			var art_allowed: bool = state.drink.get("latte_art_allowed", false)
			latte_seen = latte_seen or art_allowed
			command("serve", {"latte_art": true})
			check(state.stage != "reaction" or state.drink.get("latte_art", false) == art_allowed, "Latte art yalnızca izinli içecekte işaretlenmeli")
		elif state.stage == "tutorial":
			check(state.tutorial == "book_hint", "İlk yanlış fincan gizli ayracı açmalı")
			command("shelf")
			check(state.shelf == "human", "Defter okunmadan kepenk açılmamalı")
			command("book_closed")
			check(state.tutorial == "book_hint", "Ayraç görülmeden kitap kapatmak ilerletmemeli")
			command("book_tab")
			check(state.tutorial == "tab_seen", "Fallen sayfası görüldü")
			command("book_closed")
			check(state.tutorial == "switch_hint", "Kitap kapanınca raf düğmesi açılmalı")
			command("shelf")
			check(state.tutorial == "ready" and state.shelf == "fallen", "Kepenk öğreticisi tamamlandı")
			tutorial_checked = true
		elif state.stage == "interview":
			var questions: Array = session._visit().get("questions", [])
			check(snapshot.questions.size() == questions.size(), "Sorgu sırasında sorular görünmeli")
			check(not str(snapshot.questions).contains("answer") and not snapshot.visit.has("questions"), "Cevaplar sorulmadan görünmemeli")
			if state.asked.size() < InterrogationRules.QUESTION_LIMIT and state.asked.size() < questions.size():
				var was_marked: bool = snapshot.marked
				command("mark")
				check(session.state.marks.get(session._record_id(), []).has(snapshot.line) != was_marked, "İşaretle görünen cümleyi açıp kapamalı")
				command("ask", {"index": state.asked.size()})
				check(state.stage == "answer", "Soru sorunca cevap gelmeli")
				interviewed = true
			else:
				var before: int = state.asked.size()
				command("ask", {"index": 0})
				check(state.asked.size() == before, "Sorulmuş soru ya da hak bitince soru sorulamaz")
				command("next")
				check(state.stage == "brewing", "Sorgudan siparişe geçilmeli")
		elif state.stage == "questioning":
			check(snapshot.questions.size() >= 2 and snapshot.line != "", "Sorguda soru ve cevaplar görünmeli")
			var before: Dictionary = state.suspicion.duplicate()
			command("answer_interrogation", {"index": 0})
			check(state.stage == "verdict" and state.suspicion != before, "Sorgu cevabı şüpheyi oynatmalı")
			questioned = true
		elif state.stage == "verdict":
			command("next")
			check(state.stage in ["decision", "ending"], "Sorgudan sonra teslimat sürmeli")
		elif state.stage == "answer":
			command("next")
		elif state.stage == "reaction":
			command("next")
		elif state.stage == "decision":
			share(strategy)
			if state.phase != "ending":
				command("next")
	check(guard < 1500, "Akış kilitlenmemeli: " + strategy)
	if mode == "endless":
		check(session.state.day == 7 and session.state.ending.is_empty(), "Endless dördüncü günde bitmemeli")
		print("  endless → gün ", session.state.day, " / ", session.state.served, " fincan")
		return
	var expected: Array = {"silent": ["fallen_world"], "balanced": ["grey"], "give_humans": ["human_supplier"], "give_fallen": ["fallen_supplier"], "mistakes": ["state_arrest", "order_vanish"]}[strategy]
	check(session.state.ending.get("id") in expected, strategy + " sonu: " + str(session.state.ending.get("id")))
	if strategy == "mistakes":
		check(session.state.ending.get("variant") == "errors", "Yanlış servis alt sonu")
	print("  ", strategy, " → ", session.state.ending.get("id"), " / ", session.state.served, " fincan")
	check(tutorial_checked, "Öğretici test edilmeli")

func share(strategy: String) -> void:
	var state: RefCounted = session.state
	if state.day < 2 or strategy in ["silent", "mistakes"]:
		return
	var target := "fallen" if state.phase == "morning_supplier" else "human"
	if strategy == "give_humans" and target != "human":
		return
	if strategy == "give_fallen" and target != "fallen":
		return
	if strategy == "balanced" and ((target == "human" and state.human_reports >= 1) or (target == "fallen" and state.fallen_reports >= 1)):
		return
	for record: Dictionary in state.records:
		if state.phase == "ending":
			return
		if record.truth != target or record.reported_to != "":
			continue
		var previously := false
		for other: Dictionary in state.records:
			if other.character == record.character and other.reported_to != "":
				previously = true
		if previously:
			continue
		command("report", {"id": record.id})
		var count: int = state.human_reports + state.fallen_reports + state.wrong_reports
		command("report", {"id": record.id})
		check(count == state.human_reports + state.fallen_reports + state.wrong_reports, "Aynı fotoğraf iki kez bildirilemez")
		if strategy == "balanced":
			return
