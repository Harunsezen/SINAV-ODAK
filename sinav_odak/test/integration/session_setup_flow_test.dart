import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/app_router.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// Uçtan uca: ana panel → ders → konu → tür → plan → BAŞLAT → /run.
/// Gerçek router, gerçek Drift, gerçek use-case'ler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer c;

  setUp(() async {
    db = newDb();
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(onboardingCompleted: Value(true)),
    );
    c = ProviderContainer(
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
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: c.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String location() => c
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  testWidgets('tam akış: ana panel -> ders -> konu -> tür -> plan -> BAŞLAT',
      (tester) async {
    await pumpApp(tester);

    // 1) Ana panelden başla.
    expect(find.text('Sınav Odak'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();
    expect(location(), Routes.sessionSubject);

    // 2) Ders listesi geliyor (YKS: 15 ders).
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    expect(location(), Routes.sessionTopic);

    // 3) Konular geliyor. (Listenin ilk konusu; "Türev" 23. sırada olduğu
    // için ListView.builder onu henüz render etmiyor.)
    expect(find.text('Temel Kavramlar'), findsOneWidget);
    await tester.tap(find.text('Temel Kavramlar'));
    await tester.pumpAndSettle();
    expect(location(), Routes.sessionType);

    // 4) Çalışma türleri geliyor.
    expect(find.text('Soru Çözümü'), findsOneWidget);
    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();
    expect(location(), Routes.sessionPlan);

    // 5) Plan önizlemesi hazır, BAŞLAT.
    expect(find.byKey(const Key('plan-preview')), findsOneWidget);
    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    // 6) DB'de oturum var, /run'a gidildi.
    final active = await db.sessionDao.findActiveSession();
    expect(active, isNotNull);
    expect(active!.status, SessionStatus.running);
    expect(active.subjectId, 'sub_yks_1');
    expect(active.topicId, isNotNull, reason: 'konu seçildi');
    expect(active.dateKey, '2025-08-06');

    final blocks = await db.sessionDao.blocksOf(active.id);
    expect(blocks.length, 5);

    expect(location(), Routes.run);
    // 7) Setup state sıfırlandı.
    expect(c.read(setupProvider), const SetupSelection());
  });

  testWidgets('konu seçmeden devam: topicId null kalıyor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('topic-skip')));
    await tester.pumpAndSettle();
    expect(location(), Routes.sessionType);

    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    final active = await db.sessionDao.findActiveSession();
    expect(active!.topicId, isNull);
  });

  testWidgets('ders değişince konu seçimi sıfırlanıyor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temel Kavramlar'));
    await tester.pumpAndSettle();

    expect(c.read(setupProvider).topicId, isNotNull);

    // Geri dönüp başka ders seç.
    c.read(appRouterProvider).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fizik'));
    await tester.pumpAndSettle();

    expect(c.read(setupProvider).subjectName, 'Fizik');
    expect(c.read(setupProvider).topicId, isNull);
  });

  testWidgets('kurulum ekranlarında alt navigasyon GİZLİ', (tester) async {
    await pumpApp(tester);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'ana panelde var',
    );

    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();

    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'kurulum route\'ları shell DIŞINDA',
    );
  });

  testWidgets('aktif oturum varken kurulum akışına girilemiyor (R4)',
      (tester) async {
    await seedRunningSession(db, id: 'mevcut', sch: schedule());
    await pumpApp(tester);

    c.read(appRouterProvider).go(Routes.sessionSubject);
    await tester.pumpAndSettle();

    expect(location(), Routes.run, reason: 'redirect /run\'a göndermeli');
  });

  testWidgets('ders seçmeden plana gelinirse akışın başına dönülüyor',
      (tester) async {
    await pumpApp(tester);

    c.read(appRouterProvider).go(Routes.sessionTopic);
    await tester.pumpAndSettle();

    expect(find.text('Önce ders seçmen gerekiyor.'), findsOneWidget);
  });
}
