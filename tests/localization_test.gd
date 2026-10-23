extends SceneTree
var failures: int = 0
var checked: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var locale: Node = root.get_node("I18n")
	var pattern := RegEx.new()
	pattern.compile('"([a-z_]+\\.[a-z_]+)"')
	for folder: String in ["application", "presentation", "infrastructure/content"]:
		check_folder("res://" + folder, pattern, locale)
	var formatted: String = locale.t("feedback.drink_ready", {"drink": "TEST"})
	check(formatted.begins_with("TEST") and "{drink}" not in formatted, "Adlandırılmış parametre")
	check(locale.t("unknown.test_key") == "[unknown.test_key]", "Eksik anahtar görünür olmalı")
	locale.messages = {}
	check(locale.t("button.brew") == locale.fallback["button.brew"], "Türkçe yedek katalog")
	print("LOCALIZATION: ", "PASS" if failures == 0 else "FAIL", " (", checked, " referans)")
	quit(failures)

func check_folder(path: String, pattern: RegEx, locale: Node) -> void:
	for child: String in DirAccess.get_directories_at(path):
		check_folder(path + "/" + child, pattern, locale)
	for file_name: String in DirAccess.get_files_at(path):
		if not file_name.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string(path + "/" + file_name)
		for result: RegExMatch in pattern.search_all(source):
			checked += 1
			check(locale.fallback.has(result.get_string(1)), "Eksik çeviri: " + result.get_string(1))

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
