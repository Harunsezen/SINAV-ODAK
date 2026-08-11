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
/// **Değişmez kurallar:**
/// 1. Rıza yoksa **HİÇBİR reklam yok** (ürün kararı — kişiselleştirilmiş
///    olsun olmasın). KVKK/GDPR'ın gerektirdiğinden daha katı, bilinçli.
/// 2. Aktif çalışma bloğunda (`SessionInBlock`) **tam ekran ASLA**. Ürünün
///    tek vaadi "odaklanmanı kolaylaştırırım"; onu en yüksek niyetli anda
///    bozmak ürünü yalanlar.
/// 3. Çalışma ekranında yalnızca **ince banner** olabilir, o da kullanıcı
///    ayarı açıksa.
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
  /// Banner, ekranı kaplamadığı için çalışma bloğunda da mümkündür — ancak
  /// yalnızca [AdPlacement.runBanner] yerinde ve **kullanıcı ayarı açıksa**
  /// (`showAdsInFocusScreen`). Diğer ekranlarda ayara bakılmaz.
  static bool banner({
    required AdPlacement placement,
    required bool consent,
    required bool showAdsInFocusScreen,
  }) {
    if (!consent) return false;
    if (placement.kind != AdKind.banner) return false;
    if (placement == AdPlacement.runBanner) return showAdsInFocusScreen;
    return true;
  }

  /// Molada büyük native kart gösterilebilir mi?
  ///
  /// Mola reklam için doğal andır: öğrenci zaten dinleniyor. Ama molanın
  /// [minBreakRemainingS] saniyeden fazlası kalmış olmalı.
  static bool nativeBreak({
    required SessionState state,
    required bool consent,
    required int breakRemainingS,
  }) {
    if (!consent) return false;
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
    required bool consent,
    required int nowMs,
    required int? lastShownAtMs,
  }) {
    if (!consent) return false;
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
    required bool consent,
  }) {
    if (!consent) return false;
    return !state.isInStudyBlock;
  }

  /// Tek giriş noktası — [AdPlacement]'a göre doğru kuralı seçer.
  ///
  /// `AdGateway` implementasyonu bunu çağırır; böylece yeni bir çağrı yolu
  /// açan kişi kuralı atlayamaz.
  static bool allows({
    required AdPlacement placement,
    required SessionState state,
    required bool consent,
    bool showAdsInFocusScreen = true,
    int breakRemainingS = 0,
    int nowMs = 0,
    int? lastShownAtMs,
  }) {
    return switch (placement) {
      AdPlacement.homeBanner ||
      AdPlacement.statsBanner ||
      AdPlacement.calendarBanner ||
      AdPlacement.runBanner =>
        banner(
          placement: placement,
          consent: consent,
          showAdsInFocusScreen: showAdsInFocusScreen,
        ),
      AdPlacement.breakNative => nativeBreak(
          state: state,
          consent: consent,
          breakRemainingS: breakRemainingS,
        ),
      AdPlacement.doneInterstitial => interstitial(
          state: state,
          consent: consent,
          nowMs: nowMs,
          lastShownAtMs: lastShownAtMs,
        ),
      AdPlacement.supportRewarded => rewarded(state: state, consent: consent),
    };
  }
}
