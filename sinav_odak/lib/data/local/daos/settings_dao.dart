import 'package:drift/drift.dart';

import '../../../core/utils/time.dart';
import '../database.dart';

part 'settings_dao.g.dart';

const kSettingsId = 'me';

@DriftAccessor(tables: [UserSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  /// Ayar satırını garanti eder (ilk açılış / bozulma durumları).
  Future<UserSetting> ensure() async {
    final existing = await (select(userSettings)
          ..where((t) => t.id.equals(kSettingsId)))
        .getSingleOrNull();
    if (existing != null) return existing;

    await into(userSettings).insert(
      UserSettingsCompanion.insert(createdAt: nowMs()),
      mode: InsertMode.insertOrReplace,
    );
    return (select(userSettings)..where((t) => t.id.equals(kSettingsId)))
        .getSingle();
  }

  /// Satır silinmiş olsa bile stream HATA DURUMUNA DÜŞMEZ.
  /// "Verileri sıfırla" akışı user_settings satırını da silebiliyor;
  /// watchSingle() bu durumda tüm uygulama ağacını hataya sokuyordu.
  Stream<UserSetting?> watch() =>
      (select(userSettings)..where((t) => t.id.equals(kSettingsId)))
          .watchSingleOrNull();

  /// Not: `update` adı DatabaseAccessor.update<T,D>() ile çakıştığı için
  /// bilinçli olarak `patchSettings` kullanıldı.
  Future<void> patchSettings(UserSettingsCompanion patch) async {
    await (update(userSettings)..where((t) => t.id.equals(kSettingsId)))
        .write(patch);
  }

  Future<UserSetting> read() =>
      (select(userSettings)..where((t) => t.id.equals(kSettingsId)))
          .getSingle();
}
