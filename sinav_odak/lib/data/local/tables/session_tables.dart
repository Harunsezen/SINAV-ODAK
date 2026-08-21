import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';
import '../converters/block_type_converter.dart';
import 'catalog_tables.dart';

@TableIndex(name: 'idx_sessions_date', columns: {#dateKey})
@TableIndex(name: 'idx_sessions_status', columns: {#status})
@TableIndex(name: 'idx_sessions_subject', columns: {#subjectId})
@TableIndex(name: 'idx_sessions_topic', columns: {#topicId})
class StudySessions extends Table {
  TextColumn get id => text()();

  /// 'YYYY-MM-DD' — oturumun BAŞLADIĞI yerel gün.
  TextColumn get dateKey => text()();

  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();

  /// Planlanan NET çalışma süresi (molalar hariç), saniye.
  IntColumn get plannedDurationS => integer()();

  /// Gerçekleşen çalışma süresi (molalar hariç), saniye.
  IntColumn get actualDurationS => integer().withDefault(const Constant(0))();

  IntColumn get totalBreakS => integer().withDefault(const Constant(0))();

  // restrict: bu kayıtlar arşivlenir, asla silinmez — şemada açıkça belirt.
  TextColumn get subjectId =>
      text().references(Subjects, #id, onDelete: KeyAction.restrict)();

  // setNull: konu bir şekilde silinirse oturum kaybolmasın, konusuz kalsın.
  TextColumn get topicId =>
      text().nullable().references(Topics, #id, onDelete: KeyAction.setNull)();

  TextColumn get activityTypeId =>
      text().references(ActivityTypes, #id, onDelete: KeyAction.restrict)();

  TextColumn get status => textEnum<SessionStatus>()();

  /// 0..100. Oturum kaydedilene kadar null.
  IntColumn get focusScore => integer().nullable()();

  // --- Dürüst odak ölçümü (bkz. doküman 0.2) ---
  /// Uygulama ÖNPLANDAYKEN geçen süre.
  IntColumn get foregroundS => integer().withDefault(const Constant(0))();

  /// Uygulama arka plandayken geçen süre.
  IntColumn get awayS => integer().withDefault(const Constant(0))();

  /// Oturum boyunca uygulamadan çıkma sayısı.
  IntColumn get exitCount => integer().withDefault(const Constant(0))();

  // --- Soru takibi ---
  IntColumn get questionCount => integer().withDefault(const Constant(0))();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get emptyCount => integer().withDefault(const Constant(0))();

  /// Kaydedildiği andaki katsayıyla hesaplanmış net (denormalize).
  RealColumn get net => real().withDefault(const Constant(0))();

  /// 1..5 (😖 😕 😐 🙂 😄)
  IntColumn get mood => integer().nullable()();
  TextColumn get note => text().nullable()();

  /// Mutlak zaman damgalı çizelge (JSON). Kurtarmanın ve resolve(now)'ın
  /// tek doğruluk kaynağı.
  TextColumn get scheduleJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_blocks_session', columns: {#sessionId})
class SessionBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(StudySessions, #id, onDelete: KeyAction.cascade)();

  /// Çizelgedeki sıra (0'dan başlar, çalışma ve mola karışık).
  IntColumn get indexNo => integer()();

  /// `textEnum` yerine converter: DB'ye `'breakTime'` değil **`'break'`**
  /// yazılır. Böylece `session_blocks.type` ile `schedule_json` içindeki
  /// blok tipi aynı sözleşmeyi kullanır.
  ///
  /// Temiz şema değişikliği: `schemaVersion` 1'de kalır, ancak mevcut
  /// veritabanında `'breakTime'` yazılı satır varsa converter onu çözemez —
  /// geliştirme cihazından uygulama silinmelidir.
  TextColumn get type => text().map(const BlockTypeConverter())();

  IntColumn get plannedStartAt => integer()();
  IntColumn get plannedEndAt => integer()();
  IntColumn get actualEndAt => integer().nullable()();

  IntColumn get plannedS => integer()();
  IntColumn get actualS => integer().withDefault(const Constant(0))();

  /// Mola "Molayı Bitir" ile erken kapatıldıysa true.
  BoolColumn get wasSkipped => boolean().withDefault(const Constant(false))();

  /// "+5 dk" ile eklenen toplam süre (saniye).
  IntColumn get extendedS => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bir oturumda çalışılan konular (v1.2/D).
///
/// ## Neden ayrı tablo, neden `study_sessions.topic_id` DURUYOR
///
/// v1.1'de bir oturumun tek konusu vardı. Çoklu konu için iki yol vardı:
/// `topic_id`'yi silip her okuyanı bu tabloya çevirmek, ya da tabloyu
/// EKLEYİP `topic_id`'yi **birincil konu** olarak bırakmak.
///
/// İkincisi seçildi. `topic_id`'yi okuyan altı yer var — CSV dışa
/// aktarma, "gelişim gereken konular", oturum sonu yanlış kaydı, yanlış
/// defterindeki "bu konuyu çalış", ana panel listesi ve aktif oturum
/// başlığı. Hepsi **tek bir konu** gösteriyor; çoklu listeye çevrilseler
/// bile "hangisini göstereyim" sorusunu yine cevaplamaları gerekirdi.
/// Kural açıkça yazılı olsun diye birincil konu şemada duruyor:
/// **`topic_id` = listenin İLK konusu.**
///
/// İkisinin ayrışması gerçek bir risk; bu yüzden ikisi de TEK yerden
/// (`StartSessionUseCase`) yazılıyor ve bir test eşitliği kilitliyor.
///
/// ## Süre bu konulara BÖLÜNMÜYOR
///
/// Oturum 90 dakika ve üç konu seçildiyse, her konuya 30 dakika yazmak
/// uydurma olurdu — kullanıcı hangi konuya ne kadar ayırdığını
/// bildirmiyor. Bu tablo "bu oturumda şunlara çalışıldı" etiketi;
/// istatistikteki süre oturumun kendisine ait kalıyor.
@TableIndex(name: 'idx_session_topics_topic', columns: {#topicId})
class SessionTopics extends Table {
  TextColumn get sessionId =>
      text().references(StudySessions, #id, onDelete: KeyAction.cascade)();

  /// `cascade` DEĞİL `restrict` de değil: konu silinirse satır düşsün ama
  /// oturum yaşasın. Konular zaten arşivleniyor, silinmiyor (G8); bu
  /// yalnızca son çare.
  TextColumn get topicId =>
      text().references(Topics, #id, onDelete: KeyAction.cascade)();

  /// Kullanıcının seçtiği sıra. 0 = birincil konu.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId, topicId};
}
