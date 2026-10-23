# CoFFallen: Coffee Talk tarzı sunum ve hibrit demleme

Tarih: 2026-10-23 · Süre: 48 saat jam

## Hedef
Hikâye ve kurallar (insan/Fallen, gündüz/gece, gizli raf, fotoğraf + ihbar, sonlar) aynen kalır.
Sunum Coffee Talk hissine geçer: tam ekran kafe, tezgâh arkasında büyük karakter, karakterin
yanında daktilo metinli konuşma balonu, sağdan kayan demleme makinesi, minimal köşe ikonları.
Çizimleri ekip yapıyor; bu iş yalnızca **yer tutucu** üretir ve çizim değişimini dosya üzerine
yazmak kadar kolaylaştırır.

## Demleme (hibrit, Coffee Talk kuralları)
- 3 slot. 1. slot yalnızca `base: true` malzeme. 2–3. slot `mix: true` ya da bazla aynı malzeme.
- Her malzemenin `warm/cool/sweet/bitter` değeri slot başına ayrı dizi (`[s1, s2, s3]`), toplanır.
- Tier: 0 → 0, 1–3 → 1, 4–5 → 2, ≥6 → 3.
- Renk: baz ×2, 2. slot ×0,3, 3. slot ×0,1 ağırlıklı ortalama.
- İsim: hazır tarif varsa onun adı (baz aynı, diğer iki malzeme sırasız); yoksa malzeme
  sıfatlarından üretilir (`Saf`, `Bol`, `Koyu` şablonları `tr.json` içinde).
- Sipariş iki türlü: tarif kimliği (`"latte"`) ya da tat isteği (`{"stats": {"warm": 2}}`).
  Tat isteğinde her istenen tier'a eşit veya üstü yeterli. Tür yanlışsa her durumda yanlış.
- Pişirdikten sonra **Servis et** ya da **Çöpe at** (stok harcanmış olur).

## Sunum (1920×1080, çizimler 640×360 ölçeğinde ×3, nearest filtre)
| Sahne | Görev | Çizim değişimi |
|---|---|---|
| `presentation/cafe.tscn` | Orkestra: girdiler, snapshot dağıtımı, ekranlar | — |
| `world/cafe_world.tscn` | Arka plan gündüz/gece, tezgâh, servis fincanı, kamera kayması | `assets/cafe/*.png` |
| `world/character_view.tscn` | Karakter girişi/çıkışı, nefes animasyonu, balon çapası | `assets/characters/<id>.png` |
| `dialogue/speech_balloon.tscn` | Daktilo, tıkla-atla, AUTO/FFWD, ekran kenarına göre konum | tema |
| `brewing/brew_panel.tscn` | Raf, kepenk, 3 slot, 4 tat çubuğu, demleme animasyonu, servis/çöp | `assets/ui/ingredients/<id>.png` |
| `ui/recipe_book.tscn` | Tarif defteri (mock) | tema |
| `ui/phone.tscn` | GBT sicili / ihbar (mock telefon) | tema |
| `theme/cafe_theme.tres` | Tüm buton/panel/yazı stili | editörden düzenlenir |

Yer tutucular `tools/generate_mock_assets.gd` ile üretilir; var olan dosyanın üstüne yazmaz.
Çizim gelince aynı yola aynı adla kaydetmek yeterli.

## Eski sunumun sorumlulukları → yeni yeri
- Kısayollar Esc, B, G, Space/Enter, E, F, R, C, M, 1–6 → `cafe_screen.gd` (aynı), + T (çöp), A (auto).
- `EventBus.state_changed` / `feedback` / `I18n.language_changed` → `cafe_screen.gd`.
- Menü (ses, hareket azaltma, yeni hikâye/endless), yardım, yeni oyun onayı → `ui/overlay_screens.gd`.
- Giriş (devam/yeni), Fall/şafak geçişi, son ekranı, içerik hatası, toast → `ui/overlay_screens.gd`.
- Tarif defteri sekmeleri + `book_tab` / `book_closed` öğretici olayları → `ui/recipe_book`.
- Sicil listesi, fotoğraf, ihbar → `ui/phone`.
- Yağmur ambiyansı + sessiz → `cafe_screen.gd`. Hareket azaltma tüm tween'leri atlar.
- `@export cafe_background/counter` ve editör önizlemesi → gerçek `.tscn` sahneleri, editörde görünür.
- Kepenk perdesi animasyonu → `brew_panel`.

## Kapsam dışı (48 saat)
Latte art, sıvı simülasyonu, Spine. Karakter animasyonu tween ile (nefes, giriş/çıkış, konuşurken zıplama).

## Test
Domain testleri yeni demleme kurallarını kapsar; flow testi tat siparişlerini de çözer;
görsel smoke testi yeni sahneleri açıp ekran görüntüsü alır.
