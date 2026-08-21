import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/application/usecases/start_session.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late FakeTracker tracker;
  late StartSessionUseCase start;

  setUp(() {
    db = newDb();
    notifier = FakeNotifier();
    tracker = FakeTracker();
    start = StartSessionUseCase(db, notifier, tracker);
  });

  tearDown(() async => db.close());

  Future<String> run({String id = 's1', int startAtMs = t0}) => start(
        sessionId: id,
        schedule: schedule(startAtMs: startAtMs),
        subjectId: subjectId,
        topicIds: const [topicId],
        activityTypeId: activityId,
      );

  test('oturum başlatınca running kayıt ve bloklar oluşuyor', () async {
    await run();

    final s = await db.sessionDao.findById('s1');
    expect(s, isNotNull);
    expect(s!.status, SessionStatus.running);
    expect(s.startedAt, t0);
    expect(s.plannedDurationS, 2880, reason: '2 x 24 dk');
    expect(s.subjectId, subjectId);

    final blocks = await db.sessionDao.blocksOf('s1');
    expect(blocks.length, 3, reason: 'çalışma + mola + çalışma');
    expect(blocks[1].type, BlockType.breakTime);
    expect(blocks[1].plannedS, 300);
  });

  test('aktif oturum varken ikinci başlatma reddediliyor', () async {
    await run();
    expect(
      () => run(id: 's2'),
      throwsA(isA<SessionFailure>()),
    );
  });

  test('scheduleJson round-trip kayıpsız', () async {
    await run();
    final s = await db.sessionDao.findById('s1');
    final parsed = ScheduleWriter.parse(s!);

    expect(parsed, schedule());
    expect(parsed.totalStudyS, 2880);
    expect(parsed.plannedEndAtMs, lastEnd);
  });

  test('scheduleJson ile session_blocks aynı çizelgeyi temsil ediyor',
      () async {
    await run();
    final s = await db.sessionDao.findById('s1');
    final parsed = ScheduleWriter.parse(s!);
    final blocks = await db.sessionDao.blocksOf('s1');

    expect(blocks.length, parsed.blockCount);
    for (var i = 0; i < blocks.length; i++) {
      expect(blocks[i].plannedStartAt, parsed.blocks[i].startMs);
      expect(blocks[i].plannedEndAt, parsed.blocks[i].endMs);
      expect(blocks[i].plannedS, parsed.blocks[i].seconds);
      expect(blocks[i].type, parsed.blocks[i].type);
    }
  });

  test('gece yarısını aşan oturum BAŞLADIĞI güne yazılıyor', () async {
    // 2025-08-06 23:50 UTC
    const lateStart = 1754524200000;
    await start(
      sessionId: 's3',
      schedule: ScheduleBuilder.fromPreset(
        startAtMs: lateStart,
        workMinutes: 30,
        breakMinutes: 5,
        cycles: 2,
      ).schedule,
      subjectId: subjectId,
      activityTypeId: activityId,
    );

    final s = await db.sessionDao.findById('s3');
    expect(
      s!.dateKey,
      '2025-08-06',
      reason: 'oturum ertesi güne taşsa da başladığı güne sayılır',
    );
  });

  test('bildirimler kuruluyor', () async {
    await run();
    expect(notifier.scheduled, ['s1']);
  });
}
