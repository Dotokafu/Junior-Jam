extends SceneTree
var failures: int = 0

func _initialize() -> void:
	var recipes: Array = [{"id": "latte", "ingredients": ["coffee", "milk", "milk"]}]
	check(BrewingRules.identify(["milk", "coffee", "milk"], recipes).get("id") == "latte", "Malzeme sırası")
	check(BrewingRules.identify(["coffee", "coffee", "milk"], recipes).is_empty(), "Tekrarlı malzeme adedi")
	check(not BrewingRules.can_consume(["milk", "milk", "coffee"], {"milk": 1, "coffee": 9}), "Stok kontrolü")
	check(EndingRules.resolve(3, 0, 0, 0, false).id == "human_supplier", "İnsan tedarikçisi sonu")
	check(EndingRules.resolve(0, 3, 0, 0, false).id == "fallen_supplier", "Fallen tedarikçisi sonu")
	check(EndingRules.resolve(1, 1, 0, 0, true).id == "grey", "Gri son")
	check(EndingRules.resolve(0, 2, 0, 0, true).id == "fallen_world", "Tek taraflı liste denge değildir")
	check(EndingRules.resolve(0, 0, 0, 0, true).id == "fallen_world", "Sessizlik sonucu")
	check(EndingRules.resolve(1, 1, 1, 1, true).id != "grey", "Yanlış teşhis gri sonu engeller")
	check(EndingRules.resolve(3, 0, 2, 0, false).variant == "errors", "Alt son varyantı")
	var state := ShiftState.new()
	state.tutorial = "tab_seen"
	state.stock = {"coffee": 4}
	check(ShiftState.restore(state.serialize()).tutorial == "tab_seen", "Kayıt gidiş dönüş")
	var repository := ContentRepository.new()
	check(repository.load_all(), "İçerik doğrulama: " + str(repository.errors))
	print("DOMAIN: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
