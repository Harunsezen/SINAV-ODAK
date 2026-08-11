import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';
import 'package:sinav_odak/presentation/run/summary_form.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../unit/usecase_helpers.dart';

/// S10 — Oturum sonu formu.
///
/// Bu dosya, iskelet dönemindeki `summary_screen_test.dart`'ın yerini alır.
/// Oradaki iki test ("yer tutucular mevcut", "KAYDET henüz bağlı değil")
/// AG5-2'nin tam olarak bitirdiği durumu doğruluyordu; taşınamazdı. Kalan üç
/// koruma (boş durum, özet başlığı, REKLAM YOK) buraya aynen taşındı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  /// Gerçek GoRouter: KAYDET sonrası `context.go('/run/done')` çağrılıyor.
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/summary',
        routes: [
          GoRoute(
            path: '/run/summary',
            builder: (_, __) => const SummaryForm(),
          ),
          GoRoute(
            path: '/run/done',
            builder: (_, __) => const Scaffold(body: Text('DONE EKRANI')),
          ),
        ],
      );

  Future<ProviderContainer> pumpForm(WidgetTester tester) async {
    // Form uzun bir liste; varsayılan 800x600 yüzeyde KAYDET görünür alanın
    // dışında kalıyor ve dokunuşlar hedefe ulaşmıyor. Yüzeyi yükselterek
    // her bölüm tek çerçevede render ediliyor.
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // KRİTİK: sabit epoch. Testler DateTime.now()'a bağlı değil.
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

  /// Sayacı [times] kez artırır.
  ///
  /// Her dokunuştan sonra çerçeve ilerletiliyor: `onPressed` kapanışı son
  /// çizilen değeri yakalar, ara pump olmadan N dokunuş değeri 1 yapar.
  Future<void> bump(WidgetTester tester, String slug, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(Key('summary-$slug-inc')));
      await tester.pump();
    }
  }

  // ---------------------------------------------------------------------

  testWidgets('oturum yoksa boş durum gösteriliyor', (tester) async {
    await pumpForm(tester);
    expect(find.byKey(const Key('summary-empty')), findsOneWidget);
  });

  testWidgets('oturum sürüyor ama bitiş onayı yoksa form açılmıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    await pumpForm(tester);

    expect(find.byKey(const Key('summary-empty')), findsOneWidget);
    expect(find.byKey(const Key('summary-form')), findsNothing);
  });

  testWidgets('çizelge bitince oturum özeti ve ders·konu gösteriliyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    expect(find.byKey(const Key('summary-form')), findsOneWidget);
    expect(find.text('Oturum tamamlandı'), findsOneWidget);
    expect(find.text('Çalışma: 48dk'), findsOneWidget);
    expect(find.text('Mola: 5dk'), findsOneWidget);
    // Seed verisi: sub_yks_1 = Matematik, top_sub_yks_1_22 = Türev.
    expect(find.text('Matematik · Türev'), findsOneWidget);
  });

  testWidgets('oturum sonu formunda REKLAM YOK', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    // Reklam yuvası anahtarları bu ekranda bulunmamalı.
    expect(find.byKey(const Key('break-ad-slot')), findsNothing);
    expect(find.textContaining('Sponsorlu'), findsNothing);
    expect(find.text('Bu ekranda reklam gösterilmez.'), findsOneWidget);
  });

  testWidgets('hızlı butonlar ve Sıfırla soru sayısını değiştiriyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('summary-q-plus20')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('summary-q-plus10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('summary-q-plus5')));
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('summary-q-field')),
    );
    expect(field.controller!.text, '35');

    await tester.tap(find.byKey(const Key('summary-q-reset')));
    await tester.pump();
    expect(field.controller!.text, '0');
  });

  testWidgets('canlı net önizlemesi ayardaki katsayıyla hesaplanıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    // 60 soru: 44 doğru, 12 yanlış, 4 boş. Katsayı 4.0 (varsayılan ayar).
    // net = 44 - (12 / 4) = 41.0
    await tester.enterText(find.byKey(const Key('summary-q-field')), '60');
    await tester.pump();
    await bump(tester, 'correct', 44);
    await bump(tester, 'wrong', 12);
    await bump(tester, 'empty', 4);

    expect(
      tester.widget<Text>(find.byKey(const Key('summary-net'))).data,
      '41',
      reason: 'net 41.0 -> formatNet "41"',
    );
    expect(find.byKey(const Key('summary-invariant-error')), findsNothing);
  });

  testWidgets(
      'D+Y+B soru sayısını aşarsa ValidationFailure mesajı çıkıyor '
      've KAYDET pasifleşiyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('summary-q-field')), '5');
    await tester.pump();
    await bump(tester, 'correct', 4);
    await bump(tester, 'wrong', 3);

    // Mesaj domain'in kendisinden geliyor (NetCalculator.calculate).
    expect(find.byKey(const Key('summary-invariant-error')), findsOneWidget);
    expect(find.textContaining('çözülen soru sayısını'), findsOneWidget);
    expect(find.byKey(const Key('summary-net')), findsNothing);

    final btn =
        tester.widget<FilledButton>(find.byKey(const Key('summary-save')));
    expect(btn.onPressed, isNull, reason: 'geçersiz girdiyle kayıt açılmamalı');
  });

  testWidgets(
      'KAYDET: oturum completed + yanlış defteri + daily_stats yazılıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    await tester.enterText(find.byKey(const Key('summary-q-field')), '20');
    await tester.pump();
    await bump(tester, 'correct', 15);
    await bump(tester, 'wrong', 4);
    await bump(tester, 'empty', 1);
    await tester.tap(find.byKey(const Key('summary-mood-4')));
    await tester.enterText(
      find.byKey(const Key('summary-note')),
      'Türev iyi gitti',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('summary-save')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.completed);
    expect(s.actualDurationS, 2880, reason: 'planlanan çalışma süresi');
    expect(s.questionCount, 20);
    expect(s.correctCount, 15);
    expect(s.wrongCount, 4);
    expect(s.emptyCount, 1);
    expect(s.net, 14.0, reason: '15 - 4/4');
    expect(s.mood, 4);
    expect(s.note, 'Türev iyi gitti');
    expect(s.focusScore, isNotNull);

    // Yanlış defteri: wrongCount > 0 olduğu için otomatik kayıt düşmeli.
    //
    // Drift AKIŞLARI (watchByStatus / watchDay) burada bilinçli olarak
    // kullanılmıyor: `testWidgets` sahte zaman bölgesinde çalışır ve akışın
    // ilk değerini beklemek kilitlenmeye yol açar. Aynı veriyi döndüren
    // Future tabanlı sorgular kullanılıyor.
    final wrongs = await db.select(db.wrongItems).get();
    expect(wrongs.length, 1);
    expect(wrongs.single.wrongCount, 4);
    expect(wrongs.single.source, WrongItemSource.auto);
    expect(wrongs.single.status, WrongItemStatus.active);

    // daily_stats orkestrasyonu SessionRepository üzerinden çalışmalı.
    final day = DateTime.parse('2025-08-06');
    final stat = await db.statsDao.summaryFor(day, day);
    expect(stat.sessionCount, 1);
    expect(stat.questionCount, 20);
    expect(stat.totalStudyS, 2880);

    expect(find.text('DONE EKRANI'), findsOneWidget);
  });

  testWidgets(
      'erken bitirmede earlyFinished ve actualDurationS pendingFinish.endMs\'ten',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    // Çizelge HÂLÂ SÜRÜYOR: erken bitirmede state `inBlock`, `summarizing`
    // değil. Formu açan şey bitiş onayının kendisidir.
    fakeNow = t0 + 600000;
    final c = await pumpForm(tester);

    c.read(pendingFinishProvider.notifier).set(early: true, endMs: t0 + 600000);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-form')), findsOneWidget);
    expect(
      find.text('Çalışma: 10dk'),
      findsOneWidget,
      reason: 'başlık gerçekleşen süreyi göstermeli',
    );

    await tester.tap(find.byKey(const Key('summary-save')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s!.status, SessionStatus.earlyFinished);
    expect(
      s.actualDurationS,
      600,
      reason: 'süre endMs\'e kadar; formda geçen süre eklenmemeli',
    );
    expect(s.endedAt, t0 + 600000);
    expect(find.text('DONE EKRANI'), findsOneWidget);
  });

  testWidgets('KAYDET sonrası bitiş bağlamı temizlenip sonuç yazılıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    final c = await pumpForm(tester);

    await tester.tap(find.byKey(const Key('summary-save')));
    await tester.pumpAndSettle();

    expect(c.read(pendingFinishProvider), isNull);
    final saved = c.read(savedResultProvider);
    expect(saved, isNotNull);
    expect(saved!.sessionId, 's1');
    expect(saved.dateKey, '2025-08-06');
    expect(saved.focusScore, isNotNull);
  });

  testWidgets('oturum kaybolmuşsa AppFailure SnackBar ile gösteriliyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    fakeNow = lastEnd + 1000;
    await pumpForm(tester);

    // Kayıt tuşuna basılmadan hemen önce oturum başka bir yoldan silinsin.
    await db.sessionDao.deleteSession('s1');

    await tester.tap(find.byKey(const Key('summary-save')));
    await tester.pumpAndSettle();

    expect(find.text('Oturum bulunamadı.'), findsOneWidget);
    expect(find.text('DONE EKRANI'), findsNothing);
  });
}
