import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/services/ad_policy_engine.dart';

/// Ödüllü reklamın **TEK** çağrı yolu (Ayarlar → "Destek ol").
///
/// Ara reklamla aynı gerekçe: her ekranın kendi `showRewarded` çağrısını
/// açması, kuralın sessizce delindiği yol olurdu.
///
/// **Frekans kapısı YOK** (S13, koordinatör onaylı): ödüllü reklamı kullanıcı
/// kendisi başlatır, dolayısıyla "beklenmeyen reklam" değildir. Rıza ve
/// çalışma bloğu kuralları yine geçerli.
class RewardedController {
  const RewardedController(this._ref);

  final Ref _ref;

  /// Gösterilebiliyorsa gösterir; kullanıcı ödülü hak ettiyse `true`.
  ///
  /// İzin yoksa veya reklam yüklenemezse `false` döner ve akış beklemez.
  Future<bool> maybeShow() async {
    final allowed = AdPolicyEngine.allows(
      placement: AdPlacement.supportRewarded,
      state: _ref.read(runStateProvider),
      consent: _ref.read(adConsentProvider),
    );
    if (!allowed) return false;

    return _ref.read(adGatewayProvider).showRewarded(
          AdPlacement.supportRewarded,
        );
  }

  /// Butonun aktif olup olmayacağı — ekranın önceden sorabilmesi için.
  ///
  /// Pasif buton, rıza vermemiş kullanıcıya "burada bir şey vardı ama
  /// sana kapalı" demekten daha dürüst: sebebi ekranda yazıyor.
  bool get canShow => AdPolicyEngine.allows(
        placement: AdPlacement.supportRewarded,
        state: _ref.read(runStateProvider),
        consent: _ref.read(adConsentProvider),
      );
}

final rewardedControllerProvider =
    Provider<RewardedController>(RewardedController.new);
