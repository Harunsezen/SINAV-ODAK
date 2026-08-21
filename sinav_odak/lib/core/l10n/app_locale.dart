import 'dart:ui' show Locale;

import '../../domain/entities/enums.dart';

/// Dil ayarı ile Flutter `Locale`'ı arasındaki tek dönüşüm noktası.
///
/// **Neden ayrı bir dosya:** dili üç ayrı yer okuyor — `MaterialApp`,
/// açılışta bildirim kanalı metinlerini yükleyen `main()` ve widget ağacı
/// dışında çalışan servisler. Dönüşüm üç yerde ayrı ayrı yazılsaydı biri
/// unutulduğunda uygulama Türkçe, bildirimler İngilizce olurdu.
abstract final class AppLocale {
  /// Desteklenen diller. `supportedLocales` ile aynı sırada olmalı:
  /// Flutter, cihaz dili desteklenmiyorsa listenin **ilkine** düşüyor.
  static const supported = <String>['tr', 'en'];

  /// Varsayılan — cihaz dili çözülemediğinde ve ayar okunamadığında.
  static const fallback = Locale('tr');

  /// `MaterialApp.locale` için. `null` = **cihaz dilini izle**.
  static Locale? materialLocaleOf(AppLanguage language) => switch (language) {
        AppLanguage.system => null,
        AppLanguage.tr => const Locale('tr'),
        AppLanguage.en => const Locale('en'),
      };

  /// Widget ağacı DIŞINDA kullanılacak **somut** dil.
  ///
  /// `MaterialApp` `null` locale'ı kendi çözüyor; bildirim metinlerini
  /// kuran servisin böyle bir lüksü yok, elinde bir `Locale` olmalı.
  /// [platformLocale] genelde `PlatformDispatcher.instance.locale`.
  ///
  /// Desteklenmeyen bir cihaz dili (ör. Almanca) [fallback]'e düşüyor —
  /// `MaterialApp`in yaptığının aynısı, böylece arayüz ile bildirimler
  /// ayrı dillere ayrılmıyor.
  static Locale resolve(AppLanguage language, {Locale? platformLocale}) {
    final explicit = materialLocaleOf(language);
    if (explicit != null) return explicit;

    final code = platformLocale?.languageCode;
    if (code != null && supported.contains(code)) return Locale(code);
    return fallback;
  }
}
