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
    SettingsDao,
    SubjectDao,
    SessionDao,
    StatsDao,
    GoalDao,
    WrongItemDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  /// Test kolaylığı için bellek içi örnek.
  factory AppDatabase.memory() => AppDatabase(openTestConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await SeedData.populate(this);
        },
        onUpgrade: (m, from, to) async {
          // v1 ilk sürüm; ileride adım adım migration buraya.
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

  /// 30 günden eski reklam olaylarını temizler (açılışta çağrılır).
  Future<void> pruneAdEvents() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    await (delete(adEvents)..where((t) => t.shownAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
