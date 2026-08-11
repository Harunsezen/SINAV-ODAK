/// Dokunsal geri bildirim kapısı.
///
/// Platform kanalı gerektirdiği için port arkasında: testte gerçek titreşim
/// çağrısı sessizce yutulur ama **çağrılıp çağrılmadığı** doğrulanabilir.
abstract interface class HapticGateway {
  /// Kayıt gibi tamamlanan bir işlem için orta şiddette geri bildirim.
  Future<void> success();

  /// Rozet açılışı gibi kutlanacak bir an için daha belirgin geri bildirim.
  Future<void> celebrate();
}
