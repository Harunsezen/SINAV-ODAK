import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/curriculum/topic_tree_view.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';
import 'package:sinav_odak/presentation/session_setup/topic_picker.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// v1.2/D — ÇOKLU KONU SEÇİMİNİN GÖRÜNTÜLERİ.
///
/// Testler seçimin çalıştığını kanıtlıyor. Bu dosya nasıl **göründüğünü**
/// üretiyor: kutucuk fark ediliyor mu, alt çubuk okunuyor mu, dar ekranda
/// "3 konu seçildi" + "Devam" sığıyor mu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_multitopic');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak v1.2/D — çoklu konu ekran görüntüleri\n'
      'Üretim: flutter test test/qa/multi_topic_shots_test.dart\n'
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

  Future<dynamic> openPicker(
    WidgetTester tester, {
    Size size = const Size(411, 731),
  }) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: size);
    c.read(appRouterProviderForQa).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> check(WidgetTester tester, String topicId) async {
    final box = find.byKey(Key('topic-check-$topicId'));
    final list = find.descendant(
      of: find.byKey(TopicTreeView.listKey),
      matching: find.byType(Scrollable),
    );
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    if (box.evaluate().isEmpty) {
      await tester.scrollUntilVisible(box, 200, scrollable: list);
    }
    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    await tester.tap(box);
    await tester.pumpAndSettle();
  }

  testWidgets('01 · seçim yokken: ipucu + atla', (tester) async {
    await openPicker(tester);
    await shoot(tester, '01_secim_yok');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 · üç konu seçili', (tester) async {
    await openPicker(tester);
    await check(tester, 'top_sub_yks_1_0');
    await check(tester, 'top_sub_yks_1_2');
    await check(tester, 'top_sub_yks_1_4');
    await shoot(tester, '02_uc_konu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('03 · dar ekran 320 px', (tester) async {
    await openPicker(tester, size: const Size(320, 568));
    await check(tester, 'top_sub_yks_1_0');
    await check(tester, 'top_sub_yks_1_2');
    await shoot(tester, '03_dar_320');
    expect(tester.takeException(), isNull);
  });

  testWidgets('04 · plan başlığında +2', (tester) async {
    final c = await openPicker(tester);
    await check(tester, 'top_sub_yks_1_0');
    await check(tester, 'top_sub_yks_1_2');
    await check(tester, 'top_sub_yks_1_4');
    await tester.tap(find.byKey(TopicPicker.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.sessionPlan);
    await shoot(tester, '04_plan_basligi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('05 · oturum sonu başlığı', (tester) async {
    final c = await openPicker(tester);
    await check(tester, 'top_sub_yks_1_0');
    await check(tester, 'top_sub_yks_1_2');
    await tester.tap(find.byKey(TopicPicker.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    // Özet ekranı bir "bitirme bağlamı" olmadan "özetlenecek oturum yok"
    // diyor; ilk denemede boş ekran çıktı. Bağlam kuruluyor.
    c
        .read(pendingFinishProvider.notifier)
        .set(early: false, endMs: t0 + 600000);
    c.read(appRouterProviderForQa).go(Routes.runSummary);
    await shoot(tester, '05_oturum_sonu');
    expect(tester.takeException(), isNull);
  });
}
