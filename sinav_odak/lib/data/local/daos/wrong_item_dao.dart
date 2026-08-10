import 'package:drift/drift.dart';

import '../../../core/utils/time.dart';
import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'wrong_item_dao.g.dart';

/// Yanlış defteri satırı + ders/konu adları (liste ekranı için).
class WrongItemView {
  const WrongItemView({
    required this.item,
    required this.subjectName,
    required this.colorHex,
    this.topicName,
  });

  final WrongItem item;
  final String subjectName;
  final String colorHex;
  final String? topicName;
}

@DriftAccessor(tables: [WrongItems])
class WrongItemDao extends DatabaseAccessor<AppDatabase>
    with _$WrongItemDaoMixin {
  WrongItemDao(super.db);

  /// Oturum sonu formunda wrong_count > 0 ise OTOMATİK çağrılır.
  ///
  /// Aynı oturum tekrar kaydedilirse (düzenleme) kopya oluşmasın diye
  /// önce o oturumun otomatik kaydı aranır.
  Future<void> upsertFromSession({
    required String id,
    required String sessionId,
    required String subjectId,
    String? topicId,
    required int wrongCount,
    String? note,
  }) async {
    final existing = await (select(wrongItems)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.source.equalsValue(WrongItemSource.auto),
          ))
        .getSingleOrNull();

    if (existing != null) {
      await (update(wrongItems)..where((t) => t.id.equals(existing.id))).write(
        WrongItemsCompanion(
          wrongCount: Value(wrongCount),
          topicId: Value(topicId),
          // Kullanıcının elle eklediği notu SİLME: yalnızca yeni bir not
          // geldiyse üzerine yaz.
          note: note == null ? const Value.absent() : Value(note),
          // mastered işaretli bir kayda yeni yanlış geldiyse listeye geri al.
          status: existing.status == WrongItemStatus.mastered
              ? const Value(WrongItemStatus.active)
              : const Value.absent(),
        ),
      );
      return;
    }

    await into(wrongItems).insert(
      WrongItemsCompanion.insert(
        id: id,
        createdAt: nowMs(),
        sessionId: Value(sessionId),
        subjectId: subjectId,
        topicId: Value(topicId),
        wrongCount: Value(wrongCount),
        note: Value(note),
        source: WrongItemSource.auto,
      ),
    );
  }

  /// wrongCount 0'a düştüğünde otomatik kaydı temizler.
  /// Aksi halde kullanıcı "Yanlışlar" sekmesinde "0 yanlış" kartı görüyordu.
  Future<void> deleteAutoFor(String sessionId) {
    return (delete(wrongItems)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.source.equalsValue(WrongItemSource.auto),
          ))
        .go();
  }

  /// Oturum silinince kayıt yetim kalmasın; manuel kayda dönüşsün.
  /// FK setNull olduğu için kayıt kalıyor ama sessionId null oluyordu;
  /// bu haliyle upsertFromSession onu bir daha asla bulamıyor ve
  /// aynı konu için ikinci bir satır oluşturuyordu.
  Future<void> detachFromSession(String sessionId) {
    return (update(wrongItems)..where((t) => t.sessionId.equals(sessionId)))
        .write(
      const WrongItemsCompanion(
        sessionId: Value(null),
        source: Value(WrongItemSource.manual),
      ),
    );
  }

  Future<void> addManual({
    required String id,
    required String subjectId,
    String? topicId,
    int wrongCount = 1,
    String? note,
  }) {
    return into(wrongItems).insert(
      WrongItemsCompanion.insert(
        id: id,
        createdAt: nowMs(),
        subjectId: subjectId,
        topicId: Value(topicId),
        wrongCount: Value(wrongCount),
        note: Value(note),
        source: WrongItemSource.manual,
      ),
    );
  }

  Stream<List<WrongItemView>> watchByStatus(WrongItemStatus status) {
    final q = select(wrongItems).join([
      innerJoin(attachedDatabase.subjects,
          attachedDatabase.subjects.id.equalsExp(wrongItems.subjectId)),
      leftOuterJoin(attachedDatabase.topics,
          attachedDatabase.topics.id.equalsExp(wrongItems.topicId)),
    ])
      ..where(wrongItems.status.equalsValue(status))
      ..orderBy([OrderingTerm.desc(wrongItems.createdAt)]);

    return q.watch().map(
          (rows) => rows
              .map(
                (r) => WrongItemView(
                  item: r.readTable(wrongItems),
                  subjectName: r.readTable(attachedDatabase.subjects).name,
                  colorHex: r.readTable(attachedDatabase.subjects).colorHex,
                  topicName: r.readTableOrNull(attachedDatabase.topics)?.name,
                ),
              )
              .toList(),
        );
  }

  /// Ders bazlı aktif yanlış sayıları — rozet ve "gelişim gerekiyor" kartı.
  Stream<Map<String, int>> watchActiveCountsBySubject() {
    final q = selectOnly(wrongItems)
      ..addColumns([wrongItems.subjectId, wrongItems.wrongCount.sum()])
      ..where(wrongItems.status.equalsValue(WrongItemStatus.active))
      ..groupBy([wrongItems.subjectId]);

    return q.watch().map((rows) {
      final map = <String, int>{};
      for (final r in rows) {
        map[r.read(wrongItems.subjectId)!] =
            r.read(wrongItems.wrongCount.sum()) ?? 0;
      }
      return map;
    });
  }

  Future<void> setStatus(String id, WrongItemStatus status) {
    return (update(wrongItems)..where((t) => t.id.equals(id))).write(
      WrongItemsCompanion(
        status: Value(status),
        reviewedAt: Value(
          status == WrongItemStatus.active ? null : nowMs(),
        ),
      ),
    );
  }

  Future<void> setNote(String id, String? note) {
    return (update(wrongItems)..where((t) => t.id.equals(id)))
        .write(WrongItemsCompanion(note: Value(note)));
  }

  Future<void> deleteItem(String id) =>
      (delete(wrongItems)..where((t) => t.id.equals(id))).go();

  Future<int> activeCount() async {
    final q = selectOnly(wrongItems)
      ..addColumns([wrongItems.id.count()])
      ..where(wrongItems.status.equalsValue(WrongItemStatus.active));
    final row = await q.getSingle();
    return row.read(wrongItems.id.count()) ?? 0;
  }
}
