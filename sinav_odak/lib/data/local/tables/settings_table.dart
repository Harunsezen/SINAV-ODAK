import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';

/// Tek satırlık ayar tablosu (id sabit: 'me').
/// SharedPreferences yerine DB'de tutuluyor çünkü ayarlar (net katsayısı,
/// günlük hedef) istatistik sorgularıyla aynı transaction içinde okunuyor.
@DataClassName('UserSetting')
class UserSettings extends Table {
  TextColumn get id => text().withDefault(const Constant('me'))();
  IntColumn get createdAt => integer()();

  TextColumn get examType =>
      textEnum<ExamType>().withDefault(const Constant('yks'))();

  IntColumn get dailyGoalMinutes =>
      integer().withDefault(const Constant(240))();
  IntColumn get dailyGoalQuestions =>
      integer().withDefault(const Constant(100))();

  /// Net = doğru - (yanlış / katsayı). YKS 4, bazı sınavlarda 3.
  RealColumn get netPenaltyCoefficient =>
      real().withDefault(const Constant(4.0))();

  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get keepScreenOn => boolean().withDefault(const Constant(true))();

  /// Rozet kazanınca ekranın üstünde kısa kart gösterilsin mi? (FAZ 2.1)
  ///
  /// **schemaVersion 2 ile eklendi.** v1.0 yüklü cihazlarda `onUpgrade`
  /// bu kolonu ekliyor; varsayılan açık.
  BoolColumn get achievementToastEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Banner konumu (FAZ 4.4). **schemaVersion 3 ile eklendi.**
  ///
  /// **KULLANILMIYOR (v1.5.2 denetimi).** Banner her yerde altta; bu değeri
  /// okuyan tek bir satır yok, `SettingsController.setBannerPosition` da
  /// hiçbir yerden çağrılmıyor. Kolon duruyor çünkü SQLite'ta kolon
  /// düşürmek migrasyon maliyeti demek ve hiçbir zarar vermiyor; yeni kod
  /// buna BAKMASIN.
  TextColumn get bannerPosition =>
      textEnum<BannerPosition>().withDefault(const Constant('bottom'))();

  TextColumn get themeMode =>
      textEnum<ThemeModeSetting>().withDefault(const Constant('system'))();

  /// Arayüz dili (v1.2/E). **schemaVersion 5 ile eklendi.**
  ///
  /// Varsayılan `tr`, `system` DEĞİL: v1.1'den yükselen kullanıcı
  /// uygulamayı Türkçe bırakmıştı; telefonu İngilizce diye arayüzü
  /// güncellemeden sonra dil değiştirmiş bulmamalı. Yeni kurulumda
  /// karşılama ekranı dili soruyor.
  TextColumn get language =>
      textEnum<AppLanguage>().withDefault(const Constant('tr'))();

  /// **ÖLÜ KOLON (v1.5.2 denetimi).**
  ///
  /// Açıklaması "aktif çalışma ekranındaki banner kullanıcı tarafından
  /// kapatılabilir" diyordu; doğru değildi. Böyle bir anahtar arayüzde hiç
  /// olmadı ve v1.5'ten beri çalışma ekranında **hiç** banner yok
  /// (`AdPolicyEngine.banner`, `runBanner` → her zaman false). Bu değeri
  /// okuyan/yazan tek satır yok.
  BoolColumn get showAdsInFocusScreen =>
      boolean().withDefault(const Constant(true))();

  /// UMP rıza sonucu — **yalnızca kişiselleştirme**. Varsayılan KAPALI
  /// (KVKK/GDPR). v1.5'e kadar bu alan reklamın GÖSTERİLİP
  /// gösterilmeyeceğini de belirliyordu; artık belirlemiyor. Rıza yoksa
  /// reklam yine görünür, sadece **kişiselleştirilmemiş** olarak
  /// (`nonPersonalizedAds: true`) — bu yasal olarak serbest.
  BoolColumn get personalizedAdsConsent =>
      boolean().withDefault(const Constant(false))();

  /// Reklam gösterilsin mi? (v1.5)
  ///
  /// **Varsayılan AÇIK.** Uygulama ücretsiz, hiçbir özelliği kilitli değil;
  /// reklam ücretsiz kalmanın karşılığı. Arayüzde bunu kapatan bir anahtar
  /// YOK — bilinçli.
  ///
  /// Neden ayrı bir kolon: v1.4'e kadar rıza vermeyen kullanıcı HİÇ reklam
  /// görmüyordu ve o kullanıcılar bunu bilerek seçmişti. Onlara verilen söz
  /// bozulmasın diye yükseltme sırasında bu alan eski rıza değerinden
  /// dolduruluyor — yani eskiden reklamsız olan reklamsız KALIYOR. Yeni
  /// kurulumlar varsayılanı (açık) alır.
  BoolColumn get adsEnabled => boolean().withDefault(const Constant(true))();

  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// 'YYYY-MM-DD' — streak hesabı buna bakar.
  TextColumn get lastStudyDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
