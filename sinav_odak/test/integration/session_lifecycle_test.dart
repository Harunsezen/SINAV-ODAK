import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/recovery_service.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/run_controller.dart';

import '../unit/usecase_helpers.dart';

/// Uçtan uca oturum akışı: gerçek Drift (bellek içi) + gerçek use-case'ler.
/// Yalnızca bildirim ve lifecycle sahte; ikisi de platform kanalı gerektiriyor.
void main() {
  late AppDatabase db;
  late int fakeNow;
  late FakeNotifier notifier;
  late FakeTracker tracker;
  late ProviderContainer c;

  setUp(() {
    db = newDb();
    fakeNow = t0;
    notifier = FakeNotifier();
    tracker = FakeTracker();
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider.overrideWithValue(notifier as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(tracker as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  RunController ctrl() => c.read(runControllerProvider);

  /// Provider'ların DB'deki son duruma göre yeniden hesaplanmasını sağlar.
  Future<SessionState> stateNow() async {
    c.invalidate(activeSessionProvider);
    await c.read(activeSessionProvider.future);
    c.invalidate(runStateProvider);
    return c.read(runStateProvider);
  }

  Future<String> startSession() => ctrl().start(
        sessionId: 's1',
        schedule: schedule(),
        subjectId: subjectId,
        topicId: topicId,
        activityTypeId: activityId,
      );

  test('1) oturum başlat: running kayıt + bloklar + bildirim + izleme',
      () async {
    await startSession();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.running);
    expect(s.plannedDurationS, 2880);
    expect(s.dateKey, '2025-08-06');

    final blocks = await db.sessionDao.blocksOf('s1');
    expect(blocks.length, 3);
    expect(blocks[1].type, BlockType.breakTime);

    expect(notifier.scheduled, ['s1'], reason: 'bildirimler kurulmalı');
    expect(tracker.attached, ['s1'], reason: 'izleme başlamalı');
  });

  test('2) çalışma bloğu sürerken state inBlock', () async {
    await startSession();
    fakeNow = t0 + 600000;

    final state = await stateNow();
    expect(state, isA<SessionInBlock>());
    expect((state as SessionInBlock).blockIndex, 0);
    expect(state.remainingMs, 1440000 - 600000);
  });

  test('3) mola başlayınca state inBreak', () async {
    await startSession();
    fakeNow = breakStart + 30000;

    final state = await stateNow();
    expect(state, isA<SessionInBreak>());
    expect((state as SessionInBreak).blockIndex, breakIndex);
    expect(state.extensionsUsed, 0);
  });

  test('4) mola uzatınca bloklar kayıyor ve iki temsil senkron', () async {
    await startSession();
    fakeNow = breakStart + 30000;
    await stateNow();

    await ctrl().extendBreak();

    final blocks = await db.sessionDao.blocksOf('s1');
    final parsed = ScheduleWriter.parse((await db.sessionDao.findById('s1'))!);

    expect(blocks[1].plannedS, 600);
    expect(blocks[2].plannedStartAt, breakEnd + 300000);
    // schedule_json ile session_blocks AYRILMAMALI.
    for (var i = 0; i < blocks.length; i++) {
      expect(blocks[i].plannedStartAt, parsed.blocks[i].startMs);
      expect(blocks[i].plannedEndAt, parsed.blocks[i].endMs);
    }
    expect(notifier.cancelled, contains('s1'));
  });

  test('5) mola atlayınca bloklar öne çekiliyor', () async {
    await startSession();
    fakeNow = breakStart + 120000;
    await stateNow();

    await ctrl().skipBreak();

    final blocks = await db.sessionDao.blocksOf('s1');
    expect(blocks[1].wasSkipped, isTrue);
    expect(blocks[1].plannedS, 120);
    expect(blocks[2].plannedStartAt, fakeNow);

    // Atlama sonrası çalışma bloğuna dönülmeli.
    final state = await stateNow();
    expect(state, isA<SessionInBlock>());
    expect((state as SessionInBlock).blockIndex, 2);
  });

  test('6) normal bitirme: completed + daily_stats + net', () async {
    await startSession();
    fakeNow = lastEnd;
    await stateNow();

    final score = await ctrl().finish(
      sessionId: 's1',
      early: false,
      questionCount: 60,
      correctCount: 44,
      wrongCount: 12,
      emptyCount: 4,
    );

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.completed);
    expect(s.actualDurationS, 2880);
    expect(s.net, 41.0);
    expect(s.focusScore, score);

    final stat = await db.statsDao.watchDay('2025-08-06').first;
    expect(stat, isNotNull);
    expect(stat!.sessionCount, 1);
    expect(stat.questionCount, 60);

    // Yanlış defterine de düşmeli.
    expect(await db.wrongItemDao.activeCount(), 1);
    expect(tracker.detachCount, 1);
    expect(notifier.cancelled, contains('s1'));
  });

  test('7) erken bitirme: earlyFinished + gerçekleşen süre + düşük skor',
      () async {
    await startSession();
    fakeNow = t0 + 600000;
    await stateNow();

    final earlyScore = await ctrl().finish(sessionId: 's1', early: true);

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.earlyFinished);
    expect(s.actualDurationS, 600, reason: 'planlanan 2880 değil');

    // Aynı çizelgeyi normal tamamlayan bir oturumla karşılaştır.
    final db2 = newDb();
    final c2 = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db2),
        clockProvider.overrideWithValue(() => lastEnd),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(c2.dispose);
    await seedRunningSession(db2, id: 's2', sch: schedule());
    final fullScore = await c2
        .read(runControllerProvider)
        .finish(sessionId: 's2', early: false);
    await db2.close();

    expect(earlyScore!, lessThan(fullScore!));
  });

  test('8) kurtarma: yarıda kalan oturum interrupted + skor + daily_stats',
      () async {
    await startSession();

    // Uygulama öldü, çizelge bitti, çok sonra açıldı.
    fakeNow = lastEnd + 3600000;
    final result = await RecoveryService(db, newRepo(db)).check(nowMs: fakeNow);

    expect(result.outcome.name, 'needsDecision');
    expect(result.recoveredStudyS, 2880);

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.focusScore, isNotNull);
    expect(s.focusScore!, inInclusiveRange(0, 100));

    final stat = await db.statsDao.watchDay('2025-08-06').first;
    expect(stat, isNotNull, reason: 'kurtarma daily_stats güncellemeli');
  });

  test('9) aktif oturum varken ikinci oturum başlatılamıyor', () async {
    await startSession();
    await expectLater(
      ctrl().start(
        sessionId: 's2',
        schedule: schedule(),
        subjectId: subjectId,
        activityTypeId: activityId,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
