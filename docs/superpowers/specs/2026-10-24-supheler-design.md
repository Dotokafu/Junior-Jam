# Şüpheler: devlet ile örgüt arasında

Tarih: 2026-10-24 · Durum: **taslak**, onay bekliyor · Önceki belge: `2026-10-24-sorgu-ve-tempo-design.md` (Plan 2)

## Amaç

Oyunun temeli Papers, Please'teki gibi iki taraf arasında seçim:

- **Devlet (Defne, sabah teslimatı):** Fallen şüphelilerini ister.
- **Örgüt (Vey, gece teslimatı):** insanların bilgisini ister.

Birine yaslanmak ötekini işkillendirir. Hiç vermemek de soranı işkillendirir. Şüphe dolarsa o tarafın kötü sonu gelir.

Bugün olan:
- Dosya teslimi (sabah Defne'ye "Fallen şüphesi", akşam Vey'e "insan bilgisi").
- Teslim sayaçlarına bağlı sonlar.

Eksik olan:
- Soran tedarikçi.
- İki tarafın şüphesi.
- Kötü sona yaklaşıldığını hissettiren olaylar.

## Kararlar (kullanıcıyla)

| Soru | Karar |
| --- | --- |
| Şüphe görünür mü? | **Gizli.** Çubuk yok. Tedarikçinin tavrı, sorgu ve kapı notları hissettirir. |
| Sorulup dosya verilmezse? | Soranın şüphesi **biraz** artar. |
| Şüphe dolunca? | **Her tarafın kendi kötü sonu:** devlet seni alır (kafe mühürlenir); örgüt bir gece kapıyı kapatır. |
| Yükselirken ne olur? | **Tedarikçinin tavrı değişir**, yüksek şüphede **sorgu sahnesi** açılır, gece kapanışında **kapı notu** gelir. (Gazete manşeti seçilmedi.) |

## Şüphe modeli

- İki gizli değer: `suspicion.state` (devlet) ve `suspicion.order` (örgüt). Aralık 0–100.
- Seviyeler: `calm` (0–33), `wary` (34–66), `threat` (67–99). 100'e ulaşınca o tarafın kötü sonu gelir.

Değerleri oynatan olaylar. Sayılar `content/endings.json` → `suspicion` alanında; kod değişmeden dengelenir.

| Olay | Etki (varsayılan) |
| --- | --- |
| Bir tarafa doğru ya da yanlış dosya vermek | Öteki tarafın şüphesi +15 |
| Aynı tarafa art arda dosya vermek ("bariz") | Her ardışık teslimde öteki tarafa ek +10 (2. teslim +25, 3. teslim +35) |
| Dosya verdiğin taraf | Kendi şüphesi −10 (sana güvenir) |
| Yanlış kişiyi vermek (insanı Fallen diye ya da tersi) | Aldığın tarafın şüphesi +20 (onları yanılttın) |
| Teslimatta sorulup hiç dosya vermemek (2. günden sonra) | Soranın şüphesi +8 |
| İnsana Fallen içeceği vermek | Devletin şüphesi +12 (müşteri polise gider) |
| Fallen'a insan içeceği vermek | Örgütün şüphesi +12 (aç kalan Fallen şikâyet eder) |
| Doğru rafın yanlış içeceği (istediğinden başka bir insan ya da Fallen içeceği) | Müşterinin tarafının şüphesi +5 |

**Kötü sonun zamanı:** Şüphe 100'e ulaştığında son hemen gelmez. O tarafın bir sonraki teslimatının başında gelir: "Defne bu sabah yalnız gelmedi…" Teslim anında ulaşılırsa son o teslimatın sonunda gelir. Kötü sonlar diğer sonlardan önce gelir.

## Oyunda nasıl hissedilir

**1. Soran tedarikçi.** 2. günden itibaren teslimatın sonunda tedarikçi açıkça sorar:
- Defne: "Dün gece şüpheli biri geldiyse dosyasını ver."
- Vey: "Bize verebileceğin biri var mı? Bir yüz, bir isim yeter."

Bunlar mevcut genel "Dosya vermek zorunda değilsin" satırının yerini alır.

**2. Tavır değişimi.** Tedarikçinin sabah/akşam satırlarının sonuna, o tarafın şüphe seviyesine göre bir satır eklenir:
- `calm`: ek yok
- `wary`: imalı
- `threat`: açık tehdit

Satırlar içerikte durur (`suspicion_lines.state.wary` vb.).

**3. Sorgu sahnesi.** Bir tarafın şüphesi `threat` seviyesine ilk ulaştığında, o tarafın bir sonraki teslimatında olur. Oyun boyunca taraf başına bir kez yaşanır.
- Tedarikçi bir soru sorar ve 3 cevap seçeneği çıkar. Sorgu ekranının düğmeleri yeniden kullanılır.
- Her cevabın etkisi ve tedarikçinin karşılığı içerikte durur. Örnek: "Eski raflar, boş" −15; "Kimseye bir şey vermiyorum" +10.

**4. Kapı notu.** Gece kapanınca şafak ekranında, şüphesi en yüksek tarafın seviyesine göre kısa bir not çıkar. Örnek, devlet `wary`: "Kepengin altından bir kâğıt: *Saat dörtte ışıkların yanıyordu.*" Bütün taraflar `calm` ise not çıkmaz.

**5. Gizlilik.** Şüphe değerleri, art arda teslim sayacı ve sorgu bayrakları snapshot'a girmez. Sunum yalnızca metinleri alır: tavır satırı, soru, cevaplar ve kapı notu.

## Tarif defteri

Kullanıcı isteği: tarif defteri boş başlar. Bir tarifi ilk kez demleyince deftere yazılır ve kısa bir bildirim çıkar. Sağ sayfa boşsa "Henüz tarif yok" yazar.

## Sonlar

Mevcut dört son ve `reserved` yuvası kalır. Bunlara iki son eklenir:

- **`state_arrest`, "Mühür":** Defne bu sabah yalnız gelmez; kafe mühürlenir.
- **`order_vanish`, "Kapı":** Vey'in adamları bir gece kapıyı içeriden kapatır.

İkisinin de `errors` metni vardır; 2 veya daha fazla hata varsa sona eklenir.

## Mimari

- **Domain (`domain/consequences/suspicion_rules.gd`, yeni):** Saf fonksiyonlar. `after_report`, `after_decline`, `after_serve`, `level`, `bad_ending`, `answer_effect`. Her biri yeni bir sözlük döndürür; verilen değişmez.
- **Domain (`ending_rules.gd`):** `resolve` önce kötü sonlara bakar.
- **Durum (`shift_state.gd`):** `suspicion`, `give_streak`, `last_given`, `delivery_reported`, `interrogated`, `interrogation`. Eski kayıtlar varsayılanlarla yüklenir.
- **Oturum (`game_session.gd`):**
  - Teslim/servis/teslimat sonu kancaları.
  - Teslimat başında kötü son kontrolü.
  - Tavır satırı ekleme.
  - Sorgu aşaması `questioning` ve `answer_interrogation` komutu.
  - Snapshot'ta kapı notu.
- **İçerik:**
  - `endings.json`: `suspicion` sayıları, iki yeni son.
  - `encounter_pools.json`: `suspicion_lines`, `interrogations`, `door_notes`.
  - `tr.json`: soran satırlar.
- **Sunum:**
  - Balon sorgu cevaplarını sorgu düğmeleriyle gösterir.
  - Şafak ekranı kapı notunu gösterir.
  - Son ekranı veriyle çalıştığı için değişmez.

## Test

- **`domain_test`:** her olayın etkisi, art arda teslim bonusu, seviyeler, kötü son önceliği, verilen sözlüğün değişmemesi.
- **`flow_test`:**
  - Mevcut stratejilerin sonları korunur.
  - "mistakes" stratejisi artık bir kötü sonla biter (`state_arrest` ya da `order_vanish`).
  - Yeni bir strateji, hep aynı tarafa teslim, öteki tarafın kötü sonuna gider.
  - Şüphe değerleri snapshot'a sızmaz.
- **`save_test`:** şüphe alanları olmayan eski kayıt yüklenir.
- **`visual_smoke`:** sorgu cevabına gerçek tıklama, kapı notunun şafak ekranında görünmesi.
