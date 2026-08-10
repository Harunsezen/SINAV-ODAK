import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:uuid/uuid.dart';

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
    required bool Function() consentReader,
    required int Function() clock,
    bool Function()? focusScreenAdsReader,
  })  : _events = eventDao,
        _state = stateReader,
        _consent = consentReader,
        _clock = clock,
        _focusScreenAds = focusScreenAdsReader ?? (() => true);

  final AdEventDao _events;
  final SessionState Function() _state;
  final bool Function() _consent;
  final int Function() _clock;
  final bool Function() _focusScreenAds;

  bool _initialized = false;

  // --- GOOGLE TEST BİRİM KİMLİKLERİ ---
  static const String testBannerUnit = 'ca-app-pub-3940256099942544/6300978111';
  static const String testNativeUnit = 'ca-app-pub-3940256099942544/2247696110';
  static const String testInterstitialUnit =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedUnit =
      'ca-app-pub-3940256099942544/5224354917';

  /// Native kartın görünme gecikmesi: kart aniden belirip göz yormasın.
  static const Duration nativeRevealDelay = Duration(milliseconds: 1200);

  String _unitFor(AdPlacement p) => switch (p.kind) {
        AdKind.banner => testBannerUnit,
        AdKind.native => testNativeUnit,
        AdKind.interstitial => testInterstitialUnit,
        AdKind.rewarded => testRewardedUnit,
      };

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      // TÜM video reklamlar SESSİZ başlar (ürün kuralı): çalışan öğrencinin
      // kulağına habersiz ses gitmez.
      await MobileAds.instance.setAppMuted(true);
      await MobileAds.instance.setAppVolume(0);
      _initialized = true;
    } on Object catch (e) {
      // Reklam altyapısı kurulamadıysa uygulama yine çalışır.
      debugPrint('AdMobGateway.initialize başarısız: $e');
    }
  }

  /// Politika kapısı — her gösterim/yükleme buradan geçer.
  Future<bool> _allowed(AdPlacement placement) async {
    final state = _state();
    return AdPolicyEngine.allows(
      placement: placement,
      state: state,
      consent: _consent(),
      showAdsInFocusScreen: _focusScreenAds(),
      breakRemainingS: state.remainingSeconds,
      nowMs: _clock(),
      lastShownAtMs: await _events.lastShownAt(placement),
    );
  }

  Future<void> _log(AdPlacement placement, {String? id}) =>
      _events.logShown(
        id: id ?? const Uuid().v4(),
        placement: placement,
        shownAtMs: _clock(),
      );

  @override
  Future<Object?> loadBanner(AdPlacement placement) async {
    if (!_initialized) return null;
    if (!await _allowed(placement)) return null;
    try {
      final eventId = const Uuid().v4();
      final ad = BannerAd(
        adUnitId: _unitFor(placement),
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdImpression: (_) => _log(placement, id: eventId),
          onAdClicked: (_) => _events.markClicked(eventId),
          onAdFailedToLoad: (ad, err) {
            debugPrint('Banner yüklenemedi ($placement): $err');
            ad.dispose();
          },
        ),
      );
      await ad.load();
      return ad;
    } on Object catch (e) {
      debugPrint('loadBanner hatası ($placement): $e');
      return null;
    }
  }

  @override
  Future<Object?> loadNative(AdPlacement placement) async {
    if (!_initialized) return null;
    if (!await _allowed(placement)) return null;
    try {
      final eventId = const Uuid().v4();
      final ad = NativeAd(
        adUnitId: _unitFor(placement),
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
        ),
        listener: NativeAdListener(
          onAdImpression: (_) => _log(placement, id: eventId),
          onAdClicked: (_) => _events.markClicked(eventId),
          onAdFailedToLoad: (ad, err) {
            debugPrint('Native yüklenemedi ($placement): $err');
            ad.dispose();
          },
        ),
      );
      await ad.load();
      return ad;
    } on Object catch (e) {
      debugPrint('loadNative hatası ($placement): $e');
      return null;
    }
  }

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    if (!_initialized) return false;
    // G7: çalışma bloğunda tam ekran ASLA — kontrol BURADA.
    if (!await _allowed(placement)) return false;

    try {
      final eventId = const Uuid().v4();
      InterstitialAd? loaded;
      await InterstitialAd.load(
        adUnitId: _unitFor(placement),
        request: const AdRequest(),
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
    if (!_initialized) return false;
    if (!await _allowed(placement)) return false;

    try {
      final eventId = const Uuid().v4();
      RewardedAd? loaded;
      await RewardedAd.load(
        adUnitId: _unitFor(placement),
        request: const AdRequest(),
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
  Future<void> dispose() async {
    _initialized = false;
  }
}
