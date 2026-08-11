import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/session_schedule.dart';
import '../../domain/ports/session_notifier.dart';
import '../../domain/services/notification_planner.dart';
import 'notification_service.dart';

/// [SessionNotifier]'ın gerçek implementasyonu.
///
/// Yalnızca **uygular**: hangi bildirimin ne zaman kurulacağına
/// [NotificationPlanner] karar verir (saf Dart, test edilebilir).
///
/// Hiçbir metot hata fırlatmaz. Eklenti yoksa, izin reddedildiyse veya
/// platform çağrısı patlarsa sessizce geçer — oturumun doğruluğu
/// bildirimlere bağlı değildir.
class LocalSessionNotifier implements SessionNotifier {
  LocalSessionNotifier(this._service, {required this.nowMsProvider});

  final NotificationService _service;

  /// Zaman kaynağı dışarıdan verilir; geçmişe bildirim kurulmasın diye.
  final int Function() nowMsProvider;

  @override
  Future<void> scheduleFor({
    required String sessionId,
    required SessionSchedule schedule,
  }) async {
    if (!await _service.initialize()) return;

    final planned = NotificationPlanner.plan(
      sessionId: sessionId,
      schedule: schedule,
      // Geçmiş bloklar atlanır: geçmişe bildirim kurmak anlamsız ve
      // bazı platformlarda hata verir.
      fromMs: nowMsProvider(),
    );

    for (final n in planned) {
      try {
        await _service.plugin.zonedSchedule(
          n.id,
          n.title,
          n.body,
          tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, n.atMs),
          NotificationService.details,
          // Doze modunda bile tam zamanında tetiklenir. Play politikası
          // timer uygulamaları için buna izin veriyor (USE_EXACT_ALARM).
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // Çizelge MUTLAK zaman damgası tutuyor; duvar saati yorumlanmalı.
          // wallClockTime seçilseydi saat dilimi değişiminde bildirim kayardı.
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } on Object catch (e) {
        debugPrint('Bildirim kurulamadı (#${n.id}): $e');
      }
    }
  }

  @override
  Future<void> cancelAll(String sessionId) async {
    if (!_service.isInitialized) return;
    for (final id in NotificationPlanner.idsOf(sessionId)) {
      try {
        await _service.plugin.cancel(id);
      } on Object {
        // Zaten yoksa sorun değil.
      }
    }
  }

  @override
  Future<bool> hasPermission() => _service.hasPermission();
}
