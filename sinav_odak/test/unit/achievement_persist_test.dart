import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// FAZ 7B — Rozetlerin KAYDET yolunda yazılması.
///
/// `achievements` tablosu Adım 1'den beri şemadaydı ama yazan kod yoktu.
/// Burada doğrulanan: `SessionRepository.save()` yolundan geçen bir oturum
/// rozetleri gerçekten açıyor mu.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Tamamlanmış oturum yazar (save yolunu KULLANMADAN — ön koşul kurmak
  /// için).
  Future<void> seedCompleted({
    required String id,
    String dateKey = '2025-08-06',
    int actualDurationS = 2880,
    int questionCount = 40,
    int startedAt = t0,
    int focusScore = 80,
  }) async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: id,
            dateKey: dateKey,
            startedAt: startedAt,
            plannedDurationS: 2880,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: Value(actualDurationS),
            questionCount: Value(questionCount),
            correctCount: Value(questionCount),
            endedAt: Value(startedAt + actualDurationS * 1000),
            focusScore: Value(focusScore),
          ),
        );
    await db.statsDao.recomputeDay(dateKey);
  }

  Future<Set<String>> codes() => db.achievementDao.unlockedCodes();

  // -------------------------------------------------------------------

  test('ilk oturum rozeti KAYDET yolunda açılıyor', () async {
    await seedCompleted(id: 's1');

    await newRepo(db).recomputeAchievements('2025-08-06');

    expect(await codes(), contains('first_session'));
  });

  test('hiç oturum yoksa rozet açılmıyor', () async {
    await newRepo(db).recomputeAchievements('2025-08-06');
    expect(await codes(), isEmpty);
  });

  test('maraton rozeti 6 saatlik günde açılıyor', () async {
    await seedCompleted(id: 's1', actualDurationS: 6 * 3600);

    await newRepo(db).recomputeAchievements('2025-08-06');

    expect(await codes(), contains('marathon_day'));
  });

  test('kısa günde maraton rozeti YOK', () async {
    await seedCompleted(id: 's1', actualDurationS: 1800);

    await newRepo(db).recomputeAchievements('2025-08-06');

    expect(await codes(), isNot(contains('marathon_day')));
  });

  test('1000 soru rozeti toplam üzerinden açılıyor', () async {
    await seedCompleted(id: 's1', questionCount: 600);
    await seedCompleted(id: 's2', dateKey: '2025-08-07', questionCount: 400);

    await newRepo(db).recomputeAchievements('2025-08-07');

    expect(await codes(), contains('questions_1000'));
  });

  test('seri rozeti ayardaki currentStreak üzerinden açılıyor', () async {
    await seedCompleted(id: 's1');
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(currentStreak: Value(7)),
    );

    await newRepo(db).recomputeAchievements('2025-08-06');

    final c = await codes();
    expect(c, containsAll(['streak_3', 'streak_7']));
  });

  test('rozet İKİ KEZ yazılmıyor, unlockedAt korunuyor', () async {
    await seedCompleted(id: 's1');
    await newRepo(db).recomputeAchievements('2025-08-06');

    final first = await db.select(db.achievements).get();
    final firstUnlockedAt =
        first.firstWhere((a) => a.code == 'first_session').unlockedAt;

    // İkinci kez çalıştır: yeni oturum eklendi ama rozet zaten açık.
    await seedCompleted(id: 's2', dateKey: '2025-08-07');
    await newRepo(db).recomputeAchievements('2025-08-07');

    final after = await db.select(db.achievements).get();
    final again = after.where((a) => a.code == 'first_session').toList();

    expect(again, hasLength(1), reason: 'aynı rozet iki satır olmamalı');
    expect(
      again.first.unlockedAt,
      firstUnlockedAt,
      reason: 'ilk oturum rozeti 2. oturumda yeniden kazanılmış görünmemeli',
    );
  });

  test('yeni açılan rozet kodları DÖNÜYOR', () async {
    await seedCompleted(id: 's1');

    final newly = await newRepo(db).recomputeAchievements('2025-08-06');

    expect(newly, contains('first_session'));

    // İkinci çağrıda yeni bir şey yok.
    final again = await newRepo(db).recomputeAchievements('2025-08-06');
    expect(again, isEmpty);
  });

  test('erken kuş rozeti oturum saatinden açılıyor', () async {
    // 2025-08-06 07:30 YEREL.
    final at0730 = DateTime(2025, 8, 6, 7, 30).millisecondsSinceEpoch;
    await seedCompleted(id: 's1', startedAt: at0730);

    await newRepo(db).recomputeAchievements('2025-08-06');

    expect(await codes(), contains('early_bird'));
  });

  test('öğlen başlayan oturum saat rozeti AÇMIYOR', () async {
    final atNoon = DateTime(2025, 8, 6, 12).millisecondsSinceEpoch;
    await seedCompleted(id: 's1', startedAt: atNoon);

    await newRepo(db).recomputeAchievements('2025-08-06');

    final c = await codes();
    expect(c, isNot(contains('early_bird')));
    expect(c, isNot(contains('night_owl')));
  });

  test('devam eden oturum toplamlara GİRMİYOR', () async {
    await seedRunningSession(db, id: 'run1', sch: schedule());

    await newRepo(db).recomputeAchievements('2025-08-06');

    expect(
      await codes(),
      isNot(contains('first_session')),
      reason: 'henüz bitmemiş oturum "ilk oturum" sayılmamalı',
    );
  });

  group('AchievementDao', () {
    test('lifetimeTotals tamamlanmış oturumları topluyor', () async {
      await seedCompleted(id: 's1', actualDurationS: 1200, questionCount: 10);
      await seedCompleted(
        id: 's2',
        dateKey: '2025-08-07',
        actualDurationS: 1800,
        questionCount: 20,
      );

      final t = await db.achievementDao.lifetimeTotals();

      expect(t.sessionCount, 2);
      expect(t.studyS, 3000);
      expect(t.questionCount, 30);
    });

    test('boş veritabanında lifetimeTotals sıfır', () async {
      final t = await db.achievementDao.lifetimeTotals();
      expect(t.sessionCount, 0);
      expect(t.studyS, 0);
    });

    test('markSeen ve unseenCount', () async {
      await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
      expect(await db.achievementDao.unseenCount(), 1);

      await db.achievementDao.markSeen('streak_3');
      expect(await db.achievementDao.unseenCount(), 0);
    });
  });
}
