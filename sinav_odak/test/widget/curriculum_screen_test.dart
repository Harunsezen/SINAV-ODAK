import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/curriculum/curriculum_screen.dart';
import 'package:sinav_odak/presentation/curriculum/topic_tree_view.dart';

import '../unit/usecase_helpers.dart';

/// v1.2 — MÜFREDAT EKRANI (ders > konu > alt dal).
///
/// Buradaki iddialar ağacın **arayüze bağlandığını** doğruluyor; ağacın
/// kuralları `test/unit/topic_tree_test.dart` içinde.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> pumpCurriculum(
    WidgetTester tester, {
    Size size = const Size(1200, 2400),
    Locale locale = const Locale('tr'),
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const CurriculumScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Ders çubuğundaki bir dersi seçer.
  Future<void> pickSubject(WidgetTester tester, String id) async {
    final chip = find.byKey(Key('curriculum-subject-$id'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byKey(TopicTreeView.searchKey), q);
    await tester.pumpAndSettle();
  }

  /// Yalnızca AĞAÇ içindeki metni arar.
  ///
  /// Düz `find.text` arama kutusunun kendi metnini de yakalıyor: "Mitoz"
  /// yazınca iki eşleşme çıkıyordu ve test yanlış yere düşüyordu.
  Finder inTree(String text) => find.descendant(
        of: find.byKey(TopicTreeView.listKey),
        matching: find.text(text),
      );

  testWidgets('ders çubuğu ve ilk dersin ağacı açılıyor', (tester) async {
    await pumpCurriculum(tester);

    expect(find.byKey(CurriculumScreen.subjectBarKey), findsOneWidget);
    expect(find.byKey(TopicTreeView.searchKey), findsOneWidget);
    expect(find.byKey(TopicTreeView.listKey), findsOneWidget);
    // Varsayılan: ilk ders (YKS sıralamasında Türkçe).
    expect(find.byKey(const Key('curriculum-subject-sub_yks_0')), findsOne);
  });

  testWidgets('ders değişince ağaç da değişiyor', (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_5'); // Biyoloji

    expect(inTree('Hücre'), findsOneWidget);
    expect(
      inTree('Sözcükte Anlam'),
      findsNothing,
      reason: 'önceki dersin konusu ekranda kalamaz',
    );
  });

  testWidgets('ALT DAL araması: üst konu başlık olarak geliyor',
      (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_5');
    await search(tester, 'Mitoz');

    // Alt dal, arama açıkken KENDİLİĞİNDEN görünüyor: kullanıcı eşleşmeyi
    // görmek için ayrıca dokunmak zorunda kalmamalı.
    expect(inTree('Mitoz'), findsOneWidget);
    expect(inTree('Hücre Bölünmeleri'), findsOneWidget);
    expect(
      inTree('Mayoz'),
      findsNothing,
      reason: 'eşleşmeyen kardeş alt dal tek sonucu gömerdi',
    );
  });

  testWidgets('Türkçe büyük harf araması eşleşiyor', (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_1'); // Matematik
    await search(tester, 'İKİNCİ');

    expect(inTree('İkinci Dereceden Denklemler'), findsOneWidget);
  });

  testWidgets('sonuç yoksa arama metniyle birlikte söyleniyor', (tester) async {
    await pumpCurriculum(tester);
    await search(tester, 'zzzzz');

    expect(find.textContaining('zzzzz'), findsWidgets);
    expect(find.byKey(TopicTreeView.listKey), findsNothing);
  });

  testWidgets('arama temizleme düğmesi listeyi geri getiriyor', (tester) async {
    await pumpCurriculum(tester);
    await search(tester, 'zzzzz');
    expect(find.byKey(TopicTreeView.listKey), findsNothing);

    await tester.tap(find.byKey(const Key('topic-tree-search-clear')));
    await tester.pumpAndSettle();

    expect(find.byKey(TopicTreeView.listKey), findsOneWidget);
  });

  testWidgets('seviye sekmesi süzüyor', (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_1');

    // 12. sınıf: Türev var, 9. sınıf konusu yok.
    final chip = find.byKey(const Key('topic-level-g12'));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(inTree('Türev'), findsOneWidget);
    expect(inTree('Mutlak Değer'), findsNothing, reason: '9. sınıf konusu');
  });

  testWidgets('sınıfsız katalogda yalnızca "Tümü" sekmesi var', (tester) async {
    await pumpCurriculum(tester);
    // Diğer: sınıf düzeyi de TYT/AYT etiketi de olmayan tek kap.
    // (Deneme'de "TYT Denemesi"/"AYT Denemesi" etiketli, sekmesi var.)
    await pickSubject(tester, 'sub_yks_14');

    expect(
      find.byKey(TopicTreeView.levelsKey),
      findsNothing,
      reason: 'tek seçenekli sekme satırı yer kaplayıp hiçbir iş yapmıyor',
    );
  });

  testWidgets('alt dallar açılıp kapanıyor', (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_5');

    final hucre = await db.subjectDao.findTopic('top_sub_yks_5_1');
    expect(hucre?.name, 'Hücre', reason: 'v1.1 kimliği duruyor');

    expect(find.text('Hücre Organelleri'), findsNothing);

    final toggle = find.byKey(Key('topic-expand-${hucre!.id}'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Hücre Organelleri'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Hücre Organelleri'), findsNothing);
  });

  testWidgets('"çalışıldı" işareti veritabanına yazılıyor', (tester) async {
    await pumpCurriculum(tester);
    await pickSubject(tester, 'sub_yks_1');

    const id = 'top_sub_yks_1_0'; // Temel Kavramlar
    expect((await db.subjectDao.findTopic(id))!.isCompleted, isFalse);

    final button = find.byKey(const Key('curriculum-done-$id'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect((await db.subjectDao.findTopic(id))!.isCompleted, isTrue);

    // G8: işaret geri alınabiliyor, satır SİLİNMİYOR.
    await tester.tap(button);
    await tester.pumpAndSettle();
    final t = await db.subjectDao.findTopic(id);
    expect(t, isNotNull);
    expect(t!.isCompleted, isFalse);
  });

  group('dar ekran taşmıyor', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('320x568 · ${locale.languageCode}', (tester) async {
        await pumpCurriculum(
          tester,
          size: const Size(320, 568),
          locale: locale,
        );
        await pickSubject(tester, 'sub_yks_1');
        expect(tester.takeException(), isNull);

        // En uzun konu adı da satırı taşırmamalı.
        await search(tester, 'Doğal');
        expect(tester.takeException(), isNull);
      });
    }
  });
}
