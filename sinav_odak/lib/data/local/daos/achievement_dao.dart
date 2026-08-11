import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'achievement_dao.g.dart';

/// Tüm zamanların toplamı — rozet değerlendirmesini besler.
class LifetimeTotals {
  const LifetimeTotals({
    required this.sessionCount,
    required this.studyS,
    required this.questionCount,
  });

  static const empty =
      LifetimeTotals(sessionCount: 0, studyS: 0, questionCount: 0);

  final int sessionCount;
  final int studyS;
  final int questionCount;
}

@DriftAccessor(tables: [Achievements, StudySessions])
class AchievementDao extends DatabaseAccessor<AppDatabase>
    with _$AchievementDaoMixin {
  AchievementDao(super.db);

  Stream<List<Achievement>> watchAll() {
    return (select(achievements)
          ..orderBy([(t) => OrderingTerm.desc(t.unlockedAt)]))
        .watch();
  }

  Future<Set<String>> unlockedCodes() async {
    final rows = await select(achievements).get();
    return rows.map((r) => r.code).toSet();
  }

  /// Rozeti açar. Zaten açıksa **hiçbir şey yapmaz**.
  ///
  /// `insertOnConflictUpdate` DEĞİL: `unlockedAt` sürekli güncellenirdi ve
  /// kullanıcı "ilk oturum" rozetini 300. oturumda kazanmış görünürdü.
  Future<void> unlock({
    required String code,
    required int unlockedAtMs,
  }) async {
    await into(achievements).insert(
      AchievementsCompanion.insert(
        id: 'ach_$code',
        code: code,
        unlockedAt: unlockedAtMs,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> markSeen(String code) {
    return (update(achievements)..where((t) => t.code.equals(code)))
        .write(const AchievementsCompanion(isSeen: Value(true)));
  }

  Future<int> unseenCount() async {
    final rows = await (select(achievements)
          ..where((t) => t.isSeen.equals(false)))
        .get();
    return rows.length;
  }

  /// Tüm zamanların toplamı.
  ///
  /// `daily_stats` yerine `study_sessions` üzerinden: günlük özet yalnızca
  /// tamamlanmış günleri taşıyor ve rozet hesabı oturum bazlı sayım
  /// istiyor (örn. "ilk oturum").
  Future<LifetimeTotals> lifetimeTotals() async {
    final row = await customSelect(
      '''
      SELECT COUNT(*)                  AS c,
             SUM(actual_duration_s)    AS s,
             SUM(question_count)       AS q
      FROM study_sessions
      WHERE status != ?
      ''',
      variables: [Variable<String>(SessionStatus.running.name)],
      readsFrom: {studySessions},
    ).getSingleOrNull();

    if (row == null) return LifetimeTotals.empty;
    return LifetimeTotals(
      sessionCount: row.read<int?>('c') ?? 0,
      studyS: row.read<int?>('s') ?? 0,
      questionCount: row.read<int?>('q') ?? 0,
    );
  }
}
