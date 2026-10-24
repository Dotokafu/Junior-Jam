# Sorgu Çekirdeği Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Müşteriler siparişi dolaylı söylesin. Oyuncu müşteri başına 2 soru sorup cevaplardaki şüpheli cümleleri işaretlesin. Hangi raftan servis ettiği teşhisi olsun.

**Architecture:**
- Saf kurallar yeni `domain/interrogation/interrogation_rules.gd` dosyasında: soru hakkı ve işaret ekle/kaldır.
- `GameSession` iki yeni aşama ve iki komut kazanır:
  - `interview`: soru seçimi.
  - `answer`: cevap satırları.
  - `ask` ve `mark` komutları.
- İçerik geriye uyumlu genişler. Ziyarete isteğe bağlı `questions` ve `order_line` alanları eklenir; soru metinleri `encounter_pools.json` → `questions` havuzunda durur. Soruları olmayan ziyaretler eskisi gibi doğrudan demlemeye geçer.
- Sunum:
  - Konuşma balonu soru düğmeleri ve bir "İşaretle" düğmesi gösterir.
  - Dava dosyası işaretli cümleleri listeler.

**Tech Stack:** Godot 4.7.2, GDScript. Testler başsız SceneTree script'leri; görsel test pencereli.

**Kaynak belge:** `docs/superpowers/specs/2026-10-24-sorgu-ve-tempo-design.md`

**Bu planın dışında (sonraki planlar):**
- **Plan 2:** İstihbarat sekmesi ve güven sayaçları.
- **Plan 3:** Rastgele müşteriler için özellik havuzu. Bu planda rastgele ziyaretler sorusuz kalır.

**Belgeden iki bilinçli sapma:**
1. **İşaretleme düğmeyle yapılır:** Balona tıklamak konuşmayı ilerlettiği için cümleye tıklamak çakışırdı. İşaretleme balondaki "İşaretle [N]" düğmesiyle ya da `N` tuşuyla yapılır ve o an balonda görünen cümleyi işaretler.
2. **Soru metinleri içerikte durur:** Kod içinde metin olmasın diye soru metinleri `tr.json`'da değil, içerikte (`encounter_pools.json` → `questions`) durur; ziyaretler soruyu kimliğiyle anar.

**Commit notu:** Kullanıcı kuralı gereği commit adımları yalnızca kullanıcı onay verdiyse çalıştırılır. Onay yoksa adım atlanır ve değişiklikler çalışma alanında kalır.

---

## Dosya yapısı

| Dosya | Sorumluluk |
| --- | --- |
| `domain/interrogation/interrogation_rules.gd` (yeni) | Soru hakkı, sorulabilirlik, işaret ekle/kaldır. Saf kural. |
| `domain/shift/shift_state.gd` | Yeni kayıt alanları: `asked`, `answering`, `marks` |
| `application/game_session.gd` | `interview` / `answer` aşamaları, `ask` / `mark` komutları, snapshot alanları |
| `infrastructure/content/content_repository.gd` | `questions` ve `order_line` doğrulaması |
| `content/encounter_pools.json` | `questions` havuzu; gece/gündüz rastgele müşteri sayısı |
| `content/days.json` | 1. günün örnek sorgu içeriği |
| `content/i18n/tr.json` | Arayüz metinleri |
| `presentation/dialogue/speech_balloon.gd/.tscn` | Soru düğmeleri, kalan hak, İşaretle düğmesi |
| `presentation/cafe_screen.gd` | Balonu besleme, `ask`/`mark` komutları, `1–4` ve `N` kısayolları |
| `presentation/ui/case_file.gd` | İşaretli cümleleri dosyada gösterme |
| `tests/domain_test.gd`, `tests/flow_test.gd`, `tests/save_test.gd`, `tests/encounter_test.gd`, `tests/visual_smoke.gd` | Testler |
| `docs/ICERIK_EKLEME.md`, `README.md` | İçerik yazarı rehberi, kısayollar |

---

### Task 1: Sorgu kuralları (domain)

**Files:**
- Create: `domain/interrogation/interrogation_rules.gd`
- Test: `tests/domain_test.gd`

- [ ] **Step 1: Write the failing test**

`tests/domain_test.gd` içinde `check(EndingRules.resolve(3, 0, 0, 0, false).id == "human_supplier", ...)` satırının hemen üstüne ekle:

```gdscript
	var questions := [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	check(InterrogationRules.can_ask(questions, [], 0) == "", "İlk soru sorulabilir")
	check(InterrogationRules.can_ask(questions, [0], 0) == "asked", "Aynı soru iki kez sorulmaz")
	check(InterrogationRules.can_ask(questions, [0, 1], 2) == "limit", "Soru hakkı ikidir")
	check(InterrogationRules.can_ask(questions, [], 5) == "unknown", "Olmayan soru sorulmaz")
	check(InterrogationRules.questions_left([0]) == 1 and InterrogationRules.questions_left([0, 1, 2]) == 0, "Kalan soru hakkı")
	var marks := InterrogationRules.toggle_mark([], "Soğuk mu? Hiç fark etmedim.")
	check(marks == ["Soğuk mu? Hiç fark etmedim."], "Cümle işaretlenir")
	var cleared := InterrogationRules.toggle_mark(marks, "Soğuk mu? Hiç fark etmedim.")
	check(cleared.is_empty() and marks.size() == 1, "Tekrar işaretlemek kaldırır, eski liste değişmez")
	check(InterrogationRules.toggle_mark(marks, "") == marks, "Boş cümle işaretlenmez")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s tests/domain_test.gd 2>&1 | grep -E "DOMAIN|SCRIPT ERROR" | head -3`
Expected: `SCRIPT ERROR: ... Identifier "InterrogationRules" not declared`

- [ ] **Step 3: Write minimal implementation**

`domain/interrogation/interrogation_rules.gd`:

```gdscript
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
```

- [ ] **Step 4: Register the class and run test to verify it passes**

Yeni `class_name`'in global sınıf önbelleğine girmesi için önce içe aktar:

Run: `godot --headless --path . --import >/dev/null 2>&1; godot --headless --path . -s tests/domain_test.gd 2>&1 | grep -E "DOMAIN|SCRIPT ERROR" | head -3`
Expected: `DOMAIN: PASS (0 hata)`

- [ ] **Step 5: Commit (kullanıcı onayıyla)**

```bash
git add domain/interrogation/interrogation_rules.gd domain/interrogation/interrogation_rules.gd.uid tests/domain_test.gd
git commit -m "feat: interrogation rules (question limit, line marks)"
```

---

### Task 2: Kayıt alanları ve oturum aşamaları

**Files:**
- Modify: `domain/shift/shift_state.gd`
- Modify: `application/game_session.gd` (komut dağıtımı, `_lines`, `_next`, `_reset_visit`, `_advance_customer`, `snapshot`; yeni `_ask`, `_mark`, `_current_line`, `_order_line`)
- Modify: `content/i18n/tr.json`
- Test: `tests/flow_test.gd`, `tests/save_test.gd`

- [ ] **Step 1: Write the failing flow test**

`tests/flow_test.gd`'de `var latte_seen: bool = false` satırının altına ekle:

```gdscript
var interviewed: bool = false
```

`check(latte_seen, ...)` satırının altına ekle:

```gdscript
	check(interviewed, "Akışta en az bir müşteri sorgulanmalı")
```

`while session.state.phase != "ending" and guard < 700:` satırını şuyla değiştir:

```gdscript
	while session.state.phase != "ending" and guard < 1500:
```

`check(guard < 700, ...)` satırını şuyla değiştir:

```gdscript
	check(guard < 1500, "Akış kilitlenmemeli: " + strategy)
```

`elif state.stage == "reaction":` dalının hemen üstüne iki dal ekle:

```gdscript
		elif state.stage == "interview":
			var questions: Array = session._visit().get("questions", [])
			check(snapshot.questions.size() == questions.size(), "Sorgu sırasında sorular görünmeli")
			check(not str(snapshot.questions).contains("answer") and not snapshot.visit.has("questions"), "Cevaplar sorulmadan görünmemeli")
			if state.asked.size() < InterrogationRules.QUESTION_LIMIT and state.asked.size() < questions.size():
				command("mark")
				check(session.state.marks.get(session._record_id(), []).has(snapshot.line), "Görünen cümle işaretlenmeli")
				command("ask", {"index": state.asked.size()})
				check(state.stage == "answer", "Soru sorunca cevap gelmeli")
				interviewed = true
			else:
				var before: int = state.asked.size()
				command("ask", {"index": 0})
				check(state.asked.size() == before, "Sorulmuş soru ya da hak bitince soru sorulamaz")
				command("next")
				check(state.stage == "brewing", "Sorgudan siparişe geçilmeli")
		elif state.stage == "answer":
			command("next")
```

- [ ] **Step 2: Write the failing save test**

`tests/save_test.gd`'de `# Eski kayıt: sonradan eklenen malzemenin stoğu açılır...` satırının üstüne ekle:

```gdscript
	# Sorgu alanları olmayan eski kayıt varsayılanlarla yüklenir.
	var legacy: Dictionary = session.state.serialize()
	legacy.erase("asked")
	legacy.erase("answering")
	legacy.erase("marks")
	Saves.write(legacy, 3)
	bus.request("load_slot", {"slot": 3})
	check(session.state.asked.is_empty() and session.state.answering == -1 and session.state.marks.is_empty(), "Eski kayıt sorgu alanları olmadan yüklenmeli")
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `for t in flow_test save_test; do godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -2; done`
Expected: `SCRIPT ERROR` (`asked` / `marks` alanları yok) ya da `FAIL`.

- [ ] **Step 4: Add state fields**

`domain/shift/shift_state.gd`'de `var notes: Array = []` altına ekle:

```gdscript
## Sorgu: bu müşteriye sorulan soruların sırası, cevabı okunan soru (-1 yok) ve ziyaret kimliğine göre
## oyuncunun işaretlediği cümleler.
var asked: Array = []
var answering: int = -1
var marks: Dictionary = {}
```

`serialize()` içindeki dönüş sözlüğünün son satırını şuyla değiştir:

```gdscript
		"served": served, "ending": ending.duplicate(), "notes": notes.duplicate(),
		"asked": asked.duplicate(), "answering": answering, "marks": marks.duplicate(true)
```

- [ ] **Step 5: Add session stages and commands**

`application/game_session.gd`:

Üstteki preload'ların yanına ekle:

```gdscript
const Interrogation = preload("res://domain/interrogation/interrogation_rules.gd")
## Soru hatası → bildirim anahtarı.
const ASK_ERRORS := {"unknown": "feedback.ask_unknown", "asked": "feedback.ask_asked", "limit": "feedback.ask_limit"}
```

`_on_command` içindeki `match action:` bloğuna `"report"` satırının altına ekle:

```gdscript
			"ask": _ask(int(payload.get("index", -1)))
			"mark": _mark()
```

`_lines()` fonksiyonunun son satırını (`return _visit().get("dialogue", [])`) şuyla değiştir:

```gdscript
	if state.stage == "answer":
		var questions: Array = _visit().get("questions", [])
		if state.answering >= 0 and state.answering < questions.size():
			return questions[state.answering].get("answer", [])
		return []
	return _visit().get("dialogue", [])
```

`_next()` içindeki `elif state.stage == "dialogue":` dalını şuyla değiştir. Sonraki `elif state.stage == "reaction":` aynen kalır:

```gdscript
	elif state.stage == "dialogue":
		state.line_index += 1
		if state.line_index >= _lines().size():
			if state.phase in ["morning_supplier", "night_supplier"]:
				state.stage = "decision"
			elif _visit().get("questions", []).is_empty():
				state.stage = "brewing"
			else:
				state.stage = "interview"
	elif state.stage == "answer":
		state.line_index += 1
		if state.line_index >= _lines().size():
			state.answering = -1
			state.stage = "interview"
	elif state.stage == "interview":
		state.stage = "brewing"
```

`_reset_visit()` ve `_advance_customer()` içinde `state.drink = {}` satırının altına ikisine de ekle:

```gdscript
	state.asked = []
	state.answering = -1
```

`_switch_shelf()` fonksiyonunun üstüne yeni fonksiyonları ekle:

```gdscript
## Sorgu: soru sorulur, cevap satırları okunur, sonra soru listesine dönülür.
func _ask(index: int) -> void:
	if state.stage != "interview":
		return
	var problem := Interrogation.can_ask(_visit().get("questions", []), state.asked, index)
	if problem != "":
		EventBus.feedback.emit(I18n.t(ASK_ERRORS[problem]))
		return
	state.asked.append(index)
	state.answering = index
	state.line_index = 0
	state.stage = "answer"

## Balonda o an görünen cümleyi bu ziyaretin notlarına ekler ya da notlardan çıkarır.
func _mark() -> void:
	if state.phase not in ["day", "night"] or state.stage not in ["dialogue", "answer", "interview"]:
		return
	var id := _record_id()
	state.marks[id] = Interrogation.toggle_mark(state.marks.get(id, []), _current_line())

## Sipariş cümlesi: ziyaretin order_line alanı; yoksa (eski içerik) ilk konuşma satırı.
func _order_line() -> String:
	var visit := _visit()
	if visit.get("order_line", "") != "":
		return visit.order_line
	var dialogue: Array = visit.get("dialogue", [])
	return dialogue[0] if not dialogue.is_empty() else I18n.t("dialogue.brewing")

func _current_line() -> String:
	match state.stage:
		"dialogue", "answer":
			var lines := _lines()
			return lines[mini(state.line_index, lines.size() - 1)] if not lines.is_empty() else ""
		"interview", "brewing":
			return _order_line()
	return ""
```

`snapshot()` içinde şu bloğu:

```gdscript
	if content_ok and state.stage == "dialogue":
		var lines := _lines()
		view.line = lines[mini(state.line_index, lines.size() - 1)] if not lines.is_empty() else ""
	elif state.stage == "brewing":
		# Coffee Talk gibi: demlerken balonda siparişin kendisi durur.
		var lines := _lines()
		view.line = lines[0] if not lines.is_empty() else I18n.t("dialogue.brewing")
	elif state.stage == "tutorial":
```

şuyla değiştir:

```gdscript
	if content_ok and state.stage in ["dialogue", "answer", "interview", "brewing"]:
		# Demlerken ve sorgu sırasında balonda siparişin kendisi durur.
		view.line = _current_line()
	elif state.stage == "tutorial":
```

`snapshot()` içinde `view.records = []` satırının üstüne ekle:

```gdscript
	# Cevaplar yalnızca sorulunca "line" olarak gelir; ziyaretin soru listesi sunuma gitmez.
	view.visit.erase("questions")
	view["questions"] = []
	if content_ok and state.stage == "interview":
		var questions: Array = _visit().get("questions", [])
		for i in range(questions.size()):
			view.questions.append({"text": str(content.pools.get("questions", {}).get(questions[i].get("id", ""), "")), "asked": i in state.asked})
	view["questions_left"] = Interrogation.questions_left(state.asked)
	view["marked"] = view.line != "" and view.line in state.marks.get(_record_id(), [])
```

`snapshot()` içinde `public_record.erase("truth")` satırının altına ekle:

```gdscript
		public_record["marks"] = state.marks.get(record.id, []).duplicate()
```

- [ ] **Step 6: Add messages**

`content/i18n/tr.json`'da `"key.latte_art": "[L]",` satırının altına ekle:

```json
  "feedback.ask_unknown": "Böyle bir soru yok.",
  "feedback.ask_asked": "Bunu zaten sordun.",
  "feedback.ask_limit": "Soru hakkın bitti.",
```

- [ ] **Step 7: Run tests**

Run: `godot --headless --path . --import >/dev/null 2>&1; for t in domain_test flow_test save_test localization_test; do godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -2; done`

Expected:
- `DOMAIN`, `SAVES` ve `LOCALIZATION` PASS.
- `FLOW` FAIL, yalnızca "Akışta en az bir müşteri sorgulanmalı" hatasıyla. İçerikte henüz soru yok; Task 3'te düzelecek.

- [ ] **Step 8: Commit (kullanıcı onayıyla)**

```bash
git add domain/shift/shift_state.gd application/game_session.gd content/i18n/tr.json tests/flow_test.gd tests/save_test.gd
git commit -m "feat: interview and answer stages with ask/mark commands"
```

---

### Task 3: İçerik biçimi, doğrulama ve 1. günün örnek sorguları

**Files:**
- Modify: `infrastructure/content/content_repository.gd`
- Modify: `content/encounter_pools.json`
- Modify: `content/days.json` (1. gün `day` ve `night`)
- Modify: `content/i18n/tr.json`
- Test: `tests/encounter_test.gd`

- [ ] **Step 1: Write the failing test**

`tests/encounter_test.gd`'de `var catalog := content.catalog()` satırının altına ekle:

```gdscript
	var first_day: Dictionary = catalog.days[0]
	for visit: Dictionary in first_day.day + first_day.night:
		check(visit.get("questions", []).size() == 3 and visit.get("order_line", "") != "", "1. günün müşterileri sorgulanabilir olmalı: " + visit.character)
	var broken := ContentRepository.new()
	broken.load_all()
	broken.days[0].night[0]["questions"] = [{"id": "olmayan_soru", "answer": ["..."]}]
	broken.errors.clear()
	broken.validate_visits()
	check(not broken.errors.is_empty(), "Havuzda olmayan soru içerik hatası vermeli")
```

`check(endless.size() == 4 ...)` ve `check(daytime.size() == 3 ...)` satırları aynen kalır; Endless sayıları değişmiyor.

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s tests/encounter_test.gd 2>&1 | grep -E "ENCOUNTERS|SCRIPT ERROR|ERROR" | head -4`
Expected: `SCRIPT ERROR` (`validate_visits` yok) ya da sorgulanabilirlik kontrolünde FAIL.

- [ ] **Step 3: Extract visit validation and add question checks**

`infrastructure/content/content_repository.gd`:

Dosyanın başındaki değişkenlerin altına ekle:

```gdscript
const MAX_QUESTIONS := 4
```

`load_all()` içindeki şu bloğu:

```gdscript
	for day: Dictionary in days:
		for period: String in ["day", "night"]:
			if day.get(period, []).is_empty():
				errors.append(_message("error.empty_shift") + str(day.get("number", "?")))
			for visit: Dictionary in day.get(period, []):
				if not characters.has(visit.character) or not _valid_order(visit.get("order"), characters[visit.character].species, recipe_ids):
					errors.append(_message("error.invalid_visit") + str(visit))
```

şu tek satırla değiştir:

```gdscript
	validate_visits(recipe_ids)
```

`_validate_ingredients()` fonksiyonunun üstüne ekle:

```gdscript
## Hikâye ziyaretleri: karakter, sipariş ve (varsa) sorgu alanları. Testler içeriği bozup tekrar çağırabilir.
func validate_visits(recipe_ids: Array = []) -> void:
	if recipe_ids.is_empty():
		recipe_ids = recipes.map(func(recipe: Dictionary) -> String: return recipe.id)
	for day: Dictionary in days:
		for period: String in ["day", "night"]:
			if day.get(period, []).is_empty():
				errors.append(_message("error.empty_shift") + str(day.get("number", "?")))
			for visit: Dictionary in day.get(period, []):
				if not characters.has(visit.character) or not _valid_order(visit.get("order"), characters[visit.character].species, recipe_ids):
					errors.append(_message("error.invalid_visit") + str(visit))
				elif not _valid_questions(visit):
					errors.append(_message("error.invalid_questions") + str(visit.character))

## questions: en fazla MAX_QUESTIONS; her soru havuzdaki bir kimlik ve boş olmayan cevap satırları.
func _valid_questions(visit: Dictionary) -> bool:
	if visit.has("order_line") and not visit.order_line is String:
		return false
	var questions: Variant = visit.get("questions", [])
	if not questions is Array or questions.size() > MAX_QUESTIONS:
		return false
	for question: Variant in questions:
		if not question is Dictionary or not pools.get("questions", {}).has(question.get("id", "")):
			return false
		var answer: Variant = question.get("answer", [])
		if not answer is Array or answer.is_empty():
			return false
	return true
```

`tr.json`'da `"error.unreachable_order"` hangi bölümdeyse aynı bölüme ekle:

```json
  "error.invalid_questions": "Geçersiz sorgu (soru havuzda yok ya da cevap boş): ",
```

- [ ] **Step 4: Add question pool and shift sizes**

`content/encounter_pools.json`'da `"story_random_visits": {"day": 0, "night": 1},` satırını şuyla değiştir. Değerler gündüz 2–3, gece 3–4 müşteri verir:

```json
  "story_random_visits": {"day": 1, "night": 2},
  "questions": {
    "where_from": "Bu saatte nereden geliyorsun?",
    "sleep": "En son ne zaman uyudun?",
    "sirens": "Siren çaldığında neredeydin?",
    "cold": "Dışarısı soğuk muydu?",
    "previous_barista": "Benden öncekini tanır mıydın?",
    "work": "Ne iş yaparsın?"
  },
```

- [ ] **Step 5: Rewrite day 1 visits**

`content/days.json`'da 1. günün (`"number": 1`) `day` ve `night` dizilerini şunlarla değiştir. Metinler yer tutucudur, hikâye yazarı değiştirir:

```json
    "day": [
      {
        "character": "ada",
        "order": "latte",
        "dialogue": [
          "Bütün gece ayaktaydım.",
          "Hastanede yine elektrik kesildi. Kan bankasını elle soğuttuk.",
          "İnsanlar üzerimdeki lekelere bakıyor.",
          "Kimse ne kadar yorulduğumu sormuyor."
        ],
        "order_line": "Bana sıradan bir sabahı hatırlatacak bir şey ver. Yumuşak olsun, sütlü.",
        "questions": [
          {"id": "where_from", "answer": ["Hastaneden. Ellerimdeki leke kan bankasından; temizlemeye vakit olmadı."]},
          {"id": "sleep", "answer": ["Dün sabah, galiba. Güneş doğarken gözlerim kapandı, sonra yine çağırdılar."]},
          {"id": "sirens", "answer": ["Ameliyathanedeydim. Siren çalınca kimse bıçağı bırakmaz."]}
        ]
      },
      {
        "character": "mira",
        "order": "tea",
        "dialogue": [
          "Postaneden çıktım, ellerim hâlâ titriyor.",
          "Fotoğraf bazen gerçeği yakalar. Bazen yalnızca birinin en kötü anını."
        ],
        "order_line": "Titreyen ellere iyi gelecek bir şey… limonlu, naneli olsun.",
        "questions": [
          {"id": "work", "answer": ["Mektup ayırıyorum. Çoğunun sahibi artık yok; yine de ayırıyorum."]},
          {"id": "cold", "answer": ["İliklerime kadar. Bak, parmaklarım hâlâ buz gibi."]},
          {"id": "previous_barista", "answer": ["Tanırdım. Hep aynı şarkıyı mırıldanırdı. Bir gece gitti, dönmedi."]}
        ]
      }
    ],
    "night": [
      {
        "character": "eren",
        "order": "red",
        "dialogue": [
          "Bu saatte açık olacağını söylemişti.",
          "Kim mi? Senden önce tezgâhın arkasında duran kişi."
        ],
        "order_line": "Eskisi gibi bir şey. Sıcak… biraz demir tadında.",
        "questions": [
          {"id": "where_from", "answer": ["Yürüyordum. Güneş tam tepedeydi, sokaklar bomboştu."]},
          {"id": "cold", "answer": ["Soğuk mu? Hiç fark etmedim."]},
          {"id": "previous_barista", "answer": ["Ellerini hatırlıyorum. Bardağı tutuşunu. Seninkiler de benziyor."]}
        ]
      }
    ],
```

`morning` ve `evening` aynen kalır.

- [ ] **Step 6: Run tests**

Run: `for t in encounter_test flow_test domain_test save_test localization_test; do godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -2; done`
Expected: hepsi PASS.

FLOW'da bir son değişirse (gece başına daha çok rastgele müşteri, daha çok servis) çıktıdaki `strateji → son` satırına bak. Beklenen sonlar `tests/flow_test.gd`'deki sözlükte; değişen son yalnızca müşteri sayısından geliyorsa sözlüğü değil `story_random_visits` gece değerini 1'e çekmeyi dene.

- [ ] **Step 7: Commit (kullanıcı onayıyla)**

```bash
git add infrastructure/content/content_repository.gd content/encounter_pools.json content/days.json content/i18n/tr.json tests/encounter_test.gd
git commit -m "feat: question pool, visit validation, day 1 interrogation content"
```

---

### Task 4: Konuşma balonunda sorular ve İşaretle düğmesi

**Files:**
- Modify: `presentation/dialogue/speech_balloon.tscn`
- Modify: `presentation/dialogue/speech_balloon.gd`
- Modify: `presentation/cafe_screen.gd` (`_ready` bağlantıları, `_update_balloon`, `_unhandled_key_input`)
- Modify: `content/i18n/tr.json`

- [ ] **Step 1: Add nodes to the balloon scene**

`presentation/dialogue/speech_balloon.tscn`'de `[node name="Footer" type="HBoxContainer" parent="Panel/Box"]` satırının üstüne ekle:

```
[node name="Questions" type="VBoxContainer" parent="Panel/Box"]
visible = false
theme_override_constants/separation = 6

```

`[node name="Hint" type="Label" parent="Panel/Box/Footer"]` satırının üstüne ekle:

```
[node name="MarkButton" type="Button" parent="Panel/Box/Footer"]
visible = false

```

- [ ] **Step 2: Add balloon logic**

`presentation/dialogue/speech_balloon.gd`:

`signal line_started` altına ekle:

```gdscript
signal question_pressed(index: int)
signal mark_pressed
```

`var awaiting_next: bool = false` altına ekle:

```gdscript
var interview_key: String = ""
```

`@onready var arrow: Label = $Panel/Box/Footer/Arrow` altına ekle:

```gdscript
@onready var questions_box: VBoxContainer = $Panel/Box/Questions
@onready var mark_button: Button = $Panel/Box/Footer/MarkButton
```

`_ready()` içinde `decision_button.pressed.connect(...)` satırının altına ekle:

```gdscript
	mark_button.pressed.connect(func() -> void: mark_pressed.emit())
```

`close()` fonksiyonunun üstüne ekle:

```gdscript
## Sorgu: soru düğmeleri (sorulanlar ve hak bitince kapalı), kalan hak; İşaretle düğmesi.
## questions: [{text, asked}]. Liste değişmedikçe düğmeler yeniden kurulmaz.
func set_interview(questions: Array, left: int, marked: bool, can_mark: bool) -> void:
	mark_button.visible = can_mark
	mark_button.text = I18n.t("balloon.marked" if marked else "balloon.mark")
	var key := "%s|%d" % [str(questions), left]
	if key == interview_key:
		return
	interview_key = key
	for child: Node in questions_box.get_children():
		child.queue_free()
	questions_box.visible = not questions.is_empty()
	for i in range(questions.size()):
		var button := Button.new()
		button.text = I18n.t("balloon.question", {"number": i + 1, "text": questions[i].text})
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = TEXT_WIDTH
		button.disabled = questions[i].asked or left <= 0
		button.pressed.connect(func() -> void: question_pressed.emit(i))
		questions_box.add_child(button)
	if not questions.is_empty():
		var remaining := Label.new()
		remaining.theme_type_variation = &"Caption"
		remaining.text = I18n.t("balloon.questions_left", {"count": left})
		questions_box.add_child(remaining)
	panel.reset_size()
	_place.call_deferred()
```

- [ ] **Step 3: Feed the balloon from the cafe screen**

`presentation/cafe_screen.gd`:

`_ready()` içinde `balloon.line_started.connect(...)` satırının altına ekle:

```gdscript
	balloon.question_pressed.connect(func(index: int) -> void: EventBus.request("ask", {"index": index}))
	balloon.mark_pressed.connect(func() -> void: EventBus.request("mark"))
```

`_update_balloon()` içindeki `match view.stage:` bloğuna `"decision":` dalının altına ekle:

```gdscript
		"interview":
			mode = Balloon.Mode.DECISION
			hint = I18n.t("balloon.interview_hint")
```

`_update_balloon()` sonundaki `balloon.say(speaker, view.line, mode, key, hint, I18n.t("button.finish_delivery"))` satırını şuyla değiştir:

```gdscript
	var decision_text := I18n.t("button.to_order") if view.stage == "interview" else I18n.t("button.finish_delivery")
	balloon.say(speaker, view.line, mode, key, hint, decision_text)
	var can_mark: bool = view.phase in ["day", "night"] and view.stage in ["dialogue", "answer", "interview"]
	balloon.set_interview(view.get("questions", []), int(view.get("questions_left", 0)), view.get("marked", false), can_mark)
```

`_unhandled_key_input()` içinde:

```gdscript
		elif not balloon.try_advance() and view.stage == "decision":
			EventBus.request("next")
```

satırlarını şuyla değiştir:

```gdscript
		elif not balloon.try_advance() and view.stage in ["decision", "interview"]:
			EventBus.request("next")
```

Aynı fonksiyonda:

```gdscript
	elif key >= KEY_1 and key <= KEY_9:
		brew_panel.select_index(key - KEY_1)
```

satırlarını şuyla değiştir:

```gdscript
	elif key == KEY_N:
		EventBus.request("mark")
	elif key >= KEY_1 and key <= KEY_9:
		if view.stage == "interview":
			EventBus.request("ask", {"index": key - KEY_1})
		else:
			brew_panel.select_index(key - KEY_1)
```

- [ ] **Step 4: Add texts**

`content/i18n/tr.json`'da `"feedback.ask_limit"` satırının altına ekle:

```json
  "balloon.question": "{number}. {text}",
  "balloon.questions_left": "Soru hakkı: {count}",
  "balloon.interview_hint": "Sor, dinle, karar ver.  [1–4 · N işaretle]",
  "balloon.mark": "İşaretle  [N]",
  "balloon.marked": "İşaretli ✓  [N]",
  "button.to_order": "Siparişi hazırla",
```

- [ ] **Step 5: Run headless tests**

Run: `for t in localization_test flow_test; do godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -2; done`
Expected: ikisi de PASS.

- [ ] **Step 6: Commit (kullanıcı onayıyla)**

```bash
git add presentation/dialogue/speech_balloon.gd presentation/dialogue/speech_balloon.tscn presentation/cafe_screen.gd content/i18n/tr.json
git commit -m "feat: question buttons and mark toggle in speech balloon"
```

---

### Task 5: Dava dosyasında işaretli cümleler

**Files:**
- Modify: `presentation/ui/case_file.gd` (`_render_record`)
- Modify: `content/i18n/tr.json`

- [ ] **Step 1: Show marks under the observation**

`presentation/ui/case_file.gd`'de `_render_record()` içindeki `observation.text = current.appearance` satırını şuyla değiştir:

```gdscript
	var marks: Array = current.get("marks", [])
	var lines := PackedStringArray([current.appearance, "", I18n.t("dossier.marks") if not marks.is_empty() else I18n.t("dossier.no_marks")])
	for line: String in marks:
		lines.append("• " + line)
	observation.text = "\n".join(lines)
```

- [ ] **Step 2: Add texts**

`content/i18n/tr.json`'da `"button.to_order"` satırının altına ekle:

```json
  "dossier.marks": "İşaretlediklerin:",
  "dossier.no_marks": "İşaretli cümle yok.",
```

- [ ] **Step 3: Run headless tests**

Run: `godot --headless --path . -s tests/localization_test.gd 2>&1 | grep -E "PASS|FAIL" | head -2`
Expected: `LOCALIZATION: PASS`

- [ ] **Step 4: Commit (kullanıcı onayıyla)**

```bash
git add presentation/ui/case_file.gd content/i18n/tr.json
git commit -m "feat: list marked lines in case file"
```

---

### Task 6: Görsel test: gerçek tıklamayla soru ve işaretleme

**Files:**
- Modify: `tests/visual_smoke.gd`

- [ ] **Step 1: Add the interview steps**

`tests/visual_smoke.gd`'de şu döngüyü:

```gdscript
	for i in range(8):
		if session.state.stage == "brewing":
			break
		bus.request("next")
```

şuyla değiştir:

```gdscript
	for i in range(8):
		if session.state.stage == "interview":
			break
		bus.request("next")
	await settle(0.6)
	check(session.state.stage == "interview", "Konuşma bitince sorgu açılmalı")
	await capture("interview")
	var first_question: String = locale.t("balloon.question", {"number": 1, "text": session.snapshot().questions[0].text})
	await click(first_question)
	await settle(0.3)
	check(session.state.stage == "answer" and session.state.asked == [0], "Soru düğmesine tıklamak soruyu sormalı")
	await press(KEY_N)
	check(session.state.marks.get(session._record_id(), []).size() == 1, "N cevabı işaretlemeli")
	await capture("answer")
	for i in range(8):
		if session.state.stage == "brewing":
			break
		bus.request("next")
```

- [ ] **Step 2: Run the visual test**

Run: `OUT=/tmp/coffallen-shots; mkdir -p $OUT; timeout 180 godot --path . -s tests/visual_smoke.gd -- $OUT 2>&1 | grep -E "VISUAL|ERROR" | head`

Expected: yalnızca daha önce de var olan `Giriş butonuna tıklamak oyunu başlatmalı` hatası. Bu hata takım arkadaşının yeni menüsünden geliyor; temiz `main`'de de var. Yeni bir hata çıkmamalı.

`$OUT/coffallen-interview.png` ve `$OUT/coffallen-answer.png` görüntülerine bak:
- soru düğmeleri balonun içinde ve okunaklı
- kalan hak yazıyor
- İşaretle düğmesi görünüyor

- [ ] **Step 3: Commit (kullanıcı onayıyla)**

```bash
git add tests/visual_smoke.gd
git commit -m "test: visual smoke covers asking and marking"
```

---

### Task 7: Belgeler

**Files:**
- Modify: `docs/ICERIK_EKLEME.md`
- Modify: `README.md`

- [ ] **Step 1: Content guide section**

`docs/ICERIK_EKLEME.md`'de `## Malzeme ve raf yeri` başlığının üstüne ekle:

````markdown
## Sorgu (sorular ve dolaylı sipariş)

Hikâye ziyaretine iki isteğe bağlı alan eklenebilir:

```json
{
  "character": "eren",
  "order": "red",
  "dialogue": ["Bu saatte açık olacağını söylemişti."],
  "order_line": "Eskisi gibi bir şey. Sıcak… biraz demir tadında.",
  "questions": [
    {"id": "where_from", "answer": ["Yürüyordum. Güneş tam tepedeydi."]},
    {"id": "cold", "answer": ["Soğuk mu? Hiç fark etmedim."]}
  ]
}
```

- **`order_line`:** Müşterinin siparişi. Tarif adını söylemesin; oyuncu tarif defterinden çıkarsın. Demlerken ve soru listesinde balonda bu cümle durur.
- **`questions`:**
  - En fazla 4 soru; oyuncu yalnızca 2'sini sorabilir.
  - `id`, `encounter_pools.json` → `questions` havuzundaki bir sorudur; yeni soru metni oraya eklenir.
  - Cevaplar müşterinin ağzından yazılır. İpucunu (gece güneş görmek, soğuğu hissetmemek) açıkça söyletme; oyuncu kendisi fark etsin.
- **Sorusuz ziyaret:** `questions` olmayan ziyaret eskisi gibi konuşmadan sonra doğrudan demlemeye geçer.
````

- [ ] **Step 2: Shortcuts**

`README.md`'de `| Demle / servis et / sıfırla | E / F / R |` satırının altına ekle:

```markdown
| Sorgu: soru sor / cümleyi işaretle / siparişe geç | 1–4 / N / Boşluk |
```

- [ ] **Step 3: Commit (kullanıcı onayıyla)**

```bash
git add docs/ICERIK_EKLEME.md README.md
git commit -m "docs: interrogation content guide and shortcuts"
```

---

## Self-review notları

- **Belge kapsamı:**
  - Bölüm 1'deki gece döngüsünün 1–4. adımları bu planda (giriş, dolaylı sipariş, 2 soru, işaretleme, raf = teşhis). 5. adım, fotoğraf ve ihbar, zaten var.
  - İstihbarat sekmesi ve güven sonuçları Plan 2'de; özellik havuzu Plan 3'te.
  - Müşteri sayıları (gündüz 2–3, gece 3–4) Task 3 Step 4'te.
- **Gizlilik:** `species` snapshot'a hiç girmez (mevcut silme kodu). Cevaplar yalnızca sorulunca `line` olarak gelir. `view.questions` cevap içermez, `view.visit`'ten de `questions` silinir (Task 2 Step 5); bunu Task 2 testi kontrol eder.
- **Ad tutarlılığı:** `InterrogationRules.can_ask / questions_left / toggle_mark / QUESTION_LIMIT`, `state.asked / answering / marks`, snapshot `questions / questions_left / marked`, balon `set_interview / question_pressed / mark_pressed`. Bu adlar bütün görevlerde aynı.
