// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// FAZ 5 — Streak'in KAYDET yolundan yazılması.
///
/// Saf hesap `streak_calculator_test.dart`'ta; burada doğrulanan şey
/// `SessionRepository.save`'in üç kolonu gerçekten yazması. Kolonlar Adım
/// 1'den beri şemadaydı ama hep 0/null kalıyordu.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Bir günü kaydeder. Her çağrı ayrı oturum kimliği kullanır çünkü
  /// `idx_one_running` aynı anda tek `running` satıra izin veriyor.
  Future<void> studyOn(String dateKey, {required String id}) async {
    await seedRunningSession(db, id: id, sch: schedule());
    await newRepo(db).save(
      sessionId: id,
      dateKey: dateKey,
      subjectId: subjectId,
      wrongCount: 0,
      patch: const StudySessionsCompanion(
        status: Value(SessionStatus.completed),
        actualDurationS: Value(3600),
      ),
    );
  }

  test('ilk kayıt üç kolonu da yazıyor', () async {
    final before = await db.settingsDao.ensure();
    expect(before.currentStreak, 0);
    expect(before.lastStudyDate, isNull);

    await studyOn('2025-08-06', id: 's1');

    final s = await db.settingsDao.read();
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 1);
    expect(s.lastStudyDate, '2025-08-06');
  });

  test('ardışık günler streak\'i büyütüyor', () async {
    await studyOn('2025-08-06', id: 's1');
    await studyOn('2025-08-07', id: 's2');
    await studyOn('2025-08-08', id: 's3');

    final s = await db.settingsDao.read();
    expect(s.currentStreak, 3);
    expect(s.longestStreak, 3);
    expect(s.lastStudyDate, '2025-08-08');
  });

  test('boş gün zinciri kırıyor ama REKOR duruyor', () async {
    await studyOn('2025-08-06', id: 's1');
    await studyOn('2025-08-07', id: 's2');
    await studyOn('2025-08-08', id: 's3');
    // 09 ve 10 boş.
    await studyOn('2025-08-11', id: 's4');

    final s = await db.settingsDao.read();
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 3, reason: 'rekor silinmemeli');
  });

  test('aynı güne ikinci oturum streak\'i artırmıyor', () async {
    await studyOn('2025-08-06', id: 's1');
    await studyOn('2025-08-06', id: 's2');

    final s = await db.settingsDao.read();
    expect(s.currentStreak, 1);
  });

  test('kurtarılan (interrupted) oturum streak yazmıyor', () async {
    // markInterrupted `save` yolundan geçmez; streak yalnızca KAYDET
    // yolunda yazılır. Bu bilinçli: kurtarma kullanıcının o gün gerçekten
    // çalıştığını değil, uygulamanın yarıda kaldığını gösterir.
    await seedRunningSession(db, id: 's1', sch: schedule());
    await newRepo(db).markInterrupted(
      sessionId: 's1',
      actualDurationS: 600,
      totalBreakS: 0,
      endedAt: lastEnd,
      focusScore: 40,
    );

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 0);
    expect(s.lastStudyDate, isNull);
  });
}
