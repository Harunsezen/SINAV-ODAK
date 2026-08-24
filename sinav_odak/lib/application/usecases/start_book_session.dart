import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/date_key.dart';
import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/book_input.dart';

/// KİTAP OKUMA oturumunu başlatır (v1.3).
///
/// **Bildirim ve yaşam döngüsü izleyicisi YOK.** İkisi de çalışma
/// oturumunun odak skoruna hizmet ediyor; kitap okumada odak skoru
/// hesaplanmıyor ("uygulamadan kaç kez çıktın" ölçüsü, telefonu bırakıp
/// kâğıt kitap okuyan öğrenci için anlamsız — ve onu cezalandırırdı).
///
/// **Sayaç duvar saatiyle işliyor**, `Timer` ile değil: başlangıç anı
/// yazılıyor, kalan/geçen süre her karede `now - startedAt` ile yeniden
/// hesaplanıyor. Uygulama kapansa da süre doğru kalıyor — çalışma
/// oturumundaki `ScheduleResolver` ile aynı ilke.
class StartBookSessionUseCase {
  const StartBookSessionUseCase(this._db);

  final AppDatabase _db;

  /// [durationS] süre modunda zorunlu, [pageTarget] sayfa modunda.
  ///
  /// Aynı anda **hiçbir** oturum açık olamaz: çalışma oturumu sürerken
  /// kitap oturumu başlatılırsa iki sayaç birden işler ve ikisi de aynı
  /// dakikaları kendi hanesine yazardı.
  Future<String> call({
    required String sessionId,
    required BookMode mode,
    required int nowMs,
    int? durationS,
    int? pageTarget,
  }) async {
    if (await _db.sessionDao.findActiveSession() != null) {
      throw const SessionFailure(
        'Zaten devam eden bir çalışma oturumu var. Önce onu bitir.',
      );
    }
    if (await _db.bookDao.findActive() != null) {
      throw const SessionFailure(
        'Zaten devam eden bir okuma oturumu var. Önce onu bitir.',
      );
    }

    switch (mode) {
      case BookMode.duration:
        final seconds = durationS ?? 0;
        if (seconds < BookInput.minDurationMinutes * 60 ||
            seconds > BookInput.maxReadingS) {
          throw const ValidationFailure(
            'Okuma süresi geçersiz.',
            field: 'durationS',
          );
        }
      case BookMode.pageTarget:
        final target = pageTarget ?? 0;
        if (target < BookInput.minPages || target > BookInput.maxPages) {
          throw const ValidationFailure(
            'Sayfa hedefi geçersiz.',
            field: 'pageTarget',
          );
        }
    }

    await _db.bookDao.insertSession(
      BookSessionsCompanion.insert(
        id: sessionId,
        // Gece yarısını aşan okuma BAŞLADIĞI güne yazılır (çalışma
        // oturumuyla aynı kural, G9).
        dateKey: dateKeyOfMs(nowMs),
        mode: mode,
        startedAt: nowMs,
        // Karşı modun alanı `null` KALIYOR: sayfa modunda uydurma bir
        // süre yazmak, "planlanan 30 dk" diye olmayan bir hedef üretirdi.
        plannedDurationS: Value(mode == BookMode.duration ? durationS : null),
        pageTarget: Value(mode == BookMode.pageTarget ? pageTarget : null),
        status: SessionStatus.running,
      ),
    );

    return sessionId;
  }
}
