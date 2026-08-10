import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/application/usecases/extend_break.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/data/local/database.dart';

import 'usecase_helpers.dart';

void main() {
  late AppDatabase db;
  late FakeNotifier notifier;
  late ExtendBreakUseCase extend;

  setUp(() async {
    db = newDb();
    notifier = FakeNotifier();
    extend = ExtendBreakUseCase(db, newWriter(db, notifier));
    await seedRunningSession(db, id: 's1', sch: schedule());
  });

  tearDown(() async => db.close());

  test('+5 dk: mola uzuyor, sonraki bloklar kayıyor', () async {
    final updated =
        await extend(sessionId: 's1', breakBlockIndex: breakIndex);

    expect(updated.blocks[1].seconds, 600);
    expect(updated.blocks[1].extendedS, 300);
    expect(updated.blocks[2].startMs, breakEnd + 300000);
    expect(updated.plannedEndAtMs, lastEnd + 300000);
    expect(updated.validate, returnsNormally);
  });

  test('scheduleJson VE session_blocks birlikte güncelleniyor', () async {
    await extend(sessionId: 's1', breakBlockIndex: breakIndex);

    final s = await db.sessionDao.findById('s1');
    final parsed = ScheduleWriter.parse(s!);
    final blocks = await db.sessionDao.blocksOf('s1');

    expect(parsed.blocks[1].seconds, 600);
    expect(blocks[1].plannedS, 600, reason: 'iki temsil ayrışmamalı');
    expect(blocks[1].extendedS, 300);
    expect(blocks[2].plannedStartAt, parsed.blocks[2].startMs);
  });

  test('bildirimler iptal edilip yeniden kuruluyor', () async {
    await extend(sessionId: 's1', breakBlockIndex: breakIndex);
    expect(notifier.cancelled, ['s1']);
    expect(notifier.scheduled, ['s1']);
  });

  test('iki uzatma sonrası limit doluyor', () async {
    await extend(sessionId: 's1', breakBlockIndex: breakIndex);
    await extend(sessionId: 's1', breakBlockIndex: breakIndex);

    final s = await db.sessionDao.findById('s1');
    expect(ScheduleWriter.parse(s!).blocks[1].extendedS, 600);

    await expectLater(
      extend(sessionId: 's1', breakBlockIndex: breakIndex),
      throwsA(isA<PlanFailure>()),
    );
  });

  test('tek seferde limit aşımı reddediliyor', () async {
    await expectLater(
      extend(sessionId: 's1', breakBlockIndex: breakIndex, addS: 601),
      throwsA(isA<PlanFailure>()),
    );
  });

  test('çalışma bloğu uzatılamaz', () async {
    await expectLater(
      extend(sessionId: 's1', breakBlockIndex: 0),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('geçersiz indeks reddediliyor', () async {
    await expectLater(
      extend(sessionId: 's1', breakBlockIndex: 99),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('olmayan oturum reddediliyor', () async {
    await expectLater(
      extend(sessionId: 'yok', breakBlockIndex: breakIndex),
      throwsA(isA<SessionFailure>()),
    );
  });
}
