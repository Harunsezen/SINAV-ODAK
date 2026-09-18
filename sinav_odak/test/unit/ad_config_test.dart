import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/config/ad_config.dart';

/// v1.5.2 — **KİMLİK SÜZGECİ.**
///
/// ## Neden bu dosya var
///
/// 1.5.2'nin ilk derlemesinde PowerShell `-Padmob_app_id=$APP_ID` içindeki
/// değişkeni açmadı. Gradle'a `$APP_ID` **metni** gitti, manifest'e
/// `android:value="$APP_ID"` yazıldı ve uygulama açılışta çöktü —
/// google_mobile_ads kimliği bir ContentProvider içinde, Dart kodu hiç
/// çalışmadan kontrol ediyor. Derleme sorunsuz bitti, AAB imzalandı,
/// Play'e yüklendi ve orada "Bozuk İşlevsellik" ile reddedildi. Hiçbir
/// aşamada kimse değerin BİÇİMİNE bakmamıştı.
///
/// Uygulama kimliği artık Gradle'da doğrulanıyor, derleme orada duruyor.
/// Burada sınanan şey ikinci yarısı: `--dart-define` ile gelen reklam
/// birimi kimlikleri. Aynı kaza orada da olabilirdi ve çok daha sessiz
/// olurdu — uygulama açılır, çökmez, sadece hiç reklam gelmezdi.
void main() {
  group('kalıplar GERÇEK kimlikleri kabul ediyor', () {
    test('uygulama kimliği (~ ayraçlı)', () {
      expect(AdConfig.appIdPattern.hasMatch(AdConfig.testAppId), isTrue);
      expect(
        AdConfig.appIdPattern
            .hasMatch('ca-app-pub-6172662947666489~1593328391'),
        isTrue,
      );
    });

    test('reklam birimleri (/ ayraçlı)', () {
      for (final unit in [
        AdConfig.testBannerUnit,
        AdConfig.testNativeUnit,
        AdConfig.testInterstitialUnit,
        AdConfig.testRewardedUnit,
        'ca-app-pub-6172662947666489/8951963727',
      ]) {
        expect(AdConfig.unitPattern.hasMatch(unit), isTrue, reason: unit);
      }
    });
  });

  group('kalıplar BOZUK değerleri reddediyor', () {
    // Listenin başındaki iki değer teorik değil: 1.5.2'de manifest'e
    // gerçekten `$APP_ID` yazıldı.
    const bozuk = [
      r'$APP_ID',
      r'$BANNER',
      r'${admobAppId}',
      '',
      '   ',
      'ca-app-pub-',
      'BURAYA_BANNER',
      'ca-app-pub-6172662947666489',
    ];

    test('uygulama kimliği kalıbı', () {
      for (final v in bozuk) {
        expect(AdConfig.appIdPattern.hasMatch(v), isFalse, reason: v);
      }
    });

    test('birim kalıbı', () {
      for (final v in bozuk) {
        expect(AdConfig.unitPattern.hasMatch(v), isFalse, reason: v);
      }
    });
  });

  test('AYRAÇLAR birbirinin yerine geçmiyor', () {
    // En olası insan hatası: uygulama kimliği yerine birim yapıştırmak.
    // İkisi de `ca-app-pub-` ile başlıyor, farkı tek karakter.
    expect(
      AdConfig.appIdPattern.hasMatch('ca-app-pub-6172662947666489/8951963727'),
      isFalse,
      reason: 'birim kimliği uygulama kimliği olarak kabul edilmemeli',
    );
    expect(
      AdConfig.unitPattern.hasMatch('ca-app-pub-6172662947666489~1593328391'),
      isFalse,
      reason: 'uygulama kimliği birim olarak kabul edilmemeli',
    );
  });

  test('define verilmeyince TEST kimlikleri kullanılıyor', () {
    // Testler `--dart-define` olmadan koşuyor: varsayılan yol burası.
    // Unutmanın GÜVENLİ tarafa düşmesi ürün kuralı — kendi reklamına
    // tıklamak hesabı kapattırır.
    expect(AdConfig.appId, AdConfig.testAppId);
    expect(AdConfig.bannerUnit, AdConfig.testBannerUnit);
    expect(AdConfig.nativeUnit, AdConfig.testNativeUnit);
    expect(AdConfig.interstitialUnit, AdConfig.testInterstitialUnit);
    expect(AdConfig.rewardedUnit, AdConfig.testRewardedUnit);
    expect(AdConfig.usingTestIds, isTrue);
    expect(AdConfig.hasMalformedIds, isFalse);
  });
}
