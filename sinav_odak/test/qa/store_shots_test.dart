import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// MAĞAZA EKRAN GÖRÜNTÜLERİ — `store_assets/` üretici.
///
/// Play listelemesindeki **altı** görüntünün tamamı burada üretiliyor:
/// dört telefon + iki tablet. Tek komutla yenilenebilmesi önemli, çünkü
/// arayüz her değiştiğinde vitrin görselleri eskiyor.
///
/// ## Ölçek: yüzey logical, çıktı pixelRatio ile büyütülüyor
///
/// | Hedef | Yüzey (logical) | pixelRatio | Çıktı |
/// | --- | --- | --- | --- |
/// | Telefon | 360×640 | 3.0 | **1080×1920** (9:16) |
/// | Tablet | 1280×800 | 1.5 | **1920×1200** (10" standardı) |
///
/// Yeniden boyutlandırma **yok**: `toImage` widget ağacını doğrudan hedef
/// çözünürlükte çiziyor, dolayısıyla metin gerçekten keskin.
///
/// > Tabletler önce pixelRatio 1.0 ile (1280×800) üretilmişti ve aynı
/// > listelemede telefonların yanında yumuşak kalıyordu. Ölçek farkı
/// > listeleme sayfasında gözle görülüyor.
///
/// Tablet yüzeyi yatay ve geniş olduğu için `AppShell` **yan rayı**
/// seçiyor — vitrindeki görüntü büyük ekran düzenini gösteriyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('store_assets');
    outDir.createSync(recursive: true);
  });

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required double ratio,
  }) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(qaRepaintKey),
    );
    // `runAsync` şart: `toImage`/`toByteData` gerçek asenkron iş yapıyor;
    // sahte zaman bölgesinde beklenirse test bitişte kilitleniyor.
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
    });
    File('${outDir.path}/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  /// Vitrin için birkaç rozet daha açıyor — `activeUser` ikisini açıyor.
  Future<void> seedShowcase() async {
    await QaSeed.activeUser(db);
    for (final code in ['streak_7', 'hours_10', 'focus_90']) {
      await db.achievementDao.unlock(code: code, unlockedAtMs: t0);
      await db.achievementDao.markSeen(code);
    }
  }

  Future<void> capture(
    WidgetTester tester, {
    required String file,
    required Size surface,
    required double ratio,
    required String route,
    bool running = false,
    bool scrollToEnd = false,
  }) async {
    await seedShowcase();
    if (running) {
      await seedRunningSession(db, id: 'store', sch: schedule());
    }
    final c = await pumpQaApp(tester, db, size: surface);
    if (route != Routes.home) {
      c.read(appRouterProviderForQa).go(route);
      await tester.pumpAndSettle();
    }
    if (scrollToEnd) {
      // Listenin SONUNA kaydır. `AppBar` sabit olduğu için başlık yerinde
      // kalıyor; kazanılan tek şey alttaki içeriğin tam çerçeveye
      // girmesi.
      //
      // Miktar GÖZLE ayarlandı: sona kadar (-600) kaydırınca üstteki
      // çubuk grafik yarılanıyordu. -190 hem halkayı tam çerçeveye
      // alıyor hem grafiği bütün bırakıyor.
      await tester.drag(find.byType(ListView), const Offset(0, -190));
      await tester.pumpAndSettle();
    }
    await shoot(tester, file, ratio: ratio);
    expect(tester.takeException(), isNull, reason: '$file çizilirken hata');
  }

  // --- Telefon: 360×640 @3.0 → 1080×1920 --------------------------------
  const phone = Size(360, 640);
  const phoneRatio = 3.0;

  testWidgets('font gerçek mi (yoksa harfler siyah kutu çıkar)',
      (tester) async {
    // ignore: avoid_print
    print('STORE FONT: ${fonts.detail}');
    expect(fonts.detail, isNotEmpty);
  });

  testWidgets('screen_1 — ana panel', (tester) async {
    await capture(
      tester,
      file: 'screen_1.png',
      surface: phone,
      ratio: phoneRatio,
      route: Routes.home,
    );
  });

  testWidgets('screen_2 — çalışma ekranı', (tester) async {
    await capture(
      tester,
      file: 'screen_2.png',
      surface: phone,
      ratio: phoneRatio,
      route: Routes.run,
      running: true,
    );
  });

  testWidgets('screen_3 — istatistik', (tester) async {
    await capture(
      tester,
      file: 'screen_3.png',
      surface: phone,
      ratio: phoneRatio,
      route: Routes.stats,
    );
  });

  testWidgets('screen_4 — rozetler', (tester) async {
    await capture(
      tester,
      file: 'screen_4.png',
      surface: phone,
      ratio: phoneRatio,
      route: Routes.achievements,
    );
  });

  // --- Tablet: 1280×800 @1.5 → 1920×1200 --------------------------------
  const tablet = Size(1280, 800);
  const tabletRatio = 1.5;

  testWidgets('tablet_1 — ana panel (yan ray)', (tester) async {
    await capture(
      tester,
      file: 'tablet_1.png',
      surface: tablet,
      ratio: tabletRatio,
      route: Routes.home,
    );
  });

  testWidgets('tablet_2 — istatistik (yan ray, halka tam görünür)',
      (tester) async {
    // İlk çekimde alttaki ders dağılımı halkası çerçeveden taşıyordu:
    // içerik kaydırılabilir, görünen alan halkanın ortasında bitiyordu.
    // Vitrin görselinde yarım kesilmiş grafik özensiz duruyor.
    await capture(
      tester,
      file: 'tablet_2.png',
      surface: tablet,
      ratio: tabletRatio,
      route: Routes.stats,
      scrollToEnd: true,
    );
  });
}
