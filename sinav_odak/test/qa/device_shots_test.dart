import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// CİHAZ YELPAZESİ — dikey + YATAY ekran görüntüleri.
///
/// `responsive_test.dart` taşma **olmadığını** kanıtlıyor; bu dosya
/// sonucun nasıl **göründüğünü** üretiyor. İkisi ayrı sorular: taşmayan
/// bir düzen yine de kullanılamaz olabilir (her şey tek sütuna sıkışmış,
/// sayaç minicik kalmış, yatayda kocaman boşluk…).
///
/// Boyutlar **logical piksel**. Cihazın fiziksel çözünürlüğü piksel
/// oranıyla bölünerek buraya geliyor; düzen kararlarını belirleyen ölçü
/// logical olan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_devices');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak — cihaz yelpazesi ekran görüntüleri\n'
      'Üretim: flutter test test/qa/device_shots_test.dart\n'
      'Boyutlar logical piksel; dosya adı <cihaz>_<yön>_<ekran>.png\n'
      'Font: ${fonts.detail}\n',
    );
  });

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// (dosya adı, dikey logical boyut, açıklama)
  const devices = <(String, Size, String)>[
    ('01_j7prime', Size(360, 640), 'Galaxy J7 Prime · 720x1280 @dpr2'),
    ('02_telefon', Size(411, 731), 'tipik modern telefon'),
    ('03_ultra', Size(480, 1040), 'S26 Ultra sınıfı · 1440x3120 @dpr3'),
    ('04_tablet', Size(800, 1280), 'tablet · yatayda 1280x800'),
    ('05_chromebook', Size(768, 1366), 'Chromebook · yatayda 1366x768'),
    ('06_monitor', Size(1080, 1920), 'monitör / XR · yatayda 1920x1080'),
  ];

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(qaRepaintKey),
    );
    // `runAsync` şart: `toImage`/`toByteData` gerçek asenkron iş yapıyor.
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }
    });
    File('${outDir.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  for (final (devFile, portrait, note) in devices) {
    for (final (orient, size) in [
      ('dikey', portrait),
      ('yatay', Size(portrait.height, portrait.width)),
    ]) {
      final label = '$devFile · $orient '
          '(${size.width.toInt()}x${size.height.toInt()}) — $note';

      testWidgets('$label · ana panel', (tester) async {
        await QaSeed.activeUser(db);
        await pumpQaApp(tester, db, size: size);
        await shoot(tester, '${devFile}_${orient}_ana-panel');
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label · çalışma', (tester) async {
        await QaSeed.activeUser(db);
        await seedRunningSession(db, id: 'dev', sch: schedule());
        final c = await pumpQaApp(tester, db, size: size);
        c.read(appRouterProviderForQa).go(Routes.run);
        await tester.pumpAndSettle();
        await shoot(tester, '${devFile}_${orient}_calisma');
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label · istatistik', (tester) async {
        await QaSeed.activeUser(db);
        final c = await pumpQaApp(tester, db, size: size);
        c.read(appRouterProviderForQa).go(Routes.stats);
        await tester.pumpAndSettle();
        await shoot(tester, '${devFile}_${orient}_istatistik');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
