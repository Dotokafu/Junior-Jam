# Görseller: yer tutucuyu gerçek çizimle değiştirme

Buradaki PNG'lerin hepsi geçici. **Gerçek çizimi aynı klasöre, aynı adla kaydet; kod değişmez.**
Godot dosyayı yeniden içe aktarır, oyun yeni çizimi kullanır.

Oyun 1920×1080 çalışır. Çizimler **640×360 ölçeğinde** yapılır ve oyunda **×3** büyütülür
(piksel sanatı için keskin, `nearest` filtre açık). Yani 1 çizim pikseli = 3 ekran pikseli.

| Dosya | Çizim ölçüsü | Ne |
|---|---|---|
| `cafe/background_day.png` | 640×360 | Gündüz kafe duvarı, raflar, pencere |
| `cafe/background_night.png` | 640×360 | Aynı mekân, gece (The Fall) |
| `cafe/counter.png` | 640×110 | Tezgâh; karakterin önüne çizilir. Ekranda y=750'den başlar |
| `cafe/cup.png` | 32×28 | Servis fincanı |
| `cafe/cup_liquid.png` | 32×28 | Fincanın sıvı kısmı, **beyaz** çiz; oyun içeceğin rengine boyar |
| `characters/<id>.png` | 160×224 | Karakter, şeffaf arka plan. Alt kısmı tezgâhın arkasında kalır |
| `ui/ingredients/<id>.png` | 24×24 | Demleme makinesindeki malzeme ikonu |

`<id>` = `content/characters.json` ve `content/ingredients.json` içindeki `id` (ör. `ada.png`, `coffee.png`).
Rastgele müşteriler görünüşünü `encounter_pools.json` → `portraits` listesindeki karakterlerden alır.

## Arayüz stili (UI ekibi)

Buton, panel, balon, defter ve telefon renkleri/yazı tipleri tek dosyada:
`presentation/theme/cafe_theme.tres`. Godot'da çift tıkla, Theme editöründe değiştir.
Önemli tipler: `BalloonPanel`, `NameTag`, `PrimaryButton`, `MachinePanel`, `ShelfPanel`, `BookPage`, `PhoneFrame`.

Sahne düzenleri editörde açılabilir: `presentation/world/cafe_world.tscn` (mekân, karakter yeri, fincan),
`presentation/brewing/brew_panel.tscn` (makine), `presentation/ui/recipe_book.tscn` (defter),
`presentation/ui/phone.tscn` (GBT telefonu), `presentation/dialogue/speech_balloon.tscn` (balon).

## Yer tutucuları yeniden üretmek

```
godot --headless --path . -s tools/generate_mock_assets.gd
```

Var olan dosyalara **dokunmaz**; yalnızca eksikleri üretir. `-- --force` hepsini (çizimlerin dahil!) ezer, dikkat.

`audio/rain.wav` basit ortam sesi yer tutucusudur. Fontlar Liberation ailesi; lisans `fonts/LICENSE` içinde.
