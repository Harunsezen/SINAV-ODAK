import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../data/local/database.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/entities/enums.dart';
import '../../domain/ports/session_activity_tracker.dart';
import '../../domain/ports/session_notifier.dart';
import '../../domain/services/focus_score_calculator.dart';
import '../../domain/services/net_calculator.dart';
import '../schedule_writer.dart';

/// Oturumu kapatır: süre, net ve odak skorunu hesaplar, kaydeder.
class FinishSessionUseCase {
  const FinishSessionUseCase(
    this._db,
    this._repo,
    this._notifier,
    this._tracker,
  );

  final AppDatabase _db;
  final SessionRepository _repo;
  final SessionNotifier _notifier;
  final SessionActivityTracker _tracker;

  /// [early] `true` ise kullanıcı "Oturumu Bitir" dedi (onay UI'da alınır).
  ///
  /// Süre hesabı iki modda farklı:
  /// - Normal tamamlanma: planlanan çalışma süresi
  /// - Erken bitirme: çizelgeye göre [nowMs]'e kadar GERÇEKLEŞEN süre
  Future<int?> call({
    required String sessionId,
    required int nowMs,
    required bool early,
    int questionCount = 0,
    int correctCount = 0,
    int wrongCount = 0,
    int emptyCount = 0,
    int? mood,
    String? note,
  }) async {
    // Son dışarıda kalma dilimi de yazılsın diye ÖNCE izlemeyi durdur.
    await _tracker.detach();

    final session = await _db.sessionDao.findById(sessionId);
    if (session == null) {
      throw const SessionFailure('Oturum bulunamadı.');
    }

    final schedule = ScheduleWriter.parse(session);
    final elapsed = ScheduleWriter.elapsedOf(schedule, nowMs);
    final breaks = ScheduleWriter.breakTotalsOf(schedule);

    final status =
        early ? SessionStatus.earlyFinished : SessionStatus.completed;
    final actualDurationS = early ? elapsed.studyS : schedule.totalStudyS;
    final totalBreakS = early ? elapsed.breakS : schedule.totalBreakS;

    // Net katsayısı kullanıcı ayarından gelir (YKS 4, bazı sınavlarda 3).
    final settings = await _db.settingsDao.read();
    final net = NetCalculator.calculate(
      questionCount: questionCount,
      correctCount: correctCount,
      wrongCount: wrongCount,
      emptyCount: emptyCount,
      coefficient: settings.netPenaltyCoefficient,
      actualDurationS: actualDurationS,
    );

    // foregroundS ÖLÇÜLMEZ, HESAPLANIR: LifecycleTracker yalnızca awayS
    // yazar. Doğrudan ölçüm, uygulama öldürüldüğünde son önplan dilimini
    // kaybederdi; bu hesap ise zarif bozulur.
    final foregroundS =
        (actualDurationS - session.awayS).clamp(0, actualDurationS);

    final focusScore = FocusScoreCalculator.calculate(
      status: status,
      plannedDurationS: session.plannedDurationS,
      actualDurationS: actualDurationS,
      foregroundS: foregroundS,
      exitCount: session.exitCount,
      extendedBreakS: breaks.extendedS,
      totalPlannedBreakS: breaks.plannedS,
    );

    await _repo.save(
      sessionId: sessionId,
      dateKey: session.dateKey,
      subjectId: session.subjectId,
      topicId: session.topicId,
      wrongCount: wrongCount,
      wrongNote: note,
      patch: StudySessionsCompanion(
        status: Value(status),
        endedAt: Value(nowMs),
        actualDurationS: Value(actualDurationS),
        totalBreakS: Value(totalBreakS),
        questionCount: Value(questionCount),
        correctCount: Value(correctCount),
        wrongCount: Value(wrongCount),
        emptyCount: Value(emptyCount),
        net: Value(net.net),
        focusScore: Value(focusScore),
        foregroundS: Value(foregroundS),
        mood: Value(mood),
        note: Value(note),
      ),
    );

    await _notifier.cancelAll(sessionId);
    return focusScore;
  }
}
