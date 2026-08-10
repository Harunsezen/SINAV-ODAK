import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/local/daos/ad_event_dao.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// FAZ 4 — Reklam olay günlüğü.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  const day = 86400000;

  test('gösterim kaydı formatı ve ekran adıyla yazılıyor', () async {
    await db.adEventDao.logShown(
      id: 'e1',
      placement: AdPlacement.breakNative,
      shownAtMs: t0,
    );

    final rows = await db.adEventDao.all();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'e1');
    expect(rows.single.adKind, AdKind.native);
    expect(rows.single.placement, 'breakNative');
    expect(rows.single.screenName, 'break');
    expect(rows.single.shownAt, t0);
    expect(rows.single.wasClicked, isFalse);
    expect(rows.single.wasCompleted, isFalse);
  });

  test('tıklama ve tamamlanma işaretleniyor', () async {
    await db.adEventDao.logShown(
      id: 'e1',
      placement: AdPlacement.doneInterstitial,
      shownAtMs: t0,
    );

    await db.adEventDao.markClicked('e1');
    await db.adEventDao.markCompleted('e1');

    final row = (await db.adEventDao.all()).single;
    expect(row.wasClicked, isTrue);
    expect(row.wasCompleted, isTrue);
  });

  test('30 GÜNDEN eski kayıtlar siliniyor, yeniler kalıyor', () async {
    await db.adEventDao
        .logShown(id: 'eski', placement: AdPlacement.homeBanner, shownAtMs: t0 - 31 * day);
    await db.adEventDao
        .logShown(id: 'sinir', placement: AdPlacement.homeBanner, shownAtMs: t0 - 30 * day);
    await db.adEventDao
        .logShown(id: 'yeni', placement: AdPlacement.homeBanner, shownAtMs: t0 - day);

    final deleted = await db.adEventDao.pruneOlderThan(t0);

    expect(deleted, 1, reason: 'yalnızca 31 günlük kayıt düşmeli');
    final ids = (await db.adEventDao.all()).map((e) => e.id).toSet();
    expect(ids, {'sinir', 'yeni'});
  });

  test('prune saati PARAMETRE: sabit epoch ile deterministik', () async {
    await db.adEventDao
        .logShown(id: 'e1', placement: AdPlacement.homeBanner, shownAtMs: t0);

    // "Şimdi" 29 gün sonra: kayıt durur.
    expect(await db.adEventDao.pruneOlderThan(t0 + 29 * day), 0);
    // "Şimdi" 31 gün sonra: kayıt düşer.
    expect(await db.adEventDao.pruneOlderThan(t0 + 31 * day), 1);
  });

  test('lastShownAt yer BAZINDA en son gösterimi döndürüyor', () async {
    await db.adEventDao.logShown(
      id: 'i1',
      placement: AdPlacement.doneInterstitial,
      shownAtMs: t0,
    );
    await db.adEventDao.logShown(
      id: 'i2',
      placement: AdPlacement.doneInterstitial,
      shownAtMs: t0 + 120000,
    );
    await db.adEventDao.logShown(
      id: 'b1',
      placement: AdPlacement.homeBanner,
      shownAtMs: t0 + 999999,
    );

    expect(
      await db.adEventDao.lastShownAt(AdPlacement.doneInterstitial),
      t0 + 120000,
      reason: 'başka yerin kaydı frekans kapısını etkilememeli',
    );
  });

  test('hiç gösterim yoksa lastShownAt null (kapı açık)', () async {
    expect(
      await db.adEventDao.lastShownAt(AdPlacement.doneInterstitial),
      isNull,
    );
  });

  test('retentionDays sözleşmesi 30 gün', () {
    expect(AdEventDao.retentionDays, 30);
  });
}
