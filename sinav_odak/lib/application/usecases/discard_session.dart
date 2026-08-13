import '../../data/local/daos/session_dao.dart';
import '../../domain/ports/session_activity_tracker.dart';
import '../../domain/ports/session_notifier.dart';

/// Aktif oturumu **kaydetmeden** siler (v1.1 / FAZ 1.3).
///
/// v1.0'da "Bitir" tek yolu gösteriyordu: özet formuna git ve kaydet.
/// Yanlışlıkla başlatılan ya da beş dakikada terk edilen bir oturumun
/// istatistiklere karışmaması için hiçbir kapı yoktu; kullanıcı ya sahte
/// bir kayıt bırakıyor ya da ekranda mahsur kalıyordu.
///
/// **Neden ayrı use-case:** silme üç şeyi birlikte yapmak zorunda —
/// bildirimleri iptal et, yaşam döngüsü izleyicisini bırak, satırları sil.
/// Yalnızca `deleteSession` çağrılsaydı oturum giderdi ama bildirimleri
/// OS'ta asılı kalır ve izleyici olmayan bir oturuma yazmaya devam ederdi.
///
/// Sıra önemli: önce dış dünya (bildirim + izleyici), sonra veritabanı.
/// Ters sırada, silme başarılı olup bildirim iptali patlarsa kullanıcı
/// olmayan bir oturumun mola bildirimini alırdı.
class DiscardSessionUseCase {
  const DiscardSessionUseCase(this._dao, this._notifier, this._tracker);

  final SessionDao _dao;
  final SessionNotifier _notifier;
  final SessionActivityTracker _tracker;

  Future<void> call(String sessionId) async {
    await _notifier.cancelAll(sessionId);
    await _tracker.detach();
    // `deleteSession` blokları da siliyor (şemada ON DELETE CASCADE).
    await _dao.deleteSession(sessionId);
  }
}
