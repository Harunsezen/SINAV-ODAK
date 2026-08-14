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
  TextColumn get bannerPosition =>
      textEnum<BannerPosition>().withDefault(const Constant('bottom'))();

  TextColumn get themeMode =>
      textEnum<ThemeModeSetting>().withDefault(const Constant('system'))();

  /// Aktif çalışma ekranındaki ince banner kullanıcı tarafından kapatılabilir.
  BoolColumn get showAdsInFocusScreen =>
      boolean().withDefault(const Constant(true))();

  /// UMP rıza sonucu. Varsayılan KAPALI (KVKK/GDPR).
  BoolColumn get personalizedAdsConsent =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();

  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();

  /// 'YYYY-MM-DD' — streak hesabı buna bakar.
  TextColumn get lastStudyDate => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
