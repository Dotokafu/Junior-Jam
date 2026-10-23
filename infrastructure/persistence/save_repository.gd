class_name SaveRepository
extends RefCounted
## Kayıt dosyaları. Yuva 0 otomatik kayıttır (her komuttan sonra yazılır); 1..SLOT_COUNT elle kayıt.
const SLOT_COUNT := 3
const AUTO_SLOT := 0
## Testler oyuncunun kayıtlarına dokunmasın diye ön eki değiştirebilir.
static var prefix: String = "user://coffallen"

static func path(slot: int) -> String:
	return prefix + ("_v1.json" if slot == AUTO_SLOT else "_slot_%d.json" % slot)

static func exists(slot: int = AUTO_SLOT) -> bool:
	return FileAccess.file_exists(path(slot))

static func write(state: Dictionary, slot: int = AUTO_SLOT) -> bool:
	var target := path(slot)
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "saved_at": int(Time.get_unix_time_from_system()), "state": state}, "\t"))
	file.close()
	return DirAccess.rename_absolute(target + ".tmp", target) == OK

static func read(slot: int = AUTO_SLOT) -> Dictionary:
	return _read_file(slot).get("state", {})

## Kayıt kartları için özet: gün, evre, mod, fincan, kayıt zamanı. Boş/bozuk yuva: empty = true.
static func summaries() -> Array:
	var result: Array = []
	for slot in range(SLOT_COUNT + 1):
		var data := _read_file(slot)
		result.append(summary_for(slot, data.get("state", {}), int(data.get("saved_at", 0))))
	return result

static func summary_for(slot: int, state: Dictionary, saved_at: int) -> Dictionary:
	if state.is_empty():
		return {"slot": slot, "empty": true}
	return {"slot": slot, "empty": false, "day": int(state.get("day", 1)), "phase": str(state.get("phase", "")),
		"mode": str(state.get("mode", "story")), "served": int(state.get("served", 0)), "saved_at": saved_at}

static func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(path(slot))

static func _read_file(slot: int) -> Dictionary:
	var file := FileAccess.open(path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if int(data.get("version", 0)) != 1 or not data.get("state") is Dictionary:
		return {}
	return data
