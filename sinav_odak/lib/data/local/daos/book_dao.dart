import 'package:drift/drift.dart';

import '../../../core/utils/date_key.dart';
import '../../../domain/entities/enums.dart';
import '../database.dart';

part 'book_dao.g.dart';

/// PDF karnesindeki bir kitap satırı: **ad · sayfa · tarih**.
///
/// Adı `null` olabilir; yerine geçen etiketi ("Kitap") sunum katmanı
/// koyuyor. Burada `null` olarak duruyor ki "adı yok" ile "adı 'Kitap'"
/// karışmasın.
class BookLogRow {
  const BookLogRow({
    required this.title,
    required this.pagesRead,
    required this.dateKey,
    required this.durationS,
  });

  final String? title;
  final int pagesRead;
  final String dateKey;
  final int durationS;
}

/// Bir aralığın okuma toplamı.
class BookTotals {
  const BookTotals({
    required this.readingS,
    required this.pagesRead,
    required this.sessionCount,
  });

  static const empty = BookTotals(readingS: 0, pagesRead: 0, sessionCount: 0);

  final int readingS;
  final int pagesRead;
  final int sessionCount;
}

/// KİTAP OKUMA oturumları (v1.3).
///
/// **Kapanmamış (`running`) oturum hiçbir toplama girmiyor.** Süresi
/// henüz ölçülmedi, sayfası henüz sorulmadı; toplamlara katmak "şu an
/// 12 dakika okumuş" gibi sürekli değişen bir istatistik üretirdi.
/// Çalışma oturumlarında da aynı kural geçerli (`status != running`).
@DriftAccessor(tables: [BookSessions])
class BookDao extends DatabaseAccessor<AppDatabase> with _$BookDaoMixin {
  BookDao(super.db);

  Future<BookSession?> findActive() {
    return (select(bookSessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Stream<BookSession?> watchActive() {
    return (select(bookSessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<BookSession?> findById(String id) =>
      (select(bookSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertSession(BookSessionsCompanion row) =>
      into(bookSessions).insert(row);

  Future<void> patch(String id, BookSessionsCompanion patch) =>
      (update(bookSessions)..where((t) => t.id.equals(id))).write(patch);

  Future<void> deleteSession(String id) =>
      (delete(bookSessions)..where((t) => t.id.equals(id))).go();

  /// Bir GÜNÜN kapanmış okuma toplamı — `daily_stats` bunu yazıyor.
  Future<BookTotals> totalsForDay(String dayKey) async {
    final rows = await (select(bookSessions)
          ..where(
            (t) =>
                t.dateKey.equals(dayKey) &
                t.status.equalsValue(SessionStatus.running).not(),
          ))
        .get();
    return _sum(rows);
  }

  /// Bir ARALIĞIN kapanmış okuma toplamı (PDF ve istatistik kartı).
  Future<BookTotals> totalsForRange(DateTime from, DateTime to) async {
    final rows = await _rangeRows(from, to);
    return _sum(rows);
  }

  /// PDF'teki kitap listesi — en yeni okuma en üstte.
  ///
  /// [limit] rapora sığmayacak kadar uzun listeyi kesiyor; kesildiğini
  /// çağıran taraf toplamla karşılaştırarak anlayabiliyor.
  Future<List<BookLogRow>> logRows(
    DateTime from,
    DateTime to, {
    int limit = 40,
  }) async {
    final rows = await _rangeRows(from, to);
    rows.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return [
      for (final r in rows.take(limit))
        BookLogRow(
          title: r.bookTitle,
          pagesRead: r.pagesRead,
          dateKey: r.dateKey,
          durationS: r.actualDurationS,
        ),
    ];
  }

  /// Son kapanmış okumalar (ana panel / istatistik kartı).
  Stream<List<BookSession>> watchRecent({int limit = 5}) {
    return (select(bookSessions)
          ..where((t) => t.status.equalsValue(SessionStatus.running).not())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(limit))
        .watch();
  }

  Future<List<BookSession>> _rangeRows(DateTime from, DateTime to) {
    return (select(bookSessions)
          ..where(
            (t) =>
                t.dateKey.isBiggerOrEqualValue(dateKeyOf(from)) &
                t.dateKey.isSmallerOrEqualValue(dateKeyOf(to)) &
                t.status.equalsValue(SessionStatus.running).not(),
          ))
        .get();
  }

  static BookTotals _sum(List<BookSession> rows) {
    var seconds = 0;
    var pages = 0;
    for (final r in rows) {
      seconds += r.actualDurationS;
      pages += r.pagesRead;
    }
    return BookTotals(
      readingS: seconds,
      pagesRead: pages,
      sessionCount: rows.length,
    );
  }
}
