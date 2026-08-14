/// Dosya paylaşma kapısı.
///
/// `share_plus` ve `path_provider` platform kanalı kullanıyor; testte
/// çağrıldıklarında ya çöküyor ya da hiç tamamlanmayan bir Future dönüyor.
/// Port'un varlığı, "dışa aktarma" akışının gerçek dosya sistemi olmadan
/// baştan sona test edilebilmesini sağlıyor.
abstract interface class ShareGateway {
  /// [content]'i [fileName] adıyla geçici bir dosyaya yazar ve paylaşım
  /// sayfasını açar.
  ///
  /// Başarılıysa `true`. Hata durumunda **fırlatmaz**, `false` döner:
  /// dışa aktarma başarısız diye ayarlar ekranı çökmemeli.
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  });

  /// İkili içeriği (PDF gibi) paylaşır (FAZ 3.1).
  ///
  /// Metin sürümünden ayrı: PDF baytları `utf8` ile yazılamaz — yazılırsa
  /// dosya bozulur ve okuyucu açamaz.
  Future<bool> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  });
}
