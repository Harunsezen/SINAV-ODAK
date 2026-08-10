import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/focus_score_calculator.dart';

Matcher get throwsValidation => throwsA(isA<ValidationFailure>());

int? score({
  SessionStatus status = SessionStatus.completed,
  int plannedDurationS = 3600,
  int actualDurationS = 3600,
  int foregroundS = 3600,
  int exitCount = 0,
  int extendedBreakS = 0,
  int totalPlannedBreakS = 600,
}) =>
    FocusScoreCalculator.calculate(
      status: status,
      plannedDurationS: plannedDurationS,
      actualDurationS: actualDurationS,
      foregroundS: foregroundS,
      exitCount: exitCount,
      extendedBreakS: extendedBreakS,
      totalPlannedBreakS: totalPlannedBreakS,
    );

void main() {
  group('kritik ürün senaryosu', () {
    test('earlyFinished %60 tamamlama -> 62', () {
      // 55*0.6=33 + 25*1=25 + 10 + 10 = 78; 78 * 0.80 = 62.4 -> 62
      expect(
        score(
          status: SessionStatus.earlyFinished,
          plannedDurationS: 3600,
          actualDurationS: 2160,
          foregroundS: 2160,
        ),
        62,
      );
    });
  });

  group('durum çarpanları', () {
    test('completed + kusursuz oturum -> 100', () {
      expect(score(), 100);
    });

    test('interrupted + kusursuz oturum -> 55', () {
      expect(score(status: SessionStatus.interrupted), 55);
    });

    test('running -> skor hesaplanmaz, null', () {
      expect(score(status: SessionStatus.running), isNull);
    });
  });

  group('tamamlama bileşeni', () {
    test('planlanan süre 0 -> hata yok, katkı 0', () {
      final s = score(plannedDurationS: 0, actualDurationS: 0, foregroundS: 0);
      // completion 0, presence 0, exit 10, compliance 10 -> 20
      expect(s, isNotNull);
      expect(s, 20);
    });

    test('planlanan süre 0 + earlyFinished -> hata yok, çarpan uygulanır',
        () {
      // completion 0, presence 0, exit 10, compliance 10 = 20
      // earlyFinished çarpanı 0.80 -> 16
      final s = score(
        status: SessionStatus.earlyFinished,
        plannedDurationS: 0,
        actualDurationS: 0,
        foregroundS: 0,
      );
      expect(s, isNotNull);
      expect(s, 16, reason: '20 * 0.80 = 16');
    });

    test('planlanan süre 0 + earlyFinished -> hata yok, çarpan uygulanır',
        () {
      // completion 0, presence 0, exit 10, compliance 10 = 20
      // earlyFinished çarpanı 0.80 -> 16
      final s = score(
        status: SessionStatus.earlyFinished,
        plannedDurationS: 0,
        actualDurationS: 0,
        foregroundS: 0,
      );
      expect(s, isNotNull);
      expect(s, 16, reason: '20 * 0.80 = 16');
    });

    test('planlanan süre 0 + earlyFinished -> hata yok, çarpan uygulanır',
        () {
      // completion 0 + presence 0 + exit 10 + compliance 10 = 20
      // earlyFinished çarpanı 0.80 -> 16
      final s = score(
        status: SessionStatus.earlyFinished,
        plannedDurationS: 0,
        actualDurationS: 0,
        foregroundS: 0,
      );
      expect(s, isNotNull);
      expect(s, 16, reason: '20 * 0.80 = 16');
    });

    test('gerçekleşen süre planlanandan büyükse 1e sabitlenir', () {
      expect(score(actualDurationS: 7200, foregroundS: 7200), 100);
    });
  });

  group('önplan bileşeni', () {
    test('gerçekleşen süre 0 -> presence 0', () {
      final s = score(actualDurationS: 0, foregroundS: 0);
      // completion 0 (0/3600), presence 0, exit 10, compliance 10 -> 20
      expect(s, 20);
    });

    test('önplan süresi gerçekleşenden büyükse 1e sabitlenir', () {
      expect(score(foregroundS: 99999), 100);
    });

    test('yarısı arka planda geçtiyse presence puanı yarılanır', () {
      // 55 + 12.5 + 10 + 10 = 87.5 -> 88
      expect(score(foregroundS: 1800), 88);
    });
  });

  group('çıkış cezası', () {
    test('6 çıkış -> çıkış puanı sıfırlanır', () {
      // 55 + 25 + 0 + 10 = 90
      expect(score(exitCount: 6), 90);
    });

    test('6’dan fazla çıkış -> ceza artmaz, negatife düşmez', () {
      expect(score(exitCount: 50), 90);
    });

    test('3 çıkış -> yarım ceza', () {
      // 55 + 25 + 5 + 10 = 95
      expect(score(exitCount: 3), 95);
    });
  });

  group('mola disiplini', () {
    test('planlanan mola yoksa uyum tam sayılır', () {
      expect(score(totalPlannedBreakS: 0, extendedBreakS: 0), 100);
    });

    test('uzatma planlanan molaya eşitse uyum 0', () {
      // 55 + 25 + 10 + 0 = 90
      expect(score(extendedBreakS: 600), 90);
    });

    test('uzatma planlanan molayı aşarsa uyum yine 0, negatif değil', () {
      expect(score(extendedBreakS: 6000), 90);
    });

    test('uzatma planlanan molanın yarısıysa uyum yarılanır', () {
      // 55 + 25 + 10 + 5 = 95
      expect(score(extendedBreakS: 300), 95);
    });
  });

  group('negatif değer doğrulaması', () {
    test('planlanan süre',
        () => expect(() => score(plannedDurationS: -1), throwsValidation));
    test('gerçekleşen süre',
        () => expect(() => score(actualDurationS: -1), throwsValidation));
    test('önplan süresi',
        () => expect(() => score(foregroundS: -1), throwsValidation));
    test('çıkış sayısı',
        () => expect(() => score(exitCount: -1), throwsValidation));
    test('uzatma süresi',
        () => expect(() => score(extendedBreakS: -1), throwsValidation));
    test('planlanan mola süresi',
        () => expect(() => score(totalPlannedBreakS: -1), throwsValidation));

    test('running olsa bile negatif değer önce yakalanır', () {
      expect(
        () => score(status: SessionStatus.running, exitCount: -1),
        throwsValidation,
      );
    });
  });

  group('sonuç aralığı', () {
    test('skor her zaman 0..100 arasında', () {
      final values = <int?>[
        score(),
        score(status: SessionStatus.interrupted, exitCount: 99),
        score(plannedDurationS: 0, actualDurationS: 0, foregroundS: 0),
        score(status: SessionStatus.earlyFinished, actualDurationS: 1),
      ];
      for (final v in values) {
        expect(v, isNotNull);
        expect(v!, inInclusiveRange(0, 100));
      }
    });
  });
}
