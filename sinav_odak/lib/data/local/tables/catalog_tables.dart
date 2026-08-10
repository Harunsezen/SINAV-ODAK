import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';

/// Dersler. ASLA fiziksel silinmez; [isArchived] ile gizlenir, çünkü
/// silinen ders geçmiş istatistikleri bozar.
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// '#4F5BD5' formatında.
  TextColumn get colorHex => text().withLength(min: 4, max: 9)();

  TextColumn get examType => textEnum<ExamType>()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_topics_subject', columns: {#subjectId})
class Topics extends Table {
  TextColumn get id => text()();
  TextColumn get subjectId =>
      text().references(Subjects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get targetQuestionCount => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Dersler gibi konular da SİLİNMEZ, arşivlenir.
  /// Hard delete, konuya bağlı oturum veya yanlış kaydı varsa
  /// SQLITE_CONSTRAINT_FOREIGNKEY fırlatıyordu.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Çalışma türleri (Konu Anlatımı, Soru Çözümü, Deneme...).
class ActivityTypes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Materyal ikon adı ('menu_book' gibi). IconData codePoint YERİNE string
  /// tutuluyor: sabit olmayan IconData kullanımı `--tree-shake-icons`
  /// derlemesini kırıyor.
  TextColumn get iconKey => text().withDefault(const Constant('bolt'))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
