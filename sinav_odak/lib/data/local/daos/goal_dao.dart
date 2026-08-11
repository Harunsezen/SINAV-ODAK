import 'package:drift/drift.dart';

import '../../../core/utils/date_key.dart';
import '../../../core/utils/time.dart';
import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Stream<List<Goal>> watchActive() {
    return (select(goals)
          ..where((t) => t.status.equalsValue(GoalStatus.active))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<void> createGoal({
    required String id,
    required GoalType type,
    required double target,
    String? subjectId,
    DateTime? endDate,
  }) {
    return into(goals).insert(
      GoalsCompanion.insert(
        id: id,
        type: type,
        targetValue: target,
        subjectId: Value(subjectId),
        startDate: todayKey(),
        endDate: Value(endDate == null ? null : dateKeyOf(endDate)),
        createdAt: nowMs(),
      ),
    );
  }

  Future<void> setProgress(String id, double current) {
    return (update(goals)..where((t) => t.id.equals(id)))
        .write(GoalsCompanion(currentValue: Value(current)));
  }

  Future<void> setStatus(String id, GoalStatus status) {
    return (update(goals)..where((t) => t.id.equals(id)))
        .write(GoalsCompanion(status: Value(status)));
  }

  Future<void> deleteGoal(String id) =>
      (delete(goals)..where((t) => t.id.equals(id))).go();

  /// Tüm hedefler — Hedefler ekranı aktif ve tamamlananları birlikte gösterir.
  Stream<List<Goal>> watchAll() {
    return (select(goals)
          ..orderBy([
            // Aktifler üstte: kullanıcı önce üzerinde çalıştığını görmeli.
            (t) => OrderingTerm.asc(t.status),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }
}
