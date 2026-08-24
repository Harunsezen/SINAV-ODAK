// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/finish_book_session.dart';
import 'package:sinav_odak/application/usecases/start_book_session.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// v1.3 — **SERİ KURALI: kitap oturumu da seriye sayılır.**
///
/// Koordinatörün açık kararı: *"o gün sadece kitap okuyan öğrencinin
/// serisi KIRILMAZ."*
///
/// Bu dosya kuralın kodda gerçekten durduğunu kilitliyor. Kural üç yerden
/// birden geçiyor ve üçü de burada zorlanıyor:
/// 1. `SessionRepository.saveBookSession` → `recomputeStreak`
/// 2. çalışma ile okuma AYNI seriyi paylaşıyor (iki ayrı sayaç değil)
/// 3. aynı gün ikinci okuma seriyi İKİ KEZ artırmıyor
void main() {
  late AppDatabase db;
  late StartBookSessionUseCase start;
  late FinishBookSessionUseCase finish;

  setUp(() {
    db = newDb();
    start = StartBookSessionUseCase(db);
    finish = FinishBookSessionUseCase(db, newRepo(db));
  });
  tearDown(() async => db.close());

  /// Bir günü **yalnızca kitap okuyarak** kapatır.
  ///
  /// `dateKey` oturumun başlangıç anından türüyor; bu yüzden gün gün
  /// ilerlerken sabit `t0`'a gün ekliyoruz (`DateTime.now()` YOK).
  Future<void> readOn(int dayOffset, {required String id}) async {
    final startMs = t0 + dayOffset * 86400000;
    await start(
      sessionId: id,
      mode: BookMode.duration,
      nowMs: startMs,
      durationS: 1800,
    );
    await finish(sessionId: id, nowMs: startMs + 1800000, pagesRead: 20);
  }

  /// Bir günü çalışma oturumuyla kapatır.
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

  test('İLK okuma seriyi 1 yapıyor', () async {
    expect((await db.settingsDao.ensure()).currentStreak, 0);

    await readOn(0, id: 'b0');

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 1);
    expect(s.lastStudyDate, '2025-08-06');
  });

  test('ÜÇ GÜN ÜST ÜSTE yalnızca kitap: seri 3 — KIRILMIYOR', () async {
    // Koordinatör kuralının tam gövdesi.
    await readOn(0, id: 'b0');
    await readOn(1, id: 'b1');
    await readOn(2, id: 'b2');

    final s = await db.settingsDao.ensure();
    expect(
      s.currentStreak,
      3,
      reason: 'kitap oturumu seriye sayılmalı — o gün sadece kitap okuyan '
          'öğrencinin zinciri kırılmamalı',
    );
    expect(s.lastStudyDate, '2025-08-08');
  });

  test('ÇALIŞMA ve OKUMA aynı seriyi paylaşıyor', () async {
    // İki ayrı sayaç olsaydı "dün çalıştım, bugün okudum" zinciri kırardı.
    await studyOn('2025-08-06', id: 's0');
    await readOn(1, id: 'b1');
    await studyOn('2025-08-08', id: 's2');

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 3);
    expect(s.longestStreak, 3);
  });

  test('okumanın araya girdiği gün zinciri KURTARIYOR', () async {
    // Asıl senaryo: 6'sında çalıştı, 7'sinde vakti yoktu ama kitap okudu,
    // 8'inde yine çalıştı. Kitap sayılmasaydı seri 8'inde 1'e düşerdi.
    await studyOn('2025-08-06', id: 's0');
    await readOn(1, id: 'b1');

    expect((await db.settingsDao.ensure()).currentStreak, 2);

    await studyOn('2025-08-08', id: 's2');
    expect(
      (await db.settingsDao.ensure()).currentStreak,
      3,
      reason: 'ara gün kitapla dolduruldu, zincir devam etmeli',
    );
  });

  test('AYNI GÜN ikinci okuma seriyi iki kez artırmıyor', () async {
    await readOn(0, id: 'b0');
    await start(
      sessionId: 'b0b',
      mode: BookMode.pageTarget,
      nowMs: t0 + 7200000,
      pageTarget: 20,
    );
    await finish(sessionId: 'b0b', nowMs: t0 + 9000000, pagesRead: 20);

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 1, reason: 'seri GÜN başına bir kez artar');
  });

  test('ARADA BOŞ GÜN varsa zincir kopuyor — kitap da istisna değil', () async {
    // Kural simetrik olmalı: kitap seriyi uzatıyorsa, kitapsız geçen gün
    // de onu kırmalı. Aksi halde "kitap okuyunca seri hiç kırılmaz" gibi
    // bir kaçak kural oluşurdu.
    await readOn(0, id: 'b0');
    await readOn(3, id: 'b3');

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 1);
  });

  test('SİLİNEN okuma seriye sayılmıyor', () async {
    // Kayıt yapılmadan silinen oturum `saveBookSession` yolundan HİÇ
    // geçmiyor; seri de dokunulmadan kalıyor.
    await start(
      sessionId: 'bx',
      mode: BookMode.duration,
      nowMs: t0,
      durationS: 1800,
    );
    await db.bookDao.deleteSession('bx');

    final s = await db.settingsDao.ensure();
    expect(s.currentStreak, 0);
    expect(s.lastStudyDate, isNull);
  });

  test('seri ROZETİ okuma günüyle de açılıyor', () async {
    // `recomputeAchievements` de okuma yolundan geçiyor; geçmeseydi
    // öğrenci seriyi uzatır, rozeti bir sonraki ÇALIŞMA oturumuna kadar
    // göremezdi.
    for (var d = 0; d < 3; d++) {
      await readOn(d, id: 'b$d');
    }

    final codes = await db.achievementDao.unlockedCodes();
    expect(codes, contains('streak_3'));
  });
}
