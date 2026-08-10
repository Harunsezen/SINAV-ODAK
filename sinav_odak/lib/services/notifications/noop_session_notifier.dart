// DOĞRULANMADI — flutter test/analyze bekliyor.
// Gerekli komutlar (sırayla):
//   dart run build_runner build --delete-conflicting-outputs
//   flutter analyze
//   flutter test

import '../../domain/entities/session_schedule.dart';
import '../../domain/ports/session_notifier.dart';

/// Hiçbir şey yapmayan bildirim implementasyonu.
///
/// Adım 4 iskeletinde gerçek `flutter_local_notifications` implementasyonu
/// yerine bu kullanılır. Böylece run akışı, bildirim katmanı yazılmadan
/// uçtan uca test edilebilir.
///
/// **Gerçek implementasyon geldiğinde gereksinimler:**
/// - `tz.initializeTimeZones()` + `FlutterTimezone.getLocalTimezone()`
/// - Android 13+ `POST_NOTIFICATIONS` runtime izni
/// - Android 12+ `USE_EXACT_ALARM` (timer uygulaması olarak Play politikasına
///   uygun, Console'da gerekçe yazılmalı)
/// - `AndroidScheduleMode.exactAllowWhileIdle`
/// - `RECEIVE_BOOT_COMPLETED` → yeniden başlatma sonrası kurulum
/// - Android'de `coreLibraryDesugaringEnabled true`
class NoopSessionNotifier implements SessionNotifier {
  const NoopSessionNotifier();

  @override
  Future<void> scheduleFor({
    required String sessionId,
    required SessionSchedule schedule,
  }) async {}

  @override
  Future<void> cancelAll(String sessionId) async {}

  @override
  Future<bool> hasPermission() async => false;
}
