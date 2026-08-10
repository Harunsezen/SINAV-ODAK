import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/summary/summary_screen.dart';

import '../unit/usecase_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  Future<void> pumpSummary(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SummaryScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('oturum yoksa boş durum gösteriliyor', (tester) async {
    await pumpSummary(tester);
    expect(find.byKey(const Key('summary-empty')), findsOneWidget);
  });

  testWidgets('çizelge bitince oturum özeti gösteriliyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpSummary(tester);

    expect(find.byKey(const Key('summary-form')), findsOneWidget);
    expect(find.text('Oturum tamamlandı'), findsOneWidget);
    expect(find.text('Çalışma: 48dk'), findsOneWidget);
    expect(find.text('Mola: 5dk'), findsOneWidget);
    expect(find.text('Blok sayısı: 2'), findsOneWidget);
  });

  testWidgets('Adım 5 devamı için yer tutucular mevcut', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpSummary(tester);

    expect(find.byKey(const Key('summary-questions-placeholder')),
        findsOneWidget);
    expect(find.byKey(const Key('summary-breakdown-placeholder')),
        findsOneWidget);
    expect(find.byKey(const Key('summary-mood-placeholder')), findsOneWidget);
  });

  testWidgets('KAYDET henüz bağlı değil (iskelet)', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpSummary(tester);

    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('summary-save')));
    expect(btn.onPressed, isNull, reason: 'finishSession Adım 5 devamında');
  });

  testWidgets('oturum sonu formunda REKLAM YOK', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpSummary(tester);

    // Reklam yuvası anahtarları bu ekranda bulunmamalı.
    expect(find.byKey(const Key('break-ad-slot')), findsNothing);
    expect(find.textContaining('Sponsorlu'), findsNothing);
    expect(find.text('Bu ekranda reklam gösterilmez.'), findsOneWidget);
  });
}
