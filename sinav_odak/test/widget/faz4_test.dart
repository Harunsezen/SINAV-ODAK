import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/ad_providers.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/ad_gateway.dart';
import 'package:sinav_odak/domain/services/achievement_calculator.dart';
import 'package:sinav_odak/presentation/ads/banner_ad_slot.dart';

import 'package:go_router/go_router.dart';

import 'package:sinav_odak/core/router/routes.dart';

import 'package:sinav_odak/presentation/run/run_screen.dart';

import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';

import 'package:sinav_odak/domain/ports/session_notifier.dart';

import '../unit/usecase_helpers.dart';

/// Banner yüklemesini kontrol eden sahte kapı.
class FakeAdGateway implements AdGateway {
  FakeAdGateway({this.bannerLoads = true});

  /// `false` = internet yok / reklam gelmedi.
  final bool bannerLoads;

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> loadBanner(AdPlacement placement) async =>
      bannerLoads ? Object() : null;

  @override
  Future<Object?> loadNative(AdPlacement placement) async => null;

  @override
  Future<bool> showInterstitial(AdPlacement placement) async => false;

  @override
  Future<bool> showRewarded(AdPlacement placement) async => false;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = newDb();
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(
        onboardingCompleted: Value(true),
        personalizedAdsConsent: Value(true),
      ),
    );
  });
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpSlot(
    WidgetTester tester, {
    required bool bannerLoads,
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        adGatewayProvider
            .overrideWithValue(FakeAdGateway(bannerLoads: bannerLoads)),
        // `uiTickerProvider` gerçek 1 sn'lik periyodik akış; testte
        // askıda kalıp "Timer is still pending" veriyor.
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(
            body: BannerAdSlot(placement: AdPlacement.homeBanner),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // =====================================================================
  // 4.2 — offline Balto metni
  // =====================================================================

  group('FAZ 4.2 — reklam yüklenemezse Balto konuşuyor', () {
    testWidgets('reklam GELMEZSE offline metni görünüyor', (tester) async {
      await pumpSlot(tester, bannerLoads: false);

      expect(
        find.text('İnternet yok, reklam yok — Balto da tatilde 🌴'),
        findsOneWidget,
        reason: 'boş gri kutu kullanıcıya "bozuldu" hissi verirdi',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reklam GELİRSE normal etiket görünüyor', (tester) async {
      await pumpSlot(tester, bannerLoads: true);

      expect(find.text('Sponsorlu'), findsOneWidget);
      expect(
        find.text('İnternet yok, reklam yok — Balto da tatilde 🌴'),
        findsNothing,
      );
    });

    testWidgets('yuva yüksekliği DEĞİŞMİYOR — sayaç kaymıyor', (tester) async {
      // Offline metni daha uzun; yuva büyüseydi çalışma ekranında sayaç
      // yukarı kayardı.
      await pumpSlot(tester, bannerLoads: false);
      final offline = tester.getSize(
        find.byKey(const Key('banner-slot-homeBanner')),
      );

      await pumpSlot(tester, bannerLoads: true);
      final normal = tester.getSize(
        find.byKey(const Key('banner-slot-homeBanner')),
      );

      expect(offline.height, normal.height);
      expect(offline.height, BannerAdSlot.height);
    });
  });

  // =====================================================================
  // 4.3 — Balto'nun Dostu rozeti
  // =====================================================================

  group('FAZ 4.3 — Balto\'nun Dostu', () {
    test('rozet ÖLÇÜMLE asla açılmıyor (yalnızca eylemle)', () {
      // Bu rozet "Destek Ol" ile kazanılıyor. Hesap yolu onu açarsa
      // bedava dağıtılmış olurdu.
      final earned = AchievementCalculator.earned(
        const AchievementMetrics(
          totalStudyS: 1000 * 3600,
          totalQuestions: 999999,
          currentStreak: 365,
          daysSinceLastSession: 99,
        ),
      );
      expect(
        earned,
        isNot(contains('balto_friend')),
        reason: 'en uç ölçümlerde bile ölçümle açılmamalı',
      );
    });

    test('katalogda var ve kodu benzersiz', () {
      final codes = [for (final d in AchievementCalculator.catalog) d.code];
      expect(codes, contains('balto_friend'));
      expect(codes.toSet().length, codes.length);
    });
  });

  // =====================================================================
  // 4.4 — banner konumu
  // =====================================================================

  group('FAZ 4.4 — banner konumu', () {
    test('varsayılan ALT (v1.0 davranışı korunuyor)', () async {
      final s = await db.settingsDao.ensure();
      expect(s.bannerPosition, BannerPosition.bottom);
    });

    test('konum yazılıp okunuyor', () async {
      await db.settingsDao.patchSettings(
        const UserSettingsCompanion(
          bannerPosition: Value(BannerPosition.sideLandscape),
        ),
      );
      final s = await db.settingsDao.ensure();
      expect(s.bannerPosition, BannerPosition.sideLandscape);
    });
  });

  // =====================================================================
  // 4.4 — konum GERÇEKTEN uygulanıyor mu (ayar ölü olmasın)
  // =====================================================================

  group('FAZ 4.4 — konum ayarının ETKİSİ var', () {
    Future<ProviderContainer> pumpRun(
      WidgetTester tester, {
      required BannerPosition position,
      required Size size,
    }) async {
      await db.settingsDao.patchSettings(
        UserSettingsCompanion(bannerPosition: Value(position)),
      );
      await seedRunningSession(db, id: 'r1', sch: schedule());

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          adGatewayProvider.overrideWithValue(FakeAdGateway()),
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
          child: MaterialApp.router(
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            routerConfig: GoRouter(
              initialLocation: Routes.run,
              routes: [
                GoRoute(
                  path: Routes.run,
                  builder: (_, __) => const RunScreen(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('YATAY + "yanda": banner sol sütunda, sayacın SOLUNDA',
        (tester) async {
      await pumpRun(
        tester,
        position: BannerPosition.sideLandscape,
        size: const Size(915, 412),
      );

      final banner = find.byKey(const Key('banner-slot-runBanner'));
      expect(banner, findsOneWidget);

      final bannerX = tester.getCenter(banner).dx;
      final counterX = tester.getCenter(find.text('24:00')).dx;
      expect(
        bannerX,
        lessThan(counterX),
        reason: 'yanda seçiliyken banner sayacın solunda olmalı',
      );
    });

    testWidgets('DİKEY + "üst": banner sayacın ÜSTÜNDE', (tester) async {
      await pumpRun(
        tester,
        position: BannerPosition.top,
        size: const Size(412, 915),
      );

      final bannerY = tester
          .getCenter(
            find.byKey(const Key('banner-slot-runBanner')),
          )
          .dy;
      final counterY = tester.getCenter(find.text('24:00')).dy;
      expect(bannerY, lessThan(counterY));
    });

    testWidgets('DİKEY + "alt": banner sayacın ALTINDA (varsayılan)',
        (tester) async {
      await pumpRun(
        tester,
        position: BannerPosition.bottom,
        size: const Size(412, 915),
      );

      final bannerY = tester
          .getCenter(
            find.byKey(const Key('banner-slot-runBanner')),
          )
          .dy;
      final counterY = tester.getCenter(find.text('24:00')).dy;
      expect(bannerY, greaterThan(counterY));
    });
  });
}
