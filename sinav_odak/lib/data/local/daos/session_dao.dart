import 'package:drift/drift.dart';

import '../../../core/utils/date_key.dart';
import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'session_dao.g.dart';

@DriftAccessor(tables: [StudySessions, SessionBlocks, SessionTopics, Topics])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  /// Kurtarma akışının giriş noktası: uygulama her açılışta bunu sorar.
  /// `running` durumunda EN FAZLA BİR oturum olabilir.
  Future<StudySession?> findActiveSession() {
    return (select(studySessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<StudySession?> watchActiveSession() {
    return (select(studySessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<StudySession?> findById(String id) =>
      (select(studySessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Oturumu ve tüm bloklarını tek transaction'da yazar.
  /// Oturum + bloklar + konular TEK transaction.
  ///
  /// [topicIds] çoklu konu listesi (v1.2/D). Ayrı bir çağrıya bırakılsaydı
  /// arada uygulama ölünce `topic_id` dolu ama `session_topics` boş bir
  /// oturum kalırdı — ekranda tek konu, gerçekte üç.
  Future<void> createSession(
    StudySessionsCompanion session,
    List<SessionBlocksCompanion> blocks, {
    List<String> topicIds = const [],
  }) {
    return transaction(() async {
      await into(studySessions).insert(session);
      await batch((b) => b.insertAll(sessionBlocks, blocks));

      final sessionId = session.id.value;
      for (var i = 0; i < topicIds.length; i++) {
        await into(sessionTopics).insert(
          SessionTopicsCompanion.insert(
            sessionId: sessionId,
            topicId: topicIds[i],
            sortOrder: Value(i),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> patchSession(String id, StudySessionsCompanion patch) {
    return (update(studySessions)..where((t) => t.id.equals(id))).write(patch);
  }

  Future<void> deleteSession(String id) {
    // session_blocks CASCADE ile düşer; wrong_items.session_id SET NULL olur.
    return (delete(studySessions)..where((t) => t.id.equals(id))).go();
  }

  // --- Bloklar ---

  Future<List<SessionBlock>> blocksOf(String sessionId) {
    return (select(sessionBlocks)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.indexNo)]))
        .get();
  }

  Future<void> patchBlock(String blockId, SessionBlocksCompanion patch) {
    return (update(sessionBlocks)..where((t) => t.id.equals(blockId)))
        .write(patch);
  }

  /// Mola uzatma / erken bitirme sonrası çizelge kaydırıldığında
  /// tüm blokları toplu günceller.
  Future<void> replaceBlocks(
    String sessionId,
    List<SessionBlocksCompanion> blocks,
  ) {
    return transaction(() async {
      await (delete(sessionBlocks)..where((t) => t.sessionId.equals(sessionId)))
          .go();
      await batch((b) => b.insertAll(sessionBlocks, blocks));
    });
  }

  // --- Listeler ---

  Stream<List<StudySession>> watchByDate(String dateKey) {
    return (select(studySessions)
          ..where(
            (t) =>
                t.dateKey.equals(dateKey) &
                t.status.equalsValue(SessionStatus.running).not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .watch();
  }

  Stream<List<StudySession>> watchRecent({int limit = 5}) {
    return (select(studySessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running).not())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .watch();
  }

  /// [beforeDateKey]'den ÖNCEKİ en son çalışma günü.
  ///
  /// **Neden ayrı sorgu:** `settings.lastStudyDate` bu iş için
  /// kullanılamıyor — `save()` içinde `recomputeStreak` rozetlerden ÖNCE
  /// çalışıyor ve o alanı bugüne çekiyor. Rozet hesabı sırasında okunsaydı
  /// "son oturumdan bu yana kaç gün geçti" daima 0 çıkardı.
  Future<String?> previousSessionDateKey(String beforeDateKey) async {
    final q = selectOnly(studySessions)
      ..addColumns([studySessions.dateKey])
      ..where(
        studySessions.dateKey.isSmallerThanValue(beforeDateKey) &
            studySessions.status.equalsValue(SessionStatus.running).not(),
      )
      ..orderBy([OrderingTerm.desc(studySessions.dateKey)])
      ..limit(1);
    final row = await q.getSingleOrNull();
    return row?.read(studySessions.dateKey);
  }

  Future<List<StudySession>> rangeSessions(DateTime from, DateTime to) {
    final fromKey = dateKeyOf(from);
    final toKey = dateKeyOf(to);
    return (select(studySessions)
          ..where(
            (t) =>
                t.dateKey.isBiggerOrEqualValue(fromKey) &
                t.dateKey.isSmallerOrEqualValue(toKey) &
                t.status.equalsValue(SessionStatus.running).not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  /// Yarıda kalmış oturumu "kesinti" olarak kapatır (kurtarma akışı).
  /// [focusScore] verilmezse mevcut değere DOKUNULMAZ.
  ///
  /// `Value(null)` yerine `Value.absent()` kullanılıyor: aksi halde
  /// parametresiz bir çağrı, daha önce hesaplanmış bir skoru sessizce
  /// NULL'a çevirirdi.
  Future<void> markInterrupted({
    required String id,
    required int actualDurationS,
    required int totalBreakS,
    required int endedAt,
    int? focusScore,
    int? foregroundS,
  }) {
    return patchSession(
      id,
      StudySessionsCompanion(
        status: const Value(SessionStatus.interrupted),
        actualDurationS: Value(actualDurationS),
        totalBreakS: Value(totalBreakS),
        endedAt: Value(endedAt),
        focusScore:
            focusScore == null ? const Value.absent() : Value(focusScore),
        foregroundS:
            foregroundS == null ? const Value.absent() : Value(foregroundS),
      ),
    );
  }

  /// Uygulama arka plana her geçtiğinde çağrılır (dürüst odak ölçümü).
  ///
  /// Artırma SQL seviyesinde yapılıyor; oku-sonra-yaz yapısı foreground
  /// service ayrı isolate'te çalıştığında kayıp güncellemeye yol açıyordu.
  Future<void> bumpAwayStats({
    required String id,
    required int addAwayS,
    required int addForegroundS,
    required int addExitCount,
  }) async {
    await (update(studySessions)..where((t) => t.id.equals(id))).write(
      StudySessionsCompanion.custom(
        awayS: studySessions.awayS + Variable<int>(addAwayS),
        foregroundS: studySessions.foregroundS + Variable<int>(addForegroundS),
        exitCount: studySessions.exitCount + Variable<int>(addExitCount),
      ),
    );
  }

  /// Bugün çalışılıp çalışılmadığı — streak hesabı için.
  Future<bool> hasSessionOn(String dateKey) async {
    final q = selectOnly(studySessions)
      ..addColumns([studySessions.id.count()])
      ..where(
        studySessions.dateKey.equals(dateKey) &
            studySessions.status.equalsValue(SessionStatus.running).not(),
      );
    final row = await q.getSingle();
    return (row.read(studySessions.id.count()) ?? 0) > 0;
  }
  // --- Çoklu konu (v1.2/D) ---

  /// Oturumun konularını YAZAR ve `study_sessions.topic_id`'yi listenin
  /// İLK konusuna eşitler.
  ///
  /// **İkisi tek yerden yazılıyor.** Birincil konu şemada denormalize
  /// duruyor (bkz. `SessionTopics` başlığı); iki ayrı çağrı noktasından
  /// yazılsaydı biri unutulduğunda oturum "konusuz" görünür, CSV'de ve
  /// yanlış defterinde boş çıkardı. Tek transaction: yarıda kalırsa
  /// ikisi de yazılmamış olur.
  Future<void> setSessionTopics(String sessionId, List<String> topicIds) {
    return transaction(() async {
      await (delete(sessionTopics)..where((t) => t.sessionId.equals(sessionId)))
          .go();

      for (var i = 0; i < topicIds.length; i++) {
        await into(sessionTopics).insert(
          SessionTopicsCompanion.insert(
            sessionId: sessionId,
            topicId: topicIds[i],
            sortOrder: Value(i),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      await (update(studySessions)..where((t) => t.id.equals(sessionId))).write(
        StudySessionsCompanion(
          topicId: Value(topicIds.isEmpty ? null : topicIds.first),
        ),
      );
    });
  }

  /// Oturumun konuları, kullanıcının seçtiği sırayla.
  ///
  /// **Arşivlenmiş konu da dönüyor:** geçmiş bir oturumun başlığı, konu
  /// sonradan arşivlendi diye boşalmamalı.
  Future<List<Topic>> topicsOf(String sessionId) {
    final q = select(sessionTopics).join([
      innerJoin(topics, topics.id.equalsExp(sessionTopics.topicId)),
    ])
      ..where(sessionTopics.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(sessionTopics.sortOrder)]);

    return q.map((row) => row.readTable(topics)).get();
  }

  /// Aktif oturum başlığı bunu izliyor.
  Stream<List<Topic>> watchTopicsOf(String sessionId) {
    final q = select(sessionTopics).join([
      innerJoin(topics, topics.id.equalsExp(sessionTopics.topicId)),
    ])
      ..where(sessionTopics.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(sessionTopics.sortOrder)]);

    return q.map((row) => row.readTable(topics)).watch();
  }
}
