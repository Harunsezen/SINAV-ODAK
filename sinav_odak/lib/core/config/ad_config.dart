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

  // --- Ham `--dart-define` değerleri ---
  //
  // Doğrudan KULLANILMAZ; aşağıdaki geçerlilik süzgecinden geçerler.

  static const String _rawAppId =
      String.fromEnvironment('ADMOB_APP_ID', defaultValue: testAppId);

  static const String _rawBannerUnit =
      String.fromEnvironment('ADMOB_BANNER_UNIT', defaultValue: testBannerUnit);

  static const String _rawNativeUnit =
      String.fromEnvironment('ADMOB_NATIVE_UNIT', defaultValue: testNativeUnit);

  static const String _rawInterstitialUnit = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT',
    defaultValue: testInterstitialUnit,
  );

  static const String _rawRewardedUnit = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT',
    defaultValue: testRewardedUnit,
  );

  /// Reklam BİRİMİ biçimi: `ca-app-pub-<rakam>/<rakam>`.
  ///
  /// Uygulama kimliğinden farkı ayraç: birimlerde `/`, uygulamada `~`.
  /// Açık (private değil) çünkü `test/unit/ad_config_test.dart` bu iki
  /// kalıbı doğrudan sınıyor — kalıp bozulursa süzgeç de bozulur.
  static final RegExp unitPattern = RegExp(r'^ca-app-pub-\d+/\d+$');

  /// Uygulama kimliği biçimi: `ca-app-pub-<rakam>~<rakam>`.
  static final RegExp appIdPattern = RegExp(r'^ca-app-pub-\d+~\d+$');

  /// Bozuk değeri TEST kimliğine düşürür.
  ///
  /// ## Neden var
  ///
  /// 1.5.2 derlemesinde PowerShell `-Padmob_app_id=$APP_ID` içindeki
  /// değişkeni açmadı; manifest'e `$APP_ID` **metni** girdi ve uygulama
  /// açılışta çöktü. Uygulama kimliği tarafı artık Gradle'da
  /// doğrulanıyor, derleme orada duruyor.
  ///
  /// Aynı kaza `--dart-define` tarafında da olabilirdi ve **çok daha
  /// sessiz** olurdu: birim kimliği `$BANNER` metnine dönüşürdü, uygulama
  /// açılırdı, hiçbir şey çökmezdi, sadece hiçbir reklam gelmezdi.
  /// Panelde yine "İstekler: 0" görünürdü ve sebebini aramak günler
  /// alırdı.
  ///
  /// Bozuk değerle canlıya çıkmaktansa test reklamı göstermek yeğdir:
  /// test reklamı gözle görülür, sessizlik görülmez.
  static String _checked(String value, RegExp pattern, String fallback) =>
      pattern.hasMatch(value) ? value : fallback;

  static String get appId => _checked(_rawAppId, appIdPattern, testAppId);

  static String get bannerUnit =>
      _checked(_rawBannerUnit, unitPattern, testBannerUnit);

  static String get nativeUnit =>
      _checked(_rawNativeUnit, unitPattern, testNativeUnit);

  static String get interstitialUnit =>
      _checked(_rawInterstitialUnit, unitPattern, testInterstitialUnit);

  static String get rewardedUnit =>
      _checked(_rawRewardedUnit, unitPattern, testRewardedUnit);

  /// Derlemede verilen kimliklerden biri BOZUK muydu?
  ///
  /// Sessizce test kimliğine düşmek çökmekten iyi ama görünmez olmamalı.
  static bool get hasMalformedIds =>
      !appIdPattern.hasMatch(_rawAppId) ||
      !unitPattern.hasMatch(_rawBannerUnit) ||
      !unitPattern.hasMatch(_rawNativeUnit) ||
      !unitPattern.hasMatch(_rawInterstitialUnit) ||
      !unitPattern.hasMatch(_rawRewardedUnit);

  /// Şu an TEST reklamları mı geliyor?
  ///
  /// Ayarlar → Hakkında'da gösteriliyor; yanlışlıkla test kimlikleriyle
  /// yayına çıkmak gelir kaybı, tersi hesap kaybıdır. Bozuk bir kimlik de
  /// buraya düşüyor: süzgeç onu test birimine çevirdiği için uyarı görünür
  /// kalıyor.
  ///
  /// ## Karar neden BİRİMLERE bakıyor, uygulama kimliğine değil
  ///
  /// Hangi reklamın geleceğini reklam BİRİMİ kimlikleri belirliyor.
  /// Uygulama kimliği 1.5.2+11'den beri Dart tarafına hiç geçilmiyor —
  /// manifest'e `android/gradle.properties`ten giriyor. Dolayısıyla
  /// buradaki `appId` her zaman varsayılanda, yani TEST değerinde kalıyor.
  ///
  /// Ona bakmak yanlış uyarı veriyordu ve verdi: 1.5.2+11 derlemesinde
  /// cihazda **gerçek** reklamlar gelirken Hakkında ekranında "TEST reklam
  /// kimlikleri kullanılıyor" yazıyordu. Bu uyarının yalan söylemesi
  /// tehlikeli: "test reklamı" sanıp kendi reklamına tıklayan geliştirici
  /// AdMob hesabını kaybeder.
  static bool get usingTestIds => isTestConfig(
        banner: bannerUnit,
        native: nativeUnit,
        interstitial: interstitialUnit,
        rewarded: rewardedUnit,
        malformed: hasMalformedIds,
      );

  /// [usingTestIds]'in saf hâli — dışarıdan değer verilebildiği için
  /// sınanabiliyor. `--dart-define` testlerde ayarlanamıyor; karar mantığı
  /// buraya alınmasa hiç sınanamazdı.
  static bool isTestConfig({
    required String banner,
    required String native,
    required String interstitial,
    required String rewarded,
    bool malformed = false,
  }) =>
      malformed ||
      banner == testBannerUnit ||
      native == testNativeUnit ||
      interstitial == testInterstitialUnit ||
      rewarded == testRewardedUnit;
}
