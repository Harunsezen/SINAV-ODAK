// drift `isNull`/`isNotNull` sorgu yardımcıları matcher'larla çakışıyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/done_screen.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// S11 — Tebrik ekranı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/done',
        routes: [
          GoRoute(path: '/run/done', builder: (_, __) => const DoneScreen()),
          GoRoute(
            path: '/session/subject',
            builder: (_, __) => const Scaffold(body: Text('DERS SEÇİMİ')),
          ),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
          ),
        ],
      );

  Future<ProviderContainer> pumpDone(WidgetTester tester) async {
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
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Kaydedilmiş bir oturum + o güne ait `daily_stats` üretir.
  Future<void> seedFinishedDay(AppDatabase db) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await newRepo(db).save(
      sessionId: 's1',
      dateKey: '2025-08-06',
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 0,
      patch: const StudySessionsCompanion(
        status: Value(SessionStatus.completed),
        actualDurationS: Value(3600),
        questionCount: Value(40),
        correctCount: Value(36),
        wrongCount: Value(4),
        net: Value(35),
        focusScore: Value(88),
      ),
    );
  }

  // ---------------------------------------------------------------------

  testWidgets('kaydedilmiş sonuç yoksa boş durum gösteriliyor', (tester) async {
    await pumpDone(tester);
    expect(find.byKey(const Key('done-empty')), findsOneWidget);
  });

  testWidgets('odak skoru büyük punto ile gösteriliyor', (tester) async {
    await seedFinishedDay(db);
    final c = await pumpDone(tester);

    c.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('done-focus-score'))).data,
      '88',
    );
  });

  testWidgets('günlük ilerleme daily_stats üzerinden gösteriliyor',
      (tester) async {
    await seedFinishedDay(db);
    final c = await pumpDone(tester);

    c.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();

    // Varsayılan günlük hedef 240 dk; bu günde 3600 sn (1sa) çalışılmış.
    expect(
      tester.widget<Text>(find.byKey(const Key('done-progress-text'))).data,
      '1sa / 4sa',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('done-progress-questions')))
          .data,
      'Soru: 40 · Net: 35',
    );
  });

  testWidgets('skor hesaplanmamışsa ekran çökmüyor', (tester) async {
    await seedFinishedDay(db);
    final c = await pumpDone(tester);

    c.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: null,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('done-focus-score'))).data,
      '—',
    );
  });

  testWidgets('[Yeni oturum] ders seçimine gidiyor ve sonucu temizliyor',
      (tester) async {
    await seedFinishedDay(db);
    final c = await pumpDone(tester);

    c.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('done-new-session')));
    await tester.pumpAndSettle();

    expect(find.text('DERS SEÇİMİ'), findsOneWidget);
    expect(
      c.read(savedResultProvider),
      isNull,
      reason: 'geri dönülürse eski skor tekrar gösterilmemeli',
    );
  });

  testWidgets('[Ana panel] /home a gidiyor', (tester) async {
    await seedFinishedDay(db);
    final c = await pumpDone(tester);

    c.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('done-home')));
    await tester.pumpAndSettle();

    expect(find.text('ANA PANEL'), findsOneWidget);
    expect(c.read(savedResultProvider), isNull);
  });
}
