// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/ad_providers.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/ports/ad_gateway.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/done_screen.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';

import '../unit/ad_helpers.dart';
import '../unit/usecase_helpers.dart';

/// FAZ 4 — Ara reklam (Done → Home geçişi).
///
/// Ara reklamın TEK tetikleyicisi bu geçiş. Kritik davranış: reklam
/// gösterilse de gösterilmese de kullanıcı ana panele **her hâlükârda**
/// ulaşır — akış reklama bağlı değildir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingAdGateway gateway;
  late int fakeNow;

  setUp(() {
    db = newDb();
    gateway = RecordingAdGateway();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  Future<void> setConsent({required bool consent}) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      UserSettingsCompanion(personalizedAdsConsent: Value(consent)),
    );
  }

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/done',
        routes: [
          GoRoute(path: '/run/done', builder: (_, __) => const DoneScreen()),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
          ),
          GoRoute(
            path: '/session/subject',
            builder: (_, __) => const Scaffold(body: Text('DERS SEÇİMİ')),
          ),
        ],
      );

  Future<ProviderContainer> pumpDone(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        adGatewayProvider.overrideWithValue(gateway as AdGateway),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();

    container.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapHome(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('done-home')));
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------

  testWidgets('rıza VARSA ara reklam gösteriliyor ve ana panele geçiliyor',
      (tester) async {
    await setConsent(consent: true);
    await pumpDone(tester);
    await tapHome(tester);

    expect(gateway.shownInterstitials, [AdPlacement.doneInterstitial]);
    expect(find.text('ANA PANEL'), findsOneWidget);
  });

  testWidgets('rıza YOKSA reklam gösterilmiyor ama geçiş yine oluyor',
      (tester) async {
    await setConsent(consent: false);
    await pumpDone(tester);
    await tapHome(tester);

    expect(gateway.shownInterstitials, isEmpty, reason: 'rızasız reklam YOK');
    expect(
      find.text('ANA PANEL'),
      findsOneWidget,
      reason: 'akış reklama bağlı DEĞİL',
    );
  });

  testWidgets('90 sn dolmadıysa reklam yok, geçiş yine oluyor',
      (tester) async {
    await setConsent(consent: true);
    // 30 sn önce bir ara reklam gösterilmiş.
    await db.adEventDao.logShown(
      id: 'onceki',
      placement: AdPlacement.doneInterstitial,
      shownAtMs: t0 - 30000,
    );

    await pumpDone(tester);
    await tapHome(tester);

    expect(gateway.shownInterstitials, isEmpty, reason: 'frekans kapısı');
    expect(find.text('ANA PANEL'), findsOneWidget);
  });

  testWidgets('90 sn dolduysa reklam yeniden gösteriliyor', (tester) async {
    await setConsent(consent: true);
    await db.adEventDao.logShown(
      id: 'onceki',
      placement: AdPlacement.doneInterstitial,
      shownAtMs: t0 - 90000,
    );

    await pumpDone(tester);
    await tapHome(tester);

    expect(gateway.shownInterstitials, [AdPlacement.doneInterstitial]);
  });

  testWidgets('[Yeni oturum] ara reklam GÖSTERMİYOR', (tester) async {
    await setConsent(consent: true);
    await pumpDone(tester);

    await tester.tap(find.byKey(const Key('done-new-session')));
    await tester.pumpAndSettle();

    expect(
      gateway.shownInterstitials,
      isEmpty,
      reason: 'tek tetikleyici Done->Home geçişi',
    );
    expect(find.text('DERS SEÇİMİ'), findsOneWidget);
  });

  testWidgets('tebrik ekranının KENDİSİNDE reklam yok (G7)', (tester) async {
    await setConsent(consent: true);
    await pumpDone(tester);

    expect(find.text('Sponsorlu'), findsNothing);
    expect(gateway.loadedBanners, isEmpty);
    expect(gateway.loadedNatives, isEmpty);
    expect(
      gateway.shownInterstitials,
      isEmpty,
      reason: 'ekran açılışında değil, yalnızca GEÇİŞTE',
    );
  });
}
