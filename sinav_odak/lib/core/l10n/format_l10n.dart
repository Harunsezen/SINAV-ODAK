import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Dile bağlı sayı ve süre biçimleri.
///
/// ## Neden ayrı bir dosya, neden `formatters.dart` değil
///
/// `core/utils/formatters.dart` **saf Dart**: `L10n` import etmiyor ve
/// rapor/CSV gibi bilerek Türkçe kalan yerlerden de çağrılıyor. Dili
/// oraya taşımak, PDF karnesindeki Türkçe biçimi de arayüz diline
/// bağlardı — istenmeyen bir bağ.
///
/// ## Bulunuş hikâyesi
///
/// E turunda tüm metinler çevrildi, testler yeşildi ve arayüz İngilizceydi
/// — ama ana panelde **"1sa / 4sa"** yazıyordu. `formatDurationShort`
/// birim adlarını gövdesine gömmüştü; ARB'de `durationHm`/`durationM`
/// anahtarları vardı ama hiç kullanılmıyordu. Ekran görüntüsüne
/// bakılmasaydı görünmezdi.
extension FormatL10n on L10n {
  /// 8130 sn → "2sa 15dk" / "2h 15m".
  ///
  /// Sıfır saat ve sıfır dakika ayrı ayrı eleniyor: "0sa 15dk" ile
  /// "2sa 0dk" ikisi de gürültü.
  String durationShort(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h == 0) return durationM(m);
    if (m == 0) return durationH(h);
    return durationHm(h, m);
  }

  /// Sabit basamaklı ondalık: 66.0 → "66,0" (TR) / "66.0" (EN).
  ///
  /// v1.1'de bu değerler `toStringAsFixed(1)` ile yazılıyordu ve TÜRKÇE
  /// arayüzde de nokta gösteriyordu ("66.0"). Türkçede ondalık ayracı
  /// virgül; E turunda İngilizce ekranlara bakarken görüldü.
  String decimalFixed(double value, int digits) =>
      value.toStringAsFixed(digits).replaceAll('.', decimalSeparator);

  /// Net: 41.0 → "41" · 40.25 → "40,25" (TR) / "40.25" (EN).
  ///
  /// Ondalık ayracı bir ÇEVİRİ değil, dilin sayı biçimi; ARB'de
  /// `decimalSeparator` anahtarı tutuluyor ki iki dil de kendi
  /// kuralını söylesin.
  String netText(double net) {
    final rounded = (net * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
    return rounded.toStringAsFixed(2).replaceAll('.', decimalSeparator);
  }
}
