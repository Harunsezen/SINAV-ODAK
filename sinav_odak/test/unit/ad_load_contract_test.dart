import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v1.5.2 — **AYNI TUZAĞA BİR DAHA DÜŞÜLMESİN.**
///
/// ## Neden kaynak metni okuyan bir test
///
/// `AdMobGateway` gerçek AdMob platform kanalını kullanıyor; host
/// testinde ne `BannerAd` kurulabiliyor ne de `RewardedAd.load`
/// çağrılabiliyor. Yani bu dosyadaki hatayı **hiçbir davranış testi
/// yakalayamıyor** — cihazda denemeden görülmüyor.
///
/// Oysa hata hep aynı hata:
///
/// > `google_mobile_ads` içindeki `load()` çağrılarının Future'ı **istek
/// > gönderilince** tamamlanıyor, reklam gelince DEĞİL. `show()` de reklam
/// > **ekrana gelince** tamamlanıyor, kapanınca değil.
///
/// Bu tuzak uygulamada üç ayrı yerde birden vardı ve her biri sessizce
/// "reklam yok" diyordu: banner ve native yuvası boş kaldı, "İzle ve
/// destekle" düğmesi her seferinde "Reklam gelmedi" dedi. Panelde
/// istek sayısı sıfırdı.
///
/// Doğru kalıp: isteği `unawaited` başlat, sonucu geri çağrıdan gelen
/// `Completer` ile bekle, `timeout` koy. Aşağıdaki test kaynakta yanlış
/// kalıbın geri gelmediğini kontrol ediyor.
void main() {
  final file = File('lib/services/ads/admob_gateway.dart');
  final source = file.readAsStringSync();

  /// Yorum satırları hariç kaynak: aynı tuzağı ANLATAN yorumlar var,
  /// onların eşleşmesi yanlış alarm olurdu.
  final code = source
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  test('kaynak dosyası duruyor', () {
    expect(file.existsSync(), isTrue);
  });

  test('hiçbir load() DOĞRUDAN beklenmiyor', () {
    final bad = RegExp(r'await\s+\w+(?:Ad)?\.load\s*\(');
    expect(
      bad.allMatches(code).map((m) => m.group(0)).toList(),
      isEmpty,
      reason: 'load() Future\'ı istek gönderilince tamamlanıyor; sonucu '
          'onAdLoaded/onAdFailedToLoad veriyor',
    );
  });

  test('hiçbir show() DOĞRUDAN beklenmiyor', () {
    final bad = RegExp(r'await\s+ad\.show\s*\(');
    expect(
      bad.allMatches(code).map((m) => m.group(0)).toList(),
      isEmpty,
      reason: 'show() reklam EKRANA GELİNCE tamamlanıyor; ödül ve kapanış '
          'daha sonra geliyor',
    );
  });

  test('dört yükleme yolu da Completer + timeout kullanıyor', () {
    for (final method in [
      'Future<Object?> loadBanner',
      'Future<Object?> loadNative',
      'Future<bool> showInterstitial',
      'Future<bool> showRewarded',
    ]) {
      final start = code.indexOf(method);
      expect(start, greaterThan(-1), reason: '$method kayboldu');

      // Sonraki metoda kadar olan gövde.
      final rest = code.substring(start + method.length);
      final nextOverride = rest.indexOf('  @override');
      final body = nextOverride == -1 ? rest : rest.substring(0, nextOverride);

      expect(
        body,
        contains('Completer'),
        reason: '$method sonucu geri çağrıdan beklemeli',
      );
      expect(
        body,
        contains('loadTimeout'),
        reason: '$method hiç geri çağrı gelmezse sonsuza kadar bekler',
      );
    }
  });

  test('tam ekran reklamlar gösterim HATASINI da karşılıyor', () {
    // Yoksa reklam sızıyor ve çağıran ekran sonsuza kadar bekliyor.
    expect(
      'onAdFailedToShowFullScreenContent'.allMatches(code).length,
      greaterThanOrEqualTo(2),
      reason: 'hem ara reklam hem ödüllü reklam için gerekli',
    );
  });
}
