class_name EndingRules
extends RefCounted
## Beş ana son. Yanlış teşhisler aynı sonun metin varyantını değiştirir.
static func resolve(human_reports: int, fallen_reports: int, wrong_reports: int, wrong_serves: int, final_night: bool, rules: Dictionary = {}) -> Dictionary:
	var total := human_reports + fallen_reports
	var result := {"id": "", "variant": "errors" if wrong_reports + wrong_serves >= 2 else "standard"}
	var capture := int(rules.get("supplier_capture_threshold", 3))
	if human_reports >= capture:
		result.id = "human_supplier"
	elif fallen_reports >= capture:
		result.id = "fallen_supplier"
	elif final_night:
		var share := float(human_reports) / maxi(total, 1)
		if total >= int(rules.get("grey_minimum_reports", 2)) and share >= float(rules.get("grey_minimum_share", 0.4)) and share <= float(rules.get("grey_maximum_share", 0.6)) and wrong_reports + wrong_serves <= int(rules.get("grey_maximum_errors", 1)):
			result.id = "grey"
		else:
			result.id = "fallen_world"
	return result
