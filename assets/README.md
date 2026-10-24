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
| `cafe/cup.png` | 96×96 | Fincan (tezgâh ×1, makine ×1, çizgi roman adımı ×2, servis sayfası ×5). Şu an "Coffee Asset Pack by mimi" HotCupTemplate; ağzı **şeffaf** |
| `cafe/cup_liquid.png` | 96×96 | Fincanın ağzındaki sıvı, **beyaz** maske; oyun içeceğin rengine boyar |
| `characters/<id>.png` | serbest (önerilen 1080×1560) | **El çizimi**, şeffaf arka plan, piksel değil. 540×780 kutuya oranı korunarak sığar, alttan hizalanır, yumuşak filtreyle çizilir. Alt kısmı tezgâhın arkasında kalır |
| `cafe/brew_shelf.png` | 380×300 | Demleme ekranının arka planı. İki raf: üst tahta y=80 (x<280; ana malzemeler), alt tahta y=150 (ek malzemeler); sağda alt tahtaya oturan uzun serbest malzeme (süt) |
| `ui/ingredients/<id>.png` | 32×40 | Raftaki kavanoz; makine slotunda da küçük ikon olarak görünür |
| `ui/icons/*.png` | 24×24 (kayıtta ×3 = 72×72) | HUD ikonları: files, book, menu, auto, ffwd |
| `ui/icons/camera_device.png` | 48×48 (kayıtta ×3) | Tezgâhtaki kare anlık fotoğraf makinesi; polaroid üst yarıktan çıkar |
| `ui/polaroid.png` | 40×48 | Polaroid çerçevesi; ortadaki 32×32 alan **şeffaf** kalmalı (fotoğraf arkadan görünür) |
| `ui/tape.png`, `ui/clip.png` | 18×7, 32×22 | Fotoğrafı tutan bant ve kâğıdı tutan mandal |
| (teslim ekranı) | — | Polaroid kartları `ui/polaroid.png` çerçevesini ve kişinin çiziminden kesilen fotoğrafı kullanır; ayrı görsel gerekmez |
| `ui/logo.png` | 108×30 | Oyun logosu (giriş ekranı, ×6). Yer tutucu: COFFALLEN, bir F düşmüş |
| `ui/segment_on.png`, `ui/segment_off.png` | 5×8 (kayıtta ×3) | Makinedeki tat çubuğu kareleri; dolu kare **beyaz** çizilir, oyun boyar |
| `cafe/shutter.png` | 12×12 (kayıtta ×3) | Kepenk perdesi, döşenerek uzar |
| `comic/step_backdrop.png` | 204×200 | Hazırlık sayfasındaki adım karesinin arka planı |
| `comic/result_backdrop.png` | 627×347 | Servis sayfasının arka planı |
| `comic/stream.png` | 6×16 | Kavanozdan dökülen akış; **beyaz**, malzemenin rengine boyanır |
| `comic/<malzeme id>.png` | serbest | (İsteğe bağlı) O malzemenin adım karesi için hazır çizim; varsa kod kareyi kendisi kurmaz |
| `latte/backdrop.png` | 640×360 | Latte art ekranının arka planı (üstten tezgâh) |
| `latte/saucer.png` | 272×272 | Fincan tabağı, üstten (oyunda ×3 = 816 px) |
| `latte/cup_top.png` | 224×224 | Fincan, üstten; ortadaki **yarıçapı 96 px daire şeffaf** kalmalı (köpük arkadan görünür) |
| `latte/foam_mask.png` | 192×192 | Köpüğün görünen alanı: **beyaz daire**, `cup_top` iç dairesiyle aynı |
| `latte/cup_handle.png` | 56×40 | Fincan kulpu; fincan Q/E ile dönerken kulp da döner |
| `ui/icons/latte_pour.png`, `latte_etch.png`, `latte_flow.png`, `latte_flow_reverse.png`, `latte_reset.png` | 32×32 (kayıtta ×3) | Latte art araç düğmeleri (akış ikonu ters akışta değişir) |
| `ui/icons/latte_art.png` | 32×32 (kayıtta ×3) | Servis sayfasındaki "Latte art" seçeneği |
| `cutscene/city_back.png` | 640×360 | The Fall ara sahnesi: arka şehir, ay, zemin |
| `cutscene/building.png` | 640×360 | Bizim bina, **opak**; kafe camı şeffaf bırakılır (ışık ve silüet arkadan görünür) |
| `cutscene/cafe_light.png` | 108×30 | Kafe camının ışığı |
| `cutscene/cafe_sign.png` | 124×46 | Çatıdaki tabela; alt kenar çatı çizgisine oturur |
| `cutscene/window_light.png` | 8×8 | Rastgele yanan pencere ışığı (konumlar sahnede `near/far_window_rects`) |
| `cutscene/bat.png` | 40×12 (2 kare) | Yarasa; yan yana 2 kanat karesi |
| `cutscene/walker.png` | 20×24 (2 kare) | Camda yürüyen silüet; yan yana 2 adım karesi |
| `menu/background.jpg` (ya da `.png`) | 1920×1080 | Ana menü resmi; **üç fincan bu resmin içinde çizili**. Resim değişirse fincanların ağız elipsi ve yazı yerleri `presentation/menu/topdown_menu.tscn` içinde (`mouth_center`, `mouth_radii`, `label_y`…) yeniden ölçülmeli |
| `menu/kettle.png` | 240×210 | İsteğe bağlı demlik çizimi (fare imleci); ağız ucu (228, 46) noktasında olmalı. Yoksa bakır demlik kodla çizilir |
| `fonts/IMFellEnglish.ttf`, `fonts/Cinzel.ttf` | — | Menü başlığı ve fincanlara kazınmış yazı (OFL lisanslı, yanlarında lisans dosyaları) |
| `ui/chrome/*.png` | 12×12 / 16×16 (kayıtta ×3) | 9-slice çerçeveler: balon, makine, buton, defter, klasör kanadı, kâğıt, sekme |

`<id>` = `content/characters.json` ve `content/ingredients.json` içindeki `id` (ör. `ada.png`, `coffee.png`).
Rastgele müşteriler görünüşünü `encounter_pools.json` → `portraits` listesindeki karakterlerden alır.

Yazı tipi: **Pixelify Sans** (OFL, `fonts/PixelifySans-OFL.txt`), Türkçe karakterleri tam.

Ara sahnedeki kafe camı, yarasa yolu, duvar kenarı ve pencere ışığı konumları
`presentation/ui/fall_cutscene.tscn` → kök düğümün Inspector'ından ayarlanır; yeni bina çizimine göre hizalanabilir.

## Arayüz stili (UI ekibi)

Buton, panel, balon, defter ve telefon renkleri/yazı tipleri tek dosyada:
`presentation/theme/cafe_theme.tres`. Godot'da çift tıkla, Theme editöründe değiştir.
Önemli tipler: `BalloonPanel`, `NameTag`, `PrimaryButton`, `MachinePanel`, `BookPage`, `FolderPage`, `PaperPanel`, `FileTab`, `Stamp`.

Sahne düzenleri editörde açılabilir: `presentation/world/cafe_world.tscn` (mekân, karakter yeri, fincan),
`presentation/brewing/brew_panel.tscn` (makine), `presentation/ui/recipe_book.tscn` (defter),
`presentation/ui/case_file.tscn` (dava dosyası), `presentation/dialogue/speech_balloon.tscn` (balon).

## Yer tutucuları yeniden üretmek

```
godot --headless --path . -s tools/generate_mock_assets.gd
```

Var olan dosyalara **dokunmaz**; yalnızca eksikleri üretir. `-- --force` hepsini (çizimlerin dahil!) ezer, dikkat.

`audio/rain.wav` basit ortam sesi yer tutucusudur. Fontlar Liberation ailesi; lisans `fonts/LICENSE` içinde.
