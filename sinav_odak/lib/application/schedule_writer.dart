import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/local/database.dart';
import '../domain/entities/session_schedule.dart';
import '../domain/ports/session_notifier.dart';

/// Çizelgenin **iki temsilini** birlikte yazan tek giriş noktası.
///
/// Çizelge iki yerde tutuluyor:
/// - `study_sessions.scheduleJson` → kurtarmanın tek doğruluk kaynağı
/// - `session_blocks` satırları → SQL sorgulanabilirlik
///
/// Bunlardan yalnızca biri güncellenirse kurtarma **yanlış bloktan** devam
/// eder ve hata **sessiz** kalır. Bu yüzden ikisini ayrı ayrı yazan hiçbir
/// kod yolu bırakılmamalı; `StartSession`, `ExtendBreak` ve `SkipBreak`
/// hepsi buradan geçer.
class ScheduleWriter {
  const ScheduleWriter(this._db, this._notifier);

  final AppDatabase _db;
  final SessionNotifier _notifier;

  /// Var olan bir oturumun çizelgesini değiştirir ve bildirimleri yeniler.
  Future<void> rewrite({
    required String sessionId,
    required SessionSchedule schedule,
  }) async {
    await _db.transaction(() async {
      await _db.sessionDao.patchSession(
        sessionId,
        StudySessionsCompanion(
          scheduleJson: Value(jsonEncode(schedule.toJson())),
        ),
      );
      await _db.sessionDao.replaceBlocks(sessionId, blocksOf(sessionId, schedule));
    });

    // Bildirimler mutlak zamana bağlı; çizelge kayınca hepsi yenilenmeli.
    await _notifier.cancelAll(sessionId);
    await _notifier.scheduleFor(sessionId: sessionId, schedule: schedule);
  }

  /// `SessionSchedule` → `session_blocks` satırları.
  static List<SessionBlocksCompanion> blocksOf(
    String sessionId,
    SessionSchedule schedule,
  ) {
    return schedule.blocks
        .map(
          (b) => SessionBlocksCompanion.insert(
            id: '${sessionId}_b${b.index}',
            sessionId: sessionId,
            indexNo: b.index,
            type: b.type,
            plannedStartAt: b.startMs,
            plannedEndAt: b.endMs,
            plannedS: b.seconds,
            wasSkipped: Value(b.skipped),
            extendedS: Value(b.extendedS),
          ),
        )
        .toList(growable: false);
  }

  /// Oturumun `scheduleJson` alanını tipli modele çevirir.
  /// Bozuksa `SessionScheduleCodecException` fırlatır.
  static SessionSchedule parse(StudySession session) =>
      SessionSchedule.fromJson(
        jsonDecode(session.scheduleJson) as Map<String, dynamic>,
      );

  /// Çizelgeye göre [nowMs] anına kadar gerçekleşen süreler.
  ///
  /// Planlanan toplamı yazmak yanlış olur: 10 dakikada çıkan kullanıcıya
  /// 120 dakika kaydedilirdi.
  static ({int studyS, int breakS}) elapsedOf(
    SessionSchedule schedule,
    int nowMs,
  ) {
    var studyS = 0;
    var breakS = 0;
    for (final b in schedule.blocks) {
      final elapsedMs = (nowMs - b.startMs).clamp(0, b.seconds * 1000);
      final elapsedS = elapsedMs ~/ 1000;
      if (b.isStudy) {
        studyS += elapsedS;
      } else {
        breakS += elapsedS;
      }
    }
    return (studyS: studyS, breakS: breakS);
  }

  /// Mola bloklarının uzatma ve planlanan süre toplamları
  /// (odak skorunun mola disiplini bileşeni için).
  static ({int extendedS, int plannedS}) breakTotalsOf(
    SessionSchedule schedule,
  ) {
    var extended = 0;
    var planned = 0;
    for (final b in schedule.breakBlocks) {
      extended += b.extendedS;
      planned += b.seconds;
    }
    return (extendedS: extended, plannedS: planned);
  }
}
