// DOĞRULANMADI — flutter test/analyze bekliyor.
// Gerekli komutlar (sırayla):
//   dart run build_runner build --delete-conflicting-outputs
//   flutter analyze
//   flutter test
//
// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import '../entities/session_schedule.dart';

/// Çizelge bildirimlerinin domain sözleşmesi (port).
///
/// **Neden port?** Bildirim gönderme bir altyapı işidir ama çizelge
/// kurulumunun ayrılmaz parçasıdır: oturum başlarken blok/mola bitiş
/// bildirimleri OS'a teslim edilmezse, iOS arka planda kod çalıştıramadığı
/// için kullanıcı mola bittiğini asla öğrenemez.
///
/// Bu arayüz sayesinde `StartSessionUseCase` `flutter_local_notifications`
/// paketini hiç tanımadan bildirim kurabilir; testlerde no-op implementasyon
/// kullanılır.
abstract interface class SessionNotifier {
  /// Çizelgedeki her blok ve mola bitişi için bildirim kurar.
  ///
  /// Uygulama öldürülse bile bildirimler OS tarafında kalır. Bu yüzden
  /// çizelge değiştiğinde (mola uzatma/atlama) önce [cancelAll] çağrılıp
  /// yeniden kurulmalıdır.
  Future<void> scheduleFor({
    required String sessionId,
    required SessionSchedule schedule,
  });

  /// Bir oturuma ait tüm bekleyen bildirimleri iptal eder.
  Future<void> cancelAll(String sessionId);

  /// Bildirim izni verilmiş mi? İzin yoksa akış DURMAZ, sessizce devam eder.
  Future<bool> hasPermission();
}
