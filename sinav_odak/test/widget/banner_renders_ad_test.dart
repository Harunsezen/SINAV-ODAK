import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/ad_providers.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/ports/ad_gateway.dart';
import 'package:sinav_odak/presentation/ads/banner_ad_slot.dart';

import '../unit/usecase_helpers.dart';

/// v1.5.1 — **REKLAM GERÇEKTEN EKRANA KONUYOR MU?**
///
/// ## Neden bu dosya var
///
/// Uygulama aylarca hiç reklam gösteremedi ve kimse fark etmedi, çünkü
/// eksik olan şey testlerin baktığı yerde değildi:
///
/// - `AdWidget` projede HİÇ kullanılmıyordu. `bannerLoadedProvider`
///   yüklenen reklam nesnesini `handle != null` diye bool'a çevirip
///   ATIYORDU; yuva yalnızca gri bir kutu ile "Sponsorlu" yazısı
///   çiziyordu. Gösterim hiç oluşmadı, kazanç da.
/// - Eski testler "yuva göründü mü" ve "etiket var mı" diye soruyordu.
///   İkisi de YEŞİLDİ. Reklamın kendisini kimse sormamıştı.
///
/// Buradaki testler o soruyu soruyor: **yükleyicinin döndürdüğü nesne,
/// ekranda çizilen widget'a dönüşüyor mu?**
class _HandleGateway implements AdGateway {
  _HandleGateway(this.handle);

  final Object? handle;
  int loadCalls = 0;
  final released = <Object?>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> loadBanner(AdPlacement placement) async {
    loadCalls++;
    return handle;
  }

  @override
  Future<Object?> loadNative(AdPlacement placement) async => null;

  @override
  Future<bool> showInterstitial(AdPlacement placement) async => false;

  @override
  Future<bool> showRewarded(AdPlacement placement) async => false;

  @override
  Future<void> releaseAd(Object? h) async => released.add(h);

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Gerçek AdMob yerine tanınabilir bir widget çizen köprü.
  Widget? fakeView(Object? handle) =>
      handle == null ? null : const SizedBox(key: Key('CIZILEN-REKLAM'));

  Future<ProviderContainer> pump(
    WidgetTester tester,
    _HandleGateway gw, {
    AdViewBuilder? builder,
  }) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(adsEnabled: Value(true)),
    );
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        adGatewayProvider.overrideWithValue(gw as AdGateway),
        if (builder != null) adViewBuilderProvider.overrideWithValue(builder),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: BannerAdSlot(placement: AdPlacement.homeBanner),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('yüklenen reklam EKRANA ÇİZİLİYOR', (tester) async {
    final gw = _HandleGateway(Object());
    await pump(tester, gw, builder: fakeView);

    expect(
      find.byKey(const Key('CIZILEN-REKLAM')),
      findsOneWidget,
      reason: 'yükleyicinin döndürdüğü nesne widget\'a dönüşmeli — '
          'bu olmadan gösterim ve kazanç OLUŞMAZ',
    );
    expect(find.text('Sponsorlu'), findsOneWidget);
    expect(gw.loadCalls, 1, reason: 'yuva gerçekten reklam istemeli');
  });

  testWidgets('reklam GELMEZSE hiç yer ayrılmıyor', (tester) async {
    final gw = _HandleGateway(null);
    await pump(tester, gw, builder: fakeView);

    expect(find.byKey(const Key('banner-slot-homeBanner')), findsNothing);
    expect(find.byKey(const Key('CIZILEN-REKLAM')), findsNothing);
    expect(
      tester.getSize(find.byType(BannerAdSlot)).height,
      0,
      reason: 'boş şerit bile kalmamalı',
    );
  });

  testWidgets('köprü bağlanmamışsa yuva yine ÇÖKMÜYOR', (tester) async {
    // `adViewBuilderProvider` override edilmezse (varsayılan: null döner)
    // etiketli boş şerit kalır ve hiçbir şey patlamaz.
    final gw = _HandleGateway(Object());
    await pump(tester, gw);

    expect(find.byKey(const Key('banner-slot-homeBanner')), findsOneWidget);
    expect(find.text('Sponsorlu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yuva EKRANDAN ÇIKINCA reklam serbest bırakılıyor',
      (tester) async {
    // İki sebep: (1) bırakılmazsa her açılışta yeni bir BannerAd sızar,
    // (2) `AdWidget` aynı nesneyi ağaca İKİNCİ KEZ alamıyor — ekrandan
    // çıkıp dönen kullanıcıda hata verirdi.
    final handle = Object();
    final gw = _HandleGateway(handle);
    final c = await pump(tester, gw, builder: fakeView);

    // Yuvayı ağaçtan çıkar: autoDispose devreye girsin.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    await tester.pumpAndSettle();

    expect(gw.released, contains(handle));
  });
}
