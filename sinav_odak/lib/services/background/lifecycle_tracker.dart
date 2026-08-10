import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../data/local/database.dart';
import '../../domain/ports/session_activity_tracker.dart';

/// Oturum boyunca uygulamadan çıkışları ölçer.
///
/// **Neden gerekli?** "Pause yok" kuralı tek başına disiplini garanti etmez:
/// sayaç duvar saatiyle çalıştığı için kullanıcı uygulamadan çıkıp başka bir
/// şeyle ilgilense de süre işlemeye devam eder. Odak skorunun 35 puanı
/// (`presence` + `exitCount`) bu ölçüme dayanır.
///
/// **Kritik:** Bu sınıf oturum state'ini İLERLETMEZ. Yalnızca `awayS` ve
/// `exitCount` sayaçlarını yazar. Hangi blokta olunduğu daima
/// `ScheduleResolver.resolve(now)` ile belirlenir.
///
/// `foregroundS` burada YAZILMAZ; oturum kapanırken
/// `actualDurationS - awayS` olarak hesaplanır. Doğrudan ölçüm, uygulama
/// öldürüldüğünde son önplan dilimini kaybederdi.
class LifecycleTracker
    with WidgetsBindingObserver
    implements SessionActivityTracker {
  LifecycleTracker(this._db, {required this.nowMsProvider});

  final AppDatabase _db;

  /// Zaman kaynağı dışarıdan verilir; testlerde sabit epoch kullanılır.
  final int Function() nowMsProvider;

  String? _sessionId;
  int? _awayStartedAtMs;

  /// Test gözlemi için: şu an dışarıda mıyız?
  bool get isAway => _awayStartedAtMs != null;

  String? get trackedSessionId => _sessionId;

  @override
  void attach(String sessionId) {
    if (_sessionId != null) return; // zaten izleniyor
    _sessionId = sessionId;
    _awayStartedAtMs = null;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> detach() async {
    if (_sessionId == null) return;
    // Uygulama dışarıdayken oturum bitiyorsa son dilim de yazılmalı.
    await _closeAwayPeriod();
    WidgetsBinding.instance.removeObserver(this);
    _sessionId = null;
    _awayStartedAtMs = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_sessionId == null) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _onLeave();
      case AppLifecycleState.resumed:
        unawaited(_closeAwayPeriod(countAsExit: true));
      case AppLifecycleState.inactive:
        // Bildirim paneli, gelen arama, uygulama değiştirici önizlemesi...
        // Bunlar ÇIKIŞ SAYILMAZ; kullanıcı hâlâ oturumda sayılır.
        break;
    }
  }

  void _onLeave() {
    if (_awayStartedAtMs != null) return; // zaten dışarıda
    _awayStartedAtMs = nowMsProvider();
  }

  /// Dışarıda geçen süreyi DB'ye yazar.
  ///
  /// [countAsExit] yalnızca kullanıcı geri döndüğünde `true` olur; `detach`
  /// sırasında çıkış sayısı artırılmaz.
  Future<void> _closeAwayPeriod({bool countAsExit = false}) async {
    final id = _sessionId;
    final leftAt = _awayStartedAtMs;
    if (id == null || leftAt == null) return;

    _awayStartedAtMs = null;
    final awayS = ((nowMsProvider() - leftAt) ~/ 1000).clamp(0, 1 << 31);

    await _db.sessionDao.bumpAwayStats(
      id: id,
      addAwayS: awayS,
      addForegroundS: 0,
      addExitCount: countAsExit ? 1 : 0,
    );
  }
}

/// Testler ve bildirim/lifecycle katmanı kapalıyken kullanılan boş izleyici.
class NoopActivityTracker implements SessionActivityTracker {
  const NoopActivityTracker();

  @override
  void attach(String sessionId) {}

  @override
  Future<void> detach() async {}
}
