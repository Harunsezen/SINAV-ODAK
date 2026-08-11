// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// KARAR D3 — `idx_one_running` kısmi unique index.
///
/// `StartSessionUseCase` içindeki "önce oku sonra yaz" koruması yarış
/// durumunda iki `running` satıra izin veriyordu; ikinci satır oluştuğunda
/// ilk oturumun çalışması `daily_stats`'a hiç yansımıyor ve hata SESSİZ
/// kalıyordu. Bu testler kısıtın kodda değil ŞEMADA olduğunu doğrular:
/// use-case tamamen atlanarak doğrudan DAO'ya yazılıyor.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> insertRunning(String id) => seedRunningSession(
        db,
        id: id,
        sch: schedule(),
      );

  test('ikinci running oturum insert edilemiyor', () async {
    await insertRunning('s1');

    await expectLater(
      insertRunning('s2'),
      throwsA(isA<SqliteException>()),
      reason: 'kısıt kodda değil şemada olmalı',
    );

    expect(await db.sessionDao.findById('s2'), isNull);
  });

  test('var olan oturum running yapılamıyor (UPDATE de kısıtlı)', () async {
    await insertRunning('s1');
    await db.sessionDao.markInterrupted(
      id: 's1',
      actualDurationS: 600,
      totalBreakS: 0,
      endedAt: t0 + 600000,
    );
    await insertRunning('s2');

    await expectLater(
      db.sessionDao.patchSession(
        's1',
        const StudySessionsCompanion(status: Value(SessionStatus.running)),
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('oturum kapandıktan sonra yenisi başlatılabiliyor', () async {
    await insertRunning('s1');
    await db.sessionDao.markInterrupted(
      id: 's1',
      actualDurationS: 600,
      totalBreakS: 0,
      endedAt: t0 + 600000,
    );

    await insertRunning('s2');

    expect((await db.sessionDao.findById('s2'))!.status, SessionStatus.running);
    expect(
      (await db.sessionDao.findActiveSession())!.id,
      's2',
      reason: 'tek running kayıt kalmalı',
    );
  });

  test('running OLMAYAN oturumlar aynı statüyü paylaşabiliyor', () async {
    // Kısmi index yalnızca `running` satırları kısıtlar; iki `completed`
    // oturum aynı gün içinde tamamen normaldir.
    for (final id in ['c1', 'c2', 'c3']) {
      await db.sessionDao.createSession(
        StudySessionsCompanion.insert(
          id: id,
          dateKey: '2025-08-06',
          startedAt: t0,
          plannedDurationS: 1440,
          subjectId: subjectId,
          activityTypeId: activityId,
          status: SessionStatus.completed,
          scheduleJson: '{"version":1,"blocks":[]}',
        ),
        ScheduleWriter.blocksOf(id, schedule()),
      );
    }

    final rows = await db.sessionDao.watchByDate('2025-08-06').first;
    expect(rows.length, 3);
  });
}
