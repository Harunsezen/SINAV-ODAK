import '../../core/errors/failures.dart';
import '../entities/enums.dart';

/// Odak skoru (0–100) hesaplar.
///
/// Skor **tek bir oturumun dürüst ölçümüdür**: streak bonusu gibi dış
/// etkenler bilinçli olarak dahil edilmez, onlar ayrıca gösterilir.
///
/// "Pause yok" kuralı tek başına disiplini garanti etmez — kullanıcı
/// uygulamadan çıkıp başka bir şeyle ilgilenebilir ve sayaç işlemeye devam
/// eder. Bu yüzden skorun 35 puanı ([foregroundS] ve [exitCount] üzerinden)
/// uygulamada geçirilen gerçek süreye bakar.
abstract final class FocusScoreCalculator {
  static const int _completionWeight = 55;
  static const int _presenceWeight = 25;
  static const int _exitWeight = 10;
  static const int _breakWeight = 10;

  /// Ceza tabanı: 6 ve üzeri çıkış tam ceza demektir.
  static const int _exitPenaltyCap = 6;

  /// [SessionStatus.running] için `null` döner — devam eden oturumun skoru
  /// hesaplanmaz.
  static int? calculate({
    required SessionStatus status,
    required int plannedDurationS,
    required int actualDurationS,
    required int foregroundS,
    required int exitCount,
    required int extendedBreakS,
    required int totalPlannedBreakS,
  }) {
    if (plannedDurationS < 0) {
      throw const ValidationFailure(
        'Planlanan süre negatif olamaz.',
        field: 'plannedDurationS',
      );
    }
    if (actualDurationS < 0) {
      throw const ValidationFailure(
        'Gerçekleşen süre negatif olamaz.',
        field: 'actualDurationS',
      );
    }
    if (foregroundS < 0) {
      throw const ValidationFailure(
        'Önplan süresi negatif olamaz.',
        field: 'foregroundS',
      );
    }
    if (exitCount < 0) {
      throw const ValidationFailure(
        'Çıkış sayısı negatif olamaz.',
        field: 'exitCount',
      );
    }
    if (extendedBreakS < 0) {
      throw const ValidationFailure(
        'Mola uzatma süresi negatif olamaz.',
        field: 'extendedBreakS',
      );
    }
    if (totalPlannedBreakS < 0) {
      throw const ValidationFailure(
        'Planlanan mola süresi negatif olamaz.',
        field: 'totalPlannedBreakS',
      );
    }

    if (status == SessionStatus.running) return null;

    // 1) Tamamlama oranı — 55 puan.
    //    Planlanan süre 0 ise hata değil; oran 0 kabul edilir.
    final completion = plannedDurationS == 0
        ? 0.0
        : (actualDurationS / plannedDurationS).clamp(0.0, 1.0);
    var score = _completionWeight * completion;

    // 2) Uygulama içinde kalma — 25 puan.
    final presence = actualDurationS == 0
        ? 0.0
        : (foregroundS / actualDurationS).clamp(0.0, 1.0);
    score += _presenceWeight * presence;

    // 3) Çıkış sayısı cezası — 10 puan.
    score += _exitWeight * (1 - (exitCount / _exitPenaltyCap).clamp(0.0, 1.0));

    // 4) Mola disiplini — 10 puan.
    final compliance = totalPlannedBreakS == 0
        ? 1.0
        : 1 - (extendedBreakS / totalPlannedBreakS).clamp(0.0, 1.0);
    score += _breakWeight * compliance;

    // 5) Durum çarpanı.
    final multiplier = switch (status) {
      SessionStatus.completed => 1.00,
      SessionStatus.earlyFinished => 0.80,
      SessionStatus.interrupted => 0.55,
      SessionStatus.running => 1.00, // yukarıda null döndü
    };

    return (score * multiplier).round().clamp(0, 100);
  }
}
