import '../../core/errors/failures.dart';
import '../../data/local/database.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/services/schedule_modifier.dart';
import '../schedule_writer.dart';

/// Molayı uzatır ve sonraki tüm blokları kaydırır.
class ExtendBreakUseCase {
  const ExtendBreakUseCase(this._db, this._writer);

  final AppDatabase _db;
  final ScheduleWriter _writer;

  /// Varsayılan uzatma adımı: +5 dakika. Toplam limit 600 sn
  /// ([ScheduleModifier.maxTotalExtensionS]) ve domain tarafında zorlanır.
  static const int defaultStepS = 300;

  /// Yeni çizelgeyi döner. Limit aşımında [PlanFailure],
  /// geçersiz indekste [ValidationFailure] fırlar.
  Future<SessionSchedule> call({
    required String sessionId,
    required int breakBlockIndex,
    int addS = defaultStepS,
  }) async {
    final session = await _db.sessionDao.findById(sessionId);
    if (session == null) {
      throw const SessionFailure('Oturum bulunamadı.');
    }

    final current = ScheduleWriter.parse(session);
    // Doğrulamanın tamamı domain'de: tip, indeks, limit, atlanmışlık.
    final updated =
        ScheduleModifier.extendBreak(current, breakBlockIndex, addS);

    await _writer.rewrite(sessionId: sessionId, schedule: updated);
    return updated;
  }
}
