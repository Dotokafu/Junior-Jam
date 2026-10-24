@tool
extends Node
## Yalnızca özel test ortamında çalışır; normal editörde yan etkisi yoktur.
var errors: Array[String] = []

func _ready() -> void:
	if Engine.is_editor_hint() and OS.get_environment("COFFALLEN_EDITOR_PREVIEW_TEST") == "1":
		verify.call_deferred()

func verify() -> void:
	var screen: Control = get_node("Cafe")
	var save_path := "user://coffallen_v1.json"
	var save_time := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else 0
	var variants: Array[String] = ["day", "night", "book_human", "book_fallen", "dossier", "intro", "fall", "ending"]
	check(get_tree().root.get_node_or_null("Session") == null, "PREVIEW_MUST_NOT_START_SESSION")
	for variant: String in variants:
		screen.editor_preview = variant
		await get_tree().process_frame
		await get_tree().process_frame
		check(not screen.view.is_empty(), "EMPTY_VIEW: " + variant)
		check(screen.main.get_child_count() > 5, "EMPTY_LAYOUT: " + variant)
		check(screen.art.reduced_motion, "PREVIEW_MUST_BE_STATIC")
		if variant == "night":
			check(screen.art.night and screen.art.fallen_shelf, "NIGHT_PREVIEW")
		if variant.begins_with("book_"):
			check(is_instance_valid(screen.book) and screen.book.get_child_count() > 5, "BOOK_PREVIEW")
		if variant == "dossier":
			check(is_instance_valid(screen.dossier) and screen.dossier.view.records.size() == 1, "DOSSIER_PREVIEW")
	screen.editor_character = "eren"
	screen.editor_preview = "night"
	await get_tree().process_frame
	await get_tree().process_frame
	check(screen.view.person.id == "eren", "CHARACTER_PREVIEW")
	var after := FileAccess.get_modified_time(save_path) if FileAccess.file_exists(save_path) else 0
	check(save_time == after, "PREVIEW_MUST_NOT_WRITE_SAVE")
	var file := FileAccess.open("/tmp/coffallen-editor-preview-result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": errors.is_empty(), "variants": variants, "errors": errors}))
	file.close()
	print("EDITOR_PREVIEW: ", "PASS" if errors.is_empty() else "FAIL", " / ", variants.size(), " variants")

func check(ok: bool, code: String) -> void:
	if not ok:
		errors.append(code)
		push_error(code)
