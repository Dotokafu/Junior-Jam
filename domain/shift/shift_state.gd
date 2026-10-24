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
## Sorgu: bu müşteriye sorulan soruların sırası, cevabı okunan soru (-1 yok) ve ziyaret kimliğine göre
## oyuncunun işaretlediği cümleler.
var asked: Array = []
var answering: int = -1
var marks: Dictionary = {}
## Şüphe (gizli): devlet ve örgüt, 0–100. Art arda aynı tarafa teslim, bu teslimatta dosya verildi mi,
## sorgusu yapılmış taraflar, sürmekte olan sorgunun tarafı ve tedarikçinin cevaba karşılığı.
var suspicion: Dictionary = {"state": 0, "order": 0}
var last_given: String = ""
var give_streak: int = 0
var delivery_reported: bool = false
var interrogated: Array = []
var interrogation: String = ""
var verdict: String = ""
## Tarif defteri: demlenerek bulunan tariflerin kimlikleri (boş başlar).
var discovered: Array = []

func serialize() -> Dictionary:
	return {
		"day": day, "mode": mode, "run_seed": run_seed, "visits": visits.duplicate(true), "phase": phase, "visit_index": visit_index,
		"line_index": line_index, "stage": stage, "shelf": shelf,
		"tutorial": tutorial, "selected": selected.duplicate(), "drink": drink.duplicate(true),
		"stock": stock.duplicate(), "records": records.duplicate(true),
		"human_reports": human_reports, "fallen_reports": fallen_reports,
		"wrong_reports": wrong_reports, "wrong_serves": wrong_serves,
		"served": served, "ending": ending.duplicate(), "notes": notes.duplicate(),
		"asked": asked.duplicate(), "answering": answering, "marks": marks.duplicate(true),
		"suspicion": suspicion.duplicate(), "last_given": last_given, "give_streak": give_streak,
		"delivery_reported": delivery_reported, "interrogated": interrogated.duplicate(),
		"interrogation": interrogation, "verdict": verdict, "discovered": discovered.duplicate()
	}

static func restore(data: Dictionary) -> ShiftState:
	var state := ShiftState.new()
	for key: String in state.serialize():
		if data.has(key):
			state.set(key, data[key])
	return state
