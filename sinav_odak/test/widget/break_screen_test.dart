import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/break_screen.dart';

import '../unit/usecase_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;
  late StreamController<int> ticker;

  setUp(() {
    db = newDb();
    // Molanın 1. dakikası.
    fakeNow = breakStart + 60000;
    ticker = StreamController<int>.broadcast();
  });

  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  /// `context.go` çağrıldığı için gerçek router gerekiyor.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/break',
        routes: [
          GoRoute(
            path: '/run',
            builder: (_, __) => const Scaffold(body: Text('RUN EKRANI')),
            routes: [
              GoRoute(
                path: 'break',
                builder: (_, __) => const BreakScreen(),
              ),
              GoRoute(
                path: 'summary',
                builder: (_, __) => const Scaffold(body: Text('SUMMARY')),
              ),
            ],
          ),
        ],
      );

  Future<ProviderContainer> pumpBreak(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    addTearDown(container.dispose);

    await container.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pump();
    return container;
  }

  Future<void> tick(WidgetTester tester) async {
    ticker.add(0);
    await tester.pump();
    await tester.pump();
  }

  // ---------------------------------------------------------------------

  testWidgets('mola sayacı MM:SS biçiminde gösteriliyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    // 5 dk mola, 1. dakikadayız -> 4:00 kaldı.
    expect(find.text('MOLA'), findsOneWidget);
    expect(find.text('04:00'), findsOneWidget);
    expect(find.text('kalan mola'), findsOneWidget);
  });

  testWidgets('kalan uzatma hakkı doğru gösteriliyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    // Toplam +10 dk = 2 adet +5 dk hakkı.
    expect(find.text('+5 dk (2 hak)'), findsOneWidget);
  });

  testWidgets('+5 dk uzatma hakkı varken aktif', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('break-extend')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('+5 dk molayı uzatıyor ve hak azalıyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    await tester.tap(find.byKey(const Key('break-extend')));
    await tester.pumpAndSettle();
    await tick(tester);

    // DB'de hem session_blocks hem scheduleJson güncellenmeli.
    final blocks = await db.sessionDao.blocksOf('s1');
    expect(blocks[breakIndex].plannedS, 600);
    expect(blocks[breakIndex].extendedS, 300);

    expect(find.text('+5 dk (1 hak)'), findsOneWidget);
    // Mola 5 dk uzadı: kalan 4:00 -> 9:00
    expect(find.text('09:00'), findsOneWidget);
  });

  testWidgets('uzatma hakkı bitince +5 dk butonu PASİF', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    await tester.tap(find.byKey(const Key('break-extend')));
    await tester.pumpAndSettle();
    await tick(tester);
    await tester.tap(find.byKey(const Key('break-extend')));
    await tester.pumpAndSettle();
    await tick(tester);

    expect(find.text('+5 dk (0 hak)'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('break-extend')),
    );
    expect(button.onPressed, isNull, reason: 'toplam +10 dk limiti');
  });

  testWidgets('"Molayı Bitir" skipBreak çağırıyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    await tester.tap(find.byKey(const Key('break-skip')));
    await tester.pumpAndSettle();

    final blocks = await db.sessionDao.blocksOf('s1');
    expect(blocks[breakIndex].wasSkipped, isTrue);
    expect(blocks[breakIndex].plannedS, 60, reason: 'molanın 1. dakikası');
    // Sonraki blok öne çekilmeli.
    expect(blocks[2].plannedStartAt, fakeNow);
  });

  testWidgets('mola bitince otomatik çalışma ekranına dönüyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    expect(find.text('MOLA'), findsOneWidget);

    // Mola bitti, sonraki çalışma bloğu başladı.
    fakeNow = breakEnd + 1000;
    await tick(tester);
    await tester.pumpAndSettle();

    expect(find.text('RUN EKRANI'), findsOneWidget);
  });

  testWidgets('reklam alanı placeholder\'ı mevcut (Adım 6 için)',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    expect(find.byKey(const Key('break-ad-slot')), findsOneWidget);
  });

  testWidgets('mola ekranında da geri tuşu yakalı', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpBreak(tester);

    final guards = find.byWidgetPredicate((w) => w is PopScope && !w.canPop);
    expect(guards, findsWidgets);
  });
}
