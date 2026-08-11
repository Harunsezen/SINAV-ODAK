import '../../core/errors/failures.dart';

/// Soru istatistiği hesabının sonucu.
class NetResult {
  const NetResult({
    required this.net,
    required this.successRate,
    required this.solutionSpeed,
    required this.secondsPerQuestion,
  });

  /// `doğru - (yanlış / katsayı)`
  final double net;

  /// `doğru / (doğru + yanlış + boş)` — 0..1
  final double successRate;

  /// Saatte çözülen soru sayısı.
  final double solutionSpeed;

  /// Soru başına harcanan ortalama süre (saniye).
  final double secondsPerQuestion;

  static const empty = NetResult(
    net: 0,
    successRate: 0,
    solutionSpeed: 0,
    secondsPerQuestion: 0,
  );

  @override
  String toString() => 'NetResult(net: $net, başarı: $successRate)';
}

/// Net ve türev soru istatistiklerini hesaplar.
///
/// Katsayı **parametredir**, sabit değildir: YKS'de 4 yanlış 1 doğruyu
/// götürür, bazı sınavlarda 3. Kullanıcı ayarlardan değiştirdiğinde geçmiş
/// oturumlar bu fonksiyon yeniden çağrılarak güncellenebilir — bu yüzden
/// hesap saf ve durumsuzdur.
abstract final class NetCalculator {
  static NetResult calculate({
    required int questionCount,
    required int correctCount,
    required int wrongCount,
    required int emptyCount,
    required double coefficient,
    required int actualDurationS,
  }) {
    if (coefficient.isNaN || coefficient.isInfinite) {
      throw const ValidationFailure(
        'Net katsayısı geçerli bir sayı olmalı.',
        field: 'coefficient',
      );
    }
    if (coefficient <= 0) {
      throw const ValidationFailure(
        'Net katsayısı sıfırdan büyük olmalı.',
        field: 'coefficient',
      );
    }
    if (questionCount < 0) {
      throw const ValidationFailure(
        'Soru sayısı negatif olamaz.',
        field: 'questionCount',
      );
    }
    if (correctCount < 0) {
      throw const ValidationFailure(
        'Doğru sayısı negatif olamaz.',
        field: 'correctCount',
      );
    }
    if (wrongCount < 0) {
      throw const ValidationFailure(
        'Yanlış sayısı negatif olamaz.',
        field: 'wrongCount',
      );
    }
    if (emptyCount < 0) {
      throw const ValidationFailure(
        'Boş sayısı negatif olamaz.',
        field: 'emptyCount',
      );
    }
    if (actualDurationS < 0) {
      throw const ValidationFailure(
        'Çalışma süresi negatif olamaz.',
        field: 'actualDurationS',
      );
    }

    final answered = correctCount + wrongCount + emptyCount;
    if (answered > questionCount) {
      throw ValidationFailure(
        'Doğru + yanlış + boş toplamı ($answered) '
        'çözülen soru sayısını ($questionCount) aşamaz.',
        field: 'questionCount',
      );
    }

    if (questionCount == 0) return NetResult.empty;

    final net = correctCount - (wrongCount / coefficient);
    final successRate = answered == 0 ? 0.0 : correctCount / answered;

    // Süre yoksa hız hesaplanamaz; sıfıra bölme yerine 0 döner.
    final solutionSpeed =
        actualDurationS == 0 ? 0.0 : questionCount / (actualDurationS / 3600);
    final secondsPerQuestion =
        actualDurationS == 0 ? 0.0 : actualDurationS / questionCount;

    return NetResult(
      net: net,
      successRate: successRate,
      solutionSpeed: solutionSpeed,
      secondsPerQuestion: secondsPerQuestion,
    );
  }
}
