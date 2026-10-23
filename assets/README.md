# Geçici görseller

Kafe ve karakterler şu an `presentation/art/` altında kodla çizilen yer tutuculardır. Oyun kuralları bu çizimlere bağlı değildir.

## Kendi çizimini ekle

Karakter kaydına isteğe bağlı alan ekle:

```json
"portrait_texture": "res://assets/characters/ada.png"
```

Şeffaf arka planlı karakter çizimi kafe ekranında ve GBT fotoğrafında kullanılır. Alan boşsa yer tutucu çizilir. Rastgele müşterilerde bu görsel `portraits` havuzundan gelir. Karakter çizimi için yaklaşık **107:148** oranı uygundur; kesin ölçüler çizimler geldikten sonra uyarlanabilir.

`presentation/cafe.tscn` sahnesinin kök düğümünde Inspector üzerinden `Cafe Background` ve isteğe bağlı `Cafe Counter` dokularını atayabilirsin. İkisi de **1360×380** oranında yerleştirilir; tezgâh katmanı şeffaf olabilir ve karakterin önüne çizilir. Gerçek arka plan atandığında hazır dekor çizilmez. Raf görselleri ve animasyonunun gerçek çizimlere uyarlanması çizimler geldikten sonra yapılacak.

`audio/rain.wav` bu prototip için üretilen basit ortam sesi yer tutucusudur. Menüden susturulabilir. Fontlar Liberation ailesidir; dağıtım lisansı `fonts/LICENSE` içindedir.
