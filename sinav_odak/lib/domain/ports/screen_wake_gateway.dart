/// Ekranı açık tutma kapısı.
///
/// `wakelock_plus` platform kanalı kullanıyor; testte doğrudan çağrılırsa
/// `MissingPluginException` fırlatıyor. Port sayesinde "çalışma sırasında
/// ekran açık kalsın" davranışı gerçek cihaz olmadan test edilebiliyor.
abstract interface class ScreenWakeGateway {
  /// Ekranın kapanmasını engeller / serbest bırakır.
  ///
  /// Hata durumunda **fırlatmaz**: ekran kilidi bir kolaylıktır, oturumun
  /// doğruluğu ona bağlı değildir.
  Future<void> setEnabled({required bool enabled});
}
