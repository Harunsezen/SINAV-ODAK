/// Reklam kimliklerinin TEK kaynağı.
///
/// **Production kimlikleri koda GİRMEZ.** `--dart-define` ile geçilir;
/// verilmezse Google'ın resmî TEST kimlikleri kullanılır.
///
/// Neden bu kadar katı: kendi reklamına tıklamak AdMob hesabını kapattırır
/// ve bu hesap ebeveyn adına açıldığı için ihlal riski normalden pahalı.
/// Yanlışlıkla production kimliğiyle geliştirme yapmak tam olarak bu riski
/// doğurur. Varsayılanın test kimliği olması, "unutulursa güvenli tarafta
/// kal" ilkesidir.
///
/// Derleme:
/// ```
/// flutter build apk --release \
///   --dart-define=ADMOB_APP_ID=ca-app-pub-XXXX~YYYY \
///   --dart-define=ADMOB_BANNER_UNIT=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_NATIVE_UNIT=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_INTERSTITIAL_UNIT=ca-app-pub-XXXX/YYYY \
///   --dart-define=ADMOB_REWARDED_UNIT=ca-app-pub-XXXX/YYYY
/// ```
///
/// `ADMOB_APP_ID` ayrıca `android/gradle.properties` içindeki
/// `admobAppId` üzerinden manifest'e enjekte edilir (manifestPlaceholders);
/// Dart tarafındaki değer yalnızca doğrulama/raporlama içindir.
abstract final class AdConfig {
  // --- Google resmî TEST kimlikleri (varsayılan) ---
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBannerUnit = 'ca-app-pub-3940256099942544/6300978111';
  static const String testNativeUnit = 'ca-app-pub-3940256099942544/2247696110';
  static const String testInterstitialUnit =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedUnit =
      'ca-app-pub-3940256099942544/5224354917';

  static const String appId =
      String.fromEnvironment('ADMOB_APP_ID', defaultValue: testAppId);

  static const String bannerUnit =
      String.fromEnvironment('ADMOB_BANNER_UNIT', defaultValue: testBannerUnit);

  static const String nativeUnit =
      String.fromEnvironment('ADMOB_NATIVE_UNIT', defaultValue: testNativeUnit);

  static const String interstitialUnit = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT',
    defaultValue: testInterstitialUnit,
  );

  static const String rewardedUnit = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT',
    defaultValue: testRewardedUnit,
  );

  /// Şu an TEST kimlikleri mi kullanılıyor?
  ///
  /// Ayarlar/hakkında ekranında gösterilebilir; yanlışlıkla test
  /// kimlikleriyle yayına çıkmak gelir kaybı, tersi hesap kaybıdır.
  static bool get usingTestIds => appId == testAppId;
}
