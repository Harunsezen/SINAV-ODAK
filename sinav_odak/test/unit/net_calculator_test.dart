import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/domain/services/net_calculator.dart';

Matcher get throwsValidation => throwsA(isA<ValidationFailure>());

void main() {
  group('net hesabı', () {
    test('44 doğru 12 yanlış, katsayı 4 -> 41.0', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 4,
        actualDurationS: 3600,
      );
      expect(r.net, 41.0);
    });

    test('44 doğru 12 yanlış, katsayı 3 -> 40.0', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 3,
        actualDurationS: 3600,
      );
      expect(r.net, 40.0);
    });

    test('katsayı 0.5: 44 doğru 12 yanlış -> 44 - 12/0.5 = 20', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 0.5,
        actualDurationS: 3600,
      );
      expect(r.net, 20.0);
    });

    test('katsayı 0.5: 44 doğru 12 yanlış -> 44 - 12/0.5 = 20', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 0.5,
        actualDurationS: 3600,
      );
      expect(r.net, 20.0);
    });

    test('katsayı 0.5: 44 doğru 12 yanlış -> 20.0', () {
      // Katsayı 1'in altına inince yanlışın cezası AĞIRLAŞIR: 12 / 0.5 = 24.
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 0.5,
        actualDurationS: 3600,
      );
      expect(r.net, 20.0);
    });

    test('hiç cevap yoksa başarı oranı 0', () {
      final r = NetCalculator.calculate(
        questionCount: 10,
        correctCount: 0,
        wrongCount: 0,
        emptyCount: 0,
        coefficient: 4,
        actualDurationS: 600,
      );
      expect(r.successRate, 0);
      expect(r.net, 0);
    });

    test('soru sayısı 0 ise boş sonuç döner', () {
      final r = NetCalculator.calculate(
        questionCount: 0,
        correctCount: 0,
        wrongCount: 0,
        emptyCount: 0,
        coefficient: 4,
        actualDurationS: 1800,
      );
      expect(r.net, 0);
      expect(r.successRate, 0);
      expect(r.solutionSpeed, 0);
      expect(r.secondsPerQuestion, 0);
    });

    test('başarı oranı doğru/(doğru+yanlış+boş)', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 44,
        wrongCount: 12,
        emptyCount: 4,
        coefficient: 4,
        actualDurationS: 3600,
      );
      expect(r.successRate, closeTo(44 / 60, 1e-9));
    });

    test('çözüm hızı: 120 soru / 3600 sn -> 120 soru/saat', () {
      final r = NetCalculator.calculate(
        questionCount: 120,
        correctCount: 100,
        wrongCount: 20,
        emptyCount: 0,
        coefficient: 4,
        actualDurationS: 3600,
      );
      expect(r.solutionSpeed, closeTo(120, 1e-9));
    });

    test('soru başına süre: 3600 sn / 60 soru -> 60 sn', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 30,
        wrongCount: 20,
        emptyCount: 10,
        coefficient: 4,
        actualDurationS: 3600,
      );
      expect(r.secondsPerQuestion, closeTo(60, 1e-9));
    });

    test('süre 0 ise hız ve soru başına süre 0 (sıfıra bölme yok)', () {
      final r = NetCalculator.calculate(
        questionCount: 60,
        correctCount: 40,
        wrongCount: 20,
        emptyCount: 0,
        coefficient: 4,
        actualDurationS: 0,
      );
      expect(r.solutionSpeed, 0);
      expect(r.secondsPerQuestion, 0);
      expect(r.net.isNaN, isFalse);
      expect(r.net.isInfinite, isFalse);
    });
  });

  group('doğrulama hataları', () {
    NetResult call({
      int questionCount = 60,
      int correctCount = 40,
      int wrongCount = 10,
      int emptyCount = 10,
      double coefficient = 4,
      int actualDurationS = 3600,
    }) =>
        NetCalculator.calculate(
          questionCount: questionCount,
          correctCount: correctCount,
          wrongCount: wrongCount,
          emptyCount: emptyCount,
          coefficient: coefficient,
          actualDurationS: actualDurationS,
        );

    test(
      'katsayı 0',
      () => expect(() => call(coefficient: 0), throwsValidation),
    );
    test(
      'katsayı negatif',
      () => expect(() => call(coefficient: -4), throwsValidation),
    );
    test(
      'katsayı NaN',
      () => expect(() => call(coefficient: double.nan), throwsValidation),
    );
    test(
      'katsayı sonsuz',
      () => expect(() => call(coefficient: double.infinity), throwsValidation),
    );
    test(
      'negatif soru sayısı',
      () => expect(() => call(questionCount: -1), throwsValidation),
    );
    test(
      'negatif doğru',
      () => expect(() => call(correctCount: -1), throwsValidation),
    );
    test(
      'negatif yanlış',
      () => expect(() => call(wrongCount: -1), throwsValidation),
    );
    test(
      'negatif boş',
      () => expect(() => call(emptyCount: -1), throwsValidation),
    );
    test(
      'negatif süre',
      () => expect(() => call(actualDurationS: -1), throwsValidation),
    );

    test('doğru+yanlış+boş soru sayısını aşamaz', () {
      expect(
        () => call(
          questionCount: 50,
          correctCount: 40,
          wrongCount: 10,
          emptyCount: 10,
        ),
        throwsValidation,
      );
    });
  });
}
