extends SceneTree
## Gerçek EventBus üzerinden dört gün ve dört son. Kullanıcı kaydına yazmaz.
var session: Node
var bus: Node
var failures: int = 0
var tutorial_checked: bool = false

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
	print("FLOW: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func command(action: String, payload: Dictionary = {}) -> void:
	bus.request(action, payload)

func simulate(strategy: String, mode: String = "story") -> void:
	command("new_game", {"mode": mode, "seed": 4217})
	var guard := 0
	while session.state.phase != "ending" and guard < 700:
		guard += 1
		var state: RefCounted = session.state
		if mode == "endless" and state.day > 6:
			break
		var snapshot: Dictionary = session.snapshot()
		check(not snapshot.has("wrong_serves"), "Gizli sayaç sızmamalı")
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
			var wanted: String = visit.order
			if state.day == 1 and state.phase == "night" and state.tutorial == "locked":
				wanted = "latte"
			elif strategy == "mistakes":
				wanted = "latte" if session._person().species == "fallen" else "red"
			var recipe: Dictionary = {}
			for item: Dictionary in session.content.recipes:
				if item.id == wanted:
					recipe = item
			if recipe.side != state.shelf:
				command("shelf")
			# İlk günün gündüzünde gizli menüye zorla erişilemez.
			if recipe.side != state.shelf:
				recipe = session.content.recipes[1]
			for ingredient: String in recipe.ingredients:
				command("select", {"id": ingredient})
			command("brew")
			check(not state.drink.is_empty(), "Karışım hazırlanmalı")
			command("serve")
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
		elif state.stage == "reaction":
			command("next")
		elif state.stage == "decision":
			share(strategy)
			if state.phase != "ending":
				command("next")
	check(guard < 700, "Akış kilitlenmemeli: " + strategy)
	if mode == "endless":
		check(session.state.day == 7 and session.state.ending.is_empty(), "Endless dördüncü günde bitmemeli")
		print("  endless → gün ", session.state.day, " / ", session.state.served, " fincan")
		return
	var expected: String = {"silent": "fallen_world", "balanced": "grey", "give_humans": "human_supplier", "give_fallen": "fallen_supplier", "mistakes": "fallen_world"}[strategy]
	check(session.state.ending.get("id") == expected, strategy + " sonu: " + str(session.state.ending.get("id")))
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
