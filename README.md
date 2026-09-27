# NoPen v0.1

NoPen ses dosyası oluşturmadan Android cihaz içi konuşma tanıma ile canlı Türkçe transkript üretir.

## Özellikler
- Android On-Device SpeechRecognizer (API 31+ ve cihaz desteği gerekir)
- Ses dosyası kaydetmez
- Microsoft Graph ile Outlook takvim okuma
- Yerel, kural tabanlı toplantı raporu: özet, konular, kararlar, aksiyonlar
- Android paylaşım menüsü
- Cihaz içi toplantı arşivi

## Microsoft kurulumu
Microsoft Entra'da public/mobile app kaydı oluşturun. Redirect URI: `com.nopen.app://oauthredirect`.
CodeMagic environment variables:
- `MS_CLIENT_ID`
- `MS_REDIRECT_URI=com.nopen.app://oauthredirect`

Takvim izni: delegated `Calendars.Read`.

## CodeMagic
`codemagic.yaml` Android platformunu temiz şekilde üretir, native on-device STT köprüsünü kopyalar, ardından `flutter analyze`, `flutter test` ve release APK build çalıştırır.
