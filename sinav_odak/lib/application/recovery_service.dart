import '../data/local/database.dart';
import '../data/repositories/session_repository.dart';
import '../domain/entities/enums.dart';
import '../domain/entities/session_state.dart';
import '../domain/services/focus_score_calculator.dart';
import '../domain/services/schedule_resolver.dart';
import 'schedule_writer.dart';

enum RecoveryOutcome {
  /// Yarıda kalmış oturum yok.
  none,

  /// Çizelge hâlâ devam ediyor → kullanıcı /run'a dönmeli.
  resume,

  /// Çizelge bitmiş ama oturum kapanmamış → kaydet/sil sorulmalı.
  needsDecision,

  /// Cihaz saati çizelgenin başlangıcından geriye alınmış.
  clockMovedBack,
}

class RecoveryResult {
  const RecoveryResult(
    this.outcome, {
    this.session,
    this.state,
    this.recoveredStudyS = 0,
  });

  final RecoveryOutcome outcome;
  final StudySession? session;

  /// `resume` ve `clockMovedBack` durumlarında çözümlenmiş state;
  /// UI doğrudan ilgili ekrana gidebilir.
  final SessionState? state;

  /// `needsDecision` durumunda kurtarılan gerçek çalışma süresi (saniye).
  final int recoveredStudyS;

  static const empty = RecoveryResult(RecoveryOutcome.none);
}

/// Açılışta `running` kalmış oturumu değerlendirir.
///
/// Bu yapılmazsa `running` satır kalıcı olarak takılı kalır, kullanıcının
/// çalışması `daily_stats`'a hiç yansımaz ve yeni oturum başlatıldığında
/// iki `running` kayıt oluşur.
class RecoveryService {
  RecoveryService(this._db, this._repo);

  final AppDatabase _db;
  final SessionRepository _repo;

  Future<RecoveryResult> check({required int nowMs}) async {
    final active = await _db.sessionDao.findActiveSession();
    if (active == null) return RecoveryResult.empty;

    // --- Çizelgeyi çöz; bozuksa bloklardan kurtarmaya düş ---
    try {
      final schedule = ScheduleWriter.parse(active);
      final state = ScheduleResolver.resolve(
        sessionId: active.id,
        schedule: schedule,
        nowMs: nowMs,
      );

      return switch (state) {
        SessionInBlock() || SessionInBreak() =>
          RecoveryResult(RecoveryOutcome.resume, session: active, state: state),
        SessionClockMovedBack() => RecoveryResult(
            RecoveryOutcome.clockMovedBack,
            session: active,
            state: state,
          ),
        _ => await _interrupt(active, schedule.blocks.last.endMs, nowMs),
      };
    } on Object {
      // scheduleJson parse edilemedi: session_blocks üzerinden hesapla.
      return _fallbackFromBlocks(active, nowMs);
    }
  }

  /// Çizelge bitmiş oturumu `interrupted` olarak kapatır ve skoru yazar.
  Future<RecoveryResult> _interrupt(
    StudySession active,
    int scheduleEndMs,
    int nowMs,
  ) async {
    final schedule = ScheduleWriter.parse(active);
    final elapsed = ScheduleWriter.elapsedOf(schedule, nowMs);
    final breaks = ScheduleWriter.breakTotalsOf(schedule);

    // foregroundS ve exitCount lifecycle tracker'dan gelir. Yoksa 0'dır ve
    // presence bileşeni 0 puan verir — kurtarılan oturum ~41'i geçemez.
    // Sahte veri üretmek yerine düşük ama DÜRÜST skor yazılır.
    // foregroundS hesaplanır (bkz. FinishSessionUseCase).
    final foregroundS =
        (elapsed.studyS - active.awayS).clamp(0, elapsed.studyS);

    final focusScore = FocusScoreCalculator.calculate(
      status: SessionStatus.interrupted,
      plannedDurationS: active.plannedDurationS,
      actualDurationS: elapsed.studyS,
      foregroundS: foregroundS,
      exitCount: active.exitCount,
      extendedBreakS: breaks.extendedS,
      totalPlannedBreakS: breaks.plannedS,
    );

    await _repo.markInterrupted(
      sessionId: active.id,
      actualDurationS: elapsed.studyS,
      totalBreakS: elapsed.breakS,
      endedAt: scheduleEndMs,
      focusScore: focusScore,
      foregroundS: foregroundS,
    );

    return RecoveryResult(
      RecoveryOutcome.needsDecision,
      session: active,
      recoveredStudyS: elapsed.studyS,
    );
  }

  /// `scheduleJson` bozuksa `session_blocks` tablosundan kurtar.
  Future<RecoveryResult> _fallbackFromBlocks(
    StudySession active,
    int nowMs,
  ) async {
    final blocks = await _db.sessionDao.blocksOf(active.id);
    if (blocks.isEmpty) {
      // Çizelgesiz `running` kayıt: bozuk veri, sessizce temizle.
      await _repo.delete(active.id);
      return RecoveryResult.empty;
    }

    final scheduleEnd = blocks.last.plannedEndAt;
    if (nowMs < scheduleEnd) {
      // Devam ediyor ama state hesaplanamıyor; UI kaldığı yerden gösterir.
      return RecoveryResult(RecoveryOutcome.resume, session: active);
    }

    var studyS = 0;
    var breakS = 0;
    var extendedS = 0;
    var plannedBreakS = 0;
    for (final b in blocks) {
      final elapsedS =
          (nowMs - b.plannedStartAt).clamp(0, b.plannedS * 1000) ~/ 1000;
      if (b.type == BlockType.study) {
        studyS += elapsedS;
      } else {
        breakS += elapsedS;
        extendedS += b.extendedS;
        plannedBreakS += b.plannedS;
      }
    }

    final foregroundS = (studyS - active.awayS).clamp(0, studyS);

    final focusScore = FocusScoreCalculator.calculate(
      status: SessionStatus.interrupted,
      plannedDurationS: active.plannedDurationS,
      actualDurationS: studyS,
      foregroundS: foregroundS,
      exitCount: active.exitCount,
      extendedBreakS: extendedS,
      totalPlannedBreakS: plannedBreakS,
    );

    await _repo.markInterrupted(
      sessionId: active.id,
      actualDurationS: studyS,
      totalBreakS: breakS,
      endedAt: scheduleEnd,
      focusScore: focusScore,
      foregroundS: foregroundS,
    );

    return RecoveryResult(
      RecoveryOutcome.needsDecision,
      session: active,
      recoveredStudyS: studyS,
    );
  }
}
