import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/presentation/book/book_run_screen.dart';
import 'package:sinav_odak/presentation/book/book_setup_screen.dart';
import 'package:sinav_odak/presentation/book/book_summary_form.dart';

import '../qa/qa_harness.dart';
import '../unit/usecase_helpers.dart';

/// v1.3 — **İKİ MOD AKIŞI, baştan sona.**
///
/// Koordinatörün istediği iki akışın tamamı burada yürüyor:
///
/// ```
/// MOD A  süre belirle → sayaç → Bitti → "Emin misin?" → Evet
///        → kitap adı + sayfa → kaydet
/// MOD B  sayfa hedefi → sayaç → Bitti → "Emin misin?" → Evet
///        → kitap adı + okunan sayfa → kaydet (hedef vs gerçekleşen)
/// ```
///
/// **Saat testin elinde.** `clockProvider` değiştirilebilir bir kapanışla
/// override ediliyor; `DateTime.now()` hiç çağrılmıyor ve sayaç istenen
/// ana taşınıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  /// Testin ilerletebildiği saat.
  var now = t0;

  /// Sayacın yeniden hesaplanmasını TETİKLEYEN vuruş.
  ///
  /// Üretimde bu saniyelik bir `Stream.periodic`; QA harness'i onu boş
  /// akışla kapatıyor (yoksa `pumpAndSettle` asla dönmez). Okuma sayacını
  /// ilerletmek için testin kontrol ettiği bir akış gerekiyordu:
  /// `bookRunSnapshotProvider` sade bir `Provider` ve yalnızca bir
  /// bağımlılığı değiştiğinde yeniden hesaplanıyor. Saati ileri almak tek
  /// başına yetmiyor — vuruş da gelmeli. **Üretimde de böyle çalışıyor.**
  late StreamController<int> ticker;

  setUp(() {
    db = newDb();
    ticker = StreamController<int>.broadcast();
  });
  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  Future<dynamic> openBook(WidgetTester tester) async {
    now = t0;
    await QaSeed.emptyUser(db);
    final c = await pumpQaApp(
      tester,
      db,
      size: const Size(411, 900),
      overrides: [
        clockProvider.overrideWithValue(() => now),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    c.read(appRouterProviderForQa).go(Routes.book);
    await tester.pumpAndSettle();
    return c;
  }

  /// Saati ilerletip ekranı yeniden çizdirir.
  ///
  /// Sayaç `Timer` DEĞİL: durum saklamıyor, her çizimde `now - startedAt`
  /// ile yeniden hesaplanıyor. Bu yüzden saati taşımak yetiyor.
  var tickNo = 0;
  Future<void> advance(WidgetTester tester, int seconds) async {
    now += seconds * 1000;
    ticker.add(tickNo++);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('MOD A — SÜRE: kurulum → sayaç → Bitti → onay → kaydet',
      (tester) async {
    final c = await openBook(tester);

    // --- Süre belirle: tek dokunuş 5 dk ekliyor (varsayılan 30) ---
    await tester.tap(find.byKey(const Key('book-duration-plus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.bookRun);
    final session = await db.bookDao.findActive();
    expect(session, isNotNull);
    expect(session!.mode, BookMode.duration);
    expect(session.plannedDurationS, 35 * 60, reason: '30 + tek dokunuş 5');

    // --- Sayaç GERİ sayıyor ---
    expect(find.byKey(const Key('book-run-counter')), findsOneWidget);
    expect(find.text('35:00'), findsOneWidget);
    await advance(tester, 600);
    expect(find.text('25:00'), findsOneWidget, reason: '10 dakika geçti');

    // --- Bitti → "Emin misin?" ---
    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('book-sure-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-sure-yes')));
    await tester.pumpAndSettle();
    expect(currentRoute(c), Routes.bookSummary);

    // --- Kitap adı + sayfa ---
    await tester.enterText(
      find.byKey(const Key('book-summary-name')),
      'Sefiller',
    );
    await tester.tap(find.byKey(const Key('book-pages-plus20')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BookSummaryForm.saveKey));
    await tester.pumpAndSettle();

    // --- Kayıt ---
    final saved = await db.bookDao.findById(session.id);
    expect(saved!.status, SessionStatus.earlyFinished);
    expect(saved.actualDurationS, 600);
    expect(saved.pagesRead, 20);
    expect(saved.bookTitle, 'Sefiller');
    expect(await db.bookDao.findActive(), isNull);
    expect(currentRoute(c), Routes.home);
  });

  testWidgets('MOD A — süre DOLUNCA kendiliğinden forma geçiyor',
      (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    // 30 dakika doldu.
    await advance(tester, 1800);

    expect(
      currentRoute(c),
      Routes.bookSummary,
      reason: 'süre dolduğunda kullanıcı "Bitti"ye basmak zorunda değil',
    );
    expect(find.byKey(const Key('book-summary-duration')), findsOneWidget);

    await tester.tap(find.byKey(BookSummaryForm.saveKey));
    await tester.pumpAndSettle();

    final rows = await db.select(db.bookSessions).get();
    expect(rows.single.status, SessionStatus.completed);
    expect(rows.single.actualDurationS, 1800);
  });

  testWidgets('MOD B — SAYFA HEDEFİ: sayaç İLERİ sayıyor, hedef görünüyor',
      (tester) async {
    final c = await openBook(tester);

    await tester.tap(find.text('Sayfa hedefi'));
    await tester.pumpAndSettle();

    // Varsayılan 20 sayfa; tek dokunuş +5 → 25.
    await tester.tap(find.byKey(const Key('book-pages-plus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    final session = await db.bookDao.findActive();
    expect(session!.mode, BookMode.pageTarget);
    expect(session.pageTarget, 25);
    expect(session.plannedDurationS, isNull);

    // Sayaç sıfırdan İLERİ.
    expect(find.text('00:00'), findsOneWidget);
    await advance(tester, 900);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.byKey(const Key('book-run-target')), findsOneWidget);

    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-sure-yes')));
    await tester.pumpAndSettle();

    // --- Hedef vs gerçekleşen ---
    expect(currentRoute(c), Routes.bookSummary);
    expect(find.byKey(const Key('book-summary-target')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-pages-target')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('book-summary-target-diff')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(BookSummaryForm.saveKey));
    await tester.pumpAndSettle();

    final saved = await db.bookDao.findById(session.id);
    expect(saved!.status, SessionStatus.completed, reason: 'hedefe ulaşıldı');
    expect(saved.pagesRead, 25);
    expect(saved.actualDurationS, 900);
  });

  testWidgets('"Emin misin?" → HAYIR: okuma DEVAM ediyor, veri kaybolmuyor',
      (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 600);

    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-sure-no')));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.bookRun, reason: 'sayaçta kalınıyor');
    expect(await db.bookDao.findActive(), isNotNull, reason: 'oturum AÇIK');
    expect(find.text('20:00'), findsOneWidget, reason: 'biriken süre duruyor');

    // Sayaç durmadı: "pause yok" kuralı korunuyor.
    await advance(tester, 300);
    expect(find.text('15:00'), findsOneWidget);
  });

  testWidgets('KİTAP ADI BOŞ bırakılabiliyor', (tester) async {
    await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 600);

    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-sure-yes')));
    await tester.pumpAndSettle();

    // Ad alanına HİÇ dokunulmuyor.
    expect(find.byKey(const Key('book-summary-name-hint')), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-pages-plus10')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BookSummaryForm.saveKey));
    await tester.pumpAndSettle();

    final rows = await db.select(db.bookSessions).get();
    expect(rows.single.bookTitle, isNull);
    expect(rows.single.pagesRead, 10);
  });

  testWidgets('Bitti → SİL → onay: okuma tamamen siliniyor', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 300);

    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-sure-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('book-discard-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('book-discard-confirm')));
    await tester.pumpAndSettle();

    expect(await db.select(db.bookSessions).get(), isEmpty);
    expect(currentRoute(c), Routes.home);
  });

  testWidgets('klavyeyle süre girilebiliyor (ÜÇÜNCÜ yol)', (tester) async {
    await openBook(tester);

    await tester.tap(find.byKey(const Key('book-duration-value')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('book-value-dialog')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('book-value-field')), '1sa');
    await tester.tap(find.byKey(const Key('book-value-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    expect((await db.bookDao.findActive())!.plannedDurationS, 3600);
  });

  testWidgets('GEÇERSİZ süre diyaloğu KAPATMIYOR, değer korunuyor',
      (tester) async {
    await openBook(tester);

    await tester.tap(find.byKey(const Key('book-duration-value')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('book-value-field')), '2');
    await tester.tap(find.byKey(const Key('book-value-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('book-value-error')), findsOneWidget);
    expect(find.byKey(const Key('book-value-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('book-value-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    expect(
      (await db.bookDao.findActive())!.plannedDurationS,
      1800,
      reason: 'geçersiz giriş eski değeri BOZMAMALI',
    );
  });

  testWidgets('ana panelden KİTAP OKU kapısı açılıyor', (tester) async {
    now = t0;
    await QaSeed.emptyUser(db);
    final c = await pumpQaApp(
      tester,
      db,
      size: const Size(411, 900),
      overrides: [
        clockProvider.overrideWithValue(() => now),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );

    await tester.tap(find.byKey(const Key('home-book')));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.book);
  });

  testWidgets('okuma sürerken ana paneldeki İKİ giriş de PASİF',
      (tester) async {
    // **Ekran görüntüsü denetiminde bulundu.** "Oturumu Başlat" okuma
    // sürerken hâlâ etkindi: dokununca router kullanıcıyı sayaca geri
    // atıyor, düğme hiçbir şey yapmamış gibi görünüyordu. v1.1'de
    // çalışma oturumu için düzeltilen hatanın (UX_REVIEW §1.3) kitap
    // sürümü.
    final c = await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    // Onaylı küçültme: ana panele ancak böyle çıkılıyor.
    await tester.tap(find.byKey(const Key('book-run-minimize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-minimize-confirm')));
    await tester.pumpAndSettle();
    expect(currentRoute(c), Routes.home);

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('home-start')))
          .onPressed,
      isNull,
      reason: 'okuma sürerken yeni oturum başlatılamaz',
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('home-book')))
          .onPressed,
      isNull,
      reason: 'ikinci okuma da başlatılamaz',
    );
    // Dönüş yolu KAPALI DEĞİL: şerit duruyor.
    expect(find.byKey(const Key('home-active-book')), findsOneWidget);
  });

  testWidgets('kitap oturumu açıkken ana panele KAÇILAMIYOR', (tester) async {
    final c = await openBook(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();

    c.read(appRouterProviderForQa).go(Routes.home);
    await tester.pumpAndSettle();

    expect(
      currentRoute(c),
      Routes.bookRun,
      reason: 'sayaç görünmeden işlemeye devam etmemeli',
    );
  });
}
