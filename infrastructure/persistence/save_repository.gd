class_name SaveRepository
extends RefCounted
const SAVE_PATH := "user://coffallen_v1.json"

static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func write(state: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "state": state}, "\t"))
	file.close()
	return DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) == OK

static func read() -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if int(data.get("version", 0)) != 1 or not data.get("state") is Dictionary:
		return {}
	return data.state
