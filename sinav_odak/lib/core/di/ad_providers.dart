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

/// Reklam GÖSTERİLEBİLİR mi? (v1.5 — gösterim kapısı)
///
/// İki kapı da açık olmalı:
/// 1. `adsEnabled`: varsayılanı AÇIK. Arayüzden kapatılamıyor; yalnızca
///    v1.4 ve öncesinde rıza vermemiş kullanıcılarda kapalı geliyor
///    (bkz. `UserSettings.adsEnabled` ve şema 8 migration'ı).
/// 2. UMP `canRequestAds`: Google'ın resmî rıza akışının kararı. Bu
///    **kişiselleştirme değil, reklam isteyebilme** kararıdır — AB'de
///    reddeden kullanıcıya hiç reklam istenemez. O yüzden burada duruyor.
///
/// **Ayar okunamazsa varsayılan AÇIK.** v1.4'te burası `false`'tu çünkü
/// alan rızayı temsil ediyordu ve rızasız reklam göstermek ihlaldi. Artık
/// alan rızayı değil ürün kararını temsil ediyor; kişiselleştirme kapısı
/// ayrı ([personalizedAdsProvider]) ve o hâlâ varsayılan kapalı.
final adsEnabledProvider = Provider<bool>((ref) {
  final stored =
      ref.watch(settingsStreamProvider).valueOrNull?.adsEnabled ?? true;
  return stored && ref.watch(consentResultProvider).canRequestAds;
});

/// Reklam KİŞİSELLEŞTİRİLSİN mi? (v1.5)
///
/// Gösterimi değil, yalnızca isteğin türünü belirler: `false` ise reklam
/// `nonPersonalizedAds: true` ile istenir. KVKK/GDPR kişiselleştirilmemiş
/// reklamı rıza olmadan serbest bırakıyor.
///
/// **Okunamazsa `false`** — yani kişiselleştirilmemiş. Varsayılanın
/// "kişiselleştir" olması, ayar bir an gecikince rızasız kişisel veri
/// işlemek demekti.
final personalizedAdsProvider = Provider<bool>((ref) {
  final stored =
      ref.watch(settingsStreamProvider).valueOrNull?.personalizedAdsConsent ??
          false;
  return stored && ref.watch(consentResultProvider).canRequestAds;
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
    adsEnabled: ref.watch(adsEnabledProvider),
    breakRemainingS: state.remainingSeconds,
  );
});
