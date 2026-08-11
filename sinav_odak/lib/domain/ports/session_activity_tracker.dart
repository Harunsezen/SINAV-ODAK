/// Oturum boyunca kullanıcının uygulamada kalıp kalmadığını ölçen bileşenin
/// domain sözleşmesi.
///
/// **Neden port?** Ölçüm `WidgetsBindingObserver` gerektirir (Flutter), ama
/// oturum başlatma/bitirme use-case'leri bu ayrıntıyı bilmemeli. Bu arayüz
/// sayesinde use-case'ler Flutter'ı hiç tanımadan izlemeyi başlatıp
/// durdurabilir; testlerde no-op implementasyon kullanılır.
///
/// **Kritik:** Bu bileşen oturum state'ini İLERLETMEZ. Hangi blokta
/// olunduğu daima `ScheduleResolver.resolve(now)` ile belirlenir; burada
/// yalnızca sayaç yazılır.
abstract interface class SessionActivityTracker {
  /// Oturum başladığında izlemeyi başlatır.
  void attach(String sessionId);

  /// Oturum bittiğinde izlemeyi durdurur ve son dilimi yazar.
  Future<void> detach();
}
