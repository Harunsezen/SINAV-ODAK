// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
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
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/ads/native_ad_slot.dart';

import '../unit/usecase_helpers.dart';

/// v1.5.2 — **MOLA KARTI GERÇEKTEN REKLAM ÇİZİYOR MU?**
///
/// Banner'ın hikâyesinin aynısı burada da yaşandı ve banner düzeltilirken
/// gözden kaçtı: `loadNative` projede **hiçbir yerden çağrılmıyordu**.
/// Mola ekranındaki kart, üstünde "Sponsorlu" yazan gri bir kutudan
/// ibaretti; ne istek gitti ne gösterim oluştu.
///
/// Eski testler kartın BELİRDİĞİNİ ve etiketin durduğunu soruyordu —
/// ikisi de yeşildi. Buradaki testler kartın İÇİNİ soruyor.
class _NativeGateway implements AdGateway {
  _NativeGateway(this.handle);

  final Object? handle;
  int loadCalls = 0;
  final released = <Object?>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> loadBanner(AdPlacement placement) async => null;

  @override
  Future<Object?> loadNative(AdPlacement placement) async {
    loadCalls++;
    return handle;
  }

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
    _NativeGateway gw, {
    AdViewBuilder? builder,
  }) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(adsEnabled: Value(true)),
    );
    await seedRunningSession(db, id: 's1', sch: schedule());

    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Molanın başı: 300 sn kaldı, kısa mola eşiğinin (180) üstünde.
        clockProvider.overrideWithValue(() => breakStart + 1000),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        adGatewayProvider.overrideWithValue(gw as AdGateway),
        if (builder != null) adViewBuilderProvider.overrideWithValue(builder),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);
    await c.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: NativeAdSlot(placement: AdPlacement.breakNative),
          ),
        ),
      ),
    );
    await tester.pump(NativeAdSlot.revealDelay);
    await tester.pump();
    return c;
  }

  testWidgets('yüklenen native reklam EKRANA ÇİZİLİYOR', (tester) async {
    final gw = _NativeGateway(Object());
    await pump(tester, gw, builder: fakeView);

    expect(
      find.byKey(const Key('CIZILEN-REKLAM')),
      findsOneWidget,
      reason: 'kart yalnızca gri kutu olmamalı — içinde reklam olmalı',
    );
    expect(find.text('Sponsorlu'), findsOneWidget);
    expect(gw.loadCalls, 1, reason: 'kart gerçekten reklam istemeli');
  });

  testWidgets('reklam GELMEZSE kart hiç çizilmiyor', (tester) async {
    final gw = _NativeGateway(null);
    await pump(tester, gw, builder: fakeView);

    expect(find.byKey(const Key('native-slot-breakNative')), findsNothing);
    expect(
      tester.getSize(find.byType(NativeAdSlot)).height,
      0,
      reason: 'boş gri kutu molada yer kaplamamalı',
    );
  });

  testWidgets('istek GECİKMEYİ BEKLEMEDEN gidiyor', (tester) async {
    // Kart 1.2 sn sonra beliriyor ama isteği o âna kadar bekletmek,
    // kartın gelişini yükleme süresi kadar daha geciktirirdi.
    final gw = _NativeGateway(Object());
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(adsEnabled: Value(true)),
    );
    await seedRunningSession(db, id: 's1', sch: schedule());

    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => breakStart + 1000),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        adGatewayProvider.overrideWithValue(gw as AdGateway),
        adViewBuilderProvider.overrideWithValue(fakeView),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);
    await c.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(
            body: NativeAdSlot(placement: AdPlacement.breakNative),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      gw.loadCalls,
      1,
      reason: 'istek kart belirmeden ÖNCE başlamalı',
    );
    expect(
      find.byKey(const Key('native-slot-breakNative')),
      findsNothing,
      reason: 'istek erken gitse de kart gecikmeden önce GÖRÜNMEMELİ',
    );

    await tester.pump(NativeAdSlot.revealDelay);
    expect(find.byKey(const Key('native-slot-breakNative')), findsOneWidget);
  });

  testWidgets('kart EKRANDAN ÇIKINCA reklam serbest bırakılıyor',
      (tester) async {
    // `AdWidget` aynı nesneyi ağaca ikinci kez alamıyor; bırakılmazsa her
    // molada yeni bir native reklam sızar.
    final handle = Object();
    final gw = _NativeGateway(handle);
    final c = await pump(tester, gw, builder: fakeView);

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
