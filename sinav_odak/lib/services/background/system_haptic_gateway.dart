import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/ports/haptic_gateway.dart';

/// Gerçek dokunsal geri bildirim.
///
/// **Kullanıcının titreşim ayarına kapılıdır** — `enabled` false ise hiçbir
/// şey yapmaz. Ayarı yok sayıp titreştirmek, "titreşim kapalı" diyen
/// kullanıcıya yalan söylemek olurdu.
class SystemHapticGateway implements HapticGateway {
  const SystemHapticGateway({required this.enabledReader});

  final bool Function() enabledReader;

  Future<void> _run(Future<void> Function() action) async {
    if (!enabledReader()) return;
    try {
      await action();
    } on Object catch (e) {
      // Titreşim motoru olmayan cihazlar sessizce geçmeli.
      debugPrint('Titreşim başarısız: $e');
    }
  }

  @override
  Future<void> success() => _run(HapticFeedback.mediumImpact);

  @override
  Future<void> celebrate() => _run(HapticFeedback.heavyImpact);
}

/// Titreşimin kapalı olduğu durumlar (test, desteklenmeyen platform).
class NoopHapticGateway implements HapticGateway {
  const NoopHapticGateway();

  @override
  Future<void> success() async {}

  @override
  Future<void> celebrate() async {}
}
