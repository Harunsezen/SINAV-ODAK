import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/daos/ad_event_dao.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/ports/ad_gateway.dart';
import '../../domain/services/ad_policy_engine.dart';
import '../../domain/entities/consent_state.dart';
import '../../domain/ports/consent_gateway.dart';
import '../../services/ads/noop_ad_gateway.dart';
import '../../services/ads/noop_consent_gateway.dart';
import 'app_providers.dart';
import '../../domain/entities/enums.dart';

/// Reklam katmanının DI'ı.
///
/// `app_providers.dart`'tan ayrı tutuluyor: reklam katmanı uygulamanın geri
/// kalanının çalışması için ZORUNLU değil. Ayrı dosya, "reklamsız derleme"
/// senaryosunda neyin çıkarılacağını tek bakışta gösterir.

final adEventDaoProvider =
    Provider<AdEventDao>((ref) => ref.watch(databaseProvider).adEventDao);

/// UMP rıza akışı. `main()` gerçek cihazda `UmpConsentGateway` ile override
/// eder; testler ve UMP'siz çalıştırma bu haliyle kalır.
final consentGatewayProvider =
    Provider<ConsentGateway>((ref) => const NoopConsentGateway());

/// UMP'nin AÇILIŞTAKİ sonucu. `main()` hesaplayıp override eder.
///
/// Varsayılan `notRequired + canRequestAds: true`: bu "UMP çalışmadı"
/// demektir, "rıza var" değil — rızanın kendisi [adConsentProvider]'da
/// kullanıcı tercihiyle BİRLİKTE değerlendiriliyor.
final consentBootResultProvider = Provider<ConsentResult>(
  (ref) => const ConsentResult(
    state: ConsentState.notRequired,
    canRequestAds: true,
  ),
);

/// Kullanıcı Ayarlar'dan gizlilik formunu yeniden açtığında oluşan YENİ sonuç.
///
/// Açılış değeri `null` = "kullanıcı bu oturumda tercihini değiştirmedi".
/// Ayrı bir provider olması şart: `consentBootResultProvider` `main()`
/// tarafından sabit bir değerle override ediliyor, üzerine yazılamaz.
final consentResultOverrideProvider =
    StateProvider<ConsentResult?>((_) => null);

/// UMP'nin ŞU ANKİ sonucu: kullanıcı formu yeniden açtıysa o karar, yoksa
/// açılıştaki karar.
final consentResultProvider = Provider<ConsentResult>((ref) {
  return ref.watch(consentResultOverrideProvider) ??
      ref.watch(consentBootResultProvider);
});

/// Reklam rızası (KVKK/GDPR) — **iki kapının İKİSİ de açık olmalı**.
///
/// 1. `personalizedAdsConsent`: kullanıcının onboarding'de verdiği tercih
/// 2. UMP `canRequestAds`: Google'ın resmi rıza akışının kararı
///
/// UMP yalnızca KISITLAYABİLİR: "hayır" derse kullanıcı tercihi ne olursa
/// olsun reklam yok. Tersi geçerli değil — UMP "evet" dese bile kullanıcı
/// toggle'ı kapalıysa reklam gösterilmez.
///
/// **Ayar okunamazsa `false`.** Varsayılanın "izin var" olması, ayar akışı
/// bir an gecikince rızasız reklam göstermek demekti.
final adConsentProvider = Provider<bool>((ref) {
  final stored =
      ref.watch(settingsStreamProvider).valueOrNull?.personalizedAdsConsent ??
          false;
  return stored && ref.watch(consentResultProvider).canRequestAds;
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
/// Kullanıcının seçtiği banner konumu (FAZ 4.4).
final bannerPositionProvider = Provider<BannerPosition>((ref) {
  return ref.watch(settingsStreamProvider).valueOrNull?.bannerPosition ??
      BannerPosition.bottom;
});

/// Banner gerçekten yüklendi mi? (FAZ 4.2)
///
/// `null` dönen bir yükleme "reklam yok" demek — en yaygın sebebi
/// **internet olmaması**, ikincisi doluluk oranı. Ayırt etmek için
/// bağlantı paketi eklemedim: kullanıcı için sonuç aynı ve ek bir
/// bağımlılık + izin getirmeye değmez.
///
/// Yüklenmezse yuva boş gri kutu olarak kalmıyor; Balto konuşuyor.
final bannerLoadedProvider =
    FutureProvider.family<bool, AdPlacement>((ref, placement) async {
  if (!ref.watch(adAllowedProvider(placement))) return false;
  final handle = await ref.watch(adGatewayProvider).loadBanner(placement);
  return handle != null;
});

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
