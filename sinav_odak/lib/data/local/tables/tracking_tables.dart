import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';
import 'catalog_tables.dart';
import 'session_tables.dart';

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get type => textEnum<GoalType>()();
  RealColumn get targetValue => real()();
  RealColumn get currentValue => real().withDefault(const Constant(0))();

  /// subjectMinutes / topicCompletion hedeflerinde dolu.
  TextColumn get subjectId => text().nullable().references(Subjects, #id)();

  TextColumn get startDate => text()(); // 'YYYY-MM-DD'
  TextColumn get endDate => text().nullable()();
  TextColumn get status =>
      textEnum<GoalStatus>().withDefault(const Constant('active'))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Günlük denormalize özet. İstatistik ekranı 500+ oturumda bile
/// tek satır okuyabilsin diye tutuluyor; her oturum kaydında yeniden hesaplanır.
@DataClassName('DailyStat')
class DailyStats extends Table {
  TextColumn get dateKey => text()();
  IntColumn get totalStudyS => integer().withDefault(const Constant(0))();
  IntColumn get totalBreakS => integer().withDefault(const Constant(0))();
  IntColumn get sessionCount => integer().withDefault(const Constant(0))();
  IntColumn get questionCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get emptyCount => integer().withDefault(const Constant(0))();
  RealColumn get net => real().withDefault(const Constant(0))();
  RealColumn get avgFocusScore => real().withDefault(const Constant(0))();

  /// {"subjectId": saniye} — pasta/bar grafik için.
  TextColumn get subjectBreakdownJson =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {dateKey};
}

/// YANLIŞ DEFTERİ (MVP).
/// Soru bankası YOK, görsel YOK, metin zorunlu DEĞİL.
/// Yanlışlar ders/konu/oturum/not bazında birikir.
@TableIndex(name: 'idx_wrong_status', columns: {#status})
@TableIndex(name: 'idx_wrong_subject', columns: {#subjectId})
@TableIndex(name: 'idx_wrong_session', columns: {#sessionId})
class WrongItems extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();

  /// Otomatik kayıtlarda oturuma bağlıdır; manuel eklemede null olabilir.
  TextColumn get sessionId => text()
      .nullable()
      .references(StudySessions, #id, onDelete: KeyAction.setNull)();

  TextColumn get subjectId =>
      text().references(Subjects, #id, onDelete: KeyAction.restrict)();
  TextColumn get topicId =>
      text().nullable().references(Topics, #id, onDelete: KeyAction.setNull)();

  /// Bu kayıtta biriken yanlış adedi.
  IntColumn get wrongCount => integer().withDefault(const Constant(1))();

  /// Opsiyonel serbest not ("zincir kuralı", "sayfa 143 soru 12"...).
  TextColumn get note => text().nullable()();

  TextColumn get status =>
      textEnum<WrongItemStatus>().withDefault(const Constant('active'))();
  IntColumn get reviewedAt => integer().nullable()();
  TextColumn get source => textEnum<WrongItemSource>()();

  @override
  Set<Column> get primaryKey => {id};
}

class Achievements extends Table {
  TextColumn get id => text()();

  /// 'streak_7', 'q_1000' gibi sabit kod.
  TextColumn get code => text().unique()();
  IntColumn get unlockedAt => integer()();
  BoolColumn get isSeen => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Yalnızca yerel reklam analitiği. 30 günden eskiler otomatik temizlenir.
class AdEvents extends Table {
  TextColumn get id => text()();
  TextColumn get adKind => textEnum<AdKind>()();
  TextColumn get placement => text()();
  TextColumn get screenName => text()();
  IntColumn get shownAt => integer()();
  BoolColumn get wasCompleted => boolean().withDefault(const Constant(false))();
  BoolColumn get wasClicked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Basit key/value. Oturum kurtarma bayrakları, son kombinasyon,
/// reklam frekans sayaçları burada.
@DataClassName('AppStateEntry')
class AppStateEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  String get tableName => 'app_state';

  @override
  Set<Column> get primaryKey => {key};
}
