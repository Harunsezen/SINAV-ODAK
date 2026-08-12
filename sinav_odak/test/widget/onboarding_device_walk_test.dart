import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/onboarding/onboarding_screen.dart';

import '../unit/usecase_helpers.dart';

/// Onboarding — **GERÇEK CİHAZ KOŞULLARINDA** baştan sona yürüyüş.
///
/// **Neden ayrı dosya:** `onboarding_test.dart` akışın *mantığını* doğruluyor
/// ama iki noktada cihazdan ayrılıyordu ve tam bu yüzden yayın engelleyici
/// bir hatayı kaçırdı:
///
/// 1. **Tema verilmiyordu.** Hata `AppTheme`'in `FilledButton` stilinden
///    geliyordu (`minimumSize: Size.fromHeight(56)` = sonsuz genişlik);
///    varsayılan tema ile test edilince ortaya çıkmıyor.
/// 2. **Yüzey 1200×2400'dü.** Kendi yorumu "alt butonlar görünür alanın
///    dışında kalıyor" diyip yüzeyi büyüterek *semptomu* susturuyordu.
///
/// Buradaki testler gerçek temayı ve gerçek telefon ölçülerini kullanıyor.
/// Ayrıntılı teşhis: `ONBOARDING_BUG.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Gerçek telefon: mantıksal 412×915 (Pixel 7), durum çubuğu + jest
  /// çubuğu kesmeleriyle.
  Future<ProviderContainer> pumpDeviceOnboarding(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    double textScale = 1.0,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 48);
    addTearDown(tester.view.reset);

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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          // GERÇEK tema — hatanın kaynağı buydu.
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode:
              brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          routerConfig: GoRouter(
            initialLocation: Routes.onboarding,
            routes: [
              GoRoute(
                path: Routes.onboarding,
                builder: (_, __) => const OnboardingScreen(),
              ),
              GoRoute(
                path: Routes.home,
                builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Birincil butonun **gerçekten kullanılabilir** olduğunu doğrular:
  /// ağaçta var, ekranın içinde ve boyutu sıfır değil.
  void expectUsablePrimary(WidgetTester tester, Key key, Size screen) {
    final f = find.byKey(key);
    expect(f, findsOneWidget, reason: '$key ağaçta yok');

    final r = tester.getRect(f);
    expect(r.width, greaterThan(0), reason: '$key sıfır genişlikte');
    expect(r.height, greaterThan(0), reason: '$key sıfır yükseklikte');
    expect(
      r.width,
      lessThan(double.infinity),
      reason: '$key sonsuz genişlikte',
    );
    expect(r.left, greaterThanOrEqualTo(0), reason: '$key ekranın solunda');
    expect(
      r.right,
      lessThanOrEqualTo(screen.width),
      reason: '$key ekranın sağına taşıyor (${r.right} > ${screen.width})',
    );
    expect(
      r.bottom,
      lessThanOrEqualTo(screen.height),
      reason: '$key ekranın altına taşıyor',
    );
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
  }

  // =====================================================================

  testWidgets(
      'gerçek cihaz ölçüsünde 5 adım baştan sona: her adımda birincil buton '
      'görünür, son adımda [Başla] ana panele götürüyor', (tester) async {
    const screen = Size(412, 915);
    await pumpDeviceOnboarding(tester);

    // --- 1/5 vaat ---
    expect(find.byKey(const Key('onboarding-step-promise')), findsOneWidget);
    expectUsablePrimary(tester, const Key('onboarding-next'), screen);
    expect(tester.takeException(), isNull, reason: '1. adımda istisna');
    await tapNext(tester);

    // --- 2/5 sınav türü ---
    expect(find.byKey(const Key('onboarding-step-exam')), findsOneWidget);
    expectUsablePrimary(tester, const Key('onboarding-next'), screen);
    expect(tester.takeException(), isNull, reason: '2. adımda istisna');
    await tester.tap(find.byKey(const Key('onboarding-exam-yks')));
    await tester.pumpAndSettle();
    await tapNext(tester);

    // --- 3/5 günlük hedef ---
    expect(find.byKey(const Key('onboarding-step-goal')), findsOneWidget);
    expectUsablePrimary(tester, const Key('onboarding-next'), screen);
    expect(tester.takeException(), isNull, reason: '3. adımda istisna');
    await tapNext(tester);

    // --- 4/5 rıza ---
    expect(find.byKey(const Key('onboarding-step-consent')), findsOneWidget);
    expectUsablePrimary(tester, const Key('onboarding-next'), screen);
    expect(tester.takeException(), isNull, reason: '4. adımda istisna');
    await tapNext(tester);

    // --- 5/5 özet: HATANIN BİLDİRİLDİĞİ ADIM ---
    expect(find.byKey(const Key('onboarding-step-summary')), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-next')), findsNothing);
    expectUsablePrimary(tester, const Key('onboarding-start'), screen);
    expect(tester.takeException(), isNull, reason: '5. adımda istisna');

    // Buton yalnızca "var" değil, BASILABİLİR olmalı: `tap` isabet testi
    // yapıyor, buton başka bir widget'ın altında kalsaydı düşerdi.
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    expect(
      find.text('ANA PANEL'),
      findsOneWidget,
      reason: '[Başla] ana panele götürmedi',
    );
    expect(tester.takeException(), isNull);

    // Onboarding gerçekten tamamlandı olarak yazıldı mı?
    final settings = await db.settingsDao.read();
    expect(settings.onboardingCompleted, isTrue);
  });

  testWidgets(
      'son adımdaki [Başla] dar ekran, büyük font ve koyu temada da '
      'ekranın içinde', (tester) async {
    for (final (size, scale, brightness) in [
      (const Size(360, 640), 1.0, Brightness.light),
      (const Size(360, 800), 1.3, Brightness.light),
      (const Size(412, 915), 1.5, Brightness.dark),
    ]) {
      await pumpDeviceOnboarding(
        tester,
        size: size,
        textScale: scale,
        brightness: brightness,
      );

      await tapNext(tester);
      await tester.tap(find.byKey(const Key('onboarding-exam-yks')));
      await tester.pumpAndSettle();
      await tapNext(tester);
      await tapNext(tester);
      await tapNext(tester);

      expect(
        find.byKey(const Key('onboarding-step-summary')),
        findsOneWidget,
        reason: '$size / x$scale / $brightness: özet adımına gelinemedi',
      );
      expectUsablePrimary(tester, const Key('onboarding-start'), size);
      expect(
        tester.takeException(),
        isNull,
        reason: '$size / x$scale / $brightness: istisna',
      );
    }
  });

  testWidgets(
      'geri tuşu son adımdan 4. adıma döner ve birincil buton '
      'yeniden [İleri] olur', (tester) async {
    const screen = Size(412, 915);
    await pumpDeviceOnboarding(tester);

    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-exam-yks')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await tapNext(tester);
    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-start')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-step-consent')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-start')), findsNothing);
    expectUsablePrimary(tester, const Key('onboarding-next'), screen);
    expect(tester.takeException(), isNull);
  });
}
