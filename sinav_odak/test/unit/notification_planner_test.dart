import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/notification_planner.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';
import 'package:sinav_odak/domain/services/schedule_modifier.dart';

/// Sabit epoch: testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;
const String sid = 's1';

/// 24 dk çalışma + 5 dk mola + 24 dk çalışma (3 blok).
final schedule = ScheduleBuilder.fromPreset(
  startAtMs: t0,
  workMinutes: 24,
  breakMinutes: 5,
  cycles: 2,
).schedule;

/// 25+5 x3 → 5 blok.
final longSchedule = ScheduleBuilder.fromPreset(
  startAtMs: t0,
  workMinutes: 25,
  breakMinutes: 5,
  cycles: 3,
).schedule;

void main() {
  group('plan üretimi', () {
    test('her blok bitişi için bir bildirim kuruluyor', () {
      final plan =
          NotificationPlanner.plan(sessionId: sid, schedule: longSchedule);
      expect(plan.length, 5, reason: '5 bloklu çizelge -> 5 bildirim');
    });

    test('bildirim anları blok bitişleriyle birebir', () {
      final plan = NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      for (var i = 0; i < plan.length; i++) {
        expect(plan[i].atMs, schedule.blocks[i].endMs);
        expect(plan[i].blockIndex, i);
      }
    });

    test('çalışma bitişi mola süresini söylüyor', () {
      final plan = NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      expect(plan[0].title, 'Mola zamanı');
      expect(plan[0].body, '1. blok bitti. 5 dakika molan başladı.');
    });

    test('mola bitişi sonraki çalışma bloğunu söylüyor', () {
      final plan = NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      expect(plan[1].title, 'Mola bitti');
      expect(plan[1].body, '2. blok seni bekliyor.');
    });

    test('son blok oturum tamamlandı mesajı veriyor', () {
      final plan = NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      expect(plan.last.title, 'Oturum tamamlandı');
      expect(plan.last.blockIndex, 2);
    });

    test('blok numaraları molaları saymıyor', () {
      final plan =
          NotificationPlanner.plan(sessionId: sid, schedule: longSchedule);
      // Bloklar: study0, break1, study2, break3, study4
      expect(plan[0].body, startsWith('1. blok bitti'));
      expect(plan[2].body, startsWith('2. blok bitti'));
      expect(plan[1].body, '2. blok seni bekliyor.');
      expect(plan[3].body, '3. blok seni bekliyor.');
    });
  });

  group('geçmişe bildirim kurulmuyor', () {
    test('fromMs geçmiş blokları eliyor', () {
      // İlk blok bitmiş, mola sürüyor.
      final plan = NotificationPlanner.plan(
        sessionId: sid,
        schedule: schedule,
        fromMs: t0 + 1440000 + 1000,
      );
      expect(plan.length, 2);
      expect(plan.first.blockIndex, 1);
    });

    test('fromMs tam blok bitişine eşitse o blok elenir', () {
      final plan = NotificationPlanner.plan(
        sessionId: sid,
        schedule: schedule,
        fromMs: schedule.blocks[0].endMs,
      );
      expect(plan.first.blockIndex, 1);
    });

    test('çizelge tamamen geçmişteyse plan boş', () {
      final plan = NotificationPlanner.plan(
        sessionId: sid,
        schedule: schedule,
        fromMs: schedule.plannedEndAtMs + 1000,
      );
      expect(plan, isEmpty);
    });
  });

  group('bildirim kimlikleri', () {
    test('aynı oturum için deterministik', () {
      expect(NotificationPlanner.baseIdOf(sid), NotificationPlanner.baseIdOf(sid));
    });

    test('farklı oturumlar farklı taban alıyor', () {
      expect(
        NotificationPlanner.baseIdOf('s1'),
        isNot(NotificationPlanner.baseIdOf('s2')),
      );
    });

    test('kimlikler 32-bit sınırında ve pozitif', () {
      for (final id in NotificationPlanner.idsOf('oturum-abc-123')) {
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThan(0x7FFFFFFF));
      }
    });

    test('idsOf tüm blok aralığını kapsıyor', () {
      final ids = NotificationPlanner.idsOf(sid);
      expect(ids.length, NotificationPlanner.maxBlocksPerSession);

      final plan = NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      for (final n in plan) {
        expect(ids, contains(n.id), reason: 'iptal aralığı planı kapsamalı');
      }
    });
  });

  group('çizelge değişimi', () {
    test('mola uzatılınca bildirim anları kayıyor', () {
      final before =
          NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      final extended = ScheduleModifier.extendBreak(schedule, 1, 300);
      final after =
          NotificationPlanner.plan(sessionId: sid, schedule: extended);

      expect(after[0].atMs, before[0].atMs, reason: 'ilk blok değişmez');
      expect(after[1].atMs, before[1].atMs + 300000);
      expect(after[2].atMs, before[2].atMs + 300000);
      expect(after[0].body, '1. blok bitti. 10 dakika molan başladı.');
    });

    test('mola atlanınca bildirim anları öne çekiliyor', () {
      final skipped =
          ScheduleModifier.skipBreak(schedule, 1, t0 + 1440000 + 120000);
      final after =
          NotificationPlanner.plan(sessionId: sid, schedule: skipped);

      expect(after[1].atMs, t0 + 1440000 + 120000);
      expect(after[2].atMs, schedule.blocks[2].endMs - 180000);
    });

    test('kimlikler çizelge değişse de aynı kalıyor', () {
      final before =
          NotificationPlanner.plan(sessionId: sid, schedule: schedule);
      final extended = ScheduleModifier.extendBreak(schedule, 1, 300);
      final after =
          NotificationPlanner.plan(sessionId: sid, schedule: extended);

      expect(
        after.map((n) => n.id).toList(),
        before.map((n) => n.id).toList(),
        reason: 'iptal edilecek kimlikler değişmemeli',
      );
    });
  });
}
