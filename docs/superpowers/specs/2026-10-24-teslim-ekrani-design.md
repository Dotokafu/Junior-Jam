# Teslim ekranı: gölge ve sürükle bırak

Tarih: 2026-10-24 · Durum: **onaylandı** (kullanıcı "devam" dedi) · İlgili: `2026-10-24-supheler-design.md`

## Amaç

Teslimatta dosya vermek şu an bir form gibi: Dosyalar'ı aç, listeden seç, "Teslim et" düğmesine bas.
Kullanıcının önerisi: teslimatçı sorunca kişi, konuşma kutusu ve belgelerimiz dışında her yer kararır.
Elimizdeki belgeyi sürükleyip teslimatçıya atarız; teslimatçı "onaylıyor musun" diye sorar. Karar fiziksel ve gergin
bir an olur (Papers, Please'te belgeyi memura uzatmak gibi).

## Davranış

- **Ne zaman:** 2. günden itibaren, teslimatçı (sabah Defne, gece Vey) soruyu sorduğunda (`decision` aşaması).
  1. günde yalnızca verilecek fotoğraf varsa açılır; yoksa balondaki bitirme düğmesi kalır.
- **Gölge:** Ekranın tamamı kararır. Teslimatçının ve konuşma kutusunun olduğu yerler aydınlık kalır; HUD da kararır.
  Kararan katman tıklamaları geçirmez.
- **Belge tepsisi:** Altta, fotoğrafını çektiğin ve henüz kimseye verilmemiş kişilerin polaroidleri yan yana durur.
  Her polaroidde fotoğraf ve ad var. Daha önce dosyası verilmiş kişinin başka fotoğrafı da gösterilmez (bugünkü kural).
- **Sürükle bırak:** Polaroid tutulup teslimatçının üstüne bırakılır. Sürükleme sürerken teslimatçının alanı parlar.
- **Onay:** Bırakınca bir kutu çıkar: "{ad} dosyası. Bu mu? Geri alamazsın." Altında "Ver" ve "Vazgeç".
  - "Ver" dosyayı teslim eder (mevcut `report` komutu).
  - "Vazgeç" polaroidi tepsiye geri koyar.
- **Bitirme:** Tepsinin yanında bir düğme var. Bu teslimatta henüz dosya verilmediyse "Bugün kimse yok", verildiyse
  "Teslimatı bitir" yazar. İkisi de mevcut `next` komutunu yollar; dosya verilmediyse şüphe kuralı gereği soranın
  şüphesi biraz artar.
- **Klavye:**
  - `1–9`: o sıradaki polaroidin onayını açar.
  - `Enter`: onayda "Ver".
  - `Esc`: onayı kapatır.
  - Boşluk: bitirir.
- **Dava dosyası:** "Teslim et" düğmesi kalkar; dosyalar yalnızca bu ekrandan verilir. Dosyalar'da ipucu metni bunu söyler.

## Mimari

- **Yeni `presentation/ui/delivery_tray.gd` ve `.tscn`** (`Control`, kafe sahnesinde HUD'dan sonra):
  - Gölge: `ColorRect` + `delivery_shade.gdshader`. İki dikdörtgen delik bırakır (teslimatçı ve konuşma kutusu), kenarları yumuşaktır.
  - Bırakma alanı (`DropZone`): teslimatçının dikdörtgeninde. `_can_drop_data` / `_drop_data`; sürükleme sürerken parlar.
  - Tepsi: polaroid kartları, `_get_drag_data`.
  - Onay kutusu ve bitirme düğmesi.
  - API: `apply(view, supplier_rect, balloon_rect)`, `handle_key(key)`, `is_active`.
  - Sinyaller: `report_requested(id)`, `finish_requested`.
- **`cafe_world.gd`:** `character_rect()` teslimatçının ekrandaki dikdörtgenini verir.
- **`cafe_screen.gd`:**
  - Tepsiyi besler.
  - Sinyalleri `report` / `next` komutlarına çevirir.
  - Tepsi açıkken balondaki bitirme düğmesini ve ipucunu gizler.
  - Kısayolları önce tepsiye yollar.
- **`case_file.gd`:** "Teslim et" düğmesi kaldırılır.
- **Oyun kuralı değişmez:** `report`, `next` ve şüphe kancaları aynen kullanılır.

## Test

- **`visual_smoke`:**
  - Gece teslimatında tepsi ve gölge görünür.
  - Fotoğrafı çekilmiş kişinin polaroidi gerçek fare sürüklemesiyle teslimatçıya bırakılır.
  - Onayda "Ver"e tıklanınca kaydın `reported_to` alanı `fallen` olur.
- **Başsız testler:** Kural değişmediği için aynen geçmeli.
