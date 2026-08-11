import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:sinav_odak/application/usecases/finish_session.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/repositories/session_repository.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late FakeTracker tracker;
  late SessionRepository repo;
  late FinishSessionUseCase finish;

  setUp(() async {
    db = newDb();
    notifier = FakeNotifier();
    tracker = FakeTracker();
    repo = newRepo(db);
    finish = FinishSessionUseCase(db, repo, notifier, tracker);
    await seedRunningSession(db, id: 's1', sch: schedule());
  });

  tearDown(() async => db.close());

  test('normal tamamlanma: completed + planlanan süre + odak skoru', () async {
    final score = await finish(
      sessionId: 's1',
      nowMs: lastEnd,
      early: false,
      questionCount: 60,
      correctCount: 44,
      wrongCount: 12,
      emptyCount: 4,
    );

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.completed);
    expect(s.actualDurationS, 2880, reason: 'planlanan çalışma süresi');
    expect(s.totalBreakS, 300);
    expect(s.endedAt, lastEnd);
    expect(s.net, 41.0, reason: '44 - 12/4');
    expect(score, isNotNull);
    expect(s.focusScore, score);
  });

  test('erken bitirme: earlyFinished + GERÇEKLEŞEN süre', () async {
    // İlk bloğun 10. dakikasında bitir.
    const now = t0 + 600000;
    await finish(sessionId: 's1', nowMs: now, early: true);

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.earlyFinished);
    expect(
      s.actualDurationS,
      600,
      reason: 'planlanan 2880 değil, gerçekleşen 600 yazılmalı',
    );
    expect(s.totalBreakS, 0, reason: 'molaya hiç ulaşılmadı');
  });

  test('erken bitirme odak skorunu düşürüyor', () async {
    await finish(sessionId: 's1', nowMs: t0 + 600000, early: true);
    final early = (await db.sessionDao.findById('s1'))!.focusScore!;

    // Aynı oturumu bu kez normal tamamla.
    final db2 = newDb();
    await seedRunningSession(db2, id: 's2', sch: schedule());
    await FinishSessionUseCase(
      db2,
      newRepo(db2),
      FakeNotifier(),
      FakeTracker(),
    )(
      sessionId: 's2',
      nowMs: lastEnd,
      early: false,
    );
    final completed = (await db2.sessionDao.findById('s2'))!.focusScore!;
    await db2.close();

    expect(early, lessThan(completed));
  });

  test('recomputeDay çağrılıyor: daily_stats doluyor', () async {
    expect(await db.statsDao.watchDay('2025-08-06').first, isNull);

    await finish(
      sessionId: 's1',
      nowMs: lastEnd,
      early: false,
      questionCount: 60,
      correctCount: 44,
      wrongCount: 12,
      emptyCount: 4,
    );

    final stat = await db.statsDao.watchDay('2025-08-06').first;
    expect(stat, isNotNull);
    expect(stat!.sessionCount, 1);
    expect(stat.totalStudyS, 2880);
    expect(stat.questionCount, 60);
  });

  test('yanlış varsa yanlış defterine kayıt düşüyor', () async {
    await finish(
      sessionId: 's1',
      nowMs: lastEnd,
      early: false,
      questionCount: 60,
      correctCount: 44,
      wrongCount: 12,
      emptyCount: 4,
    );
    expect(await db.wrongItemDao.activeCount(), 1);
  });

  test('foregroundS ÖLÇÜLMEZ, actualDurationS - awayS olarak HESAPLANIR',
      () async {
    // Kullanıcı oturum boyunca toplam 300 sn dışarıda kaldı.
    await db.sessionDao.bumpAwayStats(
      id: 's1',
      addAwayS: 300,
      addForegroundS: 0,
      addExitCount: 2,
    );

    await finish(sessionId: 's1', nowMs: lastEnd, early: false);

    final s = await db.sessionDao.findById('s1');
    expect(s!.foregroundS, 2880 - 300, reason: 'planlanan 2880, away 300');
    expect(s.awayS, 300);
    expect(s.exitCount, 2);
  });

  test('awayS actualDurationS aşarsa foregroundS negatife düşmüyor', () async {
    await db.sessionDao.bumpAwayStats(
      id: 's1',
      addAwayS: 999999,
      addForegroundS: 0,
      addExitCount: 1,
    );

    await finish(sessionId: 's1', nowMs: t0 + 600000, early: true);

    final s = await db.sessionDao.findById('s1');
    expect(s!.foregroundS, 0);
    expect(s.focusScore, isNotNull);
  });

  test('dışarıda geçen süre odak skorunu düşürüyor', () async {
    await db.sessionDao.bumpAwayStats(
      id: 's1',
      addAwayS: 1440,
      addForegroundS: 0,
      addExitCount: 4,
    );
    await finish(sessionId: 's1', nowMs: lastEnd, early: false);
    final distracted = (await db.sessionDao.findById('s1'))!.focusScore!;

    final db2 = newDb();
    await seedRunningSession(db2, id: 's2', sch: schedule());
    await FinishSessionUseCase(
      db2,
      newRepo(db2),
      FakeNotifier(),
      FakeTracker(),
    )(
      sessionId: 's2',
      nowMs: lastEnd,
      early: false,
    );
    final focused = (await db2.sessionDao.findById('s2'))!.focusScore!;
    await db2.close();

    expect(distracted, lessThan(focused));
  });

  test('lifecycle izleme durduruluyor', () async {
    await finish(sessionId: 's1', nowMs: lastEnd, early: false);
    expect(tracker.detachCount, 1);
  });

  test('bildirimler iptal ediliyor', () async {
    await finish(sessionId: 's1', nowMs: lastEnd, early: false);
    expect(notifier.cancelled, ['s1']);
  });

  test('net katsayısı ayardan okunuyor (4 -> 3)', () async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(netPenaltyCoefficient: Value(3)),
    );

    await finish(
      sessionId: 's1',
      nowMs: lastEnd,
      early: false,
      questionCount: 60,
      correctCount: 44,
      wrongCount: 12,
      emptyCount: 4,
    );

    final s = await db.sessionDao.findById('s1');
    expect(s!.net, 40.0, reason: '44 - 12/3');
  });
}
