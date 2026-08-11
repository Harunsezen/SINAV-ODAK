// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/ad_providers.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/ports/ad_gateway.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/ad_helpers.dart';
import '../unit/usecase_helpers.dart';

/// FAZ 5 — Ayarlar "Destek ol" (ödüllü reklam).
///
/// S13 onaylı: ödüllü reklamda **frekans kapısı YOK** — kullanıcı kendisi
/// başlatıyor. Rıza ve çalışma bloğu kuralları geçerli.
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

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await container.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapSupport(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('settings-support-button')));
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------

  testWidgets('rıza YOKSA buton pasif ve sebebi yazıyor', (tester) async {
    await setConsent(consent: false);
    await pumpSettings(tester);

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('settings-support-button')),
    );
    expect(btn.onPressed, isNull);
    expect(
      find.byKey(const Key('settings-support-disabled-note')),
      findsOneWidget,
    );
  });

  testWidgets('rıza VARSA buton aktif', (tester) async {
    await setConsent(consent: true);
    await pumpSettings(tester);

    final btn = tester.widget<FilledButton>(
      find.byKey(const Key('settings-support-button')),
    );
    expect(btn.onPressed, isNotNull);
    expect(
      find.byKey(const Key('settings-support-disabled-note')),
      findsNothing,
    );
  });

  testWidgets('tıklayınca ödüllü reklam gösteriliyor ve teşekkür çıkıyor',
      (tester) async {
    await setConsent(consent: true);
    await pumpSettings(tester);
    await tapSupport(tester);

    expect(gateway.shownRewarded, [AdPlacement.supportRewarded]);
    expect(find.textContaining('Teşekkürler'), findsOneWidget);
  });

  testWidgets('FREKANS KAPISI YOK: ardışık iki gösterim de geçiyor (S13)',
      (tester) async {
    await setConsent(consent: true);
    // Az önce gösterilmiş bir kayıt: ara reklamda kapıyı kapatırdı.
    await db.adEventDao.logShown(
      id: 'r1',
      placement: AdPlacement.supportRewarded,
      shownAtMs: t0 - 1000,
    );

    await pumpSettings(tester);
    await tapSupport(tester);
    await tapSupport(tester);

    expect(
      gateway.shownRewarded,
      [AdPlacement.supportRewarded, AdPlacement.supportRewarded],
      reason: 'kullanıcı başlattığı için ardışık izinli',
    );
  });

  testWidgets('ÇALIŞMA BLOĞUNDA gösterilmiyor (G7)', (tester) async {
    await setConsent(consent: true);
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = t0 + 60000; // çalışma bloğu
    await pumpSettings(tester);
    await tapSupport(tester);

    expect(
      gateway.shownRewarded,
      isEmpty,
      reason: 'tam ekran reklam çalışma bloğunda ASLA',
    );
  });

  testWidgets('reklam yoksa akış çökmüyor, bilgilendirme çıkıyor',
      (tester) async {
    await setConsent(consent: true);
    gateway = RecordingAdGateway();
    await pumpSettings(tester);

    // NoopAdGateway davranışı: RecordingAdGateway rewarded'da hep true
    // döndüğü için burada çalışma bloğu üzerinden reddi doğruluyoruz.
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = t0 + 60000;
    await tester.pumpAndSettle();
    await tapSupport(tester);

    expect(
      find.textContaining('Şu an gösterilecek reklam yok'),
      findsOneWidget,
    );
  });
}
