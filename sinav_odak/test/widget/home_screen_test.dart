// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/home/home_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 5 — Ana panel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  setUp(() {
    db = newDb();
    fakeNow = t0; // 2025-08-06
  });
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: Routes.home,
        routes: [
          GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: Routes.sessionSubject,
            builder: (_, __) => const Scaffold(body: Text('DERS SEÇİMİ')),
          ),
        ],
      );

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // KRİTİK: sabit epoch. todayKeyProvider buradan türüyor.
        clockProvider.overrideWithValue(() => fakeNow),
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
    await container.read(recentSessionsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          // Ürünün TÜRKÇE metnini doğruluyoruz; locale verilmezse
          // cihaz diline (testte en_US) düşülüyor.
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Bir günü kaydeder (streak + daily_stats dolar).
  Future<void> studyOn(
    String dateKey, {
    required String id,
    int durationS = 3600,
    int questions = 40,
    double net = 35,
    int focus = 88,
  }) async {
    await seedRunningSession(db, id: id, sch: schedule());
    await newRepo(db).save(
      sessionId: id,
      dateKey: dateKey,
      subjectId: subjectId,
      wrongCount: 0,
      patch: StudySessionsCompanion(
        status: const Value(SessionStatus.completed),
        actualDurationS: Value(durationS),
        questionCount: Value(questions),
        net: Value(net),
        focusScore: Value(focus),
      ),
    );
  }

  // ---------------------------------------------------------------------

  testWidgets('boş durumda bugün kartı sıfırlarla, streak rozeti YOK',
      (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('home-today')), findsOneWidget);
    expect(find.byKey(const Key('home-streak')), findsNothing);
    expect(find.byKey(const Key('home-recent-empty')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('home-today-duration'))).data,
      '0dk / 4sa',
      reason: 'varsayılan hedef 240 dk',
    );
  });

  testWidgets('bugünkü süre, soru, net ve odak gösteriliyor', (tester) async {
    await studyOn('2025-08-06', id: 's1');
    await pumpHome(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('home-today-duration'))).data,
      '1sa / 4sa',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-metric-questions'))).data,
      '40/100',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-metric-net'))).data,
      '35',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('home-metric-focus'))).data,
      '88',
    );
  });

  testWidgets('streak rozeti kayıttan sonra görünüyor', (tester) async {
    await studyOn('2025-08-06', id: 's1');
    await pumpHome(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('home-streak'))).data,
      '1',
    );
  });

  testWidgets('zincir koptuysa rozet gizleniyor (DB\'ye dokunmadan)',
      (tester) async {
    await studyOn('2025-08-06', id: 's1');
    // İki gün sonra açılıyor: zincir kopmuş.
    fakeNow = t0 + 2 * 86400000;
    await pumpHome(tester);

    expect(find.byKey(const Key('home-streak')), findsNothing);

    final s = await db.settingsDao.read();
    expect(
      s.currentStreak,
      1,
      reason: 'gösterim 0 ama DB DEĞİŞMEDİ — yazma yolu yalnızca kayıt anı',
    );
  });

  testWidgets('ertesi gün zincir hâlâ canlı gösteriliyor', (tester) async {
    await studyOn('2025-08-06', id: 's1');
    fakeNow = t0 + 86400000;
    await pumpHome(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('home-streak'))).data,
      '1',
      reason: 'bugün henüz çalışılmadı ama dün çalışıldı',
    );
  });

  testWidgets('son oturumlar listeleniyor', (tester) async {
    await studyOn('2025-08-06', id: 's1', questions: 40);
    await pumpHome(tester);

    expect(find.byKey(const Key('home-recent-s1')), findsOneWidget);
    expect(find.byKey(const Key('home-recent-empty')), findsNothing);
    expect(find.textContaining('2025-08-06 · 40 soru'), findsOneWidget);
  });

  testWidgets('rıza yoksa banner yuvası BOŞ', (tester) async {
    await pumpHome(tester);

    // Varsayılan personalizedAdsConsent = false.
    expect(find.text('Sponsorlu'), findsNothing);
    expect(find.byKey(const Key('banner-slot-homeBanner')), findsNothing);
  });

  testWidgets('rıza varsa banner yuvası görünüyor', (tester) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(personalizedAdsConsent: Value(true)),
    );
    await pumpHome(tester);

    expect(find.byKey(const Key('banner-slot-homeBanner')), findsOneWidget);
    // FAZ 4.2: etiket reklamın yüklenip yüklenmediğine bağlı (Noop kapı
    // hiç reklam döndürmüyor). Korunan değişmez yuvanın ayrılması;
    // etiketin iki hâli `faz4_test.dart`'ta iddia ediliyor.
    expect(find.byKey(const Key('banner-label-homeBanner')), findsOneWidget);
  });

  testWidgets(
      '[Oturumu Başlat] kurulum akışını sıfırlayıp ders seçimine gidiyor',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();

    expect(find.text('DERS SEÇİMİ'), findsOneWidget);
  });
}
