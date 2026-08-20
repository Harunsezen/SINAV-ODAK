import 'package:drift/drift.dart';

// DİKKAT: `database.g.dart` bu dosyanın `part`'ıdır ve üretilen kod
// enum tiplerini (SessionStatus, BlockType, ...) ve BlockTypeConverter'ı
// kullanır. Part dosyaları kendi importlarını yapamaz; kütüphane kapsamını
// kullanır. Bu importlar kaldırılırsa üretilen kod DERLENMEZ —
// `flutter analyze` bunu YAKALAMAZ çünkü analysis_options *.g.dart'ı
// hariç tutuyor.
import '../../domain/entities/enums.dart';
import 'connection/connection.dart';
import 'converters/block_type_converter.dart';
import 'daos/ad_event_dao.dart';
import 'daos/achievement_dao.dart';
import 'daos/goal_dao.dart';
import 'daos/session_dao.dart';
import 'daos/settings_dao.dart';
import 'daos/stats_dao.dart';
import 'daos/subject_dao.dart';
import 'daos/wrong_item_dao.dart';
import 'seed_data.dart';
import 'tables/catalog_tables.dart';
import 'tables/session_tables.dart';
import 'tables/settings_table.dart';
import 'tables/tracking_tables.dart';

export 'tables/catalog_tables.dart';
export 'tables/session_tables.dart';
export 'tables/settings_table.dart';
export 'tables/tracking_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    UserSettings,
    Subjects,
    Topics,
    ActivityTypes,
    StudySessions,
    SessionBlocks,
    Goals,
    DailyStats,
    WrongItems,
    Achievements,
    AdEvents,
    AppStateEntries,
  ],
  daos: [
    AdEventDao,
    SettingsDao,
    SubjectDao,
    SessionDao,
    StatsDao,
    GoalDao,
    WrongItemDao,
    AchievementDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  /// Test kolaylığı için bellek içi örnek.
  factory AppDatabase.memory() => AppDatabase(openTestConnection());

  @override

  /// v2 (FAZ 2.1): `user_settings.achievement_toast_enabled` eklendi.
  /// v3 (FAZ 4.4): `user_settings.banner_position` eklendi.
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();

          // KARAR D3 — TEK `running` OTURUM ŞEMA KISITI.
          //
          // Kod seviyesindeki koruma (`StartSessionUseCase`) "önce oku sonra
          // yaz" yapısındadır ve yarış durumunda iki `running` satıra izin
          // verir. İkinci satır oluştuğunda ilkinin çalışması `daily_stats`'a
          // hiç yansımaz ve hata SESSİZ kalır. Kısmi unique index bunu
          // veritabanı seviyesinde imkânsız kılar.
          //
          // `status` kolonu enum ADINI saklar (textEnum), bu yüzden karşılaştırma
          // 'running' string'i ile yapılır.
          //
          // schemaVersion 1'de KALIYOR (temiz şema değişikliği): geliştirme
          // cihazında eski veritabanı varsa uygulama SİLİNMELİDİR.
          await customStatement(
            'CREATE UNIQUE INDEX idx_one_running '
            "ON study_sessions(status) WHERE status = 'running'",
          );

          await SeedData.populate(this);
        },
        onUpgrade: (m, from, to) async {
          // **Adım adım, ATLAMADAN.** `from` hangi sürüm olursa olsun
          // aradaki her adım sırayla uygulanmalı; tek bir `if (to == N)`
          // yazmak, iki sürüm geriden gelen cihazı bozar.
          if (from < 2) {
            // FAZ 2.1 — rozet bildirimi tercihi.
            await m.addColumn(
              userSettings,
              userSettings.achievementToastEnabled,
            );
          }
          if (from < 3) {
            // FAZ 4.4 — banner konumu tercihi.
            await m.addColumn(userSettings, userSettings.bannerPosition);
          }
          if (from < 4) {
            // v1.2 — müfredat: alt dal + sınıf + TYT/AYT etiketi.
            //
            // Üçü de NULLABLE: mevcut konular olduğu gibi kalıyor
            // (parentId null = konu, grade/examTag null = etiketsiz).
            // Kullanıcının kendi eklediği konular hiç etkilenmiyor.
            await m.addColumn(topics, topics.parentId);
            await m.addColumn(topics, topics.grade);
            await m.addColumn(topics, topics.examTag);
            // Yeni müfredat satırları eklenir; `insertOrIgnore` sayesinde
            // kullanıcının yeniden adlandırdığı kayıtlara DOKUNMAZ.
            await SeedData.populate(this);
          }
        },
        beforeOpen: (details) async {
          // Foreign key kısıtları SQLite'ta varsayılan olarak KAPALIDIR.
          await customStatement('PRAGMA foreign_keys = ON');
          // Yazma performansı + kilit çakışmalarını azaltır.
          await customStatement('PRAGMA journal_mode = WAL');

          if (details.wasCreated) {
            // onCreate zaten seed'ledi.
            return;
          }
          // Seed sonradan bozulduysa toparla. Üç tabloyu da kontrol et:
          // yalnızca activity_types'a bakmak kısmi bozulmayı kaçırıyordu.
          final hasActivity =
              await (select(activityTypes)..limit(1)).getSingleOrNull();
          final hasSubject =
              await (select(subjects)..limit(1)).getSingleOrNull();
          final hasTopic = await (select(topics)..limit(1)).getSingleOrNull();
          if (hasActivity == null || hasSubject == null || hasTopic == null) {
            await SeedData.populate(this);
          }
        },
      );

  // NOT: `pruneAdEvents` buradan `AdEventDao.pruneOlderThan(nowMs)`'e taşındı.
  // Veritabanı sınıfı tek bir tablonun bakım işini üstlenmemeli; ayrıca
  // burada `DateTime.now()` çağrıldığı için davranış test EDİLEMİYORDU.

  /// **TÜM kullanıcı verisini siler** ve fabrika ayarlarına döner.
  ///
  /// Ayarlar → "Verileri sıfırla" akışının veri katmanı ucu. Arayüz bunu
  /// **çift onay** almadan çağırmaz (bkz. `settings_screen.dart`).
  ///
  /// Silme sırası foreign key zincirini izler: çocuk tablolar önce. `PRAGMA
  /// foreign_keys = ON` açık olduğu için ters sırada silmek
  /// `SQLITE_CONSTRAINT_FOREIGNKEY` fırlatırdı.
  ///
  /// Katalog (ders/konu/tür) SİLİNİP yeniden seed'leniyor: kullanıcının
  /// eklediği dersler de gitmeli, aksi halde "sıfırla" yarım bir işlem
  /// olurdu. Ayar satırı da yeniden kuruluyor — `onboardingCompleted`
  /// sıfırlandığı için uygulama onboarding'den başlar.
  ///
  /// Tek transaction: yarıda kalırsa veritabanı tutarsız kalır (örn.
  /// oturumlar silinmiş ama günlük özetler duruyor).
  Future<void> resetAllData() async {
    await transaction(() async {
      await delete(sessionBlocks).go();
      await delete(wrongItems).go();
      await delete(studySessions).go();
      await delete(dailyStats).go();
      await delete(goals).go();
      await delete(achievements).go();
      await delete(adEvents).go();
      await delete(appStateEntries).go();

      await delete(topics).go();
      await delete(subjects).go();
      await delete(activityTypes).go();

      await delete(userSettings).go();
    });

    // Seed ve ayar satırı transaction DIŞINDA: ikisi de kendi içinde
    // idempotent ve silme işleminin başarısını beklemeleri gerekiyor.
    await SeedData.populate(this);
    await settingsDao.ensure();
  }
}
