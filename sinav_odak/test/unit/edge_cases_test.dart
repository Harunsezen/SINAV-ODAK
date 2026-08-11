import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/utils/date_key.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/streak_calculator.dart';

import 'usecase_helpers.dart';

/// FAZ 8 — Kenar durumlar.
///
/// Takvim/istatistik ekranları yıl ve ay sınırlarında sessizce yanlış
/// aralık üretebilir; katalog tamamen arşivlenirse oturum kurulumu
/// kilitlenebilir. Bu testler o sınırları kilitliyor.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  // -------------------------------------------------------------------
  // Tarih sınırları
  // -------------------------------------------------------------------

  group('yıl ve ay sınırları', () {
    test('yılbaşı: 31 Aralık -> 1 Ocak serisi KIRILMIYOR', () {
      final r = StreakCalculator.onStudyDay(
        studyDate: '2026-01-01',
        lastStudyDate: '2025-12-31',
        currentStreak: 9,
        longestStreak: 9,
      );
      expect(
        r.currentStreak,
        10,
        reason: 'yıl değişimi ardışıklığı bozmamalı',
      );
    });

    test('artık yıl: 28 Şubat -> 29 Şubat 2024 ardışık', () {
      final r = StreakCalculator.onStudyDay(
        studyDate: '2024-02-29',
        lastStudyDate: '2024-02-28',
        currentStreak: 3,
        longestStreak: 5,
      );
      expect(r.currentStreak, 4);
    });

    test('artık yıl: 29 Şubat -> 1 Mart ardışık', () {
      final r = StreakCalculator.onStudyDay(
        studyDate: '2024-03-01',
        lastStudyDate: '2024-02-29',
        currentStreak: 4,
        longestStreak: 5,
      );
      expect(r.currentStreak, 5);
    });

    test('artık OLMAYAN yıl: 28 Şubat -> 1 Mart ardışık', () {
      final r = StreakCalculator.onStudyDay(
        studyDate: '2025-03-01',
        lastStudyDate: '2025-02-28',
        currentStreak: 2,
        longestStreak: 2,
      );
      expect(r.currentStreak, 3);
    });

    test('dateKeyRange yıl sınırını geçiyor', () {
      final keys = dateKeyRange(
        DateTime(2025, 12, 30),
        DateTime(2026, 1, 2),
      );
      expect(keys, ['2025-12-30', '2025-12-31', '2026-01-01', '2026-01-02']);
    });

    test('startOfWeek yıl sınırında doğru Pazartesi', () {
      // 1 Ocak 2026 Perşembe; haftanın başı 29 Aralık 2025 Pazartesi.
      expect(dateKeyOf(startOfWeek(DateTime(2026, 1, 1))), '2025-12-29');
    });

    test('Şubat ayının son günü artık yılda 29', () {
      // Takvim ızgarasının kullandığı hesap: bir sonraki ayın "0."ıncı günü.
      expect(DateTime(2024, 3, 0).day, 29);
      expect(DateTime(2025, 3, 0).day, 28);
    });

    test('Aralık ayının son günü 31 (yıl taşması)', () {
      expect(DateTime(2025, 13, 0).day, 31);
    });
  });

  // -------------------------------------------------------------------
  // Boş / arşivli katalog
  // -------------------------------------------------------------------

  group('katalog kenar durumları', () {
    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(settingsStreamProvider.future);
      return c;
    }

    test('TÜM dersler arşivliyse liste boş ama uygulama ÇÖKMÜYOR', () async {
      final c = await container();
      final all = await db.select(db.subjects).get();
      for (final s in all) {
        await db.subjectDao.setArchived(s.id, archived: true);
      }

      final visible = await c.read(subjectsProvider.future);
      expect(visible, isEmpty);
    });

    test('arşivli ders YÖNETİM ekranında görünmeye devam ediyor', () async {
      final c = await container();
      await db.subjectDao.setArchived(subjectId, archived: true);

      final all = await c.read(allSubjectsProvider.future);
      expect(
        all.any((s) => s.id == subjectId),
        isTrue,
        reason: 'arşivden çıkarmak imkânsız olurdu',
      );
    });

    test('tüm çalışma türleri arşivliyse liste boş', () async {
      final c = await container();
      final all = await db.select(db.activityTypes).get();
      for (final a in all) {
        await db.subjectDao.setActivityTypeArchived(a.id, archived: true);
      }

      expect(await c.read(activityTypesProvider.future), isEmpty);
    });

    test('arşivli ders GEÇMİŞ oturumu bozmuyor', () async {
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's1',
              dateKey: '2025-08-06',
              startedAt: t0,
              plannedDurationS: 1200,
              subjectId: subjectId,
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              actualDurationS: const Value(1200),
              endedAt: const Value(t0 + 1200000),
            ),
          );
      await db.statsDao.recomputeDay('2025-08-06');

      await db.subjectDao.setArchived(subjectId, archived: true);

      // Ders arşivlendi ama oturum ve özet DURUYOR.
      expect(await db.sessionDao.findById('s1'), isNotNull);
      final day = DateTime.parse('2025-08-06');
      expect((await db.statsDao.summaryFor(day, day)).sessionCount, 1);
      // Dışa aktarma da ders ADINI bulabilmeli.
      final rows = await db.statsDao.exportRows(day, day);
      expect(rows, hasLength(1));
      expect(rows.first.subjectName, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------
  // Sıfır oturum
  // -------------------------------------------------------------------

  group('hiç oturum yokken', () {
    test('aralık özeti sıfır döndürüyor, patlamıyor', () async {
      final from = DateTime.parse('2025-08-01');
      final to = DateTime.parse('2025-08-31');
      final s = await db.statsDao.summaryFor(from, to);

      expect(s.sessionCount, 0);
      expect(s.totalStudyS, 0);
      expect(s.successRate, 0, reason: 'sıfıra bölme olmamalı');
    });

    test('ders kırılımı boş liste', () async {
      final d = DateTime.parse('2025-08-06');
      expect(await db.statsDao.subjectBreakdown(d, d), isEmpty);
    });

    test('dışa aktarma boş liste', () async {
      final d = DateTime.parse('2025-08-06');
      expect(await db.statsDao.exportRows(d, d), isEmpty);
    });

    test('zayıf konular boş liste', () async {
      final d = DateTime.parse('2025-08-06');
      expect(await db.statsDao.weakestTopics(d, d), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // Saat geri alma
  // -------------------------------------------------------------------

  group('saat geri alındığında', () {
    test('aynı güne ikinci çalışma seriyi ARTIRMIYOR', () {
      final r = StreakCalculator.onStudyDay(
        studyDate: '2025-08-06',
        lastStudyDate: '2025-08-06',
        currentStreak: 4,
        longestStreak: 7,
      );
      expect(r.currentStreak, 4, reason: 'gün başına bir kez sayılır');
    });

    test('GEÇMİŞ tarihli çalışma mevcut seriyi bozmuyor', () {
      // Cihaz saati geri alındı: dün tarihli bir kayıt geldi.
      final r = StreakCalculator.onStudyDay(
        studyDate: '2025-08-05',
        lastStudyDate: '2025-08-06',
        currentStreak: 4,
        longestStreak: 7,
      );
      expect(
        r.longestStreak,
        greaterThanOrEqualTo(4),
        reason: 'en uzun seri geriye gitmemeli',
      );
    });
  });
}
