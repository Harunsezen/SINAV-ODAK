import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../domain/ports/screen_wake_gateway.dart';

/// Gerçek ekran kilidi adaptörü.
class WakelockScreenGateway implements ScreenWakeGateway {
  const WakelockScreenGateway();

  @override
  Future<void> setEnabled({required bool enabled}) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on Object catch (e) {
      debugPrint('Ekran kilidi ayarlanamadı: $e');
    }
  }
}

/// Ekran kilidinin kapalı olduğu durumlar (test, desteklenmeyen platform).
class NoopScreenWakeGateway implements ScreenWakeGateway {
  const NoopScreenWakeGateway();

  @override
  Future<void> setEnabled({required bool enabled}) async {}
}
