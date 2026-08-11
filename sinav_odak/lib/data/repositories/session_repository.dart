import 'package:drift/drift.dart';

import '../../core/utils/date_key.dart';
import '../../domain/entities/enums.dart';
import '../../core/utils/time.dart';
import '../../domain/services/achievement_calculator.dart';
import '../../domain/services/goal_progress_calculator.dart';
import '../../domain/services/streak_calculator.dart';
import '../local/database.dart';

/// Oturum yazma işlemlerinin TEK giriş noktası.
///
/// Neden var: DAO'lar tek tablo bilir. Bir oturum kaydedildiğinde üç şey
/// birlikte olmak zorunda — oturum yazılır, yanlış defteri güncellenir,
/// günlük özet yeniden hesaplanır. Bu orkestrasyon hiçbir yerde yoktu ve
/// `daily_stats` pratikte hep boş kalıyordu (istatistik ekranı sıfır
/// gösteriyordu).
class SessionRepository {
  SessionRepository(this._db);
  final AppDatabase _db;

  /// Oturum sonu formundan çağrılır.
  ///
  /// [previousDateKey] yalnızca geçmiş oturum düzenlemede (v1.1) dolu olur;
  /// tarih değiştiyse eski günün özeti de yeniden hesaplanmalı.
  Future<void> save({
    required String sessionId,
    required StudySessionsCompanion patch,
    required String dateKey,
    required String subjectId,
    String? topicId,
    required int wrongCount,
    String? wrongNote,
    String? previousDateKey,
  }) async {
    await _db.transaction(() async {
      await _db.sessionDao.patchSession(sessionId, patch);

      if (wrongCount > 0) {
        await _db.wrongItemDao.upsertFromSession(
          id: 'wr_$sessionId',
          sessionId: sessionId,
          subjectId: subjectId,
          topicId: topicId,
          wrongCount: wrongCount,
          note: wrongNote,
        );
      } else {
        // wrongCount 0'a düşerse hayalet kayıt kalmasın.
        await _db.wrongItemDao.deleteAutoFor(sessionId);
      }

      await _db.statsDao.recomputeDay(dateKey);
      if (previousDateKey != null && previousDateKey != dateKey) {
        await _db.statsDao.recomputeDay(previousDateKey);
      }

      // FAZ 5: streak ve hedef ilerlemesi de KAYDET yolundan geçiyor.
      // Ayrı bir servise bırakılsaydı, oturumu yazan ikinci bir kod yolu
      // açıldığında sessizce atlanırdı — `daily_stats`'ın başına gelen buydu.
      await recomputeStreak(dateKey);
      await recomputeGoals(dateKey);
      // FAZ 7B: rozetler de AYNI yoldan. Ayrı bir tetikleyiciye bırakmak,
      // oturum yazan ikinci bir kod yolu açıldığında sessizce atlanması
      // demekti — `daily_stats`, streak ve goals'ın başına gelen buydu.
      await recomputeAchievements(dateKey);
    });
  }

  /// Ardışık çalışma günü sayacını günceller.
  ///
  /// Şemadaki `currentStreak` / `longestStreak` / `lastStudyDate` kolonları
  /// Adım 1'den beri duruyordu ama **yazan kod yoktu**; üçü de hep 0/null
  /// kalıyordu. Hesap saf (`StreakCalculator`), burada yalnızca okuma-yazma
  /// var.
  Future<void> recomputeStreak(String dateKey) async {
    final s = await _db.settingsDao.ensure();
    final next = StreakCalculator.onStudyDay(
      studyDate: dateKey,
      lastStudyDate: s.lastStudyDate,
      currentStreak: s.currentStreak,
      longestStreak: s.longestStreak,
    );
    await _db.settingsDao.patchSettings(
      UserSettingsCompanion(
        currentStreak: Value(next.currentStreak),
        longestStreak: Value(next.longestStreak),
        lastStudyDate: Value(next.lastStudyDate),
      ),
    );
  }

  /// Aktif hedeflerin `currentValue` alanını günceller.
  ///
  /// Kolon şemada vardı ama hiçbir kod yazmıyordu: kullanıcı hedef
  /// oluşturuyor, ilerleme sonsuza kadar 0 kalıyordu. Hedefe ulaşıldıysa
  /// durum `completed`'a çekilir.
  Future<void> recomputeGoals(String dateKey) async {
    final active = await (_db.select(_db.goals)
          ..where((t) => t.status.equalsValue(GoalStatus.active)))
        .get();
    if (active.isEmpty) return;

    final day = dateKeyToLocal(dateKey);
    final weekStart = startOfWeek(day);
    final settings = await _db.settingsDao.ensure();

    final dayStats = await _db.statsDao.summaryFor(day, day);
    final weekStats = await _db.statsDao.summaryFor(weekStart, day);
    final breakdown = await _db.statsDao.subjectBreakdown(day, day);

    for (final g in active) {
      // Ders bazlı hedefte yalnızca o dersin süresi sayılır.
      var subjectStudyS = 0;
      if (g.subjectId != null) {
        for (final row in breakdown) {
          if (row.subjectId == g.subjectId) subjectStudyS = row.studyS;
        }
      }

      final value = GoalProgressCalculator.valueFor(
        g.type,
        GoalMetrics(
          dayStudyS: dayStats.totalStudyS,
          dayQuestions: dayStats.questionCount,
          dayNet: dayStats.net,
          weekStudyS: weekStats.totalStudyS,
          weekQuestions: weekStats.questionCount,
          subjectStudyS: subjectStudyS,
          currentStreak: settings.currentStreak,
        ),
      );

      await _db.goalDao.setProgress(g.id, value);
      if (GoalProgressCalculator.isReached(value, g.targetValue)) {
        await _db.goalDao.setStatus(g.id, GoalStatus.completed);
      }
    }
  }

  /// Kazanılan rozetleri açar.
  ///
  /// `achievements` tablosu Adım 1'den beri şemadaydı ama **yazan kod
  /// yoktu**; tablo sonsuza kadar boş kalıyordu.
  ///
  /// **Rozetler geri ALINMAZ**: hesap yalnızca "yeni açılanları" döner.
  /// Seri bozulunca kazanılmış rozeti silmek cezalandırma olurdu.
  ///
  /// Dönen değer bu çağrıda AÇILAN rozet kodlarıdır (tebrik ekranı
  /// kullanabilir).
  Future<Set<String>> recomputeAchievements(String dateKey) async {
    final day = dateKeyToLocal(dateKey);
    final settings = await _db.settingsDao.ensure();
    final totals = await _db.achievementDao.lifetimeTotals();
    final dayStats = await _db.statsDao.summaryFor(day, day);
    final already = await _db.achievementDao.unlockedCodes();

    // O günün SON oturumunun başlangıç saati — gece/sabah rozetleri için.
    final daySessions = await _db.sessionDao.rangeSessions(day, day);
    final startHour = daySessions.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(daySessions.last.startedAt).hour;

    final newly = AchievementCalculator.evaluate(
      already: already,
      metrics: AchievementMetrics(
        currentStreak: settings.currentStreak,
        longestStreak: settings.longestStreak,
        totalSessions: totals.sessionCount,
        totalStudyS: totals.studyS,
        totalQuestions: totals.questionCount,
        daySessionCount: dayStats.sessionCount,
        dayStudyS: dayStats.totalStudyS,
        dayFocusScore: dayStats.avgFocusScore,
        startHour: startHour,
      ),
    );

    for (final code in newly) {
      // Açılış anı: rozetin kazanıldığı GÜN değil, kaydın yazıldığı an.
      // Gün anahtarı yerel gün; rozet listesi kronolojik sıralanıyor.
      await _db.achievementDao.unlock(code: code, unlockedAtMs: nowMs());
    }
    return newly;
  }

  Future<void> delete(String sessionId) async {
    final s = await _db.sessionDao.findById(sessionId);
    if (s == null) return;
    await _db.transaction(() async {
      // Yanlış kaydı yetim kalmasın: manuel kayda dönüşsün.
      await _db.wrongItemDao.detachFromSession(sessionId);
      await _db.sessionDao.deleteSession(sessionId);
      await _db.statsDao.recomputeDay(s.dateKey);
    });
  }

  /// [focusScore] `RecoveryService` tarafından hesaplanıp geçilir.
  Future<void> markInterrupted({
    required String sessionId,
    required int actualDurationS,
    required int totalBreakS,
    required int endedAt,
    int? focusScore,
    int? foregroundS,
  }) async {
    final s = await _db.sessionDao.findById(sessionId);
    if (s == null) return;
    await _db.transaction(() async {
      await _db.sessionDao.markInterrupted(
        id: sessionId,
        actualDurationS: actualDurationS,
        totalBreakS: totalBreakS,
        endedAt: endedAt,
        focusScore: focusScore,
        foregroundS: foregroundS,
      );
      await _db.statsDao.recomputeDay(s.dateKey);
    });
  }

  /// Veri bozulması veya içe aktarma sonrası tüm günleri yeniden hesaplar.
  /// `daily_stats` bozulduğunda başka kurtarma yolu yok.
  Future<void> recomputeAll() async {
    final rows = await _db.select(_db.studySessions).get();
    final days = rows.map((r) => r.dateKey).toSet();
    for (final d in days) {
      await _db.statsDao.recomputeDay(d);
    }
  }
}
