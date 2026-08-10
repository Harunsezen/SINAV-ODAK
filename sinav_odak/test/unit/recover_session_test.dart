import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/recovery_service.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late RecoveryService recovery;

  setUp(() {
    db = newDb();
    recovery = RecoveryService(db, newRepo(db));
  });

  tearDown(() async => db.close());

  test('aktif oturum yoksa none', () async {
    final r = await recovery.check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.none);
  });

  test('çalışma bloğu sürüyorsa resume + doğru blok', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final r = await recovery.check(nowMs: t0 + 600000);

    expect(r.outcome, RecoveryOutcome.resume);
    expect(r.state, isA<SessionInBlock>());
    expect((r.state! as SessionInBlock).blockIndex, 0);
  });

  test('mola sürüyorsa resume + mola state', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final r = await recovery.check(nowMs: breakStart + 60000);

    expect(r.outcome, RecoveryOutcome.resume);
    expect(r.state, isA<SessionInBreak>());
    expect((r.state! as SessionInBreak).blockIndex, breakIndex);
  });

  test('çizelge bitmişse needsDecision + interrupted + odak skoru', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final r = await recovery.check(nowMs: lastEnd + 3600000);

    expect(r.outcome, RecoveryOutcome.needsDecision);
    expect(r.recoveredStudyS, 2880);

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.focusScore, isNotNull);
    expect(s.focusScore!, inInclusiveRange(0, 100));
    expect(s.actualDurationS, 2880);
  });

  test('kurtarma sonrası daily_stats güncelleniyor', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await recovery.check(nowMs: lastEnd + 1000);

    final stat = await db.statsDao.watchDay('2025-08-06').first;
    expect(stat, isNotNull);
    expect(stat!.sessionCount, 1);
  });

  test('cihaz saati geri alınmışsa clockMovedBack', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final r = await recovery.check(nowMs: t0 - 60000);

    expect(r.outcome, RecoveryOutcome.clockMovedBack);
    expect(r.state, isA<SessionClockMovedBack>());
  });

  test('tolerans içindeki saat kayması clockMovedBack sayılmıyor', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final r = await recovery.check(nowMs: t0 - 2000);

    expect(r.outcome, RecoveryOutcome.resume);
  });

  test('bozuk scheduleJson: bloklardan kurtarılıyor (fallback)', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    // JSON'u boz; session_blocks sağlam kalsın.
    await db.sessionDao.patchSession(
      's1',
      const StudySessionsCompanion(scheduleJson: Value('{bozuk')),
    );

    final r = await recovery.check(nowMs: lastEnd + 1000);

    expect(r.outcome, RecoveryOutcome.needsDecision);
    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.actualDurationS, 2880, reason: 'bloklardan hesaplandı');
    expect(s.focusScore, isNotNull);
  });

  test('bozuk JSON + devam eden çizelge: resume (state null)', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await db.sessionDao.patchSession(
      's1',
      const StudySessionsCompanion(scheduleJson: Value('{bozuk')),
    );

    final r = await recovery.check(nowMs: t0 + 600000);
    expect(r.outcome, RecoveryOutcome.resume);
    expect(
      r.state,
      isNull,
      reason: 'çizelge çözülemedi, UI kaldığı yeri gösterir',
    );
  });

  test('çizelgesiz running kayıt sessizce temizleniyor', () async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await db.sessionDao.replaceBlocks('s1', const []);
    await db.sessionDao.patchSession(
      's1',
      const StudySessionsCompanion(scheduleJson: Value('{bozuk')),
    );

    final r = await recovery.check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.none);
    expect(await db.sessionDao.findById('s1'), isNull);
  });
}
