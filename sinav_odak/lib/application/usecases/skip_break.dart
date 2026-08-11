import '../../core/errors/failures.dart';
import '../../data/local/database.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/services/schedule_modifier.dart';
import '../schedule_writer.dart';

/// Molayı erken bitirir ve sonraki tüm blokları öne çeker.
class SkipBreakUseCase {
  const SkipBreakUseCase(this._db, this._writer);

  final AppDatabase _db;
  final ScheduleWriter _writer;

  /// Yeni çizelgeyi döner.
  ///
  /// Mola henüz başlamadıysa veya zaten bittiyse [ValidationFailure] fırlar.
  /// UI tam bitiş saniyesinde butona basılırsa bu hatayı yakalayıp sessizce
  /// yutmalı — resolver zaten sonraki bloğa geçmiş olur.
  Future<SessionSchedule> call({
    required String sessionId,
    required int breakBlockIndex,
    required int nowMs,
  }) async {
    final session = await _db.sessionDao.findById(sessionId);
    if (session == null) {
      throw const SessionFailure('Oturum bulunamadı.');
    }

    final current = ScheduleWriter.parse(session);
    final updated = ScheduleModifier.skipBreak(current, breakBlockIndex, nowMs);

    await _writer.rewrite(sessionId: sessionId, schedule: updated);
    return updated;
  }
}
