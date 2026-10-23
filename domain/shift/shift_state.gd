class_name ShiftState
extends RefCounted
## Bir vardiyanın kayıt edilebilir durumu. Godot sahnesi veya EventBus bilmez.
var day: int = 1
var mode: String = "story"
var run_seed: int = 0
var visits: Array = []
var phase: String = "morning_supplier"
var visit_index: int = 0
var line_index: int = 0
var stage: String = "dialogue"
var shelf: String = "human"
var tutorial: String = "locked"
var selected: Array = []
var drink: Dictionary = {}
var stock: Dictionary = {}
var records: Array = []
var human_reports: int = 0
var fallen_reports: int = 0
var wrong_reports: int = 0
var wrong_serves: int = 0
var served: int = 0
var ending: Dictionary = {}
var notes: Array = []

func serialize() -> Dictionary:
	return {
		"day": day, "mode": mode, "run_seed": run_seed, "visits": visits.duplicate(true), "phase": phase, "visit_index": visit_index,
		"line_index": line_index, "stage": stage, "shelf": shelf,
		"tutorial": tutorial, "selected": selected.duplicate(), "drink": drink.duplicate(true),
		"stock": stock.duplicate(), "records": records.duplicate(true),
		"human_reports": human_reports, "fallen_reports": fallen_reports,
		"wrong_reports": wrong_reports, "wrong_serves": wrong_serves,
		"served": served, "ending": ending.duplicate(), "notes": notes.duplicate()
	}

static func restore(data: Dictionary) -> ShiftState:
	var state := ShiftState.new()
	for key: String in state.serialize():
		if data.has(key):
			state.set(key, data[key])
	return state
