import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/finish_book_session.dart';
import 'package:sinav_odak/application/usecases/start_book_session.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/repositories/session_repository.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/presentation/book/book_run_screen.dart';
import 'package:sinav_odak/presentation/book/book_setup_screen.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// v1.3/KİTAP — EKRAN GÖRÜNTÜLERİ.
///
/// Testler akışın çalıştığını kanıtlıyor. Bu dosya nasıl **göründüğünü**
/// üretiyor: sayaç okunuyor mu, "Emin misin?" diyaloğundaki üç eylem dar
/// ekranda üst üste biniyor mu, istatistikteki kitap kartı çalışma
/// kartlarından ayrışıyor mu.
///
/// Bu turda üretilen görüntüler **gözle denetlendi**; bulunanlar raporda.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  var now = t0;
  late StreamController<int> ticker;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_book');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak v1.3 — kitap okuma modu ekran görüntüleri\n'
      'Üretim: flutter test test/qa/book_shots_test.dart\n'
      'Font: ${fonts.detail}\n',
    );
  });

  setUp(() {
    db = newDb();
    now = t0;
    ticker = StreamController<int>.broadcast();
  });
  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(qaRepaintKey),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2.0);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
    });
    File(
      '${outDir.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<dynamic> open(
    WidgetTester tester, {
    Size size = const Size(411, 731),
    String route = Routes.book,
  }) async {
    final c = await pumpQaApp(
      tester,
      db,
      size: size,
      overrides: [
        clockProvider.overrideWithValue(() => now),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    c.read(appRouterProviderForQa).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  var tick = 0;
  Future<void> advance(WidgetTester tester, int seconds) async {
    now += seconds * 1000;
    ticker.add(tick++);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Kapanmış okumalarla dolu bir geçmiş — istatistik kartı için.
  Future<void> seedReadings() async {
    final start = StartBookSessionUseCase(db);
    final finish = FinishBookSessionUseCase(db, SessionRepository(db));

    const days = ['2025-08-04', '2025-08-05', '2025-08-06'];
    const titles = ['Sefiller', 'Kürk Mantolu Madonna', null];
    for (final (i, day) in days.indexed) {
      final parts = day.split('-').map(int.parse).toList();
      final ms =
          DateTime(parts[0], parts[1], parts[2], 20).millisecondsSinceEpoch;
      await start(
        sessionId: 'bk$i',
        mode: BookMode.duration,
        nowMs: ms,
        durationS: 1800 + i * 600,
      );
      await finish(
        sessionId: 'bk$i',
        nowMs: ms + (1800 + i * 600) * 1000,
        pagesRead: 22 + i * 9,
        bookTitle: titles[i],
      );
    }
  }

  testWidgets('01 · kurulum — SÜRE modu', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await shoot(tester, '01_kurulum_sure');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 · kurulum — SAYFA HEDEFİ modu', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await tester.tap(find.text('Sayfa hedefi'));
    await tester.pumpAndSettle();
    await shoot(tester, '02_kurulum_sayfa');
    expect(tester.takeException(), isNull);
  });

  testWidgets('03 · sayaç — geri sayım', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 420);
    await shoot(tester, '03_sayac_geri');
    expect(tester.takeException(), isNull);
  });

  testWidgets('04 · sayaç — ileri sayım + hedef', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await tester.tap(find.text('Sayfa hedefi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 900);
    await shoot(tester, '04_sayac_ileri');
    expect(tester.takeException(), isNull);
  });

  testWidgets('05 · "Emin misin?" diyaloğu', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 600);
    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await shoot(tester, '05_emin_misin');
    expect(tester.takeException(), isNull);
  });

  testWidgets('06 · "Emin misin?" — DAR ekran 320 px', (tester) async {
    // Üç eylemli diyalog dar ekranda alt alta geçiyor; yıkıcı eylem
    // birincilin üstüne düşmemeli (v1.1'de çalışma oturumunda yaşandı).
    await QaSeed.emptyUser(db);
    await open(tester, size: const Size(320, 568));
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 600);
    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await shoot(tester, '06_emin_misin_320');
    expect(tester.takeException(), isNull);
  });

  testWidgets('07 · oturum sonu formu — sayfa hedefi', (tester) async {
    await QaSeed.emptyUser(db);
    await open(tester);
    await tester.tap(find.text('Sayfa hedefi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 1500);
    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-sure-yes')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('book-summary-name')),
      'Kürk Mantolu Madonna',
    );
    await tester.tap(find.byKey(const Key('book-pages-plus20')));
    await tester.pumpAndSettle();
    await shoot(tester, '07_oturum_sonu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('08 · ana panel — Kitap Oku kapısı', (tester) async {
    await QaSeed.activeUser(db);
    await seedReadings();
    await open(tester, route: Routes.home);
    await shoot(tester, '08_ana_panel');
    expect(tester.takeException(), isNull);
  });

  testWidgets('09 · istatistik — kitap kartı + yığılmış grafik',
      (tester) async {
    await QaSeed.activeUser(db);
    await seedReadings();
    await open(tester, size: const Size(411, 1100), route: Routes.stats);
    await shoot(tester, '09_istatistik');
    expect(tester.takeException(), isNull);
  });

  testWidgets('10 · İNGİLİZCE — kurulum ve sayaç', (tester) async {
    await QaSeed.emptyUser(db);
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(language: Value(AppLanguage.en)),
    );
    await open(tester);
    await shoot(tester, '10_en_kurulum');

    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 300);
    await tester.tap(find.byKey(BookRunScreen.finishKey));
    await tester.pumpAndSettle();
    await shoot(tester, '11_en_emin_misin');
    expect(tester.takeException(), isNull);
  });

  testWidgets('13 · oturum sonu: YANLIŞ KONU SEÇİCİ (v1.3 yaması)',
      (tester) async {
    // Çalışma oturumu formu — kitap değil. Üç konulu bir oturum yanlışla
    // bitirilince gömülü seçici çıkıyor; duygu seçicisi de artık emoji
    // değil Material ikonu.
    await QaSeed.emptyUser(db);
    final sch = schedule();
    await db.sessionDao.createSession(
      StudySessionsCompanion.insert(
        id: 'w1',
        dateKey: '2025-08-06',
        startedAt: sch.firstStartMs,
        plannedDurationS: sch.totalStudyS,
        subjectId: subjectId,
        topicId: const Value('top_sub_yks_1_22'),
        activityTypeId: activityId,
        status: SessionStatus.running,
        scheduleJson: jsonEncode(sch.toJson()),
      ),
      ScheduleWriter.blocksOf('w1', sch),
      topicIds: const [
        'top_sub_yks_1_22',
        'top_sub_yks_1_23',
        'top_sub_yks_1_0',
      ],
    );

    // **Uygulama oturum SÜRERKEN kuruluyor.** Saat doğrudan çizelgenin
    // sonuna alınsaydı ana panel `/run`a yönleniyor ve RunScreen
    // `summarizing` durumunda sonsuz dönen bir gösterge çiziyordu;
    // `pumpAndSettle` hiç dönmüyordu. Sayaç ilerletilince ekranın kendi
    // dinleyicisi formu açıyor — gerçek yol da bu.
    now = t0;
    await pumpQaApp(
      tester,
      db,
      size: const Size(411, 1400),
      overrides: [
        clockProvider.overrideWithValue(() => now),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    await advance(tester, (lastEnd + 1000 - t0) ~/ 1000);
    expect(find.byKey(const Key('summary-form')), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-q-plus20')));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('summary-wrong-inc')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('summary-mood-4')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('summary-wrong-topic')), findsOneWidget);
    await shoot(tester, '13_yanlis_konu_secici');
    expect(tester.takeException(), isNull);
  });

  testWidgets('12 · küçültülmüş okuma şeridi', (tester) async {
    await QaSeed.activeUser(db);
    final c = await open(tester);
    await tester.tap(find.byKey(BookSetupScreen.startKey));
    await tester.pumpAndSettle();
    await advance(tester, 300);
    await tester.tap(find.byKey(const Key('book-run-minimize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('book-minimize-confirm')));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.home);
    await shoot(tester, '12_kucultulmus_serit');
    expect(tester.takeException(), isNull);
  });
}
