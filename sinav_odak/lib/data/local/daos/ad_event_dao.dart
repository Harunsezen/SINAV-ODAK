import 'package:drift/drift.dart';

import '../../../domain/entities/ad_placement.dart';
import '../database.dart';

part 'ad_event_dao.g.dart';

/// Reklam olay günlüğü.
///
/// **Neden loglanıyor?** Gelir ölçümü değil — o AdMob konsolunda var. Buradaki
/// kayıt, **politika ihlallerini tespit edebilmek** için: "çalışma bloğunda
/// interstitial gösterildi mi?" sorusu ancak `screen_name` ve `shown_at`
/// kayıtlıysa yanıtlanabilir. Ayrıca frekans kapısının son gösterim anı
/// buradan okunur.
///
/// **Neden ayrı DAO?** `pruneAdEvents` daha önce `AppDatabase` gövdesindeydi;
/// veritabanı sınıfı tek bir tablonun bakım işini üstlenmiş oluyordu. Tablo
/// başına DAO kuralı bozulmuştu.
@DriftAccessor(tables: [AdEvents])
class AdEventDao extends DatabaseAccessor<AppDatabase> with _$AdEventDaoMixin {
  AdEventDao(super.db);

  /// 30 gün: Play/AdMob denetiminde son bir aylık davranışı göstermeye yeter,
  /// cihazda sınırsız büyümez.
  static const int retentionDays = 30;

  /// Bir gösterim kaydeder.
  ///
  /// [id] çağıran tarafından üretilir (uuid); aynı gösterimin tıklama ve
  /// tamamlanma güncellemeleri bu kimlik üzerinden yapılır.
  Future<void> logShown({
    required String id,
    required AdPlacement placement,
    required int shownAtMs,
  }) {
    return into(adEvents).insert(
      AdEventsCompanion.insert(
        id: id,
        adKind: placement.kind,
        placement: placement.name,
        screenName: placement.screenName,
        shownAt: shownAtMs,
      ),
    );
  }

  Future<void> markClicked(String id) {
    return (update(adEvents)..where((t) => t.id.equals(id)))
        .write(const AdEventsCompanion(wasClicked: Value(true)));
  }

  /// Ödüllü/ara reklamın sonuna kadar izlendiğini işaretler.
  Future<void> markCompleted(String id) {
    return (update(adEvents)..where((t) => t.id.equals(id)))
        .write(const AdEventsCompanion(wasCompleted: Value(true)));
  }

  /// [nowMs]'e göre [retentionDays] günden eski kayıtları siler.
  ///
  /// Zaman **parametre**: `DateTime.now()` çağrılsaydı bu davranış test
  /// edilemezdi (sabit epoch kuralı).
  Future<int> pruneOlderThan(int nowMs, {int days = retentionDays}) {
    final cutoff = nowMs - Duration(days: days).inMilliseconds;
    return (delete(adEvents)..where((t) => t.shownAt.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Frekans kapısı için son gösterim anı. Hiç yoksa `null`.
  Future<int?> lastShownAt(AdPlacement placement) async {
    final row = await (select(adEvents)
          ..where((t) => t.placement.equals(placement.name))
          ..orderBy([(t) => OrderingTerm.desc(t.shownAt)])
          ..limit(1))
        .getSingleOrNull();
    return row?.shownAt;
  }

  Future<List<AdEvent>> all() =>
      (select(adEvents)..orderBy([(t) => OrderingTerm.desc(t.shownAt)])).get();
}
