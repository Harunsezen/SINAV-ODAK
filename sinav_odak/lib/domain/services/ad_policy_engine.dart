// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import '../entities/ad_placement.dart';
import '../entities/enums.dart';
import '../entities/session_state.dart';

/// Reklam gösterim kurallarının TEK karar mercii.
///
/// **Neden saf Dart?** Reklam politikası ürünün en kolay sessizce bozulan
/// yeri: bir ekran "burada bir kez gösterebiliriz" diye kestirme yaparsa
/// kural, kimsenin bakmadığı bir yerde delinir. Kararı Flutter'dan bağımsız
/// tek bir yerde toplamak, kuralı 24+ birim testle kilitlenebilir hale
/// getiriyor.
///
/// **Değişmez kurallar (v1.5):**
/// 1. [adsEnabled] kapalıysa **HİÇBİR reklam yok**. Bu alan arayüzden
///    kapatılamıyor; yalnızca v1.4 ve öncesinde rıza vermemiş kullanıcılar
///    için kapalı geliyor (bkz. `UserSettings.adsEnabled`).
/// 2. **Çalışma ekranında (S08) HİÇBİR reklam yok** — ne tam ekran, ne
///    banner. v1.4'e kadar orada ince bir şerit vardı ve kullanıcı ayarıyla
///    kapatılabiliyordu. Kaldırıldı: uygulamanın tek vaadi "odaklanmanı
///    kolaylaştırırım" ve sayaç işlerken ekranda reklam durması o vaadi
///    yalanlıyordu. Üstelik üç reklam yeri içinde en az kazandıran,
///    vaade en çok zarar veren yerdi.
/// 3. Aktif çalışma bloğunda (`SessionInBlock`) **tam ekran ASLA**.
///
/// **Rıza ([consent]) artık gösterimi değil, yalnızca kişiselleştirmeyi
/// belirliyor.** Rıza yoksa reklam yine çıkar ama
/// `nonPersonalizedAds: true` ile istenir — KVKK/GDPR bunu serbest
/// bırakıyor. Rızayı gösterim kapısı olarak kullanmak, yasanın
/// istemediği bir geliri kendi elimizle silmekti.
abstract final class AdPolicyEngine {
  /// Ara reklamlar arası en az bekleme (ms).
  static const int interstitialCooldownMs = 90000;

  /// Native kart için gereken en az kalan mola süresi (saniye).
  ///
  /// Kısa molada kart yüklenene kadar mola biter; kullanıcı yalnızca
  /// göz yorgunluğu kazanır.
  static const int minBreakRemainingS = 180;

  /// Banner gösterilebilir mi?
  ///
  /// Ana panel, istatistik ve takvimde serbest: kullanıcı orada geziniyor,
  /// alt şerit kimseyi bölmüyor. [AdPlacement.runBanner] **her koşulda
  /// reddedilir** — sayaç işlerken ekranda reklam olmaz (Kural 2).
  static bool banner({
    required AdPlacement placement,
    required bool adsEnabled,
  }) {
    if (!adsEnabled) return false;
    if (placement.kind != AdKind.banner) return false;
    if (placement == AdPlacement.runBanner) return false;
    return true;
  }

  /// Molada büyük native kart gösterilebilir mi?
  ///
  /// Mola reklam için doğal andır: öğrenci zaten dinleniyor. Ama molanın
  /// [minBreakRemainingS] saniyeden fazlası kalmış olmalı.
  static bool nativeBreak({
    required SessionState state,
    required bool adsEnabled,
    required int breakRemainingS,
  }) {
    if (!adsEnabled) return false;
    if (state.isInStudyBlock) return false;
    if (state is! SessionInBreak) return false;
    return breakRemainingS > minBreakRemainingS;
  }

  /// Ara reklam gösterilebilir mi?
  ///
  /// Tek tetikleyici: tebrik ekranından ana panele geçiş. [lastShownAtMs]
  /// `null` ise hiç gösterilmemiş demektir ve kapı açıktır.
  static bool interstitial({
    required SessionState state,
    required bool adsEnabled,
    required int nowMs,
    required int? lastShownAtMs,
  }) {
    if (!adsEnabled) return false;
    // Kural 2: çalışma bloğunda tam ekran ASLA.
    if (state.isInStudyBlock) return false;
    if (lastShownAtMs == null) return true;
    return nowMs - lastShownAtMs >= interstitialCooldownMs;
  }

  /// Ödüllü reklam gösterilebilir mi?
  ///
  /// Kullanıcının kendi başlattığı akış olduğu için frekans kapısı yok;
  /// yine de rıza ve çalışma bloğu kuralları geçerli.
  static bool rewarded({
    required SessionState state,
    required bool adsEnabled,
  }) {
    if (!adsEnabled) return false;
    return !state.isInStudyBlock;
  }

  /// Tek giriş noktası — [AdPlacement]'a göre doğru kuralı seçer.
  ///
  /// `AdGateway` implementasyonu bunu çağırır; böylece yeni bir çağrı yolu
  /// açan kişi kuralı atlayamaz.
  static bool allows({
    required AdPlacement placement,
    required SessionState state,
    required bool adsEnabled,
    int breakRemainingS = 0,
    int nowMs = 0,
    int? lastShownAtMs,
  }) {
    return switch (placement) {
      AdPlacement.homeBanner ||
      AdPlacement.statsBanner ||
      AdPlacement.calendarBanner ||
      AdPlacement.runBanner =>
        banner(placement: placement, adsEnabled: adsEnabled),
      AdPlacement.breakNative => nativeBreak(
          state: state,
          adsEnabled: adsEnabled,
          breakRemainingS: breakRemainingS,
        ),
      AdPlacement.doneInterstitial => interstitial(
          state: state,
          adsEnabled: adsEnabled,
          nowMs: nowMs,
          lastShownAtMs: lastShownAtMs,
        ),
      AdPlacement.supportRewarded =>
        rewarded(state: state, adsEnabled: adsEnabled),
    };
  }
}
