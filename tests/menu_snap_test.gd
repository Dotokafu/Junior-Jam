extends SceneTree
## Ana menü: demlik bir bardağın yakınında o bardağın üstüne hizalanır, alandan çıkınca fareye döner.
## Gerçek pencere açar; fare olayları pencere koordinatıyla gönderilir.
var menu: Control
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FAIL ") + msg)
	if not ok:
		failures += 1

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = root.get_final_transform() * p
	root.push_input(e)
	await process_frame

func button(pressed: bool, p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.position = root.get_final_transform() * p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	root.push_input(e)
	await process_frame

func run() -> void:
	menu = load("res://presentation/menu/topdown_menu.tscn").instantiate()
	root.add_child(menu)
	await wait(0.5)
	var cup: Control = menu.endless_cup
	var rect: Rect2 = cup.get_global_rect()
	var mouth: Vector2 = cup.global_position + cup.get_cup_center()
	var spout_target: Vector2 = mouth + menu.SNAP_SPOUT_OFFSET
	# Bardağın sağ kenarının 30 px dışı: alanın içinde, düğmenin dışında.
	var near := Vector2(rect.end.x + 30, rect.position.y + 120)
	await move(near)
	await wait(0.6)
	var spout: Vector2 = menu.kettle.get_spout_global_pos()
	check(menu.snapped_cup_id == "endless", "Kenarın 30 px dışında bardağa kilitlenmeli (kilit: '%s')" % menu.snapped_cup_id)
	check(spout.distance_to(spout_target) < 3.0, "Demlik ağzı bardağın üstünde durmalı (fark %.1f px)" % spout.distance_to(spout_target))
	await button(true, near)
	await wait(0.4)
	check(menu.is_holding_pour and menu.pouring_cup_id == "endless" and cup.fill_progress > 0.0, "Alan içinde basılı tutunca dökmeli (dolum %.2f)" % cup.fill_progress)
	# Akış dikey: pot eğilmiş olsa da ağzı bardak ağzının tam üstünde, belli bir yükseklikte.
	var tip: Vector2 = menu.kettle.get_spout_global_pos()
	check(absf(tip.x - mouth.x) < 2.0 and mouth.y - tip.y > 40.0, "Dökerken akış dikey inmeli (ağız %s, hedef %s)" % [tip, mouth])
	# Bardağın üstüne geçip yine alanda kalmak dökmeyi kesmemeli.
	await move(mouth + Vector2(0, 60))
	await wait(0.2)
	check(menu.is_holding_pour, "Alan içinde gezinmek dökmeyi kesmemeli")
	# Bardaklar arası boşluğun ortası: hiçbir alanda değil.
	var gap := Vector2(rect.end.x + 60, rect.position.y + 120)
	await move(gap)
	await wait(0.6)
	check(menu.snapped_cup_id == "" and not menu.is_holding_pour, "Alandan çıkınca kilit ve dökme bitmeli (kilit: '%s')" % menu.snapped_cup_id)
	var follow: Vector2 = gap - Vector2(120, 40)
	check(menu.kettle.global_position.distance_to(follow) < 1.0, "Alandan çıkınca demlik fareye dönmeli (fark %.1f px)" % menu.kettle.global_position.distance_to(follow))
	await button(false, gap)
	check(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Fare imleci gizli kalmalı")
	print("MENU SNAP: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
