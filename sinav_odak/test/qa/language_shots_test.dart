import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// v1.2/E — İNGİLİZCE ARAYÜZÜN GÖRÜNTÜLERİ.
///
/// `l10n_coverage_test` çevirinin VAR olduğunu, `language_switch_test`
/// ayarın çalıştığını kanıtlıyor. Hiçbiri sonucun **okunabilir** olduğunu
/// söylemiyor: İngilizce metinler Türkçesinden uzun ("Continue without a
/// topic" / "Konu seçmeden devam et") ve taşma İngilizcede ortaya çıkar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FontLoadResult fonts;
  late Directory outDir;

  setUpAll(() async {
    fonts = await loadRealFonts();
    outDir = Directory('qa_english');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
    File('${outDir.path}/README.txt').writeAsStringSync(
      'Sınav Odak v1.2/E — İngilizce arayüz ekran görüntüleri\n'
      'Üretim: flutter test test/qa/language_shots_test.dart\n'
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

  Future<void> english() => db.settingsDao.patchSettings(
        const UserSettingsCompanion(language: Value(AppLanguage.en)),
      );

  /// Dar ekran: taşma burada çıkar.
  const narrow = Size(320, 568);
  const phone = Size(411, 731);

  testWidgets('01 · ana panel', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    await pumpQaApp(tester, db, size: phone);
    await shoot(tester, '01_home_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('02 · ana panel · 320 px', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    await pumpQaApp(tester, db, size: narrow);
    await shoot(tester, '02_home_en_320');
    expect(tester.takeException(), isNull);
  });

  testWidgets('03 · istatistik', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    final c = await pumpQaApp(tester, db, size: phone);
    c.read(appRouterProviderForQa).go(Routes.stats);
    await shoot(tester, '03_stats_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('04 · müfredat', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    final c = await pumpQaApp(tester, db, size: phone);
    c.read(appRouterProviderForQa).go(Routes.curriculum);
    await shoot(tester, '04_curriculum_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('05 · konu seçici', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    final c = await pumpQaApp(tester, db, size: phone);
    c.read(appRouterProviderForQa).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await shoot(tester, '05_topic_picker_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('06 · hedefler', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    final c = await pumpQaApp(tester, db, size: narrow);
    c.read(appRouterProviderForQa).go(Routes.goals);
    await shoot(tester, '06_goals_en_320');
    expect(tester.takeException(), isNull);
  });

  testWidgets('07 · karşılama · dil seçici', (tester) async {
    final c = await pumpQaApp(tester, db, size: phone);
    c.read(appRouterProviderForQa).go(Routes.onboarding);
    await tester.pumpAndSettle();
    await shoot(tester, '07_onboarding_tr');

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('onboarding-language')),
        matching: find.text('English'),
      ),
    );
    await shoot(tester, '08_onboarding_en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('09 · rozetler · 320 px', (tester) async {
    await QaSeed.activeUser(db);
    await english();
    final c = await pumpQaApp(tester, db, size: narrow);
    c.read(appRouterProviderForQa).go(Routes.achievements);
    await shoot(tester, '09_achievements_en_320');
    expect(tester.takeException(), isNull);
  });
}
