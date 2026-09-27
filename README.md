# NoPen v0.1

NoPen ses dosyası oluşturmadan Android cihaz içi konuşma tanıma ile canlı Türkçe transkript üretir.

## Özellikler
- Toplantı adını uygulamada manuel girme
- Android On-Device SpeechRecognizer (API 31+ ve cihaz desteği gerekir)
- Ses dosyası kaydetmez
- Yerel, kural tabanlı toplantı raporu: özet, konular, kararlar, aksiyonlar
- Android paylaşım menüsü
- Cihaz içi toplantı arşivi

## CodeMagic
`codemagic.yaml` Android platformunu temiz şekilde üretir, native on-device STT köprüsünü kopyalar, ardından `flutter analyze`, `flutter test` ve release APK build çalıştırır. Microsoft/Outlook değişkeni veya API anahtarı gerekmez.
