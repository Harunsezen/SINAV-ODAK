import 'package:drift/drift.dart';

import '../../../core/utils/time.dart';
import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'subject_dao.g.dart';

@DriftAccessor(tables: [Subjects, Topics, ActivityTypes])
class SubjectDao extends DatabaseAccessor<AppDatabase> with _$SubjectDaoMixin {
  SubjectDao(super.db);

  // --- Dersler ---

  /// Bir sınav türünün dersleri.
  ///
  /// [includeArchived] yalnızca KATALOG YÖNETİMİ ekranı için `true`:
  /// oturum kurulumunda arşivlenmiş ders görünmemeli, ama yönetim
  /// ekranında arşivden çıkarabilmek için listelenmesi gerekiyor.
  Stream<List<Subject>> watchSubjects(
    ExamType exam, {
    bool includeArchived = false,
  }) {
    return (select(subjects)
          ..where(
            (t) => includeArchived
                ? t.examType.equalsValue(exam)
                : t.examType.equalsValue(exam) & t.isArchived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<Subject?> findSubject(String id) =>
      (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> createSubject({
    required String id,
    required String name,
    required String colorHex,
    required ExamType exam,
  }) async {
    final maxOrder = await _nextSubjectOrder(exam);
    await into(subjects).insert(
      SubjectsCompanion.insert(
        id: id,
        name: name,
        colorHex: colorHex,
        examType: exam,
        sortOrder: Value(maxOrder),
        createdAt: nowMs(),
      ),
    );
  }

  Future<int> _nextSubjectOrder(ExamType exam) async {
    final q = selectOnly(subjects)
      ..addColumns([subjects.sortOrder.max()])
      ..where(subjects.examType.equalsValue(exam));
    final row = await q.getSingleOrNull();
    return (row?.read(subjects.sortOrder.max()) ?? -1) + 1;
  }

  Future<void> renameSubject(String id, String name, String colorHex) {
    return (update(subjects)..where((t) => t.id.equals(id))).write(
      SubjectsCompanion(name: Value(name), colorHex: Value(colorHex)),
    );
  }

  /// Ders SİLİNMEZ, arşivlenir — geçmiş istatistikler bozulmasın diye.
  Future<void> setArchived(String id, {required bool archived}) {
    return (update(subjects)..where((t) => t.id.equals(id)))
        .write(SubjectsCompanion(isArchived: Value(archived)));
  }

  // --- Konular ---

  /// Tek konu — **arşivlenmiş olsa da** döner.
  ///
  /// [watchTopics] arşivlenmişleri gizler; geçmiş bir oturumun konu adını
  /// göstermek için bu ayrım şart: ders arşivlendi diye eski oturumun
  /// başlığı boşalmamalı.
  Future<Topic?> findTopic(String id) =>
      (select(topics)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Topic>> watchTopics(
    String subjectId, {
    bool includeArchived = false,
  }) {
    return (select(topics)
          ..where(
            (t) => includeArchived
                ? t.subjectId.equals(subjectId)
                : t.subjectId.equals(subjectId) & t.isArchived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<void> createTopic({
    required String id,
    required String subjectId,
    required String name,
    int? targetQuestionCount,
  }) async {
    final q = selectOnly(topics)
      ..addColumns([topics.sortOrder.max()])
      ..where(topics.subjectId.equals(subjectId));
    final row = await q.getSingleOrNull();
    final order = (row?.read(topics.sortOrder.max()) ?? -1) + 1;

    await into(topics).insert(
      TopicsCompanion.insert(
        id: id,
        subjectId: subjectId,
        name: name,
        targetQuestionCount: Value(targetQuestionCount),
        sortOrder: Value(order),
        createdAt: nowMs(),
      ),
    );
  }

  Future<void> setTopicCompleted(String id, {required bool completed}) {
    return (update(topics)..where((t) => t.id.equals(id))).write(
      TopicsCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? nowMs() : null),
      ),
    );
  }

  /// Konu SİLİNMEZ, arşivlenir — derslerdeki politikanın aynısı.
  /// Hard delete, konuya bağlı oturum veya yanlış kaydı varsa
  /// SQLITE_CONSTRAINT_FOREIGNKEY fırlatıyordu.
  Future<void> archiveTopic(String id, {bool archived = true}) {
    return (update(topics)..where((t) => t.id.equals(id)))
        .write(TopicsCompanion(isArchived: Value(archived)));
  }

  // --- Çalışma türleri ---

  Stream<List<ActivityType>> watchActivityTypes({
    bool includeArchived = false,
  }) {
    return (select(activityTypes)
          ..where(
            (t) => includeArchived
                ? const Constant(true)
                : t.isArchived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<void> createActivityType({
    required String id,
    required String name,
    String iconKey = 'bolt',
  }) async {
    final q = selectOnly(activityTypes)
      ..addColumns([activityTypes.sortOrder.max()]);
    final row = await q.getSingleOrNull();
    final order = (row?.read(activityTypes.sortOrder.max()) ?? -1) + 1;

    await into(activityTypes).insert(
      ActivityTypesCompanion.insert(
        id: id,
        name: name,
        iconKey: Value(iconKey),
        sortOrder: Value(order),
      ),
    );
  }

  /// Konu adı ve hedef soru sayısı düzenleme (KATALOG YÖNETİMİ).
  Future<void> renameTopic(String id, String name) {
    return (update(topics)..where((t) => t.id.equals(id)))
        .write(TopicsCompanion(name: Value(name)));
  }

  Future<void> renameActivityType(String id, String name) {
    return (update(activityTypes)..where((t) => t.id.equals(id)))
        .write(ActivityTypesCompanion(name: Value(name)));
  }

  /// Çalışma türü de SİLİNMEZ, arşivlenir (G8 politikasının aynısı):
  /// türe bağlı geçmiş oturumlar var ve `onDelete: restrict` tanımlı.
  Future<void> setActivityTypeArchived(String id, {required bool archived}) {
    return (update(activityTypes)..where((t) => t.id.equals(id)))
        .write(ActivityTypesCompanion(isArchived: Value(archived)));
  }
}
