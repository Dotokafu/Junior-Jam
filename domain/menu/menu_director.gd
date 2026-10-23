class_name MenuDirector
extends RefCounted
## Ana menü seçeneklerini (Hikaye, Endless, Ayarlar) ve seçim çözümlemesini yöneten Domain Servisi.
const MenuCupScript = preload("res://domain/menu/menu_cup.gd")

var cups: Dictionary = {}  # id -> MenuCup
var active_cup_id: String = ""

func _init() -> void:
	_setup_options()

func _setup_options() -> void:
	cups["story"] = MenuCupScript.new("story", "menu.story", 1.0, 1.15)
	cups["endless"] = MenuCupScript.new("endless", "menu.endless", 1.0, 1.15)
	cups["settings"] = MenuCupScript.new("settings", "menu.settings", 1.0, 1.15)

func get_cup(id: String) -> RefCounted:
	return cups.get(id, null)

func get_all_cups() -> Array:
	var result: Array = []
	for id: String in ["story", "endless", "settings"]:
		if cups.has(id):
			result.append(cups[id])
	return result

## Verilen bardak dolduğunda tetiklenecek uygulama komutunu belirler (DDD Çözümleme).
func resolve_selection(cup_id: String, has_save: bool) -> Dictionary:
	match cup_id:
		"story":
			return {
				"type": "start",
				"action": "continue" if has_save else "new_game",
				"mode": "story"
			}
		"endless":
			return {
				"type": "start",
				"action": "new_game",
				"mode": "endless"
			}
		"settings":
			return {
				"type": "modal",
				"action": "open_settings",
				"kind": "menu"
			}
		_:
			return {}

## Doldurma ve boşalma döngüsünü günceller. Seçim tamamlandığında çözümleme sonucunu döner.
func update_pouring(target_cup_id: String, is_pouring: bool, delta: float, has_save: bool = false) -> Dictionary:
	active_cup_id = target_cup_id if is_pouring else ""
	var result: Dictionary = {}
	for cup_id: String in cups:
		var cup: RefCounted = cups[cup_id]
		if is_pouring and cup_id == target_cup_id:
			var completed: bool = cup.pour(delta)
			if completed:
				result = resolve_selection(cup_id, has_save)
		else:
			cup.drain(delta)
	return result

func reset_all() -> void:
	active_cup_id = ""
	for cup: RefCounted in cups.values():
		cup.reset()
