import 'package:drift/drift.dart';

import '../../core/errors/failures.dart';
import '../../data/local/database.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/book_input.dart';

/// Okuma oturumunu kapatır ve kaydeder (v1.3).
///
/// **Oturumun kaydedildiği TEK yer.** "Bitti" düğmesi ve "Emin misin?"
/// onayı oturumu KAPATMAZ; yalnızca formu açar. Kayıt formun KAYDET
/// düğmesinden geçiyor — çalışma oturumundaki KARAR D1'in aynısı.
class FinishBookSessionUseCase {
  const FinishBookSessionUseCase(this._db, this._repo);

  final AppDatabase _db;
  final SessionRepository _repo;

  /// [nowMs] okumanın bittiği an — formun AÇILDIĞI an, kaydete basıldığı
  /// an değil. Formu doldurma süresi okuma süresine eklenmemeli.
  ///
  /// [pagesRead] kullanıcının bildirdiği sayfa; ölçülmüyor, soruluyor.
  /// [bookTitle] boş bırakılabilir — `null` saklanır.
  Future<void> call({
    required String sessionId,
    required int nowMs,
    required int pagesRead,
    String? bookTitle,
  }) async {
    final session = await _db.bookDao.findById(sessionId);
    if (session == null) {
      throw const SessionFailure('Okuma oturumu bulunamadı.');
    }

    final durationS = measuredDurationS(session, nowMs);

    // Süre modunda süre dolduysa "tamamlandı", erken bitirildiyse
    // "erken bitirildi". Sayfa modunda ölçü sayfa: hedefe ulaşıldıysa
    // tamamlandı. Durum yalnızca kayıt/raporlama için — ikisi de
    // toplamlara AYNI şekilde giriyor, biri diğerinden az sayılmıyor.
    final reached = switch (session.mode) {
      BookMode.duration => durationS >= (session.plannedDurationS ?? 0),
      BookMode.pageTarget => pagesRead >= (session.pageTarget ?? 0),
    };

    await _repo.saveBookSession(
      sessionId: sessionId,
      dateKey: session.dateKey,
      patch: BookSessionsCompanion(
        status: Value(
          reached ? SessionStatus.completed : SessionStatus.earlyFinished,
        ),
        endedAt: Value(nowMs),
        actualDurationS: Value(durationS),
        pagesRead: Value(BookInput.clampPagesRead(pagesRead)),
        bookTitle: Value(BookInput.normalizeTitle(bookTitle)),
      ),
    );
  }

  /// Kaydedilecek okuma süresi (saniye).
  ///
  /// İki tavan var ve ikisi de gerekli:
  /// - **Süre modunda planlanan süre**: sayaç dolduktan sonra uygulama
  ///   kapalı kaldıysa geçen zaman okuma sayılamaz — alarm çaldığında
  ///   okuma bitmişti.
  /// - **[BookInput.maxReadingS]**: sayfa modunda doğal bir son yok;
  ///   sayacı açık unutan kullanıcı "23 saat okudum" kaydetmesin.
  ///
  /// `static` ve görünür: oturum sonu formu aynı sayıyı göstermek için
  /// bunu çağırıyor. İki ayrı hesap yazılsaydı biri değiştiğinde diğeri
  /// sessizce yanlış kalırdı.
  static int measuredDurationS(BookSession session, int nowMs) {
    final elapsed = ((nowMs - session.startedAt) ~/ 1000).clamp(0, 1 << 31);
    final planned = session.plannedDurationS;
    final bounded =
        planned == null ? elapsed : (elapsed > planned ? planned : elapsed);
    return BookInput.capReadingS(bounded);
  }
}
