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
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';
import 'package:sinav_odak/presentation/wrongs/add_wrong_screen.dart';
import 'package:sinav_odak/presentation/wrongs/wrong_list_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 2 — Yanlış defteri UI.
///
/// `wrong_items` tablosu Adım 2'den beri hazırdı ama ekranı yoktu; oturum
/// sonu formunun ürettiği kayıtlar kullanıcıya hiç görünmüyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: Routes.wrongs,
        routes: [
          GoRoute(
            path: Routes.wrongs,
            builder: (_, __) => const WrongListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (_, __) => const AddWrongScreen(),
              ),
            ],
          ),
          GoRoute(
            path: Routes.sessionPlan,
            builder: (_, __) => const Scaffold(body: Text('PLAN EKRANI')),
          ),
        ],
      );

  Future<ProviderContainer> pumpWrongs(WidgetTester tester) async {
    // Liste + FAB + segment birlikte uzun; varsayılan 800x600 yüzeyde
    // alttaki kartlar görünür alanın dışında kalıyor.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    // Container'ı önceden ısıt: Drift akışlarının ilk değeri gelmeden widget
    // kurulursa liste ve ders çipleri yükleniyor durumunda takılı kalır.
    await container.read(wrongItemsProvider(WrongItemStatus.active).future);
    await container.read(subjectsProvider.future);

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

  /// Seed verisi: sub_yks_1 = Matematik, top_sub_yks_1_22 = Türev.
  Future<void> addManual({
    String id = 'w1',
    String subject = subjectId,
    String? topic = topicId,
    int wrongCount = 5,
    String? note,
  }) =>
      db.wrongItemDao.addManual(
        id: id,
        subjectId: subject,
        topicId: topic,
        wrongCount: wrongCount,
        note: note,
      );

  Future<void> switchTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------

  testWidgets('kayıt yokken boş durum mesajı gösteriliyor', (tester) async {
    await pumpWrongs(tester);

    expect(find.byKey(const Key('wrongs-empty')), findsOneWidget);
    expect(find.textContaining('Aktif yanlışın yok'), findsOneWidget);
    expect(find.byKey(const Key('wrongs-list')), findsNothing);
  });

  testWidgets('boş durum mesajı sekmeye göre değişiyor', (tester) async {
    await pumpWrongs(tester);

    await switchTab(tester, 'Öğrenildi');
    expect(
      find.textContaining('öğrenildi işaretlediğin konu yok'),
      findsOneWidget,
    );
  });

  testWidgets('aktif kayıt kartta ders·konu, sayı ve rozetle görünüyor',
      (tester) async {
    await addManual(note: 'Zincir kuralı');
    await pumpWrongs(tester);

    expect(find.byKey(const Key('wrong-card-w1')), findsOneWidget);
    expect(find.text('Matematik · Türev'), findsOneWidget);
    expect(find.text('5 yanlış'), findsOneWidget);
    expect(find.text('Zincir kuralı'), findsOneWidget);
    expect(find.text('elle'), findsOneWidget, reason: 'kaynak rozeti');
  });

  testWidgets('oturumdan gelen kayıt auto rozetiyle görünüyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await db.wrongItemDao.upsertFromSession(
      id: 'wr_s1',
      sessionId: 's1',
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 3,
    );
    await pumpWrongs(tester);

    expect(find.text('oturumdan'), findsOneWidget);
    expect(find.text('3 yanlış'), findsOneWidget);
  });

  testWidgets('SegmentedButton filtresi listeyi ayırıyor', (tester) async {
    await addManual(id: 'w-aktif', wrongCount: 5);
    await addManual(id: 'w-tekrar', wrongCount: 7, topic: null);
    await db.wrongItemDao.setStatus('w-tekrar', WrongItemStatus.reviewed);
    await pumpWrongs(tester);

    // Aktif sekmesi yalnızca aktif kaydı gösterir.
    expect(find.byKey(const Key('wrong-card-w-aktif')), findsOneWidget);
    expect(find.byKey(const Key('wrong-card-w-tekrar')), findsNothing);

    await switchTab(tester, 'Tekrar edildi');
    expect(find.byKey(const Key('wrong-card-w-tekrar')), findsOneWidget);
    expect(find.byKey(const Key('wrong-card-w-aktif')), findsNothing);
  });

  testWidgets('durum ilerletme kalıcı: active -> reviewed -> mastered',
      (tester) async {
    await addManual();
    await pumpWrongs(tester);

    await tester.tap(find.text('Tekrar ettim'));
    await tester.pumpAndSettle();

    // Drift AKIŞI (watchByStatus) yerine Future sorgusu: `testWidgets` sahte
    // zaman bölgesinde akışın ilk değerini beklemek kilitleniyor.
    var rows = await db.select(db.wrongItems).get();
    expect(rows.single.status, WrongItemStatus.reviewed);
    // Aktif sekmesinden düştü.
    expect(find.byKey(const Key('wrong-card-w1')), findsNothing);

    await switchTab(tester, 'Tekrar edildi');
    await tester.tap(find.text('Öğrendim'));
    await tester.pumpAndSettle();

    rows = await db.select(db.wrongItems).get();
    expect(rows.single.status, WrongItemStatus.mastered);
  });

  testWidgets('mastered kayıtta ilerletme butonu YOK', (tester) async {
    await addManual();
    await db.wrongItemDao.setStatus('w1', WrongItemStatus.mastered);
    await pumpWrongs(tester);

    await switchTab(tester, 'Öğrenildi');

    expect(find.byKey(const Key('wrong-card-w1')), findsOneWidget);
    expect(find.text('Öğrendim'), findsNothing);
    expect(find.text('Tekrar ettim'), findsNothing);
  });

  testWidgets('detay sayfasından not düzenleniyor', (tester) async {
    await addManual(note: 'eski not');
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrong-card-w1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('wrong-note-field')),
      'yeni not',
    );
    await tester.tap(find.byKey(const Key('wrong-save-note')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.wrongItems).get();
    expect(rows.single.note, 'yeni not');
  });

  testWidgets('silme ONAY istiyor; vazgeçilirse kayıt duruyor', (tester) async {
    await addManual();
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrong-card-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wrong-delete-dialog')), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect((await db.select(db.wrongItems).get()).length, 1);
  });

  testWidgets('onaylanan silme manuel kaydı TAMAMEN kaldırıyor',
      (tester) async {
    await addManual();
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrong-card-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-delete-confirm')));
    await tester.pumpAndSettle();

    expect(await db.select(db.wrongItems).get(), isEmpty);
    expect(find.byKey(const Key('wrongs-empty')), findsOneWidget);
  });

  testWidgets('"Bu konuyu çalış" kurulumu doldurup plana gidiyor',
      (tester) async {
    await addManual();
    final c = await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrong-card-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-study-topic')));
    await tester.pumpAndSettle();

    final setup = c.read(setupProvider);
    expect(setup.subjectId, subjectId);
    expect(setup.subjectName, 'Matematik');
    expect(setup.topicId, topicId);
    expect(setup.topicName, 'Türev');
    expect(setup.activityTypeId, 'act_analiz');
    expect(
      setup.isReadyForPlan,
      isTrue,
      reason: 'kullanıcı ders/konu/tür ekranlarını tekrar gezmemeli',
    );
    expect(find.text('PLAN EKRANI'), findsOneWidget);
  });

  testWidgets('konusuz kayıtta "Bu konuyu çalış" yalnızca dersi dolduruyor',
      (tester) async {
    await addManual(topic: null);
    final c = await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrong-card-w1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-study-topic')));
    await tester.pumpAndSettle();

    final setup = c.read(setupProvider);
    expect(setup.subjectId, subjectId);
    expect(setup.topicId, isNull);
    expect(setup.isReadyForPlan, isTrue);
  });

  // --- Elle ekleme ---

  testWidgets('ders seçilmeden KAYDET pasif', (tester) async {
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrongs-add')));
    await tester.pumpAndSettle();

    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('add-wrong-save')));
    expect(btn.onPressed, isNull, reason: 'ders ZORUNLU');
  });

  testWidgets('elle kayıt ekleniyor ve listede görünüyor', (tester) async {
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrongs-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-wrong-subject-$subjectId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-wrong-inc')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-wrong-inc')));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('add-wrong-count'))).data,
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('add-wrong-note')),
      'limit tekrarı',
    );
    await tester.tap(find.byKey(const Key('add-wrong-save')));
    await tester.pumpAndSettle();

    final rows = await db.select(db.wrongItems).get();
    expect(rows.length, 1);
    expect(rows.single.subjectId, subjectId);
    expect(rows.single.wrongCount, 3);
    expect(rows.single.note, 'limit tekrarı');
    expect(rows.single.source, WrongItemSource.manual);
    expect(rows.single.status, WrongItemStatus.active);

    // Kayıt sonrası listeye dönülüyor ve kart görünüyor.
    expect(find.text('3 yanlış'), findsOneWidget);
  });

  testWidgets('yanlış sayısı 1 in altına düşmüyor', (tester) async {
    await pumpWrongs(tester);

    await tester.tap(find.byKey(const Key('wrongs-add')));
    await tester.pumpAndSettle();

    final dec =
        tester.widget<IconButton>(find.byKey(const Key('add-wrong-dec')));
    expect(dec.onPressed, isNull, reason: '0 yanlışlı kayıt anlamsız');
  });
}
