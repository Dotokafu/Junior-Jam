class_name SuspicionRules
extends RefCounted
## Devletin ("state": Defne, sabah) ve örgütün ("order": Vey, gece) senden gizli şüphesi, 0–100.
## Saf kural: her fonksiyon yeni bir sözlük döndürür, verileni değiştirmez. Sayılar içerikten gelir
## (endings.json → rules.suspicion); eksik anahtar varsayılanı kullanır.
const DEFAULTS := {"wary": 34, "threat": 67, "limit": 100, "give_other": 15, "give_streak": 10,
	"give_trust": -10, "wrong_report": 20, "decline": 8, "wrong_serve": 12, "wrong_recipe": 5}
const ENDINGS := {"state": "state_arrest", "order": "order_vanish"}

static func fresh() -> Dictionary:
	return {"state": 0, "order": 0}

static func other(side: String) -> String:
	return "order" if side == "state" else "state"

## Bir tarafa dosya verildi. streak: aynı tarafa bundan önceki ardışık teslim sayısı ("bariz"lık).
## correct: verilen kişi o tarafın istediği türdense; değilse o taraf yanıltılmıştır.
static func after_report(values: Dictionary, side: String, streak: int, correct: bool, rules: Dictionary) -> Dictionary:
	var result := values.duplicate()
	var rival := other(side)
	result[rival] = _clamp(int(result[rival]) + _rule(rules, "give_other") + streak * _rule(rules, "give_streak"), rules)
	result[side] = _clamp(int(result[side]) + (_rule(rules, "give_trust") if correct else _rule(rules, "wrong_report")), rules)
	return result

## Teslimatta tedarikçi sordu, dosya verilmedi.
static func after_decline(values: Dictionary, side: String, rules: Dictionary) -> Dictionary:
	return _add(values, side, _rule(rules, "decline"), rules)

## served_side: içeceğin rafı; customer: müşterinin gerçek türü; order_ok: istediği içecek mi.
## Yanlış raf müşterinin tarafını işkillendirir: insana Fallen içeceği → devlet (polise gider),
## Fallen'a insan içeceği → örgüt (aç kalır). Doğru raf ama başka içecek de biraz işkillendirir.
static func after_serve(values: Dictionary, served_side: String, customer: String, order_ok: bool, rules: Dictionary) -> Dictionary:
	var side := "state" if customer == "human" else "order"
	if served_side != customer:
		return _add(values, side, _rule(rules, "wrong_serve"), rules)
	if not order_ok:
		return _add(values, side, _rule(rules, "wrong_recipe"), rules)
	return values.duplicate()

## Sorgu sahnesindeki cevabın etkisi (içerikte, negatif olabilir).
static func after_answer(values: Dictionary, side: String, effect: int, rules: Dictionary) -> Dictionary:
	return _add(values, side, effect, rules)

static func level(value: int, rules: Dictionary) -> String:
	if value >= _rule(rules, "threat"):
		return "threat"
	if value >= _rule(rules, "wary"):
		return "wary"
	return "calm"

static func reached(values: Dictionary, side: String, rules: Dictionary) -> bool:
	return int(values.get(side, 0)) >= _rule(rules, "limit")

## Dolan tarafın kötü sonu ("" yoksa). İkisi birden doluysa devlet önce gelir.
static func bad_ending(values: Dictionary, rules: Dictionary) -> String:
	for side: String in ["state", "order"]:
		if reached(values, side, rules):
			return ENDINGS[side]
	return ""

static func _add(values: Dictionary, side: String, amount: int, rules: Dictionary) -> Dictionary:
	var result := values.duplicate()
	result[side] = _clamp(int(result[side]) + amount, rules)
	return result

static func _clamp(value: int, rules: Dictionary) -> int:
	return clampi(value, 0, _rule(rules, "limit"))

static func _rule(rules: Dictionary, key: String) -> int:
	return int(rules.get(key, DEFAULTS[key]))
