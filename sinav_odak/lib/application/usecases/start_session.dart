import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/date_key.dart';
import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session_schedule.dart';
import '../../domain/ports/session_activity_tracker.dart';
import '../../domain/ports/session_notifier.dart';
import '../schedule_writer.dart';

/// Oturum başlatma orkestrasyonu.
///
/// **Neden `application/`?** Hem domain modelini hem Drift'i kullanıyor;
/// saf domain servisi değil. `domain/usecases/` altına konsaydı
/// "domain'de Drift import yok" kuralı çiğnenirdi — R3'te düzeltilen
/// hatanın aynısı olurdu.
class StartSessionUseCase {
  const StartSessionUseCase(this._db, this._notifier, this._tracker);

  final AppDatabase _db;
  final SessionNotifier _notifier;
  final SessionActivityTracker _tracker;

  /// Çizelgeyi DB'ye yazar, bildirimleri kurar, oturum kimliğini döner.
  Future<String> call({
    required String sessionId,
    required SessionSchedule schedule,
    required String subjectId,
    String? topicId,
    required String activityTypeId,
  }) async {
    // Aynı anda iki `running` oturum olamaz. Şemada kısmi unique index yok,
    // bu yüzden koruma burada: aksi halde ikinci oturum başlatıldığında
    // ilkinin çalışması daily_stats'a hiç yansımıyor.
    final active = await _db.sessionDao.findActiveSession();
    if (active != null) {
      throw const SessionFailure(
        'Zaten devam eden bir oturum var. Önce onu bitir.',
      );
    }

    final startMs = schedule.firstStartMs;

    final session = StudySessionsCompanion.insert(
      id: sessionId,
      // Gece yarısını aşan oturum BAŞLADIĞI güne yazılır.
      dateKey: dateKeyOfMs(startMs),
      startedAt: startMs,
      plannedDurationS: schedule.totalStudyS,
      subjectId: subjectId,
      topicId: Value(topicId),
      activityTypeId: activityTypeId,
      status: SessionStatus.running,
      scheduleJson: jsonEncode(schedule.toJson()),
    );

    // Oturum + bloklar TEK transaction: arada uygulama ölürse çizelgesiz
    // `running` kayıt oluşurdu.
    await _db.sessionDao.createSession(
      session,
      ScheduleWriter.blocksOf(sessionId, schedule),
    );

    // Bildirim kurulumu akışı BEKLETMEZ; izin yoksa oturum yine başlar.
    await _notifier.scheduleFor(sessionId: sessionId, schedule: schedule);

    // Uygulamadan çıkışları ölçmeye başla (odak skorunun presence bileşeni).
    _tracker.attach(sessionId);

    return sessionId;
  }
}
