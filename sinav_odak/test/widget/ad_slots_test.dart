// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/ads/banner_ad_slot.dart';
import 'package:sinav_odak/presentation/ads/native_ad_slot.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 4 — Reklam yuvaları.
///
/// Yuvalar `NoopAdGateway` ile çalışıyor: gerçek AdMob platform kanalı
/// gerektirir ve host testinde çağrılamaz. Doğrulanan şey **politika
/// davranışı**: izin yoksa hiç yer ayrılmaması.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  /// Rıza ve odak ekranı ayarını yazar.
  Future<void> setAds({
    required bool consent,
    bool showInFocusScreen = true,
  }) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      UserSettingsCompanion(
        personalizedAdsConsent: Value(consent),
        showAdsInFocusScreen: Value(showInFocusScreen),
      ),
    );
  }

  Future<ProviderContainer> pumpSlot(
    WidgetTester tester,
    Widget slot,
  ) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);

    // Ayar ve oturum akışlarını ısıt: ilk değer gelmeden widget kurulursa
    // rıza bir çerçeve boyunca `false` görünür.
    await container.read(settingsStreamProvider.future);
    await container.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Scaffold(body: slot),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  // --- BANNER ---

  testWidgets('banner: RIZA YOKSA hiç yer ayrılmıyor', (tester) async {
    await setAds(consent: false);
    await pumpSlot(
      tester,
      const BannerAdSlot(placement: AdPlacement.homeBanner),
    );

    expect(find.byKey(const Key('banner-slot-homeBanner')), findsNothing);
    expect(find.text('Sponsorlu'), findsNothing);
    expect(
      tester.getSize(find.byType(BannerAdSlot)).height,
      0,
      reason: 'boş çerçeve bile bırakılmamalı',
    );
  });

  // FAZ 4.2: etiket artık reklamın YÜKLENİP yüklenmediğine bağlı.
  // Testteki `NoopAdGateway` hiç reklam döndürmediği için offline metni
  // çıkıyor. Korunan değişmez: **rıza varsa yuva ayrılır**, yoksa hiç yer
  // ayrılmaz. Etiket metninin iki hâli `faz4_test.dart`'ta iddia ediliyor.
  testWidgets(
      'banner: rıza varsa yuva ayrılıyor (etiket yükleme durumuna bağlı)',
      (tester) async {
    await setAds(consent: true);
    await pumpSlot(
      tester,
      const BannerAdSlot(placement: AdPlacement.homeBanner),
    );

    expect(find.byKey(const Key('banner-slot-homeBanner')), findsOneWidget);
    expect(find.byKey(const Key('banner-label-homeBanner')), findsOneWidget);
    expect(
      tester.getSize(find.byType(BannerAdSlot)).height,
      BannerAdSlot.height,
    );
  });

  testWidgets('run banner: odak ekranı ayarı KAPALIYSA gösterilmiyor',
      (tester) async {
    await setAds(consent: true, showInFocusScreen: false);
    await pumpSlot(
      tester,
      const BannerAdSlot(placement: AdPlacement.runBanner),
    );

    expect(find.byKey(const Key('banner-slot-runBanner')), findsNothing);
  });

  testWidgets('run banner: ayar açıksa ÇALIŞMA BLOĞUNDA da gösteriliyor',
      (tester) async {
    await setAds(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpSlot(
      tester,
      const BannerAdSlot(placement: AdPlacement.runBanner),
    );

    expect(
      find.byKey(const Key('banner-slot-runBanner')),
      findsOneWidget,
      reason: 'yasak TAM EKRAN için; ince banner serbest',
    );
  });

  // --- NATIVE ---

  testWidgets('native: RIZA YOKSA hiç yer ayrılmıyor', (tester) async {
    await setAds(consent: false);
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = breakStart + 1000;
    await pumpSlot(
      tester,
      const NativeAdSlot(placement: AdPlacement.breakNative),
    );
    await tester.pump(NativeAdSlot.revealDelay);

    expect(find.byKey(const Key('native-slot-breakNative')), findsNothing);
  });

  testWidgets('native: 1200 ms GECİKMEYLE beliriyor', (tester) async {
    await setAds(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    // Molanın başı: 300 sn kaldı, eşiğin (180) üstünde.
    fakeNow = breakStart + 1000;
    await pumpSlot(
      tester,
      const NativeAdSlot(placement: AdPlacement.breakNative),
    );

    expect(
      find.byKey(const Key('native-slot-breakNative')),
      findsNothing,
      reason: 'gecikme dolmadan kart belirmemeli',
    );

    await tester.pump(const Duration(milliseconds: 1199));
    expect(find.byKey(const Key('native-slot-breakNative')), findsNothing);

    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byKey(const Key('native-slot-breakNative')), findsOneWidget);
    expect(find.textContaining('Sponsorlu'), findsWidgets);
  });

  testWidgets('native: butonlardan en az 48dp uzakta', (tester) async {
    await setAds(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = breakStart + 1000;
    await pumpSlot(
      tester,
      const NativeAdSlot(placement: AdPlacement.breakNative),
    );
    await tester.pump(NativeAdSlot.revealDelay);

    final padding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.byKey(const Key('native-slot-breakNative')),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      (padding.padding as EdgeInsets).bottom,
      greaterThanOrEqualTo(NativeAdSlot.minButtonGap),
      reason: 'kazara tıklama hem kullanıcıyı hem hesabı yakar',
    );
  });

  testWidgets('native: mola KISAYSA (<= 3 dk) gösterilmiyor', (tester) async {
    await setAds(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    // Molanın son 2 dakikası: 5 dk molanın 3. dakikası dolmuş.
    fakeNow = breakEnd - 120000;
    await pumpSlot(
      tester,
      const NativeAdSlot(placement: AdPlacement.breakNative),
    );
    await tester.pump(NativeAdSlot.revealDelay);

    expect(find.byKey(const Key('native-slot-breakNative')), findsNothing);
  });

  testWidgets('native: ÇALIŞMA BLOĞUNDA gösterilmiyor', (tester) async {
    await setAds(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = t0 + 60000; // çalışma bloğu
    await pumpSlot(
      tester,
      const NativeAdSlot(placement: AdPlacement.breakNative),
    );
    await tester.pump(NativeAdSlot.revealDelay);

    expect(find.byKey(const Key('native-slot-breakNative')), findsNothing);
  });
}
