# Teslim Ekranı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teslimatçı dosya isteyince ekran kararsın (teslimatçı ve konuşma kutusu hariç). Fotoğrafı çekilmiş kişilerin polaroidleri altta dursun. Biri teslimatçıya sürüklenip "Bu mu?" onayından sonra teslim edilsin.

**Architecture:**
- **Tepsi:** Yeni `DeliveryTray` katmanı (`presentation/ui/`) HUD'un üstünde. Gölgesi iki delikli bir shader. Polaroid kartları ve bırakma alanı Godot'nun sürükle bırak fonksiyonlarını kullanır.
- **Kural:** Oyun kuralı değişmez; tepsi mevcut `report` ve `next` komutlarını yollar.
- **Dava dosyası:** Eski "Teslim et" düğmesi kalkar.

**Tech Stack:** Godot 4.7.2, GDScript.

**Kaynak belge:** `docs/superpowers/specs/2026-10-24-teslim-ekrani-design.md`

**Commit notu:** Görev başına commit, `teslim` dalında. Push yalnızca kullanıcı isterse.

---

## Dosya yapısı

| Dosya | Sorumluluk |
| --- | --- |
| `presentation/ui/delivery_shade.gdshader` (yeni) | İki dikdörtgen delik dışında karartır |
| `presentation/ui/delivery_card.gd` (yeni) | Polaroid kartı: görünüm, sürükleme verisi, tıklayınca seçilme |
| `presentation/ui/delivery_drop_zone.gd` (yeni) | Teslimatçının alanı: bırakmayı kabul eder, sürüklerken parlar |
| `presentation/ui/delivery_tray.gd` + `.tscn` (yeni) | Teslim ekranı: gölge, tepsi, onay, bitirme, kısayollar |
| `presentation/world/cafe_world.gd` | `character_rect()` |
| `presentation/cafe.tscn`, `presentation/cafe_screen.gd` | Tepsiyi yerleştirme, besleme, komutlar, balondaki bitirme düğmesini gizleme, kısayollar |
| `presentation/ui/case_file.gd` | "Teslim et" düğmesini kaldırma |
| `content/i18n/tr.json` | `delivery.*` metinleri |
| `tests/visual_smoke.gd` | Gerçek sürükle bırakla teslim |

---

### Task 1: Gölge, kart, bırakma alanı ve tepsi

**Files:**
- Create: `presentation/ui/delivery_shade.gdshader`, `presentation/ui/delivery_card.gd`, `presentation/ui/delivery_drop_zone.gd`, `presentation/ui/delivery_tray.gd`, `presentation/ui/delivery_tray.tscn`
- Modify: `content/i18n/tr.json`

- [ ] **Step 1: Shader**

`presentation/ui/delivery_shade.gdshader`:

```glsl
shader_type canvas_item;
// Teslim ekranının gölgesi: iki dikdörtgen delik (ekran pikseli: x, y, genişlik, yükseklik) dışında karartır.
uniform vec4 hole_a;
uniform vec4 hole_b;
uniform vec2 screen_size = vec2(1920.0, 1080.0);
uniform float darkness = 0.66;
uniform float feather = 28.0;

float lit(vec2 p, vec4 r) {
	vec2 d = max(r.xy - p, p - (r.xy + r.zw));
	return 1.0 - smoothstep(0.0, feather, length(max(d, vec2(0.0))));
}

void fragment() {
	vec2 p = UV * screen_size;
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - max(lit(p, hole_a), lit(p, hole_b))));
}
```

- [ ] **Step 2: Card**

`presentation/ui/delivery_card.gd`:

```gdscript
extends Control
## Teslim tepsisindeki polaroid: teslimatçıya sürüklenir ya da tıklanınca seçilir.
## Çerçeve assets/ui/polaroid.png (ortası şeffaf), fotoğraf kişinin çiziminden (CaseFile.photo_texture).
signal picked(record_id: String)
const POLAROID := "res://assets/ui/polaroid.png"
const SIZE := Vector2(160, 236)
const FRAME := Vector2(160, 192)
const PHOTO := Rect2(16, 16, 128, 128)
var record_id: String = ""
var photo_texture: Texture2D

func setup(record: Dictionary, index: int, photo: Texture2D) -> void:
	record_id = record.id
	photo_texture = photo
	custom_minimum_size = SIZE
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	var picture := TextureRect.new()
	picture.texture = photo
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.position = PHOTO.position
	picture.size = PHOTO.size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	var frame := TextureRect.new()
	if ResourceLoader.exists(POLAROID):
		frame.texture = load(POLAROID)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.size = FRAME
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var label := Label.new()
	label.theme_type_variation = &"HudText"
	label.text = I18n.t("delivery.card", {"number": index + 1, "name": record.get("name", "")})
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0, FRAME.y + 4)
	label.size = Vector2(SIZE.x, SIZE.y - FRAME.y - 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = photo_texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = PHOTO.size
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"record": record_id}

func _gui_input(event: InputEvent) -> void:
	# Sürüklemeden bırakılan tıklama da seçer (fare ile kısayol).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not get_viewport().gui_is_dragging():
		picked.emit(record_id)
		accept_event()
```

- [ ] **Step 3: Drop zone**

`presentation/ui/delivery_drop_zone.gd`:

```gdscript
extends Control
## Teslimatçının alanı: polaroid buraya bırakılınca dropped yayar. Sürükleme sürerken sarı parlar.
signal dropped(record_id: String)
const GLOW := Color(1.0, 0.83, 0.29)
var dragging: bool = false

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("record")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(str(data.record))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN or what == NOTIFICATION_DRAG_END:
		dragging = what == NOTIFICATION_DRAG_BEGIN
		queue_redraw()

func _draw() -> void:
	if not dragging:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(GLOW, 0.1))
	draw_rect(Rect2(Vector2.ZERO, size), GLOW, false, 4.0)
```

- [ ] **Step 4: Tray script**

`presentation/ui/delivery_tray.gd`:

```gdscript
extends Control
## Teslim ekranı: teslimatçı dosya isteyince (2. günden sonra, decision aşaması) ekran kararır; teslimatçı ve
## konuşma kutusu aydınlık kalır. Altta fotoğrafı çekilmiş, henüz verilmemiş kişilerin polaroidleri durur;
## biri teslimatçıya sürüklenip onaylanınca report_requested yayılır. Bitirme düğmesi finish_requested yayar.
signal report_requested(record_id: String)
signal finish_requested
const Card = preload("res://presentation/ui/delivery_card.gd")
const CaseFile = preload("res://presentation/ui/case_file.gd")
const HOLE_MARGIN := 18.0
var is_active: bool = false
var view: Dictionary = {}
var pending: String = ""
var cards_key: String = ""
## Delikler her karede izlenir: teslimatçı ve konuşma kutusu hareket edebilir.
var world: Control
var balloon_panel: Control
@onready var shade: ColorRect = $Shade
@onready var drop_zone: Control = $DropZone
@onready var tray: HBoxContainer = $Tray
@onready var hint: Label = $Hint
@onready var confirm: PanelContainer = $Confirm
@onready var confirm_text: Label = $Confirm/Box/Text
@onready var give_button: Button = $Confirm/Box/Buttons/GiveButton
@onready var cancel_button: Button = $Confirm/Box/Buttons/CancelButton
@onready var finish_button: Button = $FinishButton

func _ready() -> void:
	give_button.text = I18n.t("delivery.give")
	cancel_button.text = I18n.t("delivery.cancel")
	give_button.pressed.connect(_give)
	cancel_button.pressed.connect(_cancel)
	finish_button.pressed.connect(func() -> void: finish_requested.emit())
	drop_zone.dropped.connect(_pick)
	hide()
	set_process(false)

## Teslimatçı soruyu sorduğunda tepsi açılır.
static func wants(snapshot: Dictionary) -> bool:
	return bool(snapshot.get("started", false)) and snapshot.get("stage", "") == "decision" \\
		and int(snapshot.get("day", 1)) >= 2 and snapshot.get("phase", "") in ["morning_supplier", "night_supplier"]

func track(world_node: Control, panel: Control) -> void:
	world = world_node
	balloon_panel = panel

func apply(snapshot: Dictionary) -> void:
	view = snapshot
	if not wants(view):
		if is_active:
			is_active = false
			pending = ""
			hide()
			set_process(false)
		return
	is_active = true
	show()
	set_process(true)
	_process(0.0)
	finish_button.text = I18n.t("delivery.finish" if view.get("delivery_reported", false) else "delivery.nobody")
	var eligible := _eligible()
	hint.text = I18n.t("delivery.hint" if not eligible.is_empty() else "delivery.empty")
	_render_cards(eligible)
	if pending != "" and not eligible.any(func(record: Dictionary) -> bool: return record.id == pending):
		pending = ""
	confirm.visible = pending != ""

## 1–9 polaroid seçer, Enter verir, Esc onayı kapatır, Boşluk bitirir. Ele alındıysa true.
func handle_key(key: int) -> bool:
	if not is_active:
		return false
	if confirm.visible:
		if key in [KEY_ENTER, KEY_KP_ENTER]:
			_give()
		elif key == KEY_ESCAPE:
			_cancel()
		return true
	if key >= KEY_1 and key <= KEY_9:
		var index := key - KEY_1
		if index < tray.get_child_count():
			_pick(tray.get_child(index).record_id)
		return true
	if key == KEY_SPACE:
		finish_requested.emit()
		return true
	return false

func _process(_delta: float) -> void:
	if world == null or balloon_panel == null:
		return
	var person: Rect2 = world.character_rect()
	drop_zone.position = person.position
	drop_zone.size = person.size
	var material := shade.material as ShaderMaterial
	material.set_shader_parameter("hole_a", _hole(person))
	material.set_shader_parameter("hole_b", _hole(balloon_panel.get_global_rect()))

func _hole(rect: Rect2) -> Vector4:
	var grown := rect.grow(HOLE_MARGIN)
	return Vector4(grown.position.x, grown.position.y, grown.size.x, grown.size.y)

## Henüz verilmemiş ve kişisi daha önce verilmemiş kayıtlar (mevcut teslim kuralıyla aynı).
func _eligible() -> Array:
	var given: Array = []
	for record: Dictionary in view.get("records", []):
		if record.reported_to != "":
			given.append(record.character)
	return view.get("records", []).filter(func(record: Dictionary) -> bool: return record.reported_to == "" and record.character not in given)

func _render_cards(records: Array) -> void:
	var key := str(records.map(func(record: Dictionary) -> String: return record.id))
	if key == cards_key:
		return
	cards_key = key
	for child: Node in tray.get_children():
		tray.remove_child(child)
		child.queue_free()
	for i in range(records.size()):
		var card := Card.new()
		tray.add_child(card)
		card.setup(records[i], i, CaseFile.photo_texture(records[i]))
		card.picked.connect(_pick)

func _pick(record_id: String) -> void:
	for record: Dictionary in view.get("records", []):
		if record.id == record_id:
			pending = record_id
			confirm_text.text = I18n.t("delivery.confirm", {"name": record.name})
			confirm.show()
			return

func _give() -> void:
	if pending == "":
		return
	var record_id := pending
	pending = ""
	confirm.hide()
	report_requested.emit(record_id)

func _cancel() -> void:
	pending = ""
	confirm.hide()
```

- [ ] **Step 5: Tray scene**

`presentation/ui/delivery_tray.tscn`:

```
[gd_scene format=3]

[ext_resource type="Script" path="res://presentation/ui/delivery_tray.gd" id="1_script"]
[ext_resource type="Shader" path="res://presentation/ui/delivery_shade.gdshader" id="2_shade"]
[ext_resource type="Script" path="res://presentation/ui/delivery_drop_zone.gd" id="3_drop"]

[sub_resource type="ShaderMaterial" id="ShadeMaterial"]
shader = ExtResource("2_shade")

[node name="DeliveryTray" type="Control"]
offset_right = 1920.0
offset_bottom = 1080.0
mouse_filter = 2
script = ExtResource("1_script")

[node name="Shade" type="ColorRect" parent="."]
material = SubResource("ShadeMaterial")
offset_right = 1920.0
offset_bottom = 1080.0

[node name="DropZone" type="Control" parent="."]
offset_right = 540.0
offset_bottom = 780.0
script = ExtResource("3_drop")

[node name="Hint" type="Label" parent="."]
offset_left = 360.0
offset_top = 772.0
offset_right = 1560.0
offset_bottom = 812.0
theme_type_variation = &"HudText"
horizontal_alignment = 1

[node name="Tray" type="HBoxContainer" parent="."]
offset_left = 360.0
offset_top = 820.0
offset_right = 1560.0
offset_bottom = 1056.0
theme_override_constants/separation = 24
alignment = 1

[node name="FinishButton" type="Button" parent="."]
offset_left = 1580.0
offset_top = 980.0
offset_right = 1900.0
offset_bottom = 1044.0

[node name="Confirm" type="PanelContainer" parent="."]
visible = false
offset_left = 660.0
offset_top = 560.0
offset_right = 1260.0
offset_bottom = 740.0
theme_type_variation = &"BalloonPanel"

[node name="Box" type="VBoxContainer" parent="Confirm"]
theme_override_constants/separation = 14

[node name="Text" type="Label" parent="Confirm/Box"]
custom_minimum_size = Vector2(520, 0)
theme_type_variation = &"HudText"
autowrap_mode = 3

[node name="Buttons" type="HBoxContainer" parent="Confirm/Box"]
theme_override_constants/separation = 16
alignment = 2

[node name="CancelButton" type="Button" parent="Confirm/Box/Buttons"]

[node name="GiveButton" type="Button" parent="Confirm/Box/Buttons"]
theme_type_variation = &"PrimaryButton"
```

- [ ] **Step 6: Texts**

`content/i18n/tr.json`'da `"dialogue.ask_order"` satırının altına ekle:

```json
  "delivery.hint": "Bir polaroidi tutup teslimatçıya sürükle.  [1–9]",
  "delivery.empty": "Verecek fotoğrafın yok.",
  "delivery.card": "{number}. {name}",
  "delivery.confirm": "{name} dosyası. Bu mu? Geri alamazsın.",
  "delivery.give": "Ver  [Enter]",
  "delivery.cancel": "Vazgeç  [Esc]",
  "delivery.nobody": "Bugün kimse yok  [Boşluk]",
  "delivery.finish": "Teslimatı bitir  [Boşluk]",
```

`"dialogue.ask_state"` ve `"dialogue.ask_order"` metinlerinin sonundaki `  [G]` kısmını sil; artık teslim Dosyalar'dan değil tepsiden yapılıyor.

- [ ] **Step 7: Check that the scripts parse**

Run: `godot --headless --path . --import >/dev/null 2>&1; git checkout -q -- project.godot; timeout 60 godot --headless --path . -s tests/localization_test.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -3`
Expected: `LOCALIZATION: PASS`, SCRIPT ERROR yok.

- [ ] **Step 8: Commit**

```bash
git add presentation/ui/delivery_* content/i18n/tr.json
git commit -m "feat: delivery tray with shade, draggable polaroids and confirmation"
```

---

### Task 2: Kafe ekranına bağlama, eski teslim düğmesini kaldırma

**Files:**
- Modify: `presentation/world/cafe_world.gd`, `presentation/cafe.tscn`, `presentation/cafe_screen.gd`, `presentation/ui/case_file.gd`, `content/i18n/tr.json`

- [ ] **Step 1: character_rect**

`presentation/world/cafe_world.gd`'de `func balloon_point() -> Vector2:` fonksiyonunun üstüne ekle:

```gdscript
## Karşıdaki kişinin ekrandaki dikdörtgeni (teslim ekranında aydınlık kalan ve polaroidin bırakıldığı yer).
func character_rect() -> Rect2:
	return character.body.get_global_rect()
```

- [ ] **Step 2: Scene**

`presentation/cafe.tscn`:
- `ext_resource` listesinin sonuna ekle:

```
[ext_resource type="PackedScene" path="res://presentation/ui/delivery_tray.tscn" id="20_delivery"]
```

- `[node name="BrewComic" parent="." instance=ExtResource("16_comic")]` satırının üstüne ekle:

```
[node name="DeliveryTray" parent="." instance=ExtResource("20_delivery")]

```

- [ ] **Step 3: Cafe screen**

`presentation/cafe_screen.gd`:

`@onready var brew_comic: Control = $BrewComic` altına ekle:

```gdscript
@onready var delivery: Control = $DeliveryTray
```

`_ready()` içinde `balloon.mark_pressed.connect(...)` satırının altına ekle:

```gdscript
	delivery.track(world, balloon.panel)
	delivery.report_requested.connect(func(record_id: String) -> void: EventBus.request("report", {"id": record_id}))
	delivery.finish_requested.connect(func() -> void: EventBus.request("next"))
```

`_update_balloon(playing)` çağrısının hemen altına ekle:

```gdscript
	delivery.apply(view if playing else {})
```

`_update_balloon()` içindeki `"decision":` dalını şununla değiştir:

```gdscript
		"decision":
			mode = Balloon.Mode.DECISION
			# Teslim tepsisi açıkken bitirme ve ipucu tepside; balon yalnızca soruyu taşır.
			hint = "" if delivery.wants(view) else (I18n.t("balloon.decision_hint") if view.day >= 2 else "")
```

`match view.stage:` içindeki decision_text bloğunda `"decision": decision_text = I18n.t("button.finish_delivery")` satırını şununla değiştir:

```gdscript
		"decision": decision_text = "" if delivery.wants(view) else I18n.t("button.finish_delivery")
```

`_unhandled_key_input()` içinde şu satırları:

```gdscript
	elif brew_comic.latte.is_open:
		# Latte art açıkken tuşlar önce ona gider (Esc = geri, Enter = servis).
		if not brew_comic.latte.handle_key(key):
			return
```

şununla değiştir:

```gdscript
	elif brew_comic.latte.is_open:
		# Latte art açıkken tuşlar önce ona gider (Esc = geri, Enter = servis).
		if not brew_comic.latte.handle_key(key):
			return
	elif modal == "" and delivery.is_active and delivery.handle_key(key):
		pass
```

- [ ] **Step 4: Remove the old report button from the case file**

`presentation/ui/case_file.gd`'de şu satırı sil:

```gdscript
	report_button.pressed.connect(func() -> void: EventBus.request("report", {"id": selected_id}))
```

Şu bloğu:

```gdscript
	var can_report: bool = view.stage == "decision" and view.phase in ["morning_supplier", "night_supplier"] and current.reported_to == ""
	hint.text = "" if can_report or current.reported_to != "" else I18n.t("dossier.delivery_only")
	if can_report:
		var recipient := I18n.t("dossier.defne_request") if view.phase == "morning_supplier" else I18n.t("dossier.vey_request")
		report_button.text = I18n.t("button.report", {"recipient": recipient.replace("\\n", " · ")})
		report_button.show()
```

şununla değiştir:

```gdscript
	# Dosyalar yalnızca teslim ekranından (polaroidi teslimatçıya sürükleyerek) verilir.
	hint.text = "" if current.reported_to != "" else I18n.t("dossier.delivery_only")
```

`content/i18n/tr.json`'da şu iki metni değiştir:
- `"dossier.delivery_only"`: "Dosyalar teslimatta verilir: polaroidi teslimatçıya sürükle."
- `"balloon.decision_hint"`: "Polaroidi teslimatçıya sürükle"

- [ ] **Step 5: Run headless tests**

Run: `for t in domain_test flow_test save_test localization_test encounter_test; do timeout 100 godot --headless --path . -s tests/$t.gd 2>&1 | grep -E "PASS|FAIL|SCRIPT ERROR" | head -2; done`
Expected: hepsi PASS. Kural değişmedi; testler `report` komutunu doğrudan kullanıyor.

- [ ] **Step 6: Commit**

```bash
git add presentation/world/cafe_world.gd presentation/cafe.tscn presentation/cafe_screen.gd presentation/ui/case_file.gd content/i18n/tr.json
git commit -m "feat: wire delivery tray into the cafe, drop the case-file report button"
```

---

### Task 3: Görsel test, gerçek sürükle bırakla teslim

**Files:**
- Modify: `tests/visual_smoke.gd`

- [ ] **Step 1: Add the steps**

`tests/visual_smoke.gd`'de `check(session.state.stage == "decision" and screen.balloon.panel.size.y < 450.0, ...)` satırının altına ekle:

```gdscript
	# Teslim ekranı: gölge + polaroid tepsisi; polaroid teslimatçıya gerçek fareyle sürüklenir, onaylanır.
	check(screen.delivery.is_active and screen.delivery.tray.get_child_count() >= 1, "Teslimatta polaroid tepsisi açılmalı")
	await capture("delivery")
	var card: Control = screen.delivery.tray.get_child(0)
	var from: Vector2 = card.get_global_rect().get_center()
	var target: Vector2 = screen.delivery.drop_zone.get_global_rect().get_center()
	await drag([from, from + Vector2(0, -40), target], [0.15, 0.15, 0.2])
	await settle(0.3)
	check(screen.delivery.confirm.visible, "Polaroidi teslimatçıya bırakınca onay sorulmalı")
	await capture("delivery_confirm")
	await click(locale.t("delivery.give"))
	await settle(0.4)
	check(session.state.records[0].reported_to == "fallen", "Onaylanınca dosya Vey'e teslim edilmeli")
```

- [ ] **Step 2: Run the visual test**

Run: `OUT=/tmp/coffallen-shots; mkdir -p $OUT; timeout 200 godot --path . -s tests/visual_smoke.gd -- $OUT 2>&1 | grep -E "VISUAL|ERROR" | head`

Expected: yalnızca daha önce de var olan `Giriş butonuna tıklamak oyunu başlatmalı` hatası.

`$OUT/coffallen-delivery.png` ve `$OUT/coffallen-delivery_confirm.png`'ye bak:
- Teslimatçı ve konuşma kutusu aydınlık, gerisi karanlık.
- Polaroidler altta okunaklı.
- Onay kutusu ortada.

- [ ] **Step 3: Commit**

```bash
git add tests/visual_smoke.gd
git commit -m "test: visual smoke drags a polaroid to the supplier"
```

---

### Task 4: Belgeler

**Files:**
- Modify: `README.md`, `assets/README.md`

- [ ] **Step 1: Shortcuts and assets**

`README.md`'de `| Sorgu: soru sor / cümleyi işaretle / siparişe geç | 1–4 / N / Boşluk |` satırının altına ekle:

```markdown
| Teslimat: polaroidi seç / ver / vazgeç / bitir | 1–9 (ya da sürükle) / Enter / Esc / Boşluk |
```

`assets/README.md`'de `| ui/tape.png`… satırının altına ekle:

```markdown
| (teslim ekranı) | — | Polaroid kartları `ui/polaroid.png` çerçevesini ve kişinin çiziminden kesilen fotoğrafı kullanır; ayrı görsel gerekmez |
```

- [ ] **Step 2: Commit**

```bash
git add README.md assets/README.md
git commit -m "docs: delivery tray shortcuts"
```

---

## Self-review notları

- **Belge kapsamı:**
  - Gölge (Task 1 shader, Task 2 delik takibi).
  - Tepsi ve uygun kayıtlar (`_eligible` mevcut kuralla aynı).
  - Sürükle bırak ve onay (Task 1, Task 3).
  - Bitirme ve "Bugün kimse yok" (`delivery_reported` snapshot'ta görünür, gizli değil).
  - Klavye (`handle_key`), eski düğmenin kaldırılması (Task 2), 1. gün ve fotoğrafsız durum (`wants` ve `delivery.empty`).
- **Katman sırası:** Tepsi HUD'un üstünde, BrewComic/RecipeBook/CaseFile/Screens'in altında. Dosyalar açılırsa dava dosyası tepsinin üstünde görünür; Esc menüsü her şeyin üstünde.
- **Ad tutarlılığı:**
  - `DeliveryTray.wants/track/apply/handle_key/is_active/tray/drop_zone/confirm`
  - Sinyaller `report_requested`, `finish_requested`, `picked`, `dropped`
  - `cafe_world.character_rect`
