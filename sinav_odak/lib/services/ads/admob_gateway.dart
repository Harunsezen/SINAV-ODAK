import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/ad_config.dart';
import '../../data/local/daos/ad_event_dao.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/ports/ad_gateway.dart';
import '../../domain/services/ad_policy_engine.dart';

/// Gerçek AdMob adaptörü.
///
/// **Politika kontrolü BU SINIFIN İÇİNDEDİR** (ürünün değişmez kuralı).
/// Çağıran katmana bırakılsaydı, yeni bir çağrı yolu açan kişi "çalışma
/// bloğunda tam ekran reklam yok" kuralını sessizce delerdi. Ekranlar
/// politikayı ayrıca sorabilir (boş yer ayırmamak için), ama son söz burada.
///
/// **Hata durumunda sessizce Noop davranır**: yükleme `null`, gösterim
/// `false` döner. Reklam yüklenemediği için akış ASLA beklemez veya çökmez.
///
/// **Geliştirme boyunca yalnızca TEST birim kimlikleri kullanılır.** Kendi
/// reklamına tıklamak hesabı kapattırır; production kimlikleri `--dart-define`
/// ile geçilecek (FAZ 6), koda girmez.
class AdMobGateway implements AdGateway {
  AdMobGateway({
    required AdEventDao eventDao,
    required SessionState Function() stateReader,
    required bool Function() adsEnabledReader,
    required bool Function() personalizedReader,
    required int Function() clock,
  })  : _events = eventDao,
        _state = stateReader,
        _adsEnabled = adsEnabledReader,
        _personalized = personalizedReader,
        _clock = clock;

  final AdEventDao _events;
  final SessionState Function() _state;
  final bool Function() _adsEnabled;

  /// Rıza yoksa reklam yine istenir, sadece kişiselleştirilmeden.
  final bool Function() _personalized;
  final int Function() _clock;

  /// Kurulum SÖZÜ — bir kez başlar, herkes onu bekler.
  ///
  /// v1.5.1'e kadar burada `bool _initialized` vardı ve `initialize()`
  /// **hiçbir yerden çağrılmıyordu**: bayrak sonsuza kadar `false` kalıyor,
  /// her yükleme ilk satırda `return null` yapıyordu. Uygulama AdMob'a tek
  /// bir istek bile göndermedi — panelde "İstekler: 0" tam olarak buydu.
  ///
  /// Bayrak yerine Future tutmanın sebebi: artık çağırmayı unutmak MÜMKÜN
  /// DEĞİL. Her yükleme yolu `_ensureReady()`den geçiyor, ilk çağrı kurulumu
  /// başlatıyor, sonrakiler aynı sözü bekliyor. Yarış da yok: iki ekran aynı
  /// anda banner isterse ikisi de aynı kurulumu bekler.
  Future<bool>? _ready;

  // Birim kimlikleri `AdConfig`'ten gelir: varsayılan TEST, production
  // --dart-define ile. Sabitleri burada tutmak, birinin yanlışlıkla
  // production kimliğini koda yazmasına kapı açardı.

  /// Native kartın görünme gecikmesi: kart aniden belirip göz yormasın.
  static const Duration nativeRevealDelay = Duration(milliseconds: 1200);

  /// Bir reklamın yüklenmesi için beklenecek en uzun süre.
  static const Duration loadTimeout = Duration(seconds: 10);

  /// Reklam isteği. Rıza yoksa `nonPersonalizedAds: true`.
  ///
  /// `const AdRequest()` DEĞİL: kişiselleştirme kararı çalışma anında
  /// okunuyor. Sabit bir istek, rızasız kullanıcıya kişiselleştirilmiş
  /// reklam isterdi.
  AdRequest _request() => AdRequest(nonPersonalizedAds: !_personalized());

  String _unitFor(AdPlacement p) => switch (p.kind) {
        AdKind.banner => AdConfig.bannerUnit,
        AdKind.native => AdConfig.nativeUnit,
        AdKind.interstitial => AdConfig.interstitialUnit,
        AdKind.rewarded => AdConfig.rewardedUnit,
      };

  @override
  Future<void> initialize() => _ensureReady();

  /// SDK hazır mı? Değilse kurar. Çağırmayı unutmak imkânsız — her
  /// yükleme/gösterim yolu buradan geçiyor.
  Future<bool> _ensureReady() => _ready ??= _boot();

  Future<bool> _boot() async {
    try {
      await MobileAds.instance.initialize();
      // TÜM video reklamlar SESSİZ başlar (ürün kuralı): çalışan öğrencinin
      // kulağına habersiz ses gitmez.
      await MobileAds.instance.setAppMuted(true);
      await MobileAds.instance.setAppVolume(0);
      return true;
    } on Object catch (e) {
      // Reklam altyapısı kurulamadıysa uygulama yine çalışır.
      debugPrint('AdMobGateway.initialize başarısız: $e');
      // Sonraki denemede yeniden kurulabilsin: kalıcı olarak ölü kalmasın.
      _ready = null;
      return false;
    }
  }

  /// Politika kapısı — her gösterim/yükleme buradan geçer.
  Future<bool> _allowed(AdPlacement placement) async {
    final state = _state();
    return AdPolicyEngine.allows(
      placement: placement,
      state: state,
      adsEnabled: _adsEnabled(),
      breakRemainingS: state.remainingSeconds,
      nowMs: _clock(),
      lastShownAtMs: await _events.lastShownAt(placement),
    );
  }

  Future<void> _log(AdPlacement placement, {String? id}) => _events.logShown(
        id: id ?? const Uuid().v4(),
        placement: placement,
        shownAtMs: _clock(),
      );

  @override
  Future<Object?> loadBanner(AdPlacement placement) async {
    if (!await _ensureReady()) return null;
    if (!await _allowed(placement)) return null;
    try {
      final eventId = const Uuid().v4();
      // **`ad.load()`i beklemek YETMİYOR.** O Future istek gönderilince
      // tamamlanıyor, reklam gelince değil. v1.5.1'e kadar öyleydi ve
      // yuvaya doldurulamamış bir reklam veriliyordu. Gerçek sonuç
      // `onAdLoaded`/`onAdFailedToLoad` ile geliyor.
      final done = Completer<Object?>();
      void finish(Object? value) {
        if (!done.isCompleted) done.complete(value);
      }

      final ad = BannerAd(
        adUnitId: _unitFor(placement),
        size: AdSize.banner,
        request: _request(),
        listener: BannerAdListener(
          onAdLoaded: finish,
          onAdImpression: (_) => _log(placement, id: eventId),
          onAdClicked: (_) => _events.markClicked(eventId),
          onAdFailedToLoad: (ad, err) {
            debugPrint('Banner yüklenemedi ($placement): $err');
            ad.dispose();
            finish(null);
          },
        ),
      );
      unawaited(ad.load());
      // Zaman aşımı şart: iki geri çağrı da hiç gelmezse yuva sonsuza
      // kadar "yükleniyor" kalırdı.
      return done.future.timeout(
        loadTimeout,
        onTimeout: () {
          ad.dispose();
          return null;
        },
      );
    } on Object catch (e) {
      debugPrint('loadBanner hatası ($placement): $e');
      return null;
    }
  }

  @override
  Future<Object?> loadNative(AdPlacement placement) async {
    if (!await _ensureReady()) return null;
    if (!await _allowed(placement)) return null;
    try {
      final eventId = const Uuid().v4();
      final done = Completer<Object?>();
      void finish(Object? value) {
        if (!done.isCompleted) done.complete(value);
      }

      final ad = NativeAd(
        adUnitId: _unitFor(placement),
        request: _request(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
        ),
        listener: NativeAdListener(
          onAdLoaded: finish,
          onAdImpression: (_) => _log(placement, id: eventId),
          onAdClicked: (_) => _events.markClicked(eventId),
          onAdFailedToLoad: (ad, err) {
            debugPrint('Native yüklenemedi ($placement): $err');
            ad.dispose();
            finish(null);
          },
        ),
      );
      unawaited(ad.load());
      return done.future.timeout(
        loadTimeout,
        onTimeout: () {
          ad.dispose();
          return null;
        },
      );
    } on Object catch (e) {
      debugPrint('loadNative hatası ($placement): $e');
      return null;
    }
  }

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    if (!await _ensureReady()) return false;
    // G7: çalışma bloğunda tam ekran ASLA — kontrol BURADA.
    if (!await _allowed(placement)) return false;

    try {
      final eventId = const Uuid().v4();
      InterstitialAd? loaded;
      await InterstitialAd.load(
        adUnitId: _unitFor(placement),
        request: _request(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => loaded = ad,
          onAdFailedToLoad: (err) =>
              debugPrint('Interstitial yüklenemedi: $err'),
        ),
      );
      final ad = loaded;
      if (ad == null) return false;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => _log(placement, id: eventId),
        onAdDismissedFullScreenContent: (ad) {
          _events.markCompleted(eventId);
          ad.dispose();
        },
        onAdClicked: (_) => _events.markClicked(eventId),
        onAdFailedToShowFullScreenContent: (ad, err) {
          debugPrint('Interstitial gösterilemedi: $err');
          ad.dispose();
        },
      );
      await ad.show();
      return true;
    } on Object catch (e) {
      debugPrint('showInterstitial hatası: $e');
      return false;
    }
  }

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    if (!await _ensureReady()) return false;
    if (!await _allowed(placement)) return false;

    try {
      final eventId = const Uuid().v4();
      RewardedAd? loaded;
      await RewardedAd.load(
        adUnitId: _unitFor(placement),
        request: _request(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => loaded = ad,
          onAdFailedToLoad: (err) => debugPrint('Rewarded yüklenemedi: $err'),
        ),
      );
      final ad = loaded;
      if (ad == null) return false;

      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) => _log(placement, id: eventId),
        onAdDismissedFullScreenContent: (ad) => ad.dispose(),
        onAdClicked: (_) => _events.markClicked(eventId),
      );
      await ad.show(
        onUserEarnedReward: (_, __) {
          earned = true;
          _events.markCompleted(eventId);
        },
      );
      return earned;
    } on Object catch (e) {
      debugPrint('showRewarded hatası: $e');
      return false;
    }
  }

  @override
  Future<void> releaseAd(Object? handle) async {
    if (handle is Ad) {
      try {
        await handle.dispose();
      } on Object catch (e) {
        debugPrint('releaseAd hatası: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    _ready = null;
  }
}
