import 'package:drift/drift.dart' show Value;

import '../data/local/database.dart';
import '../domain/entities/enums.dart';
import 'usecases/recompute_nets.dart';

/// Ayar yazma işlemlerinin TEK kapısı.
///
/// **Neden var:** ekranlar daha önce doğrudan `UserSettingsCompanion`
/// kuruyordu; bu, `presentation` katmanının `data/local` içine uzanması
/// demekti (G4 ihlali). Companion tipi Drift'in üretilmiş kodu — arayüzün
/// veritabanı şemasının biçimini bilmesi gerekmiyor.
///
/// Ayrıca net katsayısı gibi **yan etkisi olan** ayarların doğru sırayla
/// işlenmesi burada garanti altına alınıyor.
class SettingsController {
  SettingsController(this._db);

  final AppDatabase _db;

  Future<void> _patch(UserSettingsCompanion patch) =>
      _db.settingsDao.patchSettings(patch);

  Future<void> setThemeMode(ThemeModeSetting mode) =>
      _patch(UserSettingsCompanion(themeMode: Value(mode)));

  Future<void> setKeepScreenOn({required bool value}) =>
      _patch(UserSettingsCompanion(keepScreenOn: Value(value)));

  Future<void> setNotificationEnabled({required bool value}) =>
      _patch(UserSettingsCompanion(notificationEnabled: Value(value)));

  Future<void> setSoundEnabled({required bool value}) =>
      _patch(UserSettingsCompanion(soundEnabled: Value(value)));

  Future<void> setVibrationEnabled({required bool value}) =>
      _patch(UserSettingsCompanion(vibrationEnabled: Value(value)));

  /// Rozet bildirimi şeridi (FAZ 2.1).
  Future<void> setAchievementToastEnabled({required bool value}) =>
      _patch(UserSettingsCompanion(achievementToastEnabled: Value(value)));

  /// Banner konumu (FAZ 4.4).
  Future<void> setBannerPosition(BannerPosition p) =>
      _patch(UserSettingsCompanion(bannerPosition: Value(p)));

  Future<void> setDailyGoalMinutes(int minutes) =>
      _patch(UserSettingsCompanion(dailyGoalMinutes: Value(minutes)));

  /// Net katsayısını değiştirir ve **geçmiş netleri yeniden hesaplar**.
  ///
  /// Ayar ÖNCE yazılıyor: yeniden hesaplama yarıda kalsa bile kullanıcının
  /// seçtiği katsayı kayıtlı kalır ve bundan sonraki oturumlar doğru
  /// hesaplanır. Ters sırada, hesaplama başarılı olup ayar yazılamazsa
  /// geçmiş netler yeni katsayıya, yeni oturumlar eskisine göre olurdu.
  ///
  /// Dönen değer güncellenen oturum sayısıdır.
  Future<int> setNetCoefficient(double coefficient) async {
    await _patch(
      UserSettingsCompanion(netPenaltyCoefficient: Value(coefficient)),
    );
    return RecomputeNetsUseCase(_db)(coefficient: coefficient);
  }
}
