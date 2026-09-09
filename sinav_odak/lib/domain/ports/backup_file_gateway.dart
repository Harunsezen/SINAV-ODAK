/// Yedek dosyası seçme kapısı (v1.3).
///
/// **Neden port:** dosya seçici platform kanalı kullanıyor; testte
/// çağrılırsa ya çöküyor ya hiç tamamlanmayan bir Future dönüyor.
/// Port sayesinde geri yükleme akışı, gerçek dosya sistemi olmadan
/// baştan sona test edilebiliyor — `ShareGateway` ile aynı desen.
///
/// Ayrıca yalıtım: dosya seçici paketi tek bir adaptör dosyasında
/// duruyor. Paket sorun çıkarırsa uygulamanın geri kalanı etkilenmiyor.
abstract interface class BackupFileGateway {
  /// Kullanıcıya dosya seçtirir ve **içeriğini metin olarak** döner.
  ///
  /// `null` üç ayrı durumu birden anlatıyor ve üçü de hata değil:
  /// kullanıcı iptal etti · dosya okunamadı · izin verilmedi.
  /// Arayüz `null` gelince sessizce duruyor.
  Future<String?> pickBackupText();
}

/// Varsayılan: hiçbir şey seçmez.
///
/// Testler ve platform kanalına dokunmaması gereken her yer bunu
/// kullanıyor; `main()` gerçek cihazda gerçek adaptörle override ediyor.
class NoopBackupFileGateway implements BackupFileGateway {
  const NoopBackupFileGateway();

  @override
  Future<String?> pickBackupText() async => null;
}
