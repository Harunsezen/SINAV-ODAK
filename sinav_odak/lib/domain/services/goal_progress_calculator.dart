// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import '../entities/enums.dart';

/// Bir hedefin ilerlemesini hesaplamak için gereken ölçümler.
///
/// Hangi pencerenin (gün/hafta) toplamı olduğu **çağıranın** sorumluluğu;
/// bu sınıf yalnızca "hangi ölçüm hangi hedef tipine yazılır" kuralını bilir.
class GoalMetrics {
  const GoalMetrics({
    this.dayStudyS = 0,
    this.dayQuestions = 0,
    this.dayNet = 0,
    this.weekStudyS = 0,
    this.weekQuestions = 0,
    this.subjectStudyS = 0,
    this.completedTopics = 0,
    this.currentStreak = 0,
  });

  final int dayStudyS;
  final int dayQuestions;
  final double dayNet;
  final int weekStudyS;
  final int weekQuestions;

  /// Hedefin `subjectId`'sine ait süre (yalnız `subjectMinutes` için).
  final int subjectStudyS;
  final int completedTopics;
  final int currentStreak;
}

/// `goals.currentValue`'yu besleyen saf hesap.
///
/// **Neden var?** `currentValue` kolonu şemada duruyordu ama **hiçbir kod
/// yazmıyordu**: kullanıcı hedef oluşturuyor, ilerleme sonsuza kadar 0
/// kalıyordu. Hesap saf tutuluyor ki "dakika mı saniye mi" gibi birim
/// hataları testle yakalanabilsin.
///
/// **Birim sözleşmesi:** süre hedefleri DAKİKA cinsindendir (`dailyMinutes`,
/// `weeklyMinutes`, `subjectMinutes`); ölçümler saniye gelir ve burada
/// dakikaya çevrilir. Saniye yazılsaydı 240 dakikalık hedef 4 saniyede
/// dolmuş görünürdü.
abstract final class GoalProgressCalculator {
  static double valueFor(GoalType type, GoalMetrics m) => switch (type) {
        GoalType.dailyMinutes => (m.dayStudyS ~/ 60).toDouble(),
        GoalType.weeklyMinutes => (m.weekStudyS ~/ 60).toDouble(),
        GoalType.dailyQuestions => m.dayQuestions.toDouble(),
        GoalType.weeklyQuestions => m.weekQuestions.toDouble(),
        GoalType.subjectMinutes => (m.subjectStudyS ~/ 60).toDouble(),
        GoalType.topicCompletion => m.completedTopics.toDouble(),
        GoalType.net => m.dayNet,
        GoalType.streak => m.currentStreak.toDouble(),
      };

  /// Hedefe ulaşıldı mı?
  ///
  /// `>=` bilinçli: 240 dakikalık hedefte tam 240 dakika çalışan kullanıcıya
  /// "ulaşamadın" demek olurdu.
  static bool isReached(double current, double target) =>
      target > 0 && current >= target;

  /// 0..1 arası tamamlanma oranı (ilerleme halkası için).
  static double ratio(double current, double target) {
    if (target <= 0) return 0;
    final r = current / target;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }
}
