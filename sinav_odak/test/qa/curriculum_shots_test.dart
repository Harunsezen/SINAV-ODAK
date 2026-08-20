import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/curriculum/topic_tree_view.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// v1.2 — MÜFREDAT AĞACININ GÖRÜNTÜLERİ.
///
/// `responsive_test.dart` taşma **olmadığını**, `curriculum_screen_test`
/// davranışın **doğru olduğunu** kanıtlıyor. Bu dosya sonucun nasıl
/// **göründüğünü** üretiyor: yeşil testler bir listenin okunabilir olduğunu
/// söylemiyor. 814 satırlık müfredatta okunabilirlik ürünün kendisi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_curriculum');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak v1.2 — müfredat ağacı ekran görüntüleri\n'
      'Üretim: flutter test test/qa/curriculum_shots_test.dart\n'
      'Font: ${fonts.detail}\n',
    );
  });

  setUp(() => db = newDb());
  tearDown(() async => db.close());

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

  Future<void> openCurriculum(
    WidgetTester tester, {
    Size size = const Size(411, 731),
    String subjectId = 'sub_yks_1',
  }) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: size);
    c.read(appRouterProviderForQa).go(Routes.curriculum);
    await tester.pumpAndSettle();

    final chip = find.byKey(Key('curriculum-subject-$subjectId'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  testWidgets('01 · müfredat · ders ağacı', (tester) async {
    await openCurriculum(tester);
    await shoot(tester, '01_mufredat_agac');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 · müfredat · alt dallar açık', (tester) async {
    await openCurriculum(tester);
    // Listenin ÜST ucundan bir konu: `ListView.builder` görünmeyen satırı
    // hiç kurmuyor ve `ensureVisible` var olmayan öğede StateError atıyor.
    final toggle = find.byKey(const Key('topic-expand-top_sub_yks_1_2'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await shoot(tester, '02_mufredat_alt_dallar');
    expect(tester.takeException(), isNull);
  });

  testWidgets('03 · müfredat · TYT seviyesi', (tester) async {
    await openCurriculum(tester);
    final chip = find.byKey(const Key('topic-level-tyt'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await shoot(tester, '03_mufredat_tyt');
    expect(tester.takeException(), isNull);
  });

  testWidgets('04 · müfredat · alt dal araması', (tester) async {
    await openCurriculum(tester, subjectId: 'sub_yks_5');
    await tester.enterText(find.byKey(TopicTreeView.searchKey), 'mitoz');
    await shoot(tester, '04_mufredat_arama');
    expect(tester.takeException(), isNull);
  });

  testWidgets('05 · konu seçici · ağaç', (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(411, 731));
    c.read(appRouterProviderForQa).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    await shoot(tester, '05_konu_secici');
    expect(tester.takeException(), isNull);
  });

  testWidgets('06 · müfredat · 320 px dar ekran', (tester) async {
    await openCurriculum(tester, size: const Size(320, 568));
    await shoot(tester, '06_mufredat_320');
    expect(tester.takeException(), isNull);
  });

  testWidgets('07 · müfredat · tablet yatay', (tester) async {
    await openCurriculum(tester, size: const Size(1280, 800));
    await shoot(tester, '07_mufredat_tablet');
    expect(tester.takeException(), isNull);
  });
}
