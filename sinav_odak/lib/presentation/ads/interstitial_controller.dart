import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/services/ad_policy_engine.dart';

/// Ara reklamın **TEK** tetikleyicisi: tebrik ekranından ana panele geçiş.
///
/// Neden ayrı denetleyici? Frekans kapısı için son gösterim anını
/// veritabanından okumak gerekiyor; bu asenkron olduğu için
/// [adAllowedProvider] ailesine sığmıyor. Ayrıca "ara reklam nereden
/// çağrılabilir" sorusunun yanıtı tek bir yerde kalsın istiyoruz — her
/// ekranın kendi `showInterstitial` çağrısı açması, kuralın sessizce
/// delindiği yol olurdu.
class InterstitialController {
  const InterstitialController(this._ref);

  final Ref _ref;

  /// Gösterilebiliyorsa gösterir ve `true` döner.
  ///
  /// **Akışı ASLA bloklamaz:** izin yoksa, reklam yüklenmezse veya hata
  /// olursa `false` döner ve çağıran hemen yönlendirmesini yapar.
  Future<bool> maybeShow(AdPlacement placement) async {
    final state = _ref.read(runStateProvider);
    final consent = _ref.read(adConsentProvider);
    final nowMs = _ref.read(clockProvider)();
    final lastAt = await _ref.read(adEventDaoProvider).lastShownAt(placement);

    final allowed = AdPolicyEngine.allows(
      placement: placement,
      state: state,
      consent: consent,
      nowMs: nowMs,
      lastShownAtMs: lastAt,
    );
    if (!allowed) return false;

    return _ref.read(adGatewayProvider).showInterstitial(placement);
  }
}

final interstitialControllerProvider =
    Provider<InterstitialController>(InterstitialController.new);
