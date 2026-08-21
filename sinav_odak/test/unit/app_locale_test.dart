import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/l10n/app_locale.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

/// v1.2/E — dil ayarı ile `Locale` arasındaki dönüşüm.
///
/// Saf Dart: `MaterialApp` kurmadan test ediliyor. Buradaki kural üç ayrı
/// yerden okunuyor (arayüz, açılıştaki bildirim kanalı, bildirim metinleri);
/// biri sapsa uygulama Türkçe, bildirimler İngilizce olurdu.
void main() {
  group('materialLocaleOf', () {
    test('açık seçimler somut locale veriyor', () {
      expect(AppLocale.materialLocaleOf(AppLanguage.tr), const Locale('tr'));
      expect(AppLocale.materialLocaleOf(AppLanguage.en), const Locale('en'));
    });

    test('sistem seçimi NULL — Flutter kendi çözsün', () {
      // `MaterialApp.locale = null` cihaz dilini izliyor. Burada somut bir
      // değer üretseydik "sistem" ayarı sistemi izlemeyi bırakırdı.
      expect(AppLocale.materialLocaleOf(AppLanguage.system), isNull);
    });
  });

  group('resolve (widget ağacı dışı)', () {
    test('açık seçim cihaz dilini EZİYOR', () {
      expect(
        AppLocale.resolve(
          AppLanguage.en,
          platformLocale: const Locale('tr'),
        ),
        const Locale('en'),
      );
      expect(
        AppLocale.resolve(
          AppLanguage.tr,
          platformLocale: const Locale('en'),
        ),
        const Locale('tr'),
      );
    });

    test('sistem: desteklenen cihaz dili kullanılıyor', () {
      expect(
        AppLocale.resolve(
          AppLanguage.system,
          platformLocale: const Locale('en'),
        ),
        const Locale('en'),
      );
    });

    test('sistem: DESTEKLENMEYEN cihaz dili Türkçeye düşüyor', () {
      // `MaterialApp`in yaptığının aynısı (supportedLocales'in ilki).
      // Farklı davransaydı arayüz Türkçe, bildirimler Almanca olurdu.
      expect(
        AppLocale.resolve(
          AppLanguage.system,
          platformLocale: const Locale('de'),
        ),
        AppLocale.fallback,
      );
    });

    test('sistem: cihaz dili hiç yoksa Türkçe', () {
      expect(AppLocale.resolve(AppLanguage.system), const Locale('tr'));
    });

    test('ülke kodu göz ardı ediliyor — en_US da İngilizce', () {
      expect(
        AppLocale.resolve(
          AppLanguage.system,
          platformLocale: const Locale('en', 'US'),
        ),
        const Locale('en'),
      );
    });
  });

  test('desteklenen diller listesi ile varsayılan tutarlı', () {
    // `supported`in İLKİ fallback olmalı: Flutter desteklenmeyen dilde
    // `supportedLocales.first`e düşüyor ve ikisi ayrışırsa aynı cihazda
    // iki farklı dil çıkardı.
    expect(AppLocale.supported.first, AppLocale.fallback.languageCode);
    expect(AppLocale.supported, ['tr', 'en']);
  });
}
