extends SceneTree
var failures: int = 0

func _initialize() -> void:
	var recipes: Array = [{"id": "latte", "ingredients": ["coffee", "milk", "milk"]}]
	check(BrewingRules.identify(["coffee", "milk", "milk"], recipes).get("id") == "latte", "Tarif eşleşmesi")
	check(BrewingRules.identify(["milk", "coffee", "milk"], recipes).is_empty(), "Baz değişirse tarif değişir")
	check(BrewingRules.identify(["coffee", "coffee", "milk"], recipes).is_empty(), "Tekrarlı malzeme adedi")
	check(not BrewingRules.can_consume(["milk", "milk", "coffee"], {"milk": 1, "coffee": 9}), "Stok kontrolü")
	var items := {
		"coffee": {"name": "Kahve", "adjective": "Kahveli", "side": "human", "base": true, "mix": false, "color": "000000",
			"stats": {"warm": [2, 1, 1], "cool": [0, 0, 0], "sweet": [0, 0, 0], "bitter": [3, 2, 1]}},
		"honey": {"name": "Bal", "adjective": "Ballı", "side": "human", "base": false, "mix": true, "color": "ffffff",
			"stats": {"warm": [0, 0, 0], "cool": [0, 0, 0], "sweet": [0, 3, 2], "bitter": [0, 0, 0]}},
		"milk": {"name": "Süt", "adjective": "Sütlü", "side": "human", "base": true, "mix": true, "color": "ffffff",
			"stats": {"warm": [1, 1, 1], "cool": [0, 1, 1], "sweet": [1, 1, 1], "bitter": [0, 0, 0]}}}
	check(BrewingRules.can_add([], "honey", items) == "not_base", "İlk slot baz ister")
	check(BrewingRules.can_add(["coffee"], "coffee", items) == "", "Baz kendini tekrar edebilir")
	check(BrewingRules.can_add(["milk"], "coffee", items) == "not_mix", "Karışıma uygun olmayan malzeme")
	check(BrewingRules.can_add(["coffee", "honey", "honey"], "milk", items) == "full", "En fazla üç slot")
	var totals := BrewingRules.stats(["coffee", "honey", "honey"], items)
	check(totals.sweet == 5 and totals.bitter == 3 and totals.warm == 2, "Slot başına tat değeri")
	check([0, 1, 3, 4, 5, 6, 9].map(BrewingRules.tier) == [0, 1, 1, 2, 2, 3, 3], "Tier eşikleri")
	var names := {"pure": "Saf {base}", "double": "Bol {adj} {base}", "strong": "Koyu {adj} {base}", "mix": "{first} {second} {base}"}
	check(BrewingRules.generated_name(["coffee", "honey", "honey"], items, names) == "Bol Ballı Kahve", "Üretilen isim")
	check(BrewingRules.generated_name(["coffee", "coffee", "honey"], items, names) == "Koyu Ballı Kahve", "Koyu isim")
	check(BrewingRules.generated_name(["coffee", "honey", "milk"], items, names) == "Ballı Sütlü Kahve", "Karışım isim")
	var mixed := BrewingRules.color(["coffee", "milk", "milk"], items)
	check(is_equal_approx(mixed.r, 0.4 / 2.4), "Renk ağırlıkları baz baskın")
	var drink := BrewingRules.brew(["coffee", "honey", "honey"], items, [], names)
	check(drink.id == "custom" and drink.side == "human", "Tarifsiz içecek de servis edilebilir")
	check(BrewingRules.matches_order({"stats": {"sweet": 2}}, drink), "Tat siparişi tier ile karşılanır")
	check(not BrewingRules.matches_order({"stats": {"sweet": 3}}, drink), "Yetersiz tier reddedilir")
	check(not BrewingRules.matches_order("latte", drink), "Tarif siparişi kimlik ister")
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
