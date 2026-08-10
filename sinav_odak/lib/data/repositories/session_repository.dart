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
    });
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
