import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/daos/ad_event_dao.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/ports/ad_gateway.dart';
import '../../domain/services/ad_policy_engine.dart';
import '../../services/ads/noop_ad_gateway.dart';
import 'app_providers.dart';

/// Reklam katmanının DI'ı.
///
/// `app_providers.dart`'tan ayrı tutuluyor: reklam katmanı uygulamanın geri
/// kalanının çalışması için ZORUNLU değil. Ayrı dosya, "reklamsız derleme"
/// senaryosunda neyin çıkarılacağını tek bakışta gösterir.

final adEventDaoProvider =
    Provider<AdEventDao>((ref) => ref.watch(databaseProvider).adEventDao);

/// Reklam rızası (KVKK/GDPR).
///
/// **Ayar okunamazsa `false`.** Varsayılanın "izin var" olması, ayar akışı
/// bir an gecikince rızasız reklam göstermek demekti.
final adConsentProvider = Provider<bool>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull?.personalizedAdsConsent ??
      false;
});

/// Aktif çalışma ekranında ince banner gösterilsin mi (kullanıcı ayarı).
final focusScreenAdsProvider = Provider<bool>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull?.showAdsInFocusScreen ??
      true;
});

/// **Varsayılan: REKLAMSIZ.** `main()` gerçek cihazda `AdMobGateway` ile
/// override eder; testler ve reklamsız çalıştırma bu haliyle kalır.
final adGatewayProvider = Provider<AdGateway>((ref) => const NoopAdGateway());

/// Bir yerin ŞU AN gösterilebilir olup olmadığı.
///
/// Banner ve native yuvaları bunu izler; izin yoksa hiç yer ayırmazlar.
/// Ara reklam (interstitial) bu ailede DEĞİL: frekans kapısı için veritabanı
/// okuması gerekiyor, o yüzden `InterstitialController` üzerinden asenkron
/// sorulur.
final adAllowedProvider = Provider.family<bool, AdPlacement>((ref, placement) {
  final state = ref.watch(runStateProvider);
  return AdPolicyEngine.allows(
    placement: placement,
    state: state,
    consent: ref.watch(adConsentProvider),
    showAdsInFocusScreen: ref.watch(focusScreenAdsProvider),
    breakRemainingS: state.remainingSeconds,
  );
});
