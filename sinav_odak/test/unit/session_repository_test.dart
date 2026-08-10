// drift `isNull`/`isNotNull` sorgu yardımcılarını da export ediyor ve
// matcher paketindeki aynı adlı matcher'larla çakışıyor. Testte matcher
// sürümü gerekli olduğu için drift'inkiler gizleniyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/repositories/session_repository.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/application/recovery_service.dart';

/// Sabit epoch: 2025-08-06 08:00:00 UTC. Testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;

void main() {
  late AppDatabase db;
  late SessionRepository repo;

  const day = '2026-08-06';
  const subjectId = 'sub_yks_1'; // Matematik
  const topicId = 'top_sub_yks_1_22'; // Türev
  const activityId = 'act_soru';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> insertSession({
    String id = 's1',
    String dateKey = day,
    int startedAtMs = 1754467200000,
    int plannedS = 3000,
    SessionStatus status = SessionStatus.completed,
    String? topic = topicId,
  }) async {
    await db.sessionDao.createSession(
      StudySessionsCompanion.insert(
        id: id,
        dateKey: dateKey,
        startedAt: startedAtMs,
        plannedDurationS: plannedS,
        subjectId: subjectId,
        topicId: Value(topic),
        activityTypeId: activityId,
        status: status,
        scheduleJson: '{"version":1,"blocks":[]}',
      ),
      const [],
    );
    return id;
  }

  // --- P0-01: daily_stats orkestrasyonu ---

  test('save() daily_stats üretiyor (P0-01)', () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 12,
      patch: const StudySessionsCompanion(
        actualDurationS: Value(3000),
        questionCount: Value(60),
        correctCount: Value(44),
        wrongCount: Value(12),
        emptyCount: Value(4),
        net: Value(41),
        focusScore: Value(88),
      ),
    );

    final stat = await db.statsDao.watchDay(day).first;
    expect(stat, isNotNull, reason: 'recomputeDay çağrılmalıydı');
    expect(stat!.sessionCount, 1);
    expect(stat.totalStudyS, 3000);
    expect(stat.questionCount, 60);
    expect(stat.net, 41);
    expect(stat.avgFocusScore, 88);
  });

  test('delete() sonrası daily_stats satırı siliniyor', () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      wrongCount: 0,
      patch: const StudySessionsCompanion(actualDurationS: Value(1800)),
    );
    expect(await db.statsDao.watchDay(day).first, isNotNull);

    await repo.delete('s1');
    expect(await db.statsDao.watchDay(day).first, isNull);
  });

  // --- P1-06: wrongCount = 0 ---

  test('wrongCount > 0 yanlış kaydı üretiyor', () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 12,
      patch: const StudySessionsCompanion(wrongCount: Value(12)),
    );
    final items = await db.wrongItemDao.activeCount();
    expect(items, 1);
  });

  test('wrongCount 0 olunca otomatik kayıt siliniyor (P1-06)', () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 12,
      patch: const StudySessionsCompanion(wrongCount: Value(12)),
    );
    expect(await db.wrongItemDao.activeCount(), 1);

    // Kullanıcı oturumu düzenleyip yanlışı 0 yaptı.
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 0,
      patch: const StudySessionsCompanion(wrongCount: Value(0)),
    );
    expect(
      await db.wrongItemDao.activeCount(),
      0,
      reason: '"0 yanlış" kartı listede kalmamalı',
    );
  });

  test('ikinci save kopya yanlış kaydı oluşturmuyor', () async {
    await insertSession();
    for (var i = 0; i < 3; i++) {
      await repo.save(
        sessionId: 's1',
        dateKey: day,
        subjectId: subjectId,
        topicId: topicId,
        wrongCount: 5 + i,
        patch: StudySessionsCompanion(wrongCount: Value(5 + i)),
      );
    }
    final all = await db.select(db.wrongItems).get();
    expect(all.length, 1);
    expect(all.single.wrongCount, 7);
  });

  // --- P1-07: oturum silinince yetim kayıt ---

  test('oturum silinince yanlış kaydı manuel kayda dönüşüyor (P1-07)', () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 8,
      patch: const StudySessionsCompanion(wrongCount: Value(8)),
    );

    await repo.delete('s1');

    final all = await db.select(db.wrongItems).get();
    expect(all.length, 1, reason: 'yanlışlar oturumla birlikte silinmemeli');
    expect(all.single.sessionId, isNull);
    expect(all.single.source, WrongItemSource.manual);
  });

  // --- P0-02: konu arşivleme ---

  test('bağlı oturum ve yanlış kaydı varken konu arşivlenebiliyor (P0-02)',
      () async {
    await insertSession();
    await repo.save(
      sessionId: 's1',
      dateKey: day,
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 3,
      patch: const StudySessionsCompanion(wrongCount: Value(3)),
    );

    // Eskiden burada hard delete vardı ve SQLITE_CONSTRAINT_FOREIGNKEY
    // fırlatıyordu.
    await db.subjectDao.archiveTopic(topicId);

    final visible = await db.subjectDao.watchTopics(subjectId).first;
    expect(visible.any((t) => t.id == topicId), isFalse);

    final session = await db.sessionDao.findById('s1');
    expect(session!.topicId, topicId, reason: 'geçmiş oturum konusunu korumalı');
  });

  // --- P0-03: kurtarma ---

  test('devam eden çizelge resume döndürüyor (P0-03)', () async {
    await insertSession(id: 's2', status: SessionStatus.running);
    await db.sessionDao.replaceBlocks('s2', [
      SessionBlocksCompanion.insert(
        id: 'b1',
        sessionId: 's2',
        indexNo: 0,
        type: BlockType.study,
        plannedStartAt: t0 - 60000,
        plannedEndAt: t0 + 600000,
        plannedS: 660,
      ),
    ]);

    final r = await RecoveryService(db, repo).check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.resume);
    expect(r.session!.id, 's2');
  });

  test('bitmiş çizelge interrupted işaretliyor ve süreyi kırpıyor (P0-03)',
      () async {
    await insertSession(id: 's3', status: SessionStatus.running);
    // 60 dakikalık blok, 50 dakika önce başlamış ama kullanıcı 10 dakika
    // sonra çıkmış: planlanan 3600 sn yazılmamalı.
    await db.sessionDao.replaceBlocks('s3', [
      SessionBlocksCompanion.insert(
        id: 'b1',
        sessionId: 's3',
        indexNo: 0,
        type: BlockType.study,
        plannedStartAt: t0 - 3600000 * 2,
        plannedEndAt: t0 - 3600000,
        plannedS: 3600,
      ),
    ]);

    final r = await RecoveryService(db, repo).check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.needsDecision);

    final s = await db.sessionDao.findById('s3');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.actualDurationS, 3600, reason: 'blok tamamen geçmiş');

    final stat = await db.statsDao.watchDay(day).first;
    expect(stat, isNotNull, reason: 'kurtarma sonrası daily_stats güncellenmeli');
  });

  test('kurtarılan oturumun focusScore\'u yazılıyor (K3)', () async {
    await insertSession(
      id: 's7',
      status: SessionStatus.running,
      plannedS: 3600,
    );
    // 60 dk çalışma + 10 dk mola; çizelge 1 saat önce bitmiş.
    await db.sessionDao.replaceBlocks('s7', [
      SessionBlocksCompanion.insert(
        id: 'b1',
        sessionId: 's7',
        indexNo: 0,
        type: BlockType.study,
        plannedStartAt: t0 - 7800000,
        plannedEndAt: t0 - 4200000,
        plannedS: 3600,
      ),
      SessionBlocksCompanion.insert(
        id: 'b2',
        sessionId: 's7',
        indexNo: 1,
        type: BlockType.breakTime,
        plannedStartAt: t0 - 4200000,
        plannedEndAt: t0 - 3600000,
        plannedS: 600,
      ),
    ]);

    final r = await RecoveryService(db, repo).check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.needsDecision);

    final s = await db.sessionDao.findById('s7');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.focusScore, isNotNull, reason: 'kurtarma skoru yazmalı');
    expect(s.focusScore!, inInclusiveRange(0, 100));

    // ALT GÖREV 2 ile DAVRANIŞ DEĞİŞTİ (R4 çözüldü):
    // foregroundS artık ölçülmüyor, `actualDurationS - awayS` olarak
    // hesaplanıyor. Bu oturumda hiç çıkış kaydı yok (awayS = 0), dolayısıyla
    // presence tam kabul ediliyor.
    // 55*1 + 25*1 + 10 + 10 = 100 -> 100 * 0.55 = 55
    //
    // Öncesinde foregroundS DB'den 0 okunuyordu ve skor 41'de sabitleniyordu;
    // bu, lifecycle tracker'ın yokluğundan kaynaklanan bir eksiklikti.
    expect(s.focusScore, 55);
  });

  test('kurtarmada dışarıda geçen süre skoru düşürüyor (R4)', () async {
    await insertSession(id: 's8', status: SessionStatus.running, plannedS: 3600);
    await db.sessionDao.replaceBlocks('s8', [
      SessionBlocksCompanion.insert(
        id: 'b1',
        sessionId: 's8',
        indexNo: 0,
        type: BlockType.study,
        plannedStartAt: t0 - 7200000,
        plannedEndAt: t0 - 3600000,
        plannedS: 3600,
      ),
    ]);
    // Kullanıcı oturumun yarısını uygulama dışında geçirmiş.
    await db.sessionDao.bumpAwayStats(
      id: 's8',
      addAwayS: 1800,
      addForegroundS: 0,
      addExitCount: 3,
    );

    await RecoveryService(db, repo).check(nowMs: t0);

    final s = await db.sessionDao.findById('s8');
    // presence = 1800/3600 = 0.5 -> 12.5 puan
    // exit cezası: 3/6 -> 5 puan
    // 55 + 12.5 + 5 + 10 = 82.5 -> 82.5 * 0.55 = 45.375 -> 45
    expect(s!.foregroundS, 1800);
    expect(s.focusScore, 45);
  });

  test('çizelgesiz running kayıt sessizce temizleniyor', () async {
    await insertSession(id: 's4', status: SessionStatus.running);
    final r = await RecoveryService(db, repo).check(nowMs: t0);
    expect(r.outcome, RecoveryOutcome.none);
    expect(await db.sessionDao.findById('s4'), isNull);
  });

  // --- P2-06: enum bind ---

  test('subjectBreakdown running oturumları dışarıda bırakıyor', () async {
    await insertSession(id: 's5');
    await repo.save(
      sessionId: 's5',
      dateKey: day,
      subjectId: subjectId,
      wrongCount: 0,
      patch: const StudySessionsCompanion(
        actualDurationS: Value(1200),
        questionCount: Value(30),
      ),
    );
    await insertSession(id: 's6', status: SessionStatus.running);

    final rows = await db.statsDao.subjectBreakdown(
      DateTime.parse(day),
      DateTime.parse(day),
    );
    expect(rows.length, 1);
    expect(rows.single.studyS, 1200);
  });
}
