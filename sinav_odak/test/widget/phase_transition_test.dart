import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/break_screen.dart';
import 'package:sinav_odak/presentation/run/run_screen.dart';

import '../unit/usecase_helpers.dart';

/// Çalışma → mola faz geçişi, uygulama ÖN PLANDAYKEN.
///
/// **Ürün kuralı (koordinatör vetosu):** *"Ön plandayken kullanıcı asla ana
/// ekrana atılmaz."* Faz geçişi uygulamanın İÇİNDE olur: ekran mola
/// sayacına döner, kullanıcıya kısa bir bilgi gösterilir ve **bildirim
/// gönderilmez** — kullanıcı zaten ekrana bakıyor.
///
/// Bildirimler mutlak zamana önceden kuruluyor (sayaç `Timer` tabanlı
/// değil). Ön planda bunların kullanıcıya ulaşmaması için oturum
/// bildirimlerinin **iptal edilmiş** olması gerekiyor; uygulama arka plana
/// geçtiğinde yeniden kuruluyor.
class RecordingNotifier implements SessionNotifier {
  final List<String> scheduled = [];
  final List<String> cancelled = [];

  /// O an OS'ta kurulu bildirim var mı? Ön planda **false** olmalı.
  bool get hasPending => scheduled.length > cancelled.length;

  void clear() {
    scheduled.clear();
    cancelled.clear();
  }

  @override
  Future<void> scheduleFor({
    required String sessionId,
    required SessionSchedule schedule,
  }) async =>
      scheduled.add(sessionId);

  @override
  Future<void> cancelAll(String sessionId) async => cancelled.add(sessionId);

  @override
  Future<bool> hasPermission() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;
  late StreamController<int> ticker;
  late RecordingNotifier notifier;

  setUp(() {
    db = newDb();
    fakeNow = t0;
    ticker = StreamController<int>.broadcast();
    notifier = RecordingNotifier();
  });

  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  GoRouter buildRouter() => GoRouter(
        initialLocation: Routes.run,
        routes: [
          GoRoute(path: Routes.run, builder: (_, __) => const RunScreen()),
          GoRoute(
            path: Routes.runBreak,
            builder: (_, __) => const BreakScreen(),
          ),
          GoRoute(
            path: Routes.runSummary,
            builder: (_, __) => const Scaffold(body: Text('SUMMARY')),
          ),
          // Uygulamanın "dışına" düşülürse yakalansın diye: ana panel
          // görünürse faz geçişi kullanıcıyı oturumdan KOPARMIŞ demektir.
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
          ),
        ],
      );

  late GoRouter router;

  Future<ProviderContainer> pumpRun(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider.overrideWithValue(notifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.future);

    // Üretimde `app.dart` bunu `watch` ediyor. Burada `MaterialApp.router`
    // doğrudan kurulduğu için bekçiyi elle uyandırıyoruz; okunmazsa
    // provider tembel kalır ve yaşam döngüsü gözlemcisi kaydolmaz.
    container.read(foregroundNotificationGuardProvider);

    router = buildRouter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  String currentRoute() =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> tick(WidgetTester tester) async {
    ticker.add(0);
    await tester.pump();
    await tester.pump();
  }

  // =====================================================================

  testWidgets('phase_transition_foreground_stays_in_app', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    // --- Çalışma bloğu: uygulama içindeyiz ---
    await tick(tester);
    expect(currentRoute(), Routes.run, reason: 'oturum çalışma bloğunda');
    expect(find.byType(RunScreen), findsOneWidget);

    // Ön plandayken oturum bildirimi OS'ta BEKLEMEMELİ.
    notifier.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      notifier.cancelled,
      isNotEmpty,
      reason: 'ön plana geçince oturum bildirimleri iptal edilmeli',
    );
    expect(
      notifier.hasPending,
      isFalse,
      reason: 'ön planda kullanıcıya bildirim gitmemeli',
    );

    // --- FAZ GEÇİŞİ: çalışma -> mola, uygulama ÖN PLANDA ---
    notifier.clear();
    fakeNow = breakStart + 1000;
    await tick(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // 3) Route/activity kapanmıyor: mola sayacı ekranda.
    expect(
      currentRoute(),
      Routes.runBreak,
      reason: 'faz geçişi kullanıcıyı mola ekranına almalı',
    );
    expect(
      find.byType(BreakScreen),
      findsOneWidget,
      reason: 'MOLA SAYACI görünmeli',
    );
    expect(
      find.text('ANA PANEL'),
      findsNothing,
      reason: 'KURAL: ön plandayken kullanıcı ana ekrana ATILMAZ',
    );
    expect(tester.takeException(), isNull);

    // 4) Kullanıcıya uygulama İÇİNDE haber verildi.
    expect(
      find.byKey(const Key('phase-change-banner')),
      findsOneWidget,
      reason: 'MOLA BİLDİRİMİ (snackbar) uygulama içinde gösterilmeli',
    );

    // 5) Ön planda OS bildirimi kurulmadı.
    expect(
      notifier.scheduled,
      isEmpty,
      reason: 'ön plandayken bildirim kurulmamalı — ekran zaten açık',
    );
    expect(notifier.hasPending, isFalse);

    // Snackbar zamanlayıcısını tüket.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('arka plana geçince oturum bildirimleri YENİDEN kuruluyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);
    await tick(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    notifier.clear();

    // Kullanıcı uygulamadan çıktı: artık tek haber kanalı bildirim.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(
      notifier.scheduled,
      isNotEmpty,
      reason: 'arka planda mola/blok bitişi bildirimle haber verilmeli',
    );
    expect(notifier.hasPending, isTrue);
  });

  testWidgets(
      'faz geçişi ARKA PLANDA olduysa uygulama içinde snackbar '
      'birikmiyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);
    await tick(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // Geçiş arka planda oldu.
    fakeNow = breakStart + 1000;
    await tick(tester);

    // Kullanıcı geri döndü: mola ekranı, doğru sayaç.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(currentRoute(), Routes.runBreak);
    expect(find.byType(BreakScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
