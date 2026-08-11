import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/application/usecases/extend_break.dart';
import 'package:sinav_odak/application/usecases/skip_break.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/data/local/database.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late SkipBreakUseCase skip;

  setUp(() async {
    db = newDb();
    notifier = FakeNotifier();
    skip = SkipBreakUseCase(db, newWriter(db, notifier));
    await seedRunningSession(db, id: 's1', sch: schedule());
  });

  tearDown(() async => db.close());

  test('mola atlanınca sonraki bloklar öne çekiliyor', () async {
    const now = breakStart + 120000; // molanın 2. dakikası
    final updated =
        await skip(sessionId: 's1', breakBlockIndex: breakIndex, nowMs: now);

    expect(updated.blocks[1].endMs, now);
    expect(updated.blocks[1].seconds, 120);
    expect(updated.blocks[1].skipped, isTrue);
    expect(updated.blocks[2].startMs, now);
    expect(updated.plannedEndAtMs, lastEnd - 180000);
    expect(updated.validate, returnsNormally);
  });

  test('scheduleJson VE session_blocks birlikte güncelleniyor', () async {
    await skip(
      sessionId: 's1',
      breakBlockIndex: breakIndex,
      nowMs: breakStart + 120000,
    );

    final s = await db.sessionDao.findById('s1');
    final parsed = ScheduleWriter.parse(s!);
    final blocks = await db.sessionDao.blocksOf('s1');

    expect(blocks[1].wasSkipped, isTrue);
    expect(blocks[1].plannedS, 120);
    expect(blocks[2].plannedStartAt, parsed.blocks[2].startMs);
  });

  test('uzatılmış mola atlanınca extendedS kullanılana düşüyor', () async {
    await ExtendBreakUseCase(db, newWriter(db, notifier))(
      sessionId: 's1',
      breakBlockIndex: breakIndex,
    );
    // 300 + 300 = 600 sn mola; 6. dakikada atla.
    final updated = await skip(
      sessionId: 's1',
      breakBlockIndex: breakIndex,
      nowMs: breakStart + 360000,
    );

    expect(updated.blocks[1].seconds, 360);
    expect(updated.blocks[1].extendedS, 60, reason: '360 - 300');
  });

  test('mola henüz başlamadıysa reddediliyor', () async {
    await expectLater(
      skip(sessionId: 's1', breakBlockIndex: breakIndex, nowMs: breakStart),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('mola zaten bittiyse reddediliyor', () async {
    await expectLater(
      skip(sessionId: 's1', breakBlockIndex: breakIndex, nowMs: breakEnd),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('çalışma bloğu atlanamaz', () async {
    await expectLater(
      skip(sessionId: 's1', breakBlockIndex: 0, nowMs: t0 + 60000),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('bildirimler yeniden kuruluyor', () async {
    await skip(
      sessionId: 's1',
      breakBlockIndex: breakIndex,
      nowMs: breakStart + 60000,
    );
    expect(notifier.cancelled, ['s1']);
    expect(notifier.scheduled, ['s1']);
  });
}
