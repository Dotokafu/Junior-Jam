extends Node
## Düz JSON anahtarları + adlandırılmış parametreler. Arayüz metni kodda tutulmaz.
signal language_changed(language: String)
var language: String = "tr"
var messages: Dictionary = {}
var fallback: Dictionary = {}

func _init() -> void:
	fallback = _read("tr")
	language = str(ProjectSettings.get_setting("coffallen/language", "tr"))
	messages = fallback if language == "tr" else _read(language)

func t(key: String, parameters: Dictionary = {}) -> String:
	var message: String = messages.get(key, fallback.get(key, "[" + key + "]"))
	return message.format(parameters)

func set_language(locale: String) -> bool:
	var next := _read(locale)
	if next.is_empty():
		return false
	language = locale
	messages = next
	language_changed.emit(locale)
	return true

func _read(locale: String) -> Dictionary:
	if not locale.is_valid_filename() or "/" in locale or "\\" in locale:
		return {}
	var file := FileAccess.open("res://content/i18n/" + locale + ".json", FileAccess.READ)
	if file == null:
		push_error("I18N_CATALOG_NOT_FOUND: " + locale)
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("I18N_INVALID_JSON: " + locale)
		return {}
	return parser.data
