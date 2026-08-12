import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/session_schedule.dart';
import '../../domain/ports/session_notifier.dart';

/// Aktif oturumun çizelgesi + kimliği.
typedef ActiveScheduleReader = ({String sessionId, SessionSchedule schedule})?
    Function();

/// **Ön plandayken kullanıcıya sistem bildirimi gitmez.**
///
/// Ürün kuralı (koordinatör vetosu, v1.0.2): *"Ön plandayken kullanıcı asla
/// ana ekrana atılmaz."* Bunun bildirim tarafındaki karşılığı: kullanıcı
/// zaten ekrana bakıyorsa blok/mola bitişi **uygulama içinde** anlatılır,
/// sistem bildirimiyle değil.
///
/// **Neden ayrı bir bekçi gerekiyor:** sayaç `Timer` tabanlı değil; blok ve
/// mola bitişleri oturum başlarken **mutlak zamana** kuruluyor
/// (`AndroidScheduleMode.exactAllowWhileIdle`). Bu bildirimler kurulduktan
/// sonra uygulamanın ön planda olup olmadığından habersiz tetiklenir —
/// yani kullanıcı ekrana bakarken de `category: alarm`, `Importance.high`
/// bir bildirim düşer. Kuralı uygulamanın tek yolu, ön plana geçildiğinde
/// bekleyen bildirimleri **iptal etmek**, arka plana geçildiğinde
/// **yeniden kurmak**.
///
/// Doğruluk buna bağlı DEĞİL: hangi blokta olunduğu daima
/// `ScheduleResolver.resolve(now)` ile hesaplanıyor. Bildirimler yalnızca
/// haber verme kanalı; iptal/yeniden kurma sayacı etkilemez.
class ForegroundNotificationGuard with WidgetsBindingObserver {
  ForegroundNotificationGuard({
    required this.notifier,
    required this.readActive,
  });

  final SessionNotifier notifier;
  final ActiveScheduleReader readActive;

  bool _started = false;

  /// Test gözlemi için: en son hangi kanalın açık olduğunu bildirir.
  bool get isForeground => _isForeground;
  bool _isForeground = true;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _isForeground = true;
        unawaited(_silence());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _isForeground = false;
        unawaited(_restore());
      case AppLifecycleState.inactive:
        // Bildirim paneli, gelen arama, uygulama değiştirici önizlemesi.
        // Kullanıcı hâlâ uygulamada sayılır — kanal değişmez.
        break;
    }
  }

  /// Ön plan: bekleyen oturum bildirimlerini iptal et.
  Future<void> _silence() async {
    final active = readActive();
    if (active == null) return;
    await notifier.cancelAll(active.sessionId);
  }

  /// Arka plan: blok/mola bitişlerini yeniden kur.
  ///
  /// `NotificationPlanner` geçmiş sınırları atladığı için yalnızca
  /// gelecekteki bitişler kurulur.
  Future<void> _restore() async {
    final active = readActive();
    if (active == null) return;
    await notifier.scheduleFor(
      sessionId: active.sessionId,
      schedule: active.schedule,
    );
  }
}
