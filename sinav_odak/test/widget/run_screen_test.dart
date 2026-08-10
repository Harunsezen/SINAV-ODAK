import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/services/ad_policy_engine.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';
import 'package:sinav_odak/presentation/run/run_screen.dart';

import '../unit/usecase_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;
  late StreamController<int> ticker;

  setUp(() {
    db = newDb();
    fakeNow = t0;
    ticker = StreamController<int>.broadcast();
  });

  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  /// Gerçek GoRouter: `_confirmAndFinish` sonrası `context.go` çağrıldığı
  /// için ekranın bir router ataşı olmak zorunda.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run',
        routes: [
          GoRoute(path: '/run', builder: (_, __) => const RunScreen()),
          GoRoute(
            path: '/run/break',
            builder: (_, __) => const Scaffold(body: Text('BREAK EKRANI')),
          ),
          GoRoute(
            path: '/run/summary',
            builder: (_, __) => const Scaffold(body: Text('SUMMARY EKRANI')),
          ),
        ],
      );

  /// Container'ı önceden ısıtır: Drift stream'inin ilk değeri gelmeden
  /// widget kurulursa ekran yükleniyor durumunda takılı kalır.
  Future<ProviderContainer> pumpRun(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // KRİTİK: sabit epoch. Testler DateTime.now()'a bağlı değil.
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        // Gerçek 1 sn'lik periyodik akış yerine elle kontrol edilen tik.
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

  /// Bir görsel tik gönderir ve çerçeveyi ilerletir.
  Future<void> tick(WidgetTester tester) async {
    ticker.add(0);
    await tester.pump();
    await tester.pump();
  }

  // ---------------------------------------------------------------------

  testWidgets('aktif oturum yokken yükleniyor göstergesi çıkıyor',
      (tester) async {
    await pumpRun(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Bitir'), findsNothing);
  });

  testWidgets('çalışma bloğunda sayaç MM:SS biçiminde', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    // 24 dakikalık blok henüz başladı.
    expect(find.text('24:00'), findsOneWidget);
    expect(find.text('kalan'), findsOneWidget);
  });

  testWidgets('blok numarası ve toplam çalışma bloğu gösteriliyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    // Çizelge: study, break, study -> 2 çalışma bloğu, şu an 1.'si.
    expect(find.text('1. blok / 2'), findsOneWidget);
  });

  testWidgets('PAUSE BUTONU YOK — ürünün değişmez kuralı', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    expect(find.text('Durdur'), findsNothing);
    expect(find.text('Duraklat'), findsNothing);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.pause_circle), findsNothing);
    expect(find.byIcon(Icons.pause_circle_outline), findsNothing);
  });

  testWidgets('geri tuşu yakalanıyor: canPop false ve uyarı çıkıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    // PopScope jenerik bir sınıf; `byType(PopScope<Object?>)` eşleşmiyor.
    // Ayrıca GoRouter kendi PopScope'unu da ekliyor — bizimki canPop=false.
    final guardFinder = find.byWidgetPredicate(
      (w) => w is PopScope && !w.canPop,
    );
    expect(guardFinder, findsWidgets, reason: 'kazara çıkış engellenmeli');

    // Geri tuşu davranışını tetikle.
    final guard = tester.widgetList(guardFinder).first as PopScope;
    guard.onPopInvokedWithResult!(false, null);
    await tester.pump();

    expect(find.text('Oturumu bitirmek için "Bitir"e bas.'), findsOneWidget);
  });

  testWidgets('"Molayı Atla" çalışma sırasında PASİF', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Molayı Atla'),
    );
    expect(button.onPressed, isNull, reason: 'yalnızca molada aktif olmalı');
  });

  testWidgets('Bitir tek tıkla kapatmıyor: önce onay soruyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpRun(tester);

    // `OutlinedButton.icon` alt sınıf üretir; byType tam tip eşlediği
    // için doğrudan metne tıklanıyor.
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();

    expect(find.text('Oturumu bitelim mi?'), findsNothing);
    expect(find.text('Oturumu bitirelim mi?'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);

    // Vazgeç -> oturum hâlâ açık.
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.running);
    expect(
      c.read(pendingFinishProvider),
      isNull,
      reason: 'vazgeçilen onay bitiş bağlamı yazmamalı',
    );
  });

  // KARAR D1 ile DAVRANIŞ DEĞİŞTİ (koordinatör onaylı):
  // Onay artık `finishSession` ÇAĞIRMAZ. Oturum `running` kalır ve yalnızca
  // bitiş bağlamı `pendingFinishProvider`'a yazılır; kayıt tek yoldan,
  // oturum sonu formunun KAYDET butonundan geçer.
  //
  // Eski davranışta oturum, kullanıcı soru sayılarını girmeden kapanıyordu;
  // form KAYDET'e bastığında ikinci bir finish turu gerekiyordu.
  testWidgets('onay oturumu KAPATMIYOR: bitiş bağlamı yazılıp özete gidiliyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpRun(tester);

    // Bloğun 10. dakikası.
    fakeNow = t0 + 600000;
    await tick(tester);

    // `OutlinedButton.icon` alt sınıf üretir; byType tam tip eşlediği
    // için doğrudan metne tıklanıyor.
    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evet, bitir'));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(
      s!.status,
      SessionStatus.running,
      reason: 'kayıt YALNIZCA formun KAYDET butonundan geçer',
    );
    expect(s.endedAt, isNull);
    expect(find.text('SUMMARY EKRANI'), findsOneWidget);

    final pending = c.read(pendingFinishProvider);
    expect(pending, isNotNull);
    expect(pending!.early, isTrue);
    expect(
      pending.endMs,
      t0 + 600000,
      reason: 'süre onayın verildiği ana kadar hesaplanmalı',
    );
  });

  testWidgets('çizelge normal bitince bitiş bağlamı erken DEĞİL',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpRun(tester);

    fakeNow = lastEnd + 1000;
    await tick(tester);
    await tester.pumpAndSettle();

    expect(find.text('SUMMARY EKRANI'), findsOneWidget);

    final pending = c.read(pendingFinishProvider);
    expect(pending, isNotNull);
    expect(pending!.early, isFalse);
    expect(
      pending.endMs,
      lastEnd,
      reason: 'planlanan bitiş yazılmalı, formun açıldığı an değil',
    );
  });

  testWidgets('ticker yeniden boyuyor ama state\'i İLERLETMİYOR',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    expect(find.text('24:00'), findsOneWidget);

    // Saat ilerlemeden 5 tik: sayaç DEĞİŞMEMELİ.
    // Timer tabanlı bir sayaç olsaydı burada 23:55'e düşerdi.
    for (var i = 0; i < 5; i++) {
      await tick(tester);
    }
    expect(find.text('24:00'), findsOneWidget);

    // Saat 90 sn ilerleyince tik sayaca yansımalı.
    fakeNow = t0 + 90000;
    await tick(tester);
    expect(find.text('22:30'), findsOneWidget);
    expect(find.text('24:00'), findsNothing);
  });

  testWidgets('cihaz saati geri alınınca uyarı gösteriliyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = t0 - 60000;
    await pumpRun(tester);

    expect(
      find.textContaining('Cihaz saati değişmiş görünüyor'),
      findsOneWidget,
    );
    // Uyarı ekranında sayaç ve kontrol çubuğu gösterilmez.
    expect(find.text('Bitir'), findsNothing);
  });

  // FAZ 4 REGRESYONU: çalışma bloğunda TAM EKRAN reklam ASLA (G7).
  // Kural AdPolicyEngine ve AdGateway içinde zorlanıyor; bu test ekran
  // seviyesinde de kilitliyor.
  testWidgets('çalışma bloğunda TAM EKRAN reklam gösterilmiyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    final state = SessionState.inBlock(
      sessionId: 's1',
      blockIndex: 0,
      blockEndsAtMs: breakStart,
      remainingMs: 600000,
      schedule: schedule(),
    );

    for (final p in AdPlacement.values.where((p) => p.isFullScreen)) {
      expect(
        AdPolicyEngine.allows(
          placement: p,
          state: state,
          consent: true,
          nowMs: t0,
        ),
        isFalse,
        reason: '$p çalışma bloğunda ASLA',
      );
    }
  });

  testWidgets('çalışma ekranında rıza yoksa banner yuvası boş',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    // Varsayılan ayar: personalizedAdsConsent = false.
    expect(find.text('Sponsorlu'), findsNothing);
    expect(find.byKey(const Key('banner-slot-runBanner')), findsNothing);
  });

  testWidgets('mola başlayınca otomatik mola ekranına geçiyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpRun(tester);

    expect(find.text('24:00'), findsOneWidget);

    // Çalışma bloğu bitti, mola başladı.
    fakeNow = breakStart + 1000;
    await tick(tester);
    await tester.pumpAndSettle();

    expect(find.text('BREAK EKRANI'), findsOneWidget);
  });
}
