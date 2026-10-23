class_name SettingsRepository
extends RefCounted
## Oyuncu ayarları (ekran, ses, yazı hızı, hareket). Oyun kaydından ayrı tutulur.
const SETTINGS_PATH := "user://coffallen_settings.cfg"
const DEFAULTS := {"fullscreen": false, "window_size": Vector2i(1920, 1080), "muted": false, "reduced_motion": false, "text_speed": "normal"}

static func read() -> Dictionary:
	var settings := DEFAULTS.duplicate()
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK:
		return settings
	for key: String in DEFAULTS:
		var value: Variant = file.get_value("settings", key, DEFAULTS[key])
		if typeof(value) == typeof(DEFAULTS[key]):
			settings[key] = value
	return settings

static func write(settings: Dictionary) -> bool:
	var file := ConfigFile.new()
	for key: String in DEFAULTS:
		file.set_value("settings", key, settings.get(key, DEFAULTS[key]))
	return file.save(SETTINGS_PATH) == OK
