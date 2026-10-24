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
	# Latte art (Coffee Talk): süt ilk kez 2. ya da 3. yuvada geçmeli; tarifli içecekte tarifin bayrağı geçerli.
	items.milk["latte"] = true
	check(BrewingRules.latte_art_allowed(["coffee", "honey", "milk"], items, {}), "Karışımdaki süt latte art açar")
	check(not BrewingRules.latte_art_allowed(["milk", "honey", "honey"], items, {}), "Baz süt latte art açmaz")
	check(not BrewingRules.latte_art_allowed(["milk", "milk", "honey"], items, {}), "Süt ilk yuvadaysa sonrakiler sayılmaz")
	check(BrewingRules.latte_art_allowed(["coffee", "milk", "milk"], items, {"id": "latte", "latte_art": true}), "Tarif bayrağı latte art açar")
	check(not BrewingRules.latte_art_allowed(["coffee", "milk", "honey"], items, {"id": "mocha"}), "Bayraksız tarif sütü yok sayar")
	var milky := BrewingRules.brew(["coffee", "honey", "milk"], items, [], names)
	check(milky.latte_art_allowed and not milky.latte_art, "Demlenen içecek latte art iznini taşır, çizim servis anında eklenir")
	# Latte art'ta dökülen renk: içecekteki latte malzemesinin art_color'ı (ilik), yoksa beyaz süt.
	var art_items := {"milk": {"latte": true}, "marrow": {"latte": true, "art_color": "e8d6bc"}, "blood": {}, "coffee": {}}
	check(BrewingRules.art_color(["coffee", "milk", "milk"], art_items) == "ffffff", "Süt beyaz döker")
	check(BrewingRules.art_color(["blood", "blood", "marrow"], art_items) == "e8d6bc", "İlik kendi renginde döker")
	check(BrewingRules.art_color(["blood", "blood", "blood"], art_items) == "ffffff", "Latte malzemesi yoksa varsayılan beyaz")
	check(milky.art_color == "ffffff", "Demlenen içecek çizim rengini taşır")
	check(not BrewingRules.matches_order({"stats": {"sweet": 1}, "latte_art": true}, milky), "Latte art isteyen sipariş çizimsiz reddedilir")
	milky["latte_art"] = true
	check(BrewingRules.matches_order({"stats": {"sweet": 1}, "latte_art": true}, milky), "Latte art'lı içecek siparişi karşılar")
	check(not BrewingRules.matches_order({"stats": {"sweet": 1}, "latte_art": false}, milky), "Latte art istemeyen sipariş reddeder")
	check(BrewingRules.find_sequence({"stats": {"sweet": 1}, "latte_art": true}, "human", items, []).size() == 3, "Latte art siparişi için dizi bulunur")
	var questions := [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	check(InterrogationRules.can_ask(questions, [], 0) == "", "İlk soru sorulabilir")
	check(InterrogationRules.can_ask(questions, [0], 0) == "asked", "Aynı soru iki kez sorulmaz")
	check(InterrogationRules.can_ask(questions, [0, 1], 2) == "limit", "Soru hakkı ikidir")
	check(InterrogationRules.can_ask(questions, [], 5) == "unknown", "Olmayan soru sorulmaz")
	check(InterrogationRules.questions_left([0]) == 1 and InterrogationRules.questions_left([0, 1, 2]) == 0, "Kalan soru hakkı")
	var marks := InterrogationRules.toggle_mark([], "Soğuk mu? Hiç fark etmedim.")
	check(marks == ["Soğuk mu? Hiç fark etmedim."], "Cümle işaretlenir")
	var cleared := InterrogationRules.toggle_mark(marks, "Soğuk mu? Hiç fark etmedim.")
	check(cleared.is_empty() and marks.size() == 1, "Tekrar işaretlemek kaldırır, eski liste değişmez")
	check(InterrogationRules.toggle_mark(marks, "") == marks, "Boş cümle işaretlenmez")
	var calm := SuspicionRules.fresh()
	var rules := {}
	var given := SuspicionRules.after_report(calm, "state", 0, true, rules)
	check(given.order == 15 and given.state == 0 and calm.order == 0, "Devlete dosya örgütü işkillendirir, devlet güvenir, eski sözlük değişmez")
	check(SuspicionRules.after_report(calm, "state", 2, true, rules).order == 35, "Aynı tarafa art arda teslim daha bariz")
	check(SuspicionRules.after_report(calm, "order", 0, false, rules).order == 20, "Yanlış kişi veren yanılttığı tarafı işkillendirir")
	check(SuspicionRules.after_decline(calm, "order", rules).order == 8, "Sorulup verilmezse soran işkillenir")
	check(SuspicionRules.after_serve(calm, "fallen", "human", true, rules).state == 12, "İnsana Fallen içeceği devleti işkillendirir")
	check(SuspicionRules.after_serve(calm, "human", "fallen", true, rules).order == 12, "Fallen'a insan içeceği örgütü işkillendirir")
	check(SuspicionRules.after_serve(calm, "human", "human", false, rules).state == 5, "İnsana istediğinden başka bir insan içeceği de biraz işkillendirir")
	check(SuspicionRules.after_serve(calm, "fallen", "fallen", false, rules).order == 5, "Fallen'a başka bir Fallen içeceği örgütü biraz işkillendirir")
	check(SuspicionRules.after_serve(calm, "human", "human", true, rules) == calm, "Doğru servis şüpheyi oynatmaz")
	check(SuspicionRules.after_answer({"state": 70, "order": 0}, "state", -15, rules).state == 55, "Sorgu cevabı şüpheyi oynatır")
	check(SuspicionRules.after_answer({"state": 95, "order": 0}, "state", 30, rules).state == 100, "Şüphe 100'de durur")
	check([0, 33, 34, 66, 67, 99].map(func(v: int) -> String: return SuspicionRules.level(v, rules)) == ["calm", "calm", "wary", "wary", "threat", "threat"], "Şüphe seviyeleri")
	check(SuspicionRules.bad_ending({"state": 100, "order": 100}, rules) == "state_arrest", "Kötü sonlarda devlet önce gelir")
	check(SuspicionRules.reached({"state": 0, "order": 100}, "order", rules) and not SuspicionRules.reached({"state": 0, "order": 100}, "state", rules), "Taraf bazında doluluk")
	check(SuspicionRules.after_decline(calm, "state", {"decline": 3}).state == 3, "Sayılar içerikten gelir")
	check(EndingRules.variant(1, 1) == "errors" and EndingRules.variant(1, 0) == "standard", "Hata varyantı")
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
	var test_cup := MenuCup.new("test", "menu.story", 1.0, 1.0, 1.0)
	check(test_cup.fill_amount == 0.0 and not test_cup.is_full, "Fincan başlangıçta boş olmalı")
	check(not test_cup.pour(0.5), "Yarım dolum henüz tamamlanmadı")
	check(is_equal_approx(test_cup.get_progress(), 0.5), "İlerleme oranı yarım")
	test_cup.drain(0.2)
	check(is_equal_approx(test_cup.get_progress(), 0.3), "Doldurma bırakılınca boşalma")
	check(test_cup.pour(1.0), "Tam dolum seçim olayını tetikler")
	check(test_cup.is_full and test_cup.fill_amount == 1.0, "Fincan dolu durumu")
	test_cup.reset()
	check(test_cup.fill_amount == 0.0 and not test_cup.is_full, "Fincan sıfırlama")
	var menu_dir := MenuDirector.new()
	check(menu_dir.get_all_cups().size() == 3, "Ana menüde tam üç seçenek olmalı")
	check(menu_dir.resolve_selection("story", true).type == "save_select", "Starta basınca save seçimi açılmalı")
	check(menu_dir.resolve_selection("story", false).type == "save_select", "Kayıt olmasa bile save/yeni oyun seçimi açılır")
	check(menu_dir.resolve_selection("endless", false).mode == "endless", "Endless modu")
	check(menu_dir.resolve_selection("settings", false).kind == "settings", "Ayarlar menü penceresini açar")
	print("DOMAIN: ", "PASS" if failures == 0 else "FAIL", " (", failures, " hata)")
	quit(failures)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
