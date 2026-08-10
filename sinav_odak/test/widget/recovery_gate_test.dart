import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/recovery_service.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/home/recovery_gate.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// S18 — Kurtarma diyaloğu (KARAR D2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  /// `seedRunningSession` oturumu bu güne yazar. `DateTime.parse` sabittir;
  /// testlerde `DateTime.now()` kullanılmaz.
  final day = DateTime.parse('2025-08-06');

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpGate(
    WidgetTester tester,
    RecoveryResult recovery,
  ) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        pendingRecoveryProvider.overrideWithValue(recovery),
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
        child: const MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: RecoveryGate(child: Scaffold(body: Text('ANA PANEL'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Kurtarma sonrası gerçek durum: oturum `interrupted` olarak KAYITLI.
  Future<StudySession> seedInterrupted() async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await newRepo(db).markInterrupted(
      sessionId: 's1',
      actualDurationS: 2880,
      totalBreakS: 300,
      endedAt: lastEnd,
      focusScore: 55,
      foregroundS: 2880,
    );
    return (await db.sessionDao.findById('s1'))!;
  }

  // ---------------------------------------------------------------------

  testWidgets('kurtarılacak oturum yoksa diyalog çıkmıyor', (tester) async {
    await pumpGate(tester, RecoveryResult.empty);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('ANA PANEL'), findsOneWidget);
  });

  testWidgets('resume: diyalog YOK (router zaten /run a yönlendirir)',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final session = (await db.sessionDao.findById('s1'))!;

    await pumpGate(
      tester,
      RecoveryResult(RecoveryOutcome.resume, session: session),
    );

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('needsDecision: kurtarılan süreyi gösteren diyalog çıkıyor',
      (tester) async {
    final session = await seedInterrupted();
    await pumpGate(
      tester,
      RecoveryResult(
        RecoveryOutcome.needsDecision,
        session: session,
        recoveredStudyS: 2880,
      ),
    );

    expect(
        find.byKey(const Key('recovery-interrupted-dialog')), findsOneWidget);
    expect(find.text('Oturum yarıda kesildi'), findsOneWidget);
    expect(find.textContaining('48dk'), findsOneWidget);
  });

  testWidgets('needsDecision [Kaydet]: kayıt KORUNUYOR', (tester) async {
    final session = await seedInterrupted();
    await pumpGate(
      tester,
      RecoveryResult(
        RecoveryOutcome.needsDecision,
        session: session,
        recoveredStudyS: 2880,
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-keep')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s, isNotNull, reason: 'Kaydet kaydı silmemeli');
    expect(s!.status, SessionStatus.interrupted);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('needsDecision [Sil]: kayıt ve günlük özeti siliniyor',
      (tester) async {
    final session = await seedInterrupted();
    // Drift AKIŞI (watchDay) yerine Future tabanlı sorgu: `testWidgets`
    // sahte zaman bölgesinde akışın ilk değerini beklemek kilitleniyor.
    expect(
      (await db.statsDao.summaryFor(day, day)).sessionCount,
      1,
      reason: 'ön koşul: kurtarma daily_stats yazmış olmalı',
    );

    await pumpGate(
      tester,
      RecoveryResult(
        RecoveryOutcome.needsDecision,
        session: session,
        recoveredStudyS: 2880,
      ),
    );

    await tester.tap(find.byKey(const Key('recovery-delete')));
    await tester.pumpAndSettle();

    expect(await db.sessionDao.findById('s1'), isNull);
    expect(
      (await db.statsDao.summaryFor(day, day)).sessionCount,
      0,
      reason: 'silinen oturum günlük özetten de düşmeli',
    );
  });

  testWidgets('clockMovedBack: uyarı diyaloğu çıkıyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final session = (await db.sessionDao.findById('s1'))!;
    fakeNow = t0 - 60000;

    await pumpGate(
      tester,
      RecoveryResult(RecoveryOutcome.clockMovedBack, session: session),
    );

    expect(find.byKey(const Key('recovery-clock-dialog')), findsOneWidget);
    expect(find.text('Cihaz saati değişmiş görünüyor'), findsOneWidget);
  });

  testWidgets('clockMovedBack [Devam et]: oturum AÇIK kalıyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final session = (await db.sessionDao.findById('s1'))!;
    fakeNow = t0 - 60000;

    await pumpGate(
      tester,
      RecoveryResult(RecoveryOutcome.clockMovedBack, session: session),
    );

    await tester.tap(find.byKey(const Key('recovery-continue')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.running);
  });

  testWidgets('clockMovedBack [Oturumu kes]: interruptNow ile kapanıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final session = (await db.sessionDao.findById('s1'))!;
    fakeNow = t0 - 60000;

    await pumpGate(
      tester,
      RecoveryResult(RecoveryOutcome.clockMovedBack, session: session),
    );

    await tester.tap(find.byKey(const Key('recovery-stop-session')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.interrupted);
    expect(s.endedAt, t0 - 60000, reason: 'bitiş anı kararın verildiği an');
    // Saat geriye alındığı için ölçülebilen süre yok; tahmin ÜRETİLMEZ.
    expect(s.actualDurationS, 0);
    expect(s.focusScore, isNotNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('diyalog TEK kez tüketiliyor', (tester) async {
    final session = await seedInterrupted();
    final c = await pumpGate(
      tester,
      RecoveryResult(
        RecoveryOutcome.needsDecision,
        session: session,
        recoveredStudyS: 2880,
      ),
    );

    expect(c.read(recoveryConsumedProvider), isTrue);

    await tester.tap(find.byKey(const Key('recovery-keep')));
    await tester.pumpAndSettle();

    // Ana panel SIFIRDAN kurulsa bile (sekme dönüşü) diyalog geri gelmemeli.
    // Farklı key: aksi halde Flutter mevcut State'i yeniden kullanır ve
    // `initState` hiç çalışmadığı için test bir şey kanıtlamaz.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: RecoveryGate(
            key: ValueKey('ikinci-kurulum'),
            child: Scaffold(body: Text('ANA PANEL 2')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
