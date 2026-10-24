class_name InterrogationRules
extends RefCounted
## Sorgu kuralları: müşteri başına sınırlı soru hakkı ve cümle işaretleme. Saf kural; sahne ya da
## EventBus bilmez. İşaretler yalnızca oyuncunun notudur, oyun eşleşme söylemez.
const QUESTION_LIMIT := 2

## "" uygunsa; aksi halde hata kodu: unknown, asked, limit.
static func can_ask(questions: Array, asked: Array, index: int) -> String:
	if index < 0 or index >= questions.size():
		return "unknown"
	if index in asked:
		return "asked"
	if asked.size() >= QUESTION_LIMIT:
		return "limit"
	return ""

static func questions_left(asked: Array) -> int:
	return maxi(QUESTION_LIMIT - asked.size(), 0)

## İşaretli cümlelerin yeni listesi: cümle yoksa eklenir, varsa çıkarılır. Verilen liste değişmez.
static func toggle_mark(marks: Array, line: String) -> Array:
	var result := marks.duplicate()
	if line == "":
		return result
	if line in result:
		result.erase(line)
	else:
		result.append(line)
	return result
