import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/presentation/achievements/achievement_toast.dart';
import 'package:sinav_odak/data/local/database.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// QA — EKRAN GÖRÜNTÜSÜ PASI.
///
/// Ana ekranları PNG olarak `qa_screenshots/` altına yazar: açık + koyu
/// tema, büyük font (textScale 1.5) ve dar ekran (360 px).
///
/// **Neden test içinde:** `flutter test` cihaz gerektirmiyor;
/// `RepaintBoundary.toImage` widget ağacını doğrudan piksellere çeviriyor.
/// Emulator bu ortamda çalışmıyor (KVM yok, SDK indirilemiyor — FAZ 6 §7),
/// bu yüzden görsel denetimin tek yolu bu.
///
/// Görüntüler **iddia edilmiyor** (altın dosya karşılaştırması yok); amaç
/// insan gözüyle bakılacak çıktı üretmek. Test yalnızca üretim sırasında
/// istisna atılmadığını doğruluyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_screenshots');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak — QA ekran görüntüleri\n'
      'Üretim: flutter test test/qa/screenshots_test.dart\n'
      'Font: ${fonts.detail}\n',
    );
  });

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Ağacı PNG'ye çevirip dosyaya yazar.
  Future<void> shoot(WidgetTester tester, String name) async {
    // `pumpAndSettle` sonrası bir kare daha: görüntü alınmadan önce son
    // düzen geçişinin tamamlandığından emin oluyoruz.
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(qaRepaintKey),
    );

    // **`runAsync` şart:** `toImage` ve `toByteData` gerçek (sahte olmayan)
    // asenkron iş yapıyor. Testin sahte zaman bölgesinde beklenirse PNG
    // üretiliyor ama test bitişte kilitleniyor. Flutter'ın kendi altın dosya
    // eşleştiricisi de aynı sebeple `runAsync` kullanıyor:
    // flutter_test/lib/src/_matchers_io.dart → MatchesGoldenFile.matchAsync.
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
    });

    expect(bytes, isNotNull, reason: '$name için PNG üretilemedi');
    File('${outDir.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Bir rotayı açıp görüntü alır.
  Future<void> shootRoute(
    WidgetTester tester,
    String route,
    String name, {
    Brightness brightness = Brightness.light,
    double textScale = 1.0,
    Size size = const Size(430, 932),
  }) async {
    final c = await pumpQaApp(
      tester,
      db,
      size: size,
      textScale: textScale,
      brightness: brightness,
    );
    if (route != Routes.home) {
      c.read(appRouterProviderForQa).go(route);
      await tester.pumpAndSettle();
    }
    await shoot(tester, name);
    expect(tester.takeException(), isNull, reason: '$name çizilirken hata');
  }

  // =====================================================================

  testWidgets('gerçek font yüklendi mi (rapor için)', (tester) async {
    // Font yüklenemezse görüntüler "Ahem" ile çıkar: tüm harfler siyah
    // kutu olur. Test DÜŞMÜYOR — durum rapora yazılıyor.
    // ignore: avoid_print
    print('QA FONT: ${fonts.detail}');
    expect(fonts.detail, isNotEmpty);
  });

  group('açık tema', () {
    testWidgets('ana panel', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.home, '01_home_light');
    });

    testWidgets('istatistik', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.stats, '02_stats_light');
    });

    testWidgets('takvim', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.calendar, '03_calendar_light');
    });

    testWidgets('yanlışlar', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.wrongs, '04_wrongs_light');
    });

    testWidgets('hedefler', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.goals, '05_goals_light');
    });

    testWidgets('rozetler', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.achievements, '06_achievements_light');
    });

    testWidgets('katalog yönetimi', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.manage, '07_catalog_light');
    });

    testWidgets('aktif oturum', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await shootRoute(tester, Routes.run, '08_run_light');
    });
  });

  group('koyu tema', () {
    testWidgets('ana panel', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.home,
        '11_home_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('istatistik', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.stats,
        '12_stats_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('takvim', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.calendar,
        '13_calendar_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('rozetler', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.achievements,
        '14_achievements_dark',
        brightness: Brightness.dark,
      );
    });

    testWidgets('aktif oturum', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await shootRoute(
        tester,
        Routes.run,
        '15_run_dark',
        brightness: Brightness.dark,
      );
    });
  });

  group('büyük font (textScale 1.5)', () {
    testWidgets('ana panel', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.home,
        '21_home_bigtext',
        textScale: 1.5,
      );
    });

    testWidgets('hedefler', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.goals,
        '22_goals_bigtext',
        textScale: 1.5,
      );
    });

    testWidgets('istatistik', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.stats,
        '23_stats_bigtext',
        textScale: 1.5,
      );
    });
  });

  group('dar ekran (360)', () {
    testWidgets('ana panel + uzun adlar', (tester) async {
      await QaSeed.activeUser(db);
      await QaSeed.longNames(db);
      await shootRoute(
        tester,
        Routes.home,
        '31_home_narrow',
        size: const Size(360, 800),
      );
    });

    testWidgets('istatistik + uzun adlar', (tester) async {
      await QaSeed.activeUser(db);
      await QaSeed.longNames(db);
      await shootRoute(
        tester,
        Routes.stats,
        '32_stats_narrow',
        size: const Size(360, 800),
      );
    });

    testWidgets('takvim', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(
        tester,
        Routes.calendar,
        '33_calendar_narrow',
        size: const Size(360, 800),
      );
    });
  });

  group('onboarding (cihaz hatası kanıtı)', () {
    // Bu iki görüntü ONBOARDING_BUG.md'nin görsel kanıtı: 5/5 adımında
    // [Başla] butonu gerçekten çiziliyor. Düzeltmeden önce bu ekranda
    // yalnızca "Geri" vardı.
    testWidgets('özet 5/5 açık', (tester) async {
      await QaSeed.emptyUser(db);
      await pumpQaOnboardingSummary(tester, db);
      await shoot(tester, '51_onboarding_summary_light');
      expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('özet 5/5 koyu', (tester) async {
      await QaSeed.emptyUser(db);
      await pumpQaOnboardingSummary(
        tester,
        db,
        brightness: Brightness.dark,
      );
      await shoot(tester, '52_onboarding_summary_dark');
      expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FAZ 1 — UX incelemesi görüntüleri', () {
    testWidgets('aktif oturum: geri tuşu görünür', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await shootRoute(tester, Routes.run, '61_run_backbutton');
    });

    testWidgets('oturumu küçültme onayı', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await pumpQaApp(tester, db);
      await tester.tap(find.byKey(const Key('run-minimize')));
      await tester.pumpAndSettle();
      await shoot(tester, '62_minimize_dialog');
      expect(tester.takeException(), isNull);
    });

    testWidgets('ana panel: oturuma dön şeridi', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await pumpQaMinimizedHome(tester, db);
      await shoot(tester, '63_home_active_banner');
      expect(find.byKey(const Key('home-active-session')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bitir: üç yollu diyalog', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await pumpQaApp(tester, db);
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      await shoot(tester, '64_early_finish_dialog');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bitir: üç yollu diyalog, büyük font', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await pumpQaApp(tester, db, size: const Size(360, 800), textScale: 1.3);
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      await shoot(tester, '65_early_finish_bigtext');
      expect(tester.takeException(), isNull);
    });

    testWidgets('kurulum: ders seçimi geri tuşuyla', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.sessionSubject, '66_setup_subject_back');
    });

    testWidgets('kurulum: plan ekranı geri tuşuyla', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.sessionPlan, '67_setup_plan_back');
    });
  });

  group('FAZ 2 — gamification', () {
    testWidgets('rozet şeridi (toast)', (tester) async {
      await QaSeed.activeUser(db);
      final c = await pumpQaApp(tester, db);
      c
          .read(achievementToastQueueProvider.notifier)
          .enqueue(['industry_escape']);
      await tester.pumpAndSettle();
      await shoot(tester, '71_achievement_toast');
      expect(find.byKey(const Key('achievement-toast')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('rozet şeridi koyu tema', (tester) async {
      await QaSeed.activeUser(db);
      final c = await pumpQaApp(tester, db, brightness: Brightness.dark);
      c.read(achievementToastQueueProvider.notifier).enqueue(['master_waits']);
      await tester.pumpAndSettle();
      await shoot(tester, '72_achievement_toast_dark');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('rozet şeridi dar ekran + büyük font', (tester) async {
      await QaSeed.activeUser(db);
      final c = await pumpQaApp(
        tester,
        db,
        size: const Size(360, 800),
        textScale: 1.5,
      );
      c.read(achievementToastQueueProvider.notifier).enqueue(['master_waits']);
      await tester.pumpAndSettle();
      await shoot(tester, '73_achievement_toast_narrow');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('kademe çipleri (aktif oturum)', (tester) async {
      await QaSeed.activeUser(db);
      await seedRunningSession(db, id: 'shot', sch: schedule());
      await shootRoute(tester, Routes.run, '74_block_chips');
    });

    testWidgets('Sanayi Evreni rozetleri listede', (tester) async {
      await QaSeed.activeUser(db);
      await shootRoute(tester, Routes.achievements, '75_sanayi_badges');
    });
  });

  group('boş durumlar', () {
    testWidgets('istatistik boş', (tester) async {
      await QaSeed.emptyUser(db);
      await shootRoute(tester, Routes.stats, '41_stats_empty');
    });

    testWidgets('hedefler boş', (tester) async {
      await QaSeed.emptyUser(db);
      await shootRoute(tester, Routes.goals, '42_goals_empty');
    });

    testWidgets('takvim boş', (tester) async {
      await QaSeed.emptyUser(db);
      await shootRoute(tester, Routes.calendar, '43_calendar_empty');
    });
  });
}
