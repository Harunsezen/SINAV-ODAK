import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/schedule_block.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';

/// Sabit epoch: testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;

Matcher get throwsPlanFailure => throwsA(isA<PlanFailure>());

/// Çizelgedeki çalışma bloklarının saniye listesi.
///
/// `dynamic` yerine tipli imza: hem `avoid_dynamic_calls` uyarısını kaldırır
/// hem de helper yanlış tiple çağrılırsa derleme zamanında yakalanır.
List<int> studySeconds(ScheduleBuildResult result) => result.schedule.blocks
    .where((b) => b.isStudy)
    .map((b) => b.seconds)
    .toList();

void main() {
  group('fromSpecial — blok dağıtımı', () {
    test('120 dk / 4 mola -> 5 blok x 24 dk', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 120,
        breakCount: 4,
        breakMinutes: 10,
      );
      final study = studySeconds(r);
      expect(study.length, 5);
      expect(study, everyElement(1440));
      expect(r.schedule.blockCount, 9, reason: '5 çalışma + 4 mola');
      expect(r.schedule.totalStudyS, 5 * 1440);
      expect(r.schedule.totalBreakS, 4 * 10 * 60);
    });

    test('100 dk / 3 mola -> [1500, 1500, 1500, 1500]', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 100,
        breakCount: 3,
        breakMinutes: 5,
      );
      expect(studySeconds(r), [1500, 1500, 1500, 1500]);
    });

    test('101 dk / 3 mola -> artık dakika ilk bloğa eklenir', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 101,
        breakCount: 3,
        breakMinutes: 5,
      );
      expect(
        studySeconds(r),
        [1560, 1500, 1500, 1500],
        reason: 'saniye bazlı bölme 25dk15sn x4 üretirdi',
      );
    });

    test('30 dk / 4 mola -> blok başına 10 dakikadan az, PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromSpecial(
          startAtMs: t0,
          totalStudyMinutes: 30,
          breakCount: 4,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('breakCount = 0 -> tek blok, mola yok', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 50,
        breakCount: 0,
        breakMinutes: 0,
      );
      expect(r.schedule.blockCount, 1);
      expect(r.schedule.totalBreakS, 0);
      expect(r.schedule.totalStudyS, 3000);
      expect(r.schedule.plannedEndAtMs, t0 + 3000 * 1000);
    });
  });

  group('fromSpecial — geçersiz girdiler', () {
    test('totalStudyMinutes = 0', () {
      expect(
        () => ScheduleBuilder.fromSpecial(
          startAtMs: t0,
          totalStudyMinutes: 0,
          breakCount: 1,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('totalStudyMinutes negatif', () {
      expect(
        () => ScheduleBuilder.fromSpecial(
          startAtMs: t0,
          totalStudyMinutes: -10,
          breakCount: 1,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('breakCount negatif', () {
      expect(
        () => ScheduleBuilder.fromSpecial(
          startAtMs: t0,
          totalStudyMinutes: 60,
          breakCount: -1,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('mola var ama süresi 0', () {
      expect(
        () => ScheduleBuilder.fromSpecial(
          startAtMs: t0,
          totalStudyMinutes: 60,
          breakCount: 2,
          breakMinutes: 0,
        ),
        throwsPlanFailure,
      );
    });
  });

  group('fromSpecial — uyarılar', () {
    test('lastBreakLong son molayı iki katına çıkarır', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 100,
        breakCount: 2,
        breakMinutes: 5,
        lastBreakLong: true,
      );
      final breaks = r.schedule.blocks
          .where((b) => b.type == BlockType.breakTime)
          .toList();
      expect(breaks.first.seconds, 300);
      expect(breaks.last.seconds, 600);
      expect(r.warnings, contains(ScheduleWarning.lastBreakLongApplied));
    });

    test('lastBreakLong ama mola yoksa uyarı üretilmez', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 50,
        breakCount: 0,
        breakMinutes: 0,
        lastBreakLong: true,
      );
      expect(r.warnings, isNot(contains(ScheduleWarning.lastBreakLongApplied)));
    });

    test('121 dk tek blok -> blockTooLong', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 121,
        breakCount: 0,
        breakMinutes: 0,
      );
      expect(r.warnings, contains(ScheduleWarning.blockTooLong));
    });

    test('tam 120 dk uyarı üretmez', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 120,
        breakCount: 0,
        breakMinutes: 0,
      );
      expect(r.warnings, isEmpty);
    });

    test('çoklu blok + lastBreakLong birlikte çalışıyor', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 240,
        breakCount: 2,
        breakMinutes: 10,
        lastBreakLong: true,
      );
      final breaks = r.schedule.blocks.where((b) => b.isBreak).toList();

      expect(breaks.length, 2);
      expect(breaks.first.seconds, 600);
      expect(breaks.last.seconds, 1200, reason: 'son mola iki katı');
      expect(r.warnings, contains(ScheduleWarning.lastBreakLongApplied));

      // 2 mola -> 3 çalışma bloğu. 240 dk / 3 = 80 dk = 4800 sn.
      // (Görev metnindeki [7200, 7200] beklentisi 2 bloğa karşılık gelir;
      // o ancak breakCount = 1 olsaydı doğru olurdu.)
      expect(studySeconds(r), [4800, 4800, 4800]);
      expect(
        r.warnings,
        isNot(contains(ScheduleWarning.blockTooLong)),
        reason: '80 dk sınırın altında',
      );
    });

    test('lastBreakLong ile tam 120 dk bloklar uyarı üretmiyor', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 240,
        breakCount: 1,
        breakMinutes: 10,
        lastBreakLong: true,
      );
      expect(studySeconds(r), [7200, 7200]);
      expect(r.warnings, contains(ScheduleWarning.lastBreakLongApplied));
      expect(r.warnings, isNot(contains(ScheduleWarning.blockTooLong)));
    });

    test('250 dk / 1 mola -> iki blok da 120 dakikayı aşar, blockTooLong', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 250,
        breakCount: 1,
        breakMinutes: 5,
      );
      expect(studySeconds(r), [7500, 7500]);
      expect(r.warnings, contains(ScheduleWarning.blockTooLong));
    });

    test('çoklu blok + lastBreakLong birlikte çalışıyor', () {
      // NOT: 2 mola -> 3 çalışma bloğu (blok = mola + 1). Spec'teki
      // [7200, 7200] beklentisi 2 blok gösteriyordu ve 2 molayla
      // bağdaşmıyordu; 360 dk / 2 mola ile üç adet 120 dk'lık blok
      // kurularak hem çoklu blok hem tam sınır değeri test ediliyor.
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 360,
        breakCount: 2,
        breakMinutes: 10,
        lastBreakLong: true,
      );

      final breaks = r.schedule.blocks
          .where((b) => b.type == BlockType.breakTime)
          .toList();
      expect(breaks.length, 2);
      expect(breaks.first.seconds, 600);
      expect(breaks.last.seconds, 1200, reason: 'son mola iki katı');

      expect(studySeconds(r), [7200, 7200, 7200]);
      expect(r.warnings, contains(ScheduleWarning.lastBreakLongApplied));
      expect(
        r.warnings,
        isNot(contains(ScheduleWarning.blockTooLong)),
        reason: 'tam 120 dk sınırı aşmaz',
      );
    });

    test('çoklu blok + lastBreakLong birlikte çalışıyor', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 240,
        breakCount: 2,
        breakMinutes: 10,
        lastBreakLong: true,
      );
      final breaks =
          r.schedule.blocks.where((b) => b.isBreak).toList(growable: false);

      expect(breaks.length, 2);
      expect(breaks.first.seconds, 600);
      expect(breaks.last.seconds, 1200, reason: 'son mola iki katı');
      expect(r.warnings, contains(ScheduleWarning.lastBreakLongApplied));

      // 2 mola -> 3 çalışma bloğu; 240 / 3 = 80 dk = 4800 sn.
      expect(studySeconds(r), [4800, 4800, 4800]);
      // 4800 < 7200 olduğu için uzun blok uyarısı ÇIKMAMALI.
      expect(r.warnings, isNot(contains(ScheduleWarning.blockTooLong)));
    });

    test('240 dk / 1 mola -> tam 120 dakikalık bloklar uyarı üretmez', () {
      final r = ScheduleBuilder.fromSpecial(
        startAtMs: t0,
        totalStudyMinutes: 240,
        breakCount: 1,
        breakMinutes: 5,
      );
      expect(studySeconds(r), [7200, 7200]);
      expect(r.warnings, isEmpty, reason: 'sınır değeri uyarı üretmemeli');
    });
  });

  group('fromPreset', () {
    test('25/5 x3 -> 5 blok, son blok çalışma, son mola yok', () {
      final r = ScheduleBuilder.fromPreset(
        startAtMs: t0,
        workMinutes: 25,
        breakMinutes: 5,
        cycles: 3,
      );
      expect(r.schedule.blockCount, 5);
      expect(r.schedule.studyBlockCount, 3);
      expect(r.schedule.blocks.last.type, BlockType.study);
      expect(r.schedule.totalStudyS, 3 * 1500);
      expect(r.schedule.totalBreakS, 2 * 300);
    });

    test('cycles = 1 -> tek blok, mola yok', () {
      final r = ScheduleBuilder.fromPreset(
        startAtMs: t0,
        workMinutes: 25,
        breakMinutes: 5,
        cycles: 1,
      );
      expect(r.schedule.blockCount, 1);
      expect(r.schedule.totalBreakS, 0);
    });

    test('cycles = 0 -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromPreset(
          startAtMs: t0,
          workMinutes: 25,
          breakMinutes: 5,
          cycles: 0,
        ),
        throwsPlanFailure,
      );
    });

    test('workMinutes 10 dakikadan az -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromPreset(
          startAtMs: t0,
          workMinutes: 9,
          breakMinutes: 5,
          cycles: 2,
        ),
        throwsPlanFailure,
      );
    });

    test('birden fazla döngüde mola 0 -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromPreset(
          startAtMs: t0,
          workMinutes: 25,
          breakMinutes: 0,
          cycles: 3,
        ),
        throwsPlanFailure,
      );
    });

    test('negatif mola -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromPreset(
          startAtMs: t0,
          workMinutes: 25,
          breakMinutes: -5,
          cycles: 1,
        ),
        throwsPlanFailure,
      );
    });

    test('121 dk çalışma bloğu -> blockTooLong', () {
      final r = ScheduleBuilder.fromPreset(
        startAtMs: t0,
        workMinutes: 121,
        breakMinutes: 5,
        cycles: 1,
      );
      expect(r.warnings, contains(ScheduleWarning.blockTooLong));
    });

    test('tam 120 dk çalışma bloğu -> uyarı yok', () {
      final r = ScheduleBuilder.fromPreset(
        startAtMs: t0,
        workMinutes: 120,
        breakMinutes: 5,
        cycles: 1,
      );
      expect(r.warnings, isEmpty);
    });
  });

  group('fromEndTime', () {
    test('60 dk pencere, 1 mola x 10 dk -> tam bitiş anına oturur', () {
      const end = t0 + 3600000;
      final r = ScheduleBuilder.fromEndTime(
        nowMs: t0,
        endAtMs: end,
        breakCount: 1,
        breakMinutes: 10,
      );
      expect(r.schedule.plannedEndAtMs, alignToSecond(end));
      expect(r.schedule.totalStudyS, 3600 - 600);
      expect(r.schedule.totalBreakS, 600);
      expect(studySeconds(r), [1500, 1500]);
    });

    test('endAtMs saniye hizalı değilse hizalanır', () {
      const end = t0 + 3600000 + 500;
      final r = ScheduleBuilder.fromEndTime(
        nowMs: t0,
        endAtMs: end,
        breakCount: 1,
        breakMinutes: 10,
      );
      expect(r.schedule.plannedEndAtMs, alignToSecond(end));
    });

    test('nowMs hizalı değilken de bitiş anı korunur', () {
      const end = t0 + 3600000;
      final r = ScheduleBuilder.fromEndTime(
        nowMs: t0 + 750,
        endAtMs: end,
        breakCount: 1,
        breakMinutes: 5,
      );
      expect(r.schedule.plannedEndAtMs, alignToSecond(end));
    });

    test('artık saniyeler son çalışma bloğuna eklenir, kaybolmaz', () {
      // 3630 sn pencere - 600 sn mola = 3030 sn çalışma -> 50 dk + 30 sn
      const end = t0 + 3630000;
      final r = ScheduleBuilder.fromEndTime(
        nowMs: t0,
        endAtMs: end,
        breakCount: 1,
        breakMinutes: 10,
      );
      final study = studySeconds(r);
      expect(study, [1500, 1530]);
      expect(r.schedule.totalStudyS, 3030);
      expect(r.schedule.plannedEndAtMs, alignToSecond(end));

      // Her blokta s == (end - start) / 1000 kuralı korunmalı.
      for (final b in r.schedule.blocks) {
        expect(b.seconds, (b.endMs - b.startMs) ~/ 1000);
      }
    });

    test('bitiş saati geçmişte -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromEndTime(
          nowMs: t0,
          endAtMs: t0 - 1000,
          breakCount: 1,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('bitiş saati şimdiye eşit -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromEndTime(
          nowMs: t0,
          endAtMs: t0,
          breakCount: 0,
          breakMinutes: 0,
        ),
        throwsPlanFailure,
      );
    });

    test('kalan çalışma 10 dakikadan az -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromEndTime(
          nowMs: t0,
          endAtMs: t0 + 600000,
          breakCount: 1,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });

    test('molalar tüm süreyi yiyor -> PlanFailure', () {
      expect(
        () => ScheduleBuilder.fromEndTime(
          nowMs: t0,
          endAtMs: t0 + 600000,
          breakCount: 2,
          breakMinutes: 5,
        ),
        throwsPlanFailure,
      );
    });
  });
}
