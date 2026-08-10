import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/app_router.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';
import 'package:sinav_odak/presentation/shell/db_health_page.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> setOnboarding({required bool done}) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      UserSettingsCompanion(onboardingCompleted: Value(done)),
    );
  }

  /// Gerçek `appRouterProvider` ile uygulamayı kurar ve nihai yolu döner.
  ///
  /// [prepare] router kurulmadan ÖNCE çalışır: yönlendirme kararına giren
  /// provider'lar (örn. `savedResultProvider`) burada doldurulur.
  Future<String> locationAfter(
    WidgetTester tester, {
    String? goTo,
    int nowMs = t0,
    void Function(ProviderContainer container)? prepare,
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => nowMs),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);

    prepare?.call(container);

    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    if (goTo != null) {
      router.go(goTo);
      await tester.pump();
      await tester.pump();
    }

    return router.routerDelegate.currentConfiguration.uri.toString();
  }

  group('onboarding yönlendirmesi', () {
    testWidgets('tamamlanmadıysa her yol /onboarding e gider', (tester) async {
      await setOnboarding(done: false);
      expect(await locationAfter(tester), Routes.onboarding);
    });

    testWidgets('tamamlanmadıysa /stats bile /onboarding e gider',
        (tester) async {
      await setOnboarding(done: false);
      expect(
        await locationAfter(tester, goTo: Routes.stats),
        Routes.onboarding,
      );
    });

    testWidgets('tamamlandıysa /home a gider', (tester) async {
      await setOnboarding(done: true);
      expect(await locationAfter(tester), Routes.home);
    });

    testWidgets('tamamlandıysa /onboarding e gitmeye çalışan /home a döner',
        (tester) async {
      await setOnboarding(done: true);
      expect(
        await locationAfter(tester, goTo: Routes.onboarding),
        Routes.home,
      );
    });
  });

  group('aktif oturum koruması', () {
    testWidgets('aktif oturum varken /home -> /run', (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());

      expect(await locationAfter(tester, goTo: Routes.home), Routes.run);
    });

    testWidgets('aktif oturum varken /stats -> /run', (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());

      expect(await locationAfter(tester, goTo: Routes.stats), Routes.run);
    });

    testWidgets('aktif oturum yokken /run -> /home', (tester) async {
      await setOnboarding(done: true);
      expect(await locationAfter(tester, goTo: Routes.run), Routes.home);
    });

    testWidgets('aktif oturum yokken /run/break -> /home', (tester) async {
      await setOnboarding(done: true);
      expect(await locationAfter(tester, goTo: Routes.runBreak), Routes.home);
    });
  });

  group('run katmanı korumadan muaf', () {
    testWidgets('aktif oturum varken /run/break açık kalıyor', (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());

      // Saat molada olmalı: aksi halde BreakScreen doğru davranıp
      // /run'a döner ve router redirect'i ölçemeyiz.
      expect(
        await locationAfter(
          tester,
          goTo: Routes.runBreak,
          nowMs: breakStart + 60000,
        ),
        Routes.runBreak,
      );
    });

    testWidgets('aktif oturum varken /run/summary açık kalıyor',
        (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());

      expect(
        await locationAfter(tester, goTo: Routes.runSummary),
        Routes.runSummary,
      );
    });

    testWidgets('aktif oturum varken /run/done açık kalıyor', (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());

      expect(
        await locationAfter(tester, goTo: Routes.runDone),
        Routes.runDone,
      );
    });

    // Tebrik ekranı (S11) aktif oturum OLMADAN gösterilir: kayıt tamamlandığı
    // anda `running` satır kalmaz. Muafiyet `savedResultProvider`'a bağlı,
    // yolun kendisine değil — aksi halde /run/done herkese açık kalırdı.
    testWidgets('kayıt tamamlandıysa /run/done aktif oturumsuz açılıyor',
        (tester) async {
      await setOnboarding(done: true);

      expect(
        await locationAfter(
          tester,
          goTo: Routes.runDone,
          prepare: (c) => c.read(savedResultProvider.notifier).set(
                sessionId: 's1',
                focusScore: 62,
                dateKey: '2025-08-06',
              ),
        ),
        Routes.runDone,
      );
    });

    testWidgets('kaydedilmiş sonuç yoksa /run/done -> /home', (tester) async {
      await setOnboarding(done: true);

      expect(await locationAfter(tester, goTo: Routes.runDone), Routes.home);
    });
  });

  group('KARAR D4/K3 — db_health yalnızca debug', () {
    // `DbHealthPage` BİLİNÇLİ olarak render EDİLMİYOR: açtığı Drift akışları
    // widget ağacı yıkıldıktan sonra da askıda timer bırakıyor ve test
    // çerçevesi bunu hata sayıyor. Karar zaten hangi ekranın SEÇİLDİĞİdir;
    // doğrulanması gereken de bu.
    //
    // FAZ 5'te DEĞİŞTİ: release dalı artık `PlaceholderPage` değil, gerçek
    // `SettingsScreen`. K3'ün "SettingsScreen gelince placeholder kalkar"
    // maddesi bu turda uygulandı.
    test('debug geliştirme aracını, release GERÇEK ayarları seçiyor', () {
      expect(settingsPageFor(debug: true), isA<DbHealthPage>());
      expect(settingsPageFor(debug: false), isA<SettingsScreen>());
    });

    testWidgets('release dalı Ayarlar ekranını gösteriyor, db_health\'i DEĞİL',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
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
          child: MaterialApp(
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: settingsPageFor(debug: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ayarlar'), findsOneWidget);
      expect(find.byKey(const Key('settings-support')), findsOneWidget);
      expect(
        find.text('Veritabanı Durumu'),
        findsNothing,
        reason: 'geliştirme aracı production\'a sızmamalı',
      );
    });
  });

  group('alt navigasyon', () {
    testWidgets('run katmanında BottomNavigation GİZLİ', (tester) async {
      await setOnboarding(done: true);
      await seedRunningSession(db, id: 's1', sch: schedule());
      await locationAfter(tester, goTo: Routes.run);

      expect(
        find.byType(NavigationBar),
        findsNothing,
        reason: 'run route\'ları shell DIŞINDA tanımlı olmalı',
      );
    });

    testWidgets('shell katmanında BottomNavigation GÖRÜNÜR', (tester) async {
      await setOnboarding(done: true);
      await locationAfter(tester, goTo: Routes.home);

      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });
}
