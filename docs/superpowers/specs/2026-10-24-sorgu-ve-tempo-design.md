# Sorgu ve tempo: Papers, Please gibi şüphe ve teşhis

Tarih: 2026-10-24 · Durum: **onaylandı** (kullanıcı "devam" dedi; açık sorular varsayılanlarla kapatıldı, değiştirilebilir).

## Sorun

Şu anki müşteri döngüsü şöyle:

> 3 satır konuşma (tıkla geç) → istenen tarifi demle → servis et → 1 satır tepki → sıradaki

- Bir vardiyada 2–3 müşteri var ve konuşmada seçim yok.
- Sipariş açık söyleniyor ("Bir kahve, iki süt").
- Fallen'lar gizli rafın içeceğini adıyla istediği için teşhise gerek kalmıyor.

Sonuç: oyun hızlı ve sığ akıyor. Hedef, Papers, Please'teki gibi konuşmadan ve tavırdan **şüphelenip** karar vermek. Karar zorlaşmalı ve oyuncu yanılabilmeli.

## Verilen kararlar

| Soru | Karar |
| --- | --- |
| Oyuncu konuşmadan neyi anlamalı? | **İkisi de.** Sipariş dolaylı söylenir; aynı konuşma insan mı Fallen mı olduğuna dair ipuçları da taşır. |
| Teşhis hangi eylemle verilir? | **Raf + ihbar.** Hangi raftan servis ettiğin teşhistir. İstersen fotoğraf çekip tedarikçiye ihbar edersin. |
| İpucu nasıl toplanır? | **Soru sor + işaretle.** Müşteri başına sınırlı soru seçersin; şüpheli cümleye tıklayıp not defterine işaretlersin. |
| İşaret istihbaratla eşleşince oyun yardım eder mi? | **Hiç yardım yok.** İşaretler yalnızca oyuncunun notudur; eşleştirmeyi oyuncu kendi kafasında yapar. |
| Zaman baskısı | **Saat yok.** Gece sabit sayıda müşteriyle biter; gerilim soru hakkından gelir. |

Kullanıcının tarifi: sabahları gece gelecek Fallen'lara karşı bilgi, ülkenin ve istihbaratın durumu gelir. Akşam/gece insanlardan da şüphelenirsin; kimin Fallen kimin insan olduğunu anlamak zorlaşır, bu yüzden yanlış seçim yapabilirsin.

## Önerilen yaklaşım: karma içerik

- **Hikâye müşterileri elle yazılır:** JSON'da giriş, 3–4 soru, cevaplar ve dolaylı sipariş.
- **Rastgele ve Endless müşteriler bir özellik havuzundan üretilir:** konuşma tiki, görünüş, nerede olduğu, sıcak/soğuk tepkisi.
- Her sabahın istihbaratı o gün hangi özelliklerin Fallen işareti sayılacağını belirler, Papers, Please'teki günlük kural değişimi gibi.
- İki tür müşteri de aynı soru-cevap biçimini kullanır; motor tektir.

Elenen yollar:
- **Yalnızca elle yazmak:** 48 saatte metin yükü çok büyük ve Endless tekrar eder.
- **Yalnızca üretmek:** hikâye karakterleri sığ kalır.

## Bölüm 1: Bir günün akışı

**Sabah (Defne) ve istihbarat**
- Konuşmanın sonunda bir *istihbarat notu* düşer. Örnek: "Fallen'lar saatleri karıştırıyor; gün ışığını gece gibi anlatıyorlar."
- Gazete manşeti ülkenin durumunu anlatır; bazı manşetler ipucu taşır.
- Notlar defterde **İstihbarat** sekmesinde birikir. Günler geçtikçe yeni notlar gelir; bazı eskileri artık geçmez ("Artık metal yüzük takıyorlar").

**Gündüz**
- Yalnızca insanlar gelir ama siparişler dolaylıdır.
- Soru sormayı ve işaretlemeyi burada öğrenirsin; söylentiler de buradan gelir.

**Gece: karışık, 3–4 müşteri.** Her müşteri için:
1. Giriş konuşması ve **dolaylı sipariş**. Örnekler: "Demir tadında, sıcak bir şey…" ya da "Annemin kış akşamları gibi."
2. **2 soru hakkı:** 3–4 seçenekten 2'sini seçersin. Cevaplar konuşma balonunda çıkar.
3. **İşaretleme:** Herhangi bir cümleye tıklarsın, cümle o müşterinin dava dosyasına not düşer. Oyun hiçbir eşleşme söylemez.
4. **Raf seçimi = teşhis:** İnsan rafından ya da gizli raftan demlersin. Servis ettiğinde karar verilmiş olur.
5. İstersen fotoğraf çekip **ihbar** için dava dosyasına alırsın (mevcut sistem).

**Akşam (Vey):** ihbarlar ve gecenin sonuçları.

**Yanlış teşhisin sonucu**
- **İnsana Fallen içeceği:** Müşteri tadı fark eder, panik olur, polise gider. Defne'nin güveni düşer, ertesi sabah sorgulanırsın.
- **Fallen'a insan içeceği:** Fallen aç kalır ve öfkelenir. Vey'in güveni düşer, ertesi gece biri kaybolmuş olur (gazetede çıkar).
- Bu sonuçlar mevcut son kurallarına (`wrong_serves`) bağlanır.

## Bölüm 2: Ekran ve kontroller

**Soru seçimi**
- Konuşma balonunun altında 3–4 soru düğmesi çıkar.
- Soru hakkı balonun köşesinde görünür (●●). Hak bitince düğmeler kapanır ve müşteri siparişini tekrarlar.
- Kısayollar: 1–4 soru, Boşluk/Enter devam.

**Cümle işaretleme**
- Balondaki cümlenin üstüne gelince altı çizilir; tıklayınca o cümle müşterinin dava dosyasına "not" olarak eklenir. Tekrar tıklamak notu kaldırır.
- Dava dosyasının sağ kâğıdında görünüş satırının altında işaretli cümleler listelenir.

**Defter**
- Mevcut tarif defterine **İstihbarat** sekmesi eklenir: günlere göre notlar, geçersiz olanların üstü çizili.
- Gazete manşetleri de buraya düşer.

**Dolaylı sipariş**
- Sipariş artık tarif adı söylemez.
- Tarif defteri tariflerin "anlatımını" da gösterir (ör. Sabah Sisi: "sıradan bir sabah, yumuşak").
- Oyuncu ipucuyla tarifi ya da tat isteğini eşleştirir.

**Tempo ayarları**
- AUTO kapalı başlar.
- Daktilo hızı ayarlardan değişir.
- Gece müşteri sayısı 3–4, gündüz 2–3.

## Bölüm 3: Veri biçimi

Hikâye müşterisi (`days.json` → `day` / `night` girdisi):

```json
{
  "character": "eren",
  "species": "fallen",
  "intro": ["Bu saatte açık olacağını söylemişti."],
  "order": {"recipe": "red", "line": "Eskisi gibi… sıcak, biraz demir tadında."},
  "questions": [
    {"ask": "q.where_from", "answer": ["Hastaneden. Gün batarken çıktım, güneş tam tepedeydi."]},
    {"ask": "q.cold", "answer": ["Soğuk mu? Hiç fark etmedim."]},
    {"ask": "q.previous_barista", "answer": ["Senden önceki… ellerini hatırlıyorum."]}
  ],
  "after_serve": {"right": ["…Teşekkürler."], "wrong": ["Bu ne? Bu… değil."]}
}
```

- `questions[].ask` bir `tr.json` anahtarıdır, çünkü soru metinleri ortaktır. Cevaplar içeriktir.
- `species` gizlidir. Oyuncuya gösterilmez; snapshot'a sızmaz (mevcut `wrong_serves` gibi).

İstihbarat (`days.json` → `intel`):

```json
{"id": "clock_mixup", "text": "Fallen'lar saatleri karıştırıyor; gün ışığını gece gibi anlatıyorlar.", "trait": "time_confusion", "until_day": 3}
```

Özellik havuzu (`encounter_pools.json` → `traits`), rastgele müşteriler için:
- Her özelliğin `human` ve `fallen` cevap varyantları vardır.
- Günün istihbaratındaki özellikler Fallen'larda fallen varyantıyla, insanlarda zaman zaman yanıltıcı varyantla çıkar (yorgun hemşire soluk görünür).
- Fallen'lar ilerleyen günlerde istihbarattaki özelliği saklamayı öğrenir: varyant olasılığı düşer.

## Bölüm 4: Kurallar ve durum

- **Domain:** yeni `domain/interrogation/` modülü. Soru hakkı, sorulan sorular, işaretli cümleler ve gizli tür bilgisi burada tutulur. Saf kural; EventBus komutları `ask`, `mark` ve `unmark`.
- **Servis:** teşhis, `_serve`'de içeceğin `side` alanı ile kişinin `species` alanı karşılaştırılarak bulunur. Bu alan bugün de var; değişen tek şey, siparişin artık türü ele vermemesi.
- **Güven:** `defne_trust` ve `vey_trust` sayaçları yanlış servis ve yanlış ihbarla düşer. Sonlar ve ertesi günün olayları (sorgu, kayıp haberi) bu sayaçları okur.
- **Kayıt:** sorulan sorular ve işaretler `state`'e yazılır; eski kayıtlar boş listeyle yüklenir.

## Bölüm 5: Test

- `domain_test`: soru hakkı, işaret ekle/kaldır, gizli türün snapshot'a sızmaması.
- `flow_test`: her strateji geceleri soru sorup raf seçer; yanlış teşhis güveni düşürür.
- `localization_test`: soru anahtarları `tr.json`'da.
- `visual_smoke`: soru düğmesine gerçek tıklama, cümle işaretleme, dava dosyasında notun görünmesi.

## Açık sorular: varsayılan cevaplar

1. **Sonuçların tonu:** önerildiği gibi. İnsana Fallen içeceği → polis sorgusu; Fallen'a insan içeceği → kayıp haberi.
2. **Gündüz soru hakkı:** var, 2 soru. Gündüz öğretici gibi çalışır, müşteriler insandır.
3. **Hikâye müşterisi başına soru:** 3 soru. Metinler yer tutucudur, hikâye yazarı değiştirir.
4. **Gazete manşeti:** bazı günler ipucu taşır (istihbarat notu olarak deftere düşer), bazı günler yalnızca atmosferdir.

## Uygulama sırası (onaydan sonra)

1. Domain: soru/işaret kuralları ve testleri.
2. İçerik biçimi: `days.json` yeni alanlar, bir gecelik örnek içerik, doğrulama.
3. Sunum: soru düğmeleri, cümle işaretleme, dava dosyasında notlar.
4. Defter: İstihbarat sekmesi.
5. Güven sayaçları ve sonuçlar.
6. Rastgele müşteriler için özellik havuzu.
