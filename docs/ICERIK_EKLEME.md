# İçerik ekleme

## Dosyayı seç

| Değişiklik | Dosya |
| --- | --- |
| Düğme, yardım veya bildirim metni | `content/i18n/tr.json` |
| Karakter adı, görünüş, sicil, gerçek tür, küçük sohbet | `content/characters.json` |
| Belli bir gün mutlaka gelecek hikâye karakteri ve konuşması | `content/days.json` |
| İnsan/Fallen ve görünüş havuzları, gece olasılığı, müşteri sayısı | `content/encounter_pools.json` |
| Malzeme | `content/ingredients.json` |
| Tarif / ürün | `content/recipes.json` |
| Son metni ve denge eşikleri | `content/endings.json` |

`id` alanları teknik kimliktir; Türkçe görünen adlar serbesttir. İçeriği kaydettikten sonra oyunu yeniden başlat. Mevcut kayıt o vardiyanın üretilmiş ziyaretlerini saklar; yeni üretimi denemek için yeni oyun başlat.

## Zorunlu hikâye taşı

`days.json` içindeki günün `day` veya `night` listesine bir ziyaret ekle:

```json
{
  "character": "ada",
  "order": "latte",
  "dialogue": [
    "Bugün konuşmamız gereken bir şey var.",
    "Bir Sabah Sisi hazırlar mısın?"
  ]
}
```

Bu ziyaret **rastgele seçimden bağımsız olarak** gelir. Listedeki hikâye ziyaretlerinin sırası korunur; aralarına ayarlanan sayıda rastgele müşteri yerleştirilir. İlk gecede Eren her zaman ilk müşteridir, öğretici bozulmaz. İlk günün hikâye taşları Endless'ta da çalışır. Sonraki Endless günleri havuzlardan üretilir.

Şimdiki hikâye taşları gün/dönem ile zamanlanır. Önceki kararları koşul olarak değerlendiren dallanmış ziyaret planlayıcısı bu prototipin kapsamında henüz yoktur.

## Rastgele müşteri

1. `characters.json` dosyasına benzersiz `id` ile karakter ekle. Mevcut bir `guest_...` kaydını kopyalamak en kolay başlangıçtır.
2. Gerçek türünü `species: "human"` veya `"fallen"` yap.
3. `smalltalk` listesine kısa konuşmalar, `dossier` alanına sicil ipucu ve `appearance` alanına gözlemi yaz.
4. Kimliğini `encounter_pools.json` içindeki ilgili `human` veya `fallen` listesine ekle.

Görünüş ayrı `portraits` havuzundan seçilir. Bir Fallen sıcak ve sağlıklı görünebilir; bir insan solgun görünebilir. Aynı karakterin görünüşü aynı oyun başlangıç değeri içinde sabit kalır. Gerçek tür GBT ekranına gönderilmez.

```json
{
  "fallen_chance_at_night": 0.5,
  "story_random_visits": { "day": 0, "night": 1 },
  "endless_visits": { "day": 3, "night": 4 }
}
```

`0.5` gece %50 Fallen olasılığıdır; her gecede tam yarı yarıya müşteri olacağını garanti etmez. Rastgele gündüz müşterileri insan havuzundan gelir; gündüzün zorunlu hikâye karakterleri Fallen olabilir.

## Tek fonksiyonla vardiya

```gdscript
var visits = EncounterDirector.build_shift(
    {"day": 2, "period": "night", "mode": "story", "seed": 12345},
    repository.catalog()
)
```

Fonksiyon bütün ziyaret listesini üretir: hikâye taşları → rastgele tür → karakter → görünüş → o türe uygun ürün → JSON'dan sipariş ve sohbet. Sahne oluşturma ve fincan servis etme gibi uygulama işlerini `GameSession` yönetir. Bir ziyaretin verisi `character`, `person` (rastgele müşteride), `order`, `dialogue`, `kind`, `mandatory` alanlarını taşır. İç listede gerçek tür bulunur; oyuncuya gönderilen snapshot'ta ayıklanır.

Aynı başlangıç değeri, gün, dönem ve içerik aynı listeyi üretir. Üretilmiş liste ve mevcut ziyaret kaydedildiği için oyuna devam etmek müşteriyi yeniden seçmez. Yeni içerik eklenirse aynı başlangıç değerinin sonucu değişebilir.

## Ürün kutusu

`recipes.json` dosyasına şu biçimde ekle:

```json
{
  "id": "yeni_tarif",
  "name": "Yeni Tarif",
  "side": "human",
  "ingredients": ["coffee", "milk", "cinnamon"],
  "description": "Tarif kitabındaki açıklama."
}
```

Rastgele ürün havuzu tariflerin `side` alanından otomatik oluşturulur. Ek kod yazılmaz. Üç ölçü zorunludur, tekrar serbesttir, sıralama önemsizdir. Aynı üç malzemeye ikinci bir tarif tanımlama. İnsan rafını Defne sabah, Fallen rafını Vey gece sonunda yeniler. İlk gecenin gizli rafında önceki baristadan kalan başlangıç stoğu vardır.

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

- `order_line`: müşterinin siparişi. Tarif adını söylemesin; oyuncu tarif defterinden çıkarsın. Demlerken ve soru listesinde balonda bu cümle durur.
- `questions`: en fazla 4 soru; oyuncu yalnızca 2'sini sorabilir. `id`, `encounter_pools.json` → `questions` havuzundaki bir sorudur; yeni soru metni oraya eklenir. Cevaplar müşterinin ağzından yazılır. İpucunu açıkça söyletme (gece güneş görmek, soğuğu hissetmemek gibi); oyuncu kendisi fark etsin.
- Oyuncu balonda görünen cümleyi **İşaretle [N]** ile not eder; işaretler fotoğrafı çekilmiş kişinin dava dosyasında listelenir. Oyun işaretlerin istihbaratla eşleşip eşleşmediğini söylemez.
- `questions` olmayan ziyaret eskisi gibi konuşmadan sonra doğrudan demlemeye geçer.

## Malzeme ve raf yeri

`ingredients.json`'daki `base` / `mix` bayrakları malzemenin hem kuralını hem raftaki yerini belirler:

| `base` | `mix` | Raf | Kural |
| --- | --- | --- | --- |
| true | false | Üst raf (ana malzeme: kahve, matcha, kakao, çay) | Yalnızca 1. ölçü; sonra yalnızca kendisi tekrar edebilir |
| true | true | Sağda (serbest: süt) | Her ölçüye girer |
| false | true | Alt raf (ek malzeme: tarçın, nane, baharat, limon) | Ana malzeme olmadan konamaz |

`"latte": true` olan malzeme (süt) 2. ya da 3. ölçüdeyse içecek latte art'a açılır; tarifli içecekte tarifin `"latte_art"` bayrağı geçerlidir.

## Metin / i18n

Sabit oyuncu metni GDScript içine yazılmaz:

```json
{
  "feedback.drink_ready": "{drink} hazır. Servis kararı senin."
}
```

```gdscript
I18n.t("feedback.drink_ready", {"drink": drink.name})
```

Editörde de çizilen arayüzlerde `CafeUI.text(...)` aynı anahtarı kullanır: oyun sırasında `I18n`'e gider, 2B önizlemede aynı JSON'u salt okunur açar. Böylece editörde oyun oturumu başlatmak gerekmez.

Çevrilebilir cümleyi parçalara bölme; değişkenler için `{name}` gibi adlandırılmış alanlar kullan. Sistem tepkilerinde kayıt dosyasına cümle yerine `reaction_key` yazılır. Diyaloglar, karakter/ürün adları, siciller ve son metinleri kendi JSON dosyalarında tutulur. Rastgele sipariş cümlesi `encounter_pools.json` içindeki `order_template` alanıdır.

Yeni arayüz dili için `content/i18n/en.json` gibi bir katalog ekleyebilirsin. `I18n.set_language("en")` arayüzü yeniler; eksik anahtarlar Türkçe kataloğa düşer. Hikâye ve içerik JSON'larının ayrı dil sürümleri henüz eklenmedi; yalnızca arayüz kataloğu eklemek hikâyeyi çevirmiş olmaz.

## Sonlar

`endings.json` içindeki `rules` alanı eşikleri tutar. Vey'e üç doğru insan kaydı → Defne sonu. Defne'ye üç doğru Fallen kaydı → Vey sonu. Son gece minimum kayıt, %40–60 paylaşım ve hata sınırı sağlanırsa gri son; kalan durumlarda Fallen hâkimiyeti. Yanlış servis/yanlış ihbar toplamı ikiye ulaştığında ilgili sonun `errors` metni eklenir.

`reserved` beşinci son için kapalı yuvadır. Açılma kuralı belirlenince `EndingRules` içine eklenmelidir; yalnızca metnini yazmak onu tetiklemez.
