# Görseller: yer tutucuyu gerçek çizimle değiştirme

Buradaki PNG'lerin hepsi geçici. **Gerçek çizimi aynı klasöre, aynı adla kaydet; kod değişmez.**
Godot dosyayı yeniden içe aktarır, oyun yeni çizimi kullanır.

Oyun 1920×1080 çalışır. **Mekân, demleme ekranı ve arayüz piksel**: 640×360 ölçeğinde çizilir,
oyunda **×3** büyütülür (keskin `nearest` filtre). Yani 1 çizim pikseli = 3 ekran pikseli.
**Karakterler el çizimi**: ölçek serbest, yumuşak filtreyle gösterilir.

| Dosya | Çizim ölçüsü | Ne |
|---|---|---|
| `cafe/background_day.png` | 640×360 | Gündüz kafe duvarı, raflar, pencere |
| `cafe/background_night.png` | 640×360 | Aynı mekân, gece (The Fall) |
| `cafe/counter.png` | 740×80 | Tezgâh; karakterin önüne çizilir. Ekranda y=840'tan başlar, demlerken kamera kaydığı için ekrandan 100 px geniş |
| `cafe/cup.png` | 32×28 | Servis fincanı |
| `cafe/cup_liquid.png` | 32×28 | Fincanın sıvı kısmı, **beyaz** çiz; oyun içeceğin rengine boyar |
| `characters/<id>.png` | serbest (önerilen 1080×1560) | **El çizimi**, şeffaf arka plan, piksel değil. 540×780 kutuya oranı korunarak sığar, alttan hizalanır, yumuşak filtreyle çizilir. Alt kısmı tezgâhın arkasında kalır |
| `cafe/brew_shelf.png` | 380×300 | Demleme ekranının arka planı (yakın plan raf). Kavanozlar üst rafa (y=100) dizilir |
| `ui/ingredients/<id>.png` | 32×40 | Raftaki kavanoz; makine slotunda da küçük ikon olarak görünür |
| `ui/icons/*.png` | 24×24 (kayıtta ×3 = 72×72) | HUD ikonları: phone, camera, book, menu, auto, ffwd |
| `ui/chrome/*.png` | 12×12 / 16×16 (kayıtta ×3) | 9-slice çerçeveler: balon, makine, buton, defter, telefon |

`<id>` = `content/characters.json` ve `content/ingredients.json` içindeki `id` (ör. `ada.png`, `coffee.png`).
Rastgele müşteriler görünüşünü `encounter_pools.json` → `portraits` listesindeki karakterlerden alır.

Yazı tipi: **Pixelify Sans** (OFL, `fonts/PixelifySans-OFL.txt`), Türkçe karakterleri tam.

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
