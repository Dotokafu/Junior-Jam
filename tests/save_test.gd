extends SceneTree
## Kayıt yuvaları: kaydet → ilerle → yükle aynı ana döner; ana menü ilerlemeyi bozmaz; boş yuva yüklenmez.
## Oyuncunun kayıtlarına dokunmamak için ayrı dosya ön eki kullanır ve sonunda temizler.
const Saves = preload("res://infrastructure/persistence/save_repository.gd")
var session: Node
var bus: Node
var failures: int = 0
var feedback: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Saves.prefix = "user://coffallen_test"
	for slot in range(Saves.SLOT_COUNT + 1):
		Saves.delete(slot)
	session = root.get_node("Session")
	bus = root.get_node("EventBus")
	session.persistence_enabled = false
	session.save_slots = Saves.summaries()
	bus.feedback.connect(func(message: String) -> void: feedback.append(message))
	bus.request("new_game", {"mode": "story", "seed": 77})
	bus.request("next")
	var saved_line: int = session.state.line_index
	var saved_phase: String = session.state.phase
	bus.request("save_slot", {"slot": 2})
	check(not session.save_slots[2].empty and session.save_slots[2].day == 1, "Kayıt kartı özeti güncellenmeli")
	check(session.snapshot().slots[2].phase == saved_phase, "Snapshot kayıt özetini taşımalı")
	for i in range(4):
		bus.request("next")
	check(session.state.line_index != saved_line or session.state.phase != saved_phase, "Kayıttan sonra oyun ilerlemeli")
	bus.request("load_slot", {"slot": 2})
	check(session.state.line_index == saved_line and session.state.phase == saved_phase, "Yükleme kaydedilen ana dönmeli")
	bus.request("main_menu")
	check(not session.started, "Ana menüye dönünce oyun durmalı")
	var before := feedback.size()
	bus.request("load_slot", {"slot": 3})
	check(not session.started and feedback.size() > before, "Boş yuva yüklenmemeli ve uyarı vermeli")
	bus.request("load_slot", {"slot": 2})
	check(session.started, "Ana menüden kayıt yüklenebilmeli")
	# Sorgu alanları olmayan eski kayıt varsayılanlarla yüklenir.
	var legacy: Dictionary = session.state.serialize()
	legacy.erase("asked")
	legacy.erase("answering")
	legacy.erase("marks")
	Saves.write(legacy, 3)
	bus.request("load_slot", {"slot": 3})
	check(session.state.asked.is_empty() and session.state.answering == -1 and session.state.marks.is_empty(), "Eski kayıt sorgu alanları olmadan yüklenmeli")
	# Eski kayıt: sonradan eklenen malzemenin stoğu açılır, artık olmayan malzemeli seçim temizlenir.
	var old: Dictionary = session.state.serialize()
	old.stock.erase("matcha")
	old.selected = ["olmayan_malzeme"]
	Saves.write(old, 3)
	bus.request("load_slot", {"slot": 3})
	check(int(session.state.stock.get("matcha", 0)) == 10 and session.state.selected.is_empty(), "Eski kayıt yeni raflara yükseltilmeli")
	session.state.phase = "ending"
	session.state.stage = "ending"
	bus.request("save_slot", {"slot": 1})
	check(Saves.summaries()[1].empty, "Bitmiş oyun kaydedilmemeli")
	for slot in range(Saves.SLOT_COUNT + 1):
		Saves.delete(slot)
	print("SAVES: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
