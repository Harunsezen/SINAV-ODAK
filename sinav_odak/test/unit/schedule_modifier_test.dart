import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/schedule_block.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';
import 'package:sinav_odak/domain/services/schedule_modifier.dart';

/// Sabit epoch: testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;

/// 24 dk çalışma + 5 dk mola + 24 dk çalışma. Mola indeksi 1.
SessionSchedule schedule() => ScheduleBuilder.fromPreset(
      startAtMs: t0,
      workMinutes: 24,
      breakMinutes: 5,
      cycles: 2,
    ).schedule;

const int breakIndex = 1;
const int breakStart = t0 + 1440000;
const int breakEnd = breakStart + 300000;

Matcher get throwsValidation => throwsA(isA<ValidationFailure>());
Matcher get throwsPlanFailure => throwsA(isA<PlanFailure>());

ScheduleBlock breakOf(SessionSchedule s) => s.blocks[breakIndex];

void main() {
  group('extendBreak — geçerli uzatma', () {
    test('mola uzar, sonraki bloklar kayar, toplamlar güncellenir', () {
      final before = schedule();
      final after = ScheduleModifier.extendBreak(before, breakIndex, 300);

      final b = breakOf(after);
      expect(b.endMs, breakEnd + 300000);
      expect(b.seconds, 600);
      expect(b.extendedS, 300);
      expect(b.skipped, isFalse);

      expect(after.blocks[2].startMs, before.blocks[2].startMs + 300000);
      expect(after.blocks[2].endMs, before.blocks[2].endMs + 300000);
      expect(after.blocks[2].seconds, before.blocks[2].seconds);

      expect(after.totalBreakS, before.totalBreakS + 300);
      expect(after.totalStudyS, before.totalStudyS);
      expect(after.plannedEndAtMs, before.plannedEndAtMs + 300000);
      expect(after.validate, returnsNormally);
    });

    test('önceki bloklar değişmez', () {
      final before = schedule();
      final after = ScheduleModifier.extendBreak(before, breakIndex, 300);
      expect(after.blocks[0], before.blocks[0]);
    });

    test('girdi çizelge değişmez (immutable)', () {
      final before = schedule();
      ScheduleModifier.extendBreak(before, breakIndex, 300);
      expect(breakOf(before).seconds, 300);
      expect(breakOf(before).extendedS, 0);
    });
  });

  group('extendBreak — geçersiz girdiler', () {
    test('addS = 0', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), breakIndex, 0),
        throwsValidation,
      );
    });

    test('addS negatif', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), breakIndex, -300),
        throwsValidation,
      );
    });

    test('hedef blok çalışma bloğu', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), 0, 300),
        throwsValidation,
      );
    });

    test('indeks aralık dışı', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), 99, 300),
        throwsValidation,
      );
    });

    test('negatif indeks', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), -1, 300),
        throwsValidation,
      );
    });

    test('atlanmış mola uzatılamaz', () {
      final skipped = ScheduleModifier.skipBreak(
          schedule(), breakIndex, breakStart + 60000);
      expect(
        () => ScheduleModifier.extendBreak(skipped, breakIndex, 300),
        throwsValidation,
      );
    });
  });

  group('extendBreak — toplam uzatma limiti (600 sn)', () {
    test('tek seferde tam 600 sn kabul edilir', () {
      final s = ScheduleModifier.extendBreak(schedule(), breakIndex, 600);
      expect(breakOf(s).extendedS, 600);
    });

    test('tek seferde 601 sn reddedilir', () {
      expect(
        () => ScheduleModifier.extendBreak(schedule(), breakIndex, 601),
        throwsPlanFailure,
      );
    });

    test('300 kullanılmışken 300 daha kabul edilir', () {
      var s = ScheduleModifier.extendBreak(schedule(), breakIndex, 300);
      s = ScheduleModifier.extendBreak(s, breakIndex, 300);
      expect(breakOf(s).extendedS, 600);
      expect(s.validate, returnsNormally);
    });

    test('300 kullanılmışken 301 reddedilir', () {
      final s = ScheduleModifier.extendBreak(schedule(), breakIndex, 300);
      expect(
        () => ScheduleModifier.extendBreak(s, breakIndex, 301),
        throwsPlanFailure,
      );
    });
  });

  group('skipBreak — geçerli atlama', () {
    test('mola kısalır, sonraki bloklar öne çekilir', () {
      final before = schedule();
      const now = breakStart + 120000; // molanın 2. dakikası
      final after = ScheduleModifier.skipBreak(before, breakIndex, now);

      final b = breakOf(after);
      expect(b.endMs, now);
      expect(b.seconds, 120);
      expect(b.skipped, isTrue);
      expect(b.type, BlockType.breakTime);

      expect(after.blocks[2].startMs, now);
      expect(after.blocks[2].seconds, before.blocks[2].seconds);

      expect(after.totalBreakS, 120);
      expect(after.plannedEndAtMs, before.plannedEndAtMs - 180000);
      expect(after.validate, returnsNormally);
    });

    test('nowMs saniyeye hizalanır', () {
      final after = ScheduleModifier.skipBreak(
        schedule(),
        breakIndex,
        breakStart + 120500,
      );
      final b = breakOf(after);
      expect(b.endMs, alignToSecond(breakStart + 120500));
      expect(b.seconds, 120);
      expect(b.seconds, (b.endMs - b.startMs) ~/ 1000);
    });

    test('girdi çizelge değişmez (immutable)', () {
      final before = schedule();
      ScheduleModifier.skipBreak(before, breakIndex, breakStart + 60000);
      expect(breakOf(before).skipped, isFalse);
      expect(breakOf(before).seconds, 300);
    });
  });

  group('skipBreak — geçersiz girdiler', () {
    test('mola henüz başlamadı (now = start)', () {
      expect(
        () => ScheduleModifier.skipBreak(schedule(), breakIndex, breakStart),
        throwsValidation,
      );
    });

    test('mola henüz başlamadı (now < start)', () {
      expect(
        () => ScheduleModifier.skipBreak(
            schedule(), breakIndex, breakStart - 1000),
        throwsValidation,
      );
    });

    test('tam bitiş anında atlamak anlamsız (now = end)', () {
      expect(
        () => ScheduleModifier.skipBreak(schedule(), breakIndex, breakEnd),
        throwsValidation,
      );
    });

    test('mola zaten bitmiş (now > end)', () {
      expect(
        () =>
            ScheduleModifier.skipBreak(schedule(), breakIndex, breakEnd + 1000),
        throwsValidation,
      );
    });

    test('hedef blok çalışma bloğu', () {
      expect(
        () => ScheduleModifier.skipBreak(schedule(), 0, t0 + 60000),
        throwsValidation,
      );
    });

    test('indeks aralık dışı', () {
      expect(
        () => ScheduleModifier.skipBreak(schedule(), 99, breakStart + 1000),
        throwsValidation,
      );
    });

    test('atlanmış mola tekrar atlanamaz', () {
      final skipped = ScheduleModifier.skipBreak(
          schedule(), breakIndex, breakStart + 60000);
      expect(
        () => ScheduleModifier.skipBreak(
            skipped, breakIndex, breakStart + 120000),
        throwsValidation,
      );
    });
  });

  group('KARAR B — atlanan molada extendedS gerçekten kullanılana düşer', () {
    /// 300 sn mola + 300 sn uzatma = 600 sn, extendedS = 300, originalS = 300.
    SessionSchedule extended() =>
        ScheduleModifier.extendBreak(schedule(), breakIndex, 300);

    test('başlangıç durumu doğrulanıyor', () {
      final b = breakOf(extended());
      expect(b.seconds, 600);
      expect(b.extendedS, 300);
    });

    test('6. dakikada atlanırsa extendedS 60 olur', () {
      final s = ScheduleModifier.skipBreak(
        extended(),
        breakIndex,
        breakStart + 360000,
      );
      final b = breakOf(s);
      expect(b.seconds, 360);
      expect(b.extendedS, 60, reason: '360 - 300 = 60');
      expect(s.validate, returnsNormally);
    });

    test('9. dakikada atlanırsa extendedS 240 olur', () {
      final s = ScheduleModifier.skipBreak(
        extended(),
        breakIndex,
        breakStart + 540000,
      );
      final b = breakOf(s);
      expect(b.seconds, 540);
      expect(b.extendedS, 240);
    });

    test('tam özgün sürede atlanırsa extendedS 0 olur', () {
      final s = ScheduleModifier.skipBreak(
        extended(),
        breakIndex,
        breakStart + 300000,
      );
      final b = breakOf(s);
      expect(b.seconds, 300);
      expect(b.extendedS, 0, reason: 'uzatma hiç kullanılmadı');
    });

    test('özgün süreden önce atlanırsa extendedS negatife düşmez', () {
      final s = ScheduleModifier.skipBreak(
        extended(),
        breakIndex,
        breakStart + 299000,
      );
      final b = breakOf(s);
      expect(b.seconds, 299);
      expect(b.extendedS, 0);
    });

    test('uzatılmamış mola atlanırsa extendedS 0 kalır', () {
      final s = ScheduleModifier.skipBreak(
        schedule(),
        breakIndex,
        breakStart + 120000,
      );
      expect(breakOf(s).extendedS, 0);
    });

    /// 300 sn mola + 300 + 300 = 900 sn, extendedS = 600, originalS = 300.
    SessionSchedule twiceExtended() {
      var s = ScheduleModifier.extendBreak(schedule(), breakIndex, 300);
      return ScheduleModifier.extendBreak(s, breakIndex, 300);
    }

    test('çift uzatma başlangıç durumu doğrulanıyor', () {
      final b = breakOf(twiceExtended());
      expect(b.seconds, 900);
      expect(b.extendedS, 600);
      expect(b.endMs, breakEnd + 600000);
    });

    test('iki kez uzatma sonrası skip: extendedS gerçekten kullanılana düşer',
        () {
      final skipped = ScheduleModifier.skipBreak(
        twiceExtended(),
        breakIndex,
        breakStart + 420000,
      );
      final b = breakOf(skipped);
      expect(b.seconds, 420);
      expect(b.extendedS, 120, reason: '420 - 300 = 120');
      expect(b.skipped, isTrue);
      expect(skipped.validate, returnsNormally);
    });

    test('çift uzatma sonrası tam özgün sürede skip -> extendedS 0', () {
      final skipped = ScheduleModifier.skipBreak(
        twiceExtended(),
        breakIndex,
        breakStart + 300000, // tam özgün süre (300 sn)
      );
      final b = breakOf(skipped);
      expect(b.seconds, 300);
      expect(
        b.extendedS,
        0,
        reason: 'tam özgün sürede uzatma hiç kullanılmadı',
      );
      expect(skipped.validate, returnsNormally);
    });

    test('çift uzatma sonrası tam özgün sürede skip -> extendedS 0', () {
      final skipped = ScheduleModifier.skipBreak(
        twiceExtended(),
        breakIndex,
        breakStart + 300000, // tam özgün süre (300 sn)
      );
      final b = breakOf(skipped);
      expect(b.seconds, 300);
      expect(
        b.extendedS,
        0,
        reason: 'tam özgün sürede uzatma hiç kullanılmadı',
      );
      expect(skipped.validate, returnsNormally);
    });

    test('çift uzatma sonrası TAM özgün sürede skip -> extendedS 0', () {
      final skipped = ScheduleModifier.skipBreak(
        twiceExtended(),
        breakIndex,
        breakStart + 300000, // tam özgün süre (300 sn)
      );
      final b = breakOf(skipped);
      expect(b.seconds, 300);
      expect(
        b.extendedS,
        0,
        reason: 'tam özgün sürede uzatma hiç kullanılmadı',
      );
      expect(skipped.validate, returnsNormally);
    });

    test('çift uzatma sonrası özgün süreden önce skip -> extendedS 0', () {
      final skipped = ScheduleModifier.skipBreak(
        twiceExtended(),
        breakIndex,
        breakStart + 240000,
      );
      final b = breakOf(skipped);
      expect(b.seconds, 240);
      expect(b.extendedS, 0);
    });

    test('iki uzatma sonrası toplam limit dolar, 1 sn bile eklenemez', () {
      final s = twiceExtended();
      expect(breakOf(s).extendedS, ScheduleModifier.maxTotalExtensionS);
      expect(
        () => ScheduleModifier.extendBreak(s, breakIndex, 1),
        throwsPlanFailure,
      );
    });
  });
}
