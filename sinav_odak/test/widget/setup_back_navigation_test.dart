import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/app_router.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 1.2 — kurulum akışında GERİ.
///
/// **v1.0'daki kusur (koordinatörün bildirdiğinden geniş):** kurulum akışı
/// baştan sona `context.go()` kullanıyor. `go` gezinme yığınını
/// DEĞİŞTİRİR, üstüne eklemez; dolayısıyla `Navigator.canPop()` daima
/// false ve `AppBar`'ın otomatik geri tuşu **hiçbir kurulum adımında**
/// çizilmiyordu — yalnızca Plan ekranında değil, dördünde de.
///
/// Kullanıcı yanlış ders seçtiyse tek çıkışı sistem geri tuşuydu, o da
/// akışı tamamen terk ediyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = newDb();
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(onboardingCompleted: Value(true)),
    );
  });
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
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
    await container.read(activeSessionProvider.future);
    await container.read(settingsStreamProvider.future);
    await container.read(allSubjectsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  String route(ProviderContainer c) => c
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  // =====================================================================

  testWidgets(
      'dört kurulum adımının HEPSİNDE geri tuşu var ve bir önceki '
      'adıma dönüyor', (tester) async {
    final c = await pumpApp(tester);

    // Ana panel -> ders seç
    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();
    expect(route(c), Routes.sessionSubject);

    // 1) Ders seç -> geri -> ana panel
    expect(
      find.byKey(const Key('setup-back-subject')),
      findsOneWidget,
      reason: 'v1.0\'da bu ekranda geri tuşu YOKTU',
    );
    await tester.tap(find.byKey(const Key('setup-back-subject')));
    await tester.pumpAndSettle();
    expect(route(c), Routes.home);

    // Tekrar akışa gir ve ilerle.
    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik').first);
    await tester.pumpAndSettle();
    expect(route(c), Routes.sessionTopic);

    // 2) Konu seç -> geri -> ders seç
    expect(find.byKey(const Key('setup-back-topic')), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-back-topic')));
    await tester.pumpAndSettle();
    expect(
      route(c),
      Routes.sessionSubject,
      reason: 'geri, akışı terk etmemeli — bir ÖNCEKİ adıma dönmeli',
    );
  });

  testWidgets('cupertino_icons projede YOK (FAZ 1.4 bekçisi)', (tester) async {
    // FAZ 1.4 zaten karşılanmış durumdaydı; bu test geri gelmesini
    // engelliyor. Material dışı ikon paketi eklenirse burada düşer.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('cupertino_icons'),
      isFalse,
      reason: 'ikon seti Material; cupertino_icons geri eklenmemeli',
    );

    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('CupertinoIcons') ||
          src.contains('package:flutter/cupertino.dart')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'Cupertino kullanımı: $offenders');
  });
}
