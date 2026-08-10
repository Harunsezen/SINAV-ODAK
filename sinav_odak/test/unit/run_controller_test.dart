import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/run_controller.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late int fakeNow;

  /// Ticker gerçek zamanlı akmasın diye tek değerle override edilir;
  /// state'in yalnızca clock'a bağlı olduğunu da böyle kanıtlıyoruz.
  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => fakeNow),
          sessionNotifierProvider
              .overrideWithValue(FakeNotifier() as SessionNotifier),
          activityTrackerProvider
              .overrideWithValue(FakeTracker() as SessionActivityTracker),
          uiTickerProvider.overrideWith((ref) => Stream<int>.value(0)),
        ],
      );

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });

  tearDown(() async => db.close());

  /// activeSessionProvider bir Drift stream'i; ilk değeri beklemek gerekir.
  Future<void> settle(ProviderContainer c) async {
    await c.read(activeSessionProvider.future);
  }

  test('aktif oturum yokken state idle', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    expect(c.read(runStateProvider), isA<SessionIdle>());
    expect(c.read(activeScheduleProvider), isNull);
  });

  test('çalışma bloğu sürerken inBlock', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    final state = c.read(runStateProvider);
    expect(state, isA<SessionInBlock>());
    expect((state as SessionInBlock).blockIndex, 0);
    expect(state.sessionId, 's1');
  });

  test('mola anında inBreak', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = breakStart + 60000;

    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    final state = c.read(runStateProvider);
    expect(state, isA<SessionInBreak>());
    expect((state as SessionInBreak).blockIndex, breakIndex);
  });

  test('çizelge bitince summarizing', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;

    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    expect(c.read(runStateProvider), isA<SessionSummarizing>());
  });

  test('state YALNIZCA saate bağlı; ticker onu ilerletmiyor', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    final first = c.read(runStateProvider);
    expect(first, isA<SessionInBlock>());
    final firstRemaining = (first as SessionInBlock).remainingMs;

    // Saat ilerlemeden state kaç kez yeniden hesaplanırsa hesaplansın
    // DEĞİŞMEMELİ. Ticker tabanlı bir sayaç olsaydı her tikte süre azalırdı;
    // burada süre yalnızca saatin fonksiyonu.
    for (var i = 0; i < 5; i++) {
      c.invalidate(runStateProvider);
      final s = c.read(runStateProvider) as SessionInBlock;
      expect(s.remainingMs, firstRemaining, reason: 'tik state ilerletmemeli');
    }

    // Saat ilerleyince state DEĞİŞMELİ.
    fakeNow += 60000;
    c.invalidate(runStateProvider);
    final later = c.read(runStateProvider) as SessionInBlock;
    expect(later.remainingMs, firstRemaining - 60000);
  });

  test('cihaz saati geri alınırsa clockMovedBack', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = t0 - 60000;

    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    expect(c.read(runStateProvider), isA<SessionClockMovedBack>());
  });

  test('bozuk scheduleJson: çizelge null, state idle, UI çökmüyor', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await db.sessionDao.patchSession(
      's1',
      const StudySessionsCompanion(scheduleJson: Value('{bozuk')),
    );

    final c = makeContainer();
    addTearDown(c.dispose);
    await settle(c);

    expect(c.read(activeScheduleProvider), isNull);
    expect(c.read(runStateProvider), isA<SessionIdle>());
  });

  group('RunController aksiyonları', () {
    test('start oturum açıyor', () async {
      final c = makeContainer();
      addTearDown(c.dispose);

      final id = await c.read(runControllerProvider).start(
            sessionId: 's1',
            schedule: schedule(),
            subjectId: subjectId,
            activityTypeId: activityId,
          );

      expect(id, 's1');
      expect(
        (await db.sessionDao.findById('s1'))!.status,
        SessionStatus.running,
      );
    });

    test('extendBreak molada çalışıyor, çalışma bloğunda çalışmıyor', () async {
      await seedRunningSession(db, id: 's1', sch: schedule());
      final c = makeContainer();
      addTearDown(c.dispose);
      await settle(c);

      // Çalışma bloğundayken: hiçbir şey olmamalı.
      await c.read(runControllerProvider).extendBreak();
      var blocks = await db.sessionDao.blocksOf('s1');
      expect(blocks[1].extendedS, 0);

      // Molada: uzamalı.
      fakeNow = breakStart + 60000;
      c.invalidate(runStateProvider);
      await c.read(runControllerProvider).extendBreak();

      blocks = await db.sessionDao.blocksOf('s1');
      expect(blocks[1].extendedS, 300);
      expect(blocks[1].plannedS, 600);
    });

    test('kalan uzatma hakkı doğru raporlanıyor', () async {
      await seedRunningSession(db, id: 's1', sch: schedule());
      fakeNow = breakStart + 60000;
      final c = makeContainer();
      addTearDown(c.dispose);
      await settle(c);

      final ctrl = c.read(runControllerProvider);
      expect(ctrl.remainingExtensions(), 2);

      await ctrl.extendBreak();
      await settle(c);
      c.invalidate(runStateProvider);
      expect(ctrl.remainingExtensions(), 1);
    });

    test('skipBreak molayı erken bitiriyor', () async {
      await seedRunningSession(db, id: 's1', sch: schedule());
      fakeNow = breakStart + 120000;
      final c = makeContainer();
      addTearDown(c.dispose);
      await settle(c);

      await c.read(runControllerProvider).skipBreak();

      final blocks = await db.sessionDao.blocksOf('s1');
      expect(blocks[1].wasSkipped, isTrue);
      expect(blocks[1].plannedS, 120);
    });

    test('finish oturumu kapatıyor ve skor dönüyor', () async {
      await seedRunningSession(db, id: 's1', sch: schedule());
      fakeNow = lastEnd;
      final c = makeContainer();
      addTearDown(c.dispose);
      await settle(c);

      final score = await c.read(runControllerProvider).finish(
            sessionId: 's1',
            early: false,
            questionCount: 60,
            correctCount: 44,
            wrongCount: 12,
            emptyCount: 4,
          );

      expect(score, isNotNull);
      final s = await db.sessionDao.findById('s1');
      expect(s!.status, SessionStatus.completed);
      expect(s.net, 41.0);
    });
  });
}
