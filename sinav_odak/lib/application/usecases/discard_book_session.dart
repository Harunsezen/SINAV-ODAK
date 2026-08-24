import '../../data/local/daos/book_dao.dart';

/// Okuma oturumunu **kaydetmeden** siler (v1.3).
///
/// Çalışma oturumundaki "Bitir → Sil" yolunun karşılığı: yanlışlıkla
/// başlatılan bir okuma, istatistiğe ve seriye karışmamalı.
///
/// Çalışma oturumunun aksine iptal edilecek bildirim ve bırakılacak
/// izleyici YOK (okuma oturumu ikisini de kurmuyor), bu yüzden tek iş
/// satırı silmek.
class DiscardBookSessionUseCase {
  const DiscardBookSessionUseCase(this._dao);

  final BookDao _dao;

  Future<void> call(String sessionId) => _dao.deleteSession(sessionId);
}
