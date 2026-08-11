// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/goal_progress_calculator.dart';

import 'usecase_helpers.dart';

/// FAZ 5 — Hedef ilerlemesi.
///
/// `goals.currentValue` şemada vardı ama hiçbir kod yazmıyordu: kullanıcı
/// hedef oluşturuyor, ilerleme sonsuza kadar 0 kalıyordu.
void main() {
  // --- Saf hesap ---

  group('GoalProgressCalculator (saf)', () {
    const m = GoalMetrics(
      dayStudyS: 7200, // 120 dk
      dayQuestions: 80,
      dayNet: 41,
      weekStudyS: 36000, // 600 dk
      weekQuestions: 400,
      subjectStudyS: 3600, // 60 dk
      completedTopics: 3,
      currentStreak: 5,
    );

    test('süre hedefleri DAKİKA cinsine çevriliyor', () {
      expect(GoalProgressCalculator.valueFor(GoalType.dailyMinutes, m), 120);
      expect(GoalProgressCalculator.valueFor(GoalType.weeklyMinutes, m), 600);
      expect(GoalProgressCalculator.valueFor(GoalType.subjectMinutes, m), 60);
    });

    test('soru ve net hedefleri doğrudan geçiyor', () {
      expect(GoalProgressCalculator.valueFor(GoalType.dailyQuestions, m), 80);
      expect(GoalProgressCalculator.valueFor(GoalType.weeklyQuestions, m), 400);
      expect(GoalProgressCalculator.valueFor(GoalType.net, m), 41);
    });

    test('konu ve streak hedefleri', () {
      expect(GoalProgressCalculator.valueFor(GoalType.topicCompletion, m), 3);
      expect(GoalProgressCalculator.valueFor(GoalType.streak, m), 5);
    });

    test('eksik saniye dakikaya YUVARLANMIYOR (aşağı kırpılıyor)', () {
      const partial = GoalMetrics(dayStudyS: 119);
      expect(
        GoalProgressCalculator.valueFor(GoalType.dailyMinutes, partial),
        1,
        reason: '119 sn = 1 dk 59 sn -> 1 dk',
      );
    });

    test('isReached sınır dahil', () {
      expect(GoalProgressCalculator.isReached(240, 240), isTrue);
      expect(GoalProgressCalculator.isReached(239, 240), isFalse);
      expect(GoalProgressCalculator.isReached(241, 240), isTrue);
    });

    test('hedef 0 ise ulaşılmış sayılmıyor', () {
      expect(GoalProgressCalculator.isReached(10, 0), isFalse);
    });

    test('ratio 0..1 arasında kırpılıyor', () {
      expect(GoalProgressCalculator.ratio(120, 240), closeTo(0.5, 0.001));
      expect(GoalProgressCalculator.ratio(500, 240), 1.0);
      expect(GoalProgressCalculator.ratio(-5, 240), 0.0);
      expect(GoalProgressCalculator.ratio(10, 0), 0.0);
    });
  });

  // --- Kayıt yoluna bağlanması ---

  group('SessionRepository.save hedefleri günceller', () {
    late AppDatabase db;

    setUp(() => db = newDb());
    tearDown(() async => db.close());

    Future<void> saveSession({
      int durationS = 7200,
      int questions = 80,
      double net = 41,
      String dateKey = '2025-08-06',
    }) async {
      await seedRunningSession(db, id: 's1', sch: schedule());
      await newRepo(db).save(
        sessionId: 's1',
        dateKey: dateKey,
        subjectId: subjectId,
        topicId: topicId,
        wrongCount: 0,
        patch: StudySessionsCompanion(
          status: const Value(SessionStatus.completed),
          actualDurationS: Value(durationS),
          questionCount: Value(questions),
          net: Value(net),
        ),
      );
    }

    test('dailyMinutes hedefi kayıt sonrası doluyor', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.dailyMinutes,
        target: 240,
      );
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 120, reason: '7200 sn = 120 dk');
      expect(g.status, GoalStatus.active, reason: '240 hedefine ulaşılmadı');
    });

    test('hedefe ulaşılınca durum completed oluyor', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.dailyQuestions,
        target: 80,
      );
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 80);
      expect(g.status, GoalStatus.completed);
    });

    test('ders bazlı hedef YALNIZCA o dersin süresini sayıyor', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.subjectMinutes,
        target: 600,
        subjectId: subjectId,
      );
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 120);
    });

    test('başka derse bağlı hedef bu oturumdan ETKİLENMİYOR', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.subjectMinutes,
        target: 600,
        subjectId: 'sub_yks_2',
      );
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 0);
    });

    test('arşivlenmiş hedef güncellenmiyor', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.dailyMinutes,
        target: 240,
      );
      await db.goalDao.setStatus('g1', GoalStatus.archived);
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 0, reason: 'yalnızca active hedefler');
    });

    test('streak hedefi kayıt sonrası streak değerini alıyor', () async {
      await db.goalDao.createGoal(
        id: 'g1',
        type: GoalType.streak,
        target: 7,
      );
      await saveSession();

      final g = (await db.select(db.goals).get()).single;
      expect(g.currentValue, 1, reason: 'ilk çalışma günü');
    });
  });
}
