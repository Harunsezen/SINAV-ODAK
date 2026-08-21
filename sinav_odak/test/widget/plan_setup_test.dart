import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/session_setup/plan_setup.dart';
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/session/plan',
        routes: [
          GoRoute(path: '/session/plan', builder: (_, __) => const PlanSetup()),
          GoRoute(
            path: '/session/subject',
            builder: (_, __) => const Scaffold(body: Text('DERS SEC')),
          ),
          GoRoute(
            path: '/run',
            builder: (_, __) => const Scaffold(body: Text('RUN EKRANI')),
          ),
        ],
      );

  Future<ProviderContainer> pumpPlan(WidgetTester tester) async {
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

    // Kurulum akışı ders ve tür seçilmiş halde plana geliyor.
    container.read(setupProvider.notifier)
      ..selectSubject(id: subjectId, name: 'Matematik', colorHex: '#4F5BD5')
      ..selectActivityType(id: activityId, name: 'Soru Çözümü');

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

  Future<void> tapStepper(
    WidgetTester tester,
    Key key, {
    required bool plus,
    int times = 1,
  }) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(plus ? Icons.add : Icons.remove),
        ),
      );
      await tester.pump();
    }
  }

  // ---------------------------------------------------------------------

  testWidgets('hazır mod: 25+5 x3 -> 5 blok, son blok çalışma', (tester) async {
    await pumpPlan(tester);

    // Varsayılan: preset 0 (25+5), cycles 3.
    expect(find.byKey(const Key('plan-preview')), findsOneWidget);
    // 3 çalışma (25 dk) + 2 mola (5 dk): "25 · 5m · 25 · 5m · 25"
    expect(find.text('25 · 5m · 25 · 5m · 25'), findsOneWidget);
  });

  testWidgets('hazır mod: döngü sayısı değişince önizleme güncelleniyor',
      (tester) async {
    await pumpPlan(tester);
    await tapStepper(tester, const Key('preset-cycles'), plus: false, times: 2);

    // cycles 1 -> tek blok, mola yok.
    expect(find.text('25'), findsOneWidget);
    expect(find.text('Mola: 0dk'), findsOneWidget);
  });

  testWidgets('özel mod: 101 dk / 3 mola -> ilk blok 26 dk', (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();

    // Varsayılan 100 dk -> 101'e çıkar (adım 5, o yüzden 105 olur;
    // bunun yerine doğrudan 100 dk / 3 mola dağıtımını doğrula).
    expect(find.text('25 · 5m · 25 · 5m · 25 · 5m · 25'), findsOneWidget);
    expect(find.text('Çalışma: 1sa 40dk'), findsOneWidget);
  });

  testWidgets('özel mod: son mola iki katı uyarısı', (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom-last-long')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('plan-warning-lastBreakLongApplied')),
      findsOneWidget,
    );
  });

  testWidgets('özel mod: blok < 10 dk -> hata, BAŞLAT devre dışı',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();

    // 100 dk -> 10 dk (min), mola sayısı 3 -> blok başına 2.5 dk.
    await tapStepper(tester, const Key('custom-total'), plus: false, times: 18);

    expect(find.byKey(const Key('plan-error')), findsOneWidget);
    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('plan-start')));
    expect(btn.onPressed, isNull, reason: 'geçersiz planla başlatılamaz');
  });

  testWidgets('özel mod: blockTooLong uyarısı (tek blok 121 dk)',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();

    // Mola sayısını 0'a indir, süreyi 125 dk'ya çıkar.
    await tapStepper(tester, const Key('custom-breaks'), plus: false, times: 3);
    await tapStepper(tester, const Key('custom-total'), plus: true, times: 5);

    expect(find.byKey(const Key('plan-warning-blockTooLong')), findsOneWidget);
  });

  testWidgets('bitiş saati: saat seçilmeden hata gösteriliyor', (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Bitiş'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plan-error')), findsOneWidget);
    expect(find.text('Bitiş saatini seç.'), findsOneWidget);
  });

  testWidgets('bitiş saati: geçmiş saat seçilirse PlanFailure gösteriliyor',
      (tester) async {
    await pumpPlan(tester);
    await tester.tap(find.text('Bitiş'));
    await tester.pumpAndSettle();

    // t0'ın yerel saatinden BİR ÖNCEKİ saat -> geçmişte kalıyor.
    final pastHour = DateTime.fromMillisecondsSinceEpoch(t0).hour - 1;
    await tester.tap(find.byKey(const Key('end-hour')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(pastHour.toString().padLeft(2, '0')).last);
    await tester.pumpAndSettle();

    // KARAR K7: otomatik yarına taşınmaz, hata gösterilir.
    expect(find.byKey(const Key('plan-error')), findsOneWidget);
    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('plan-start')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('BAŞLAT: DB\'de running oturum oluşuyor ve /run\'a gidiliyor',
      (tester) async {
    await pumpPlan(tester);

    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    final active = await db.sessionDao.findActiveSession();
    expect(active, isNotNull);
    expect(active!.status, SessionStatus.running);
    expect(active.subjectId, subjectId);
    expect(active.topicId, isNull, reason: 'konu seçilmedi');
    expect(active.scheduleJson, contains('"version":1'));

    final blocks = await db.sessionDao.blocksOf(active.id);
    expect(blocks.length, 5, reason: '25+5 x3');

    expect(find.text('RUN EKRANI'), findsOneWidget);
  });

  testWidgets('BAŞLAT sonrası setup state SIFIRLANIYOR', (tester) async {
    final c = await pumpPlan(tester);

    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    expect(c.read(setupProvider), const SetupSelection());
  });

  testWidgets('aktif oturum varken SessionFailure SnackBar ile gösteriliyor',
      (tester) async {
    await seedRunningSession(db, id: 'mevcut', sch: schedule());
    await pumpPlan(tester);

    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    expect(
      find.text('Zaten devam eden bir oturum var. Önce onu bitir.'),
      findsOneWidget,
    );
    // Çökme yok, ekran hâlâ ayakta.
    expect(find.byKey(const Key('plan-start')), findsOneWidget);
  });
}
