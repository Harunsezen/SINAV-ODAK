import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/settings/catalog_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 7A — Ders / konu / tür yönetimi.
///
/// **G8:** bu ekranda SİLME yok. Arşivleme var; geçmiş oturumların bağlı
/// olduğu satır asla kaybolmuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpCatalog(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          // Ürünün TÜRKÇE metnini doğruluyoruz; locale verilmezse
          // cihaz diline (testte en_US) düşülüyor.
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: CatalogScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<Subject?> subject(String id) => db.subjectDao.findSubject(id);

  /// Görünür alana getirip dokunur.
  ///
  /// v1.2'de müfredat tohumlandı: bir ders açıldığında altında 80'e yakın
  /// konu var ve düzenle/arşivle düğmeleri test yüzeyinin ALTINA taşıyor.
  /// Doğrudan `tap` "would not hit test" ile düşüyordu. İddia aynı —
  /// yalnızca düğmeye ulaşma biçimi değişti.
  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // -------------------------------------------------------------------

  testWidgets('seed dersleri listeleniyor', (tester) async {
    await pumpCatalog(tester);

    expect(find.text('Matematik'), findsOneWidget);
    expect(find.byKey(const Key('catalog-subject-$subjectId')), findsOneWidget);
  });

  testWidgets('SİLME düğmesi YOK, arşivleme var (G8)', (tester) async {
    await pumpCatalog(tester);
    await tester.tap(find.byKey(const Key('catalog-subject-$subjectId')));
    await tester.pumpAndSettle();

    expect(
      find.byIcon(Icons.delete),
      findsNothing,
      reason: 'silinen ders geçmiş istatistikleri bozar',
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(
      find.byKey(const Key('catalog-subject-archive-$subjectId')),
      findsOneWidget,
    );
  });

  group('ders ekleme', () {
    testWidgets('yeni ders veritabanına yazılıyor', (tester) async {
      await pumpCatalog(tester);
      final before = (await db.select(db.subjects).get()).length;

      await tester.tap(find.byKey(const Key('catalog-add-subject')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'Geometri',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
      await tester.pumpAndSettle();

      final after = await db.select(db.subjects).get();
      expect(after.length, before + 1);
      expect(after.any((s) => s.name == 'Geometri'), isTrue);
    });

    testWidgets('BOŞ ad kaydedilmiyor', (tester) async {
      await pumpCatalog(tester);
      final before = (await db.select(db.subjects).get()).length;

      await tester.tap(find.byKey(const Key('catalog-add-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
      await tester.pumpAndSettle();

      expect((await db.select(db.subjects).get()).length, before);
    });

    testWidgets('VAZGEÇ hiçbir şey yazmıyor', (tester) async {
      await pumpCatalog(tester);
      final before = (await db.select(db.subjects).get()).length;

      await tester.tap(find.byKey(const Key('catalog-add-subject')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'Yazılmayacak',
      );
      await tester.tap(find.byKey(const Key('catalog-name-cancel')));
      await tester.pumpAndSettle();

      expect((await db.select(db.subjects).get()).length, before);
    });
  });

  group('ders düzenleme ve arşivleme', () {
    testWidgets('ders adı değişiyor', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.byKey(const Key('catalog-subject-$subjectId')));
      await tester.pumpAndSettle();

      await tapKey(tester, 'catalog-subject-edit-$subjectId');
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'Matematik II',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
      await tester.pumpAndSettle();

      expect((await subject(subjectId))!.name, 'Matematik II');
    });

    testWidgets('arşivlenen ders SİLİNMİYOR, işaretleniyor', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.byKey(const Key('catalog-subject-$subjectId')));
      await tester.pumpAndSettle();

      await tapKey(tester, 'catalog-subject-archive-$subjectId');

      final s = await subject(subjectId);
      expect(s, isNotNull, reason: 'kayıt DURUYOR');
      expect(s!.isArchived, isTrue);
    });

    testWidgets('arşivlenen ders varsayılan görünümde GİZLİ', (tester) async {
      await db.subjectDao.setArchived(subjectId, archived: true);
      await pumpCatalog(tester);

      expect(find.byKey(const Key('catalog-subject-$subjectId')), findsNothing);
    });

    testWidgets('arşiv görünümü açılınca ders GERİ geliyor', (tester) async {
      await db.subjectDao.setArchived(subjectId, archived: true);
      await pumpCatalog(tester);

      await tester.tap(find.byKey(const Key('catalog-toggle-archived')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('catalog-subject-$subjectId')),
        findsOneWidget,
      );
    });
  });

  group('konular', () {
    testWidgets('konu ekleniyor', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.byKey(const Key('catalog-subject-$subjectId')));
      await tester.pumpAndSettle();

      await tapKey(tester, 'catalog-add-topic-$subjectId');
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'Limit',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
      await tester.pumpAndSettle();

      final topics = await (db.select(db.topics)
            ..where((t) => t.subjectId.equals(subjectId)))
          .get();
      expect(topics.any((t) => t.name == 'Limit'), isTrue);
    });

    testWidgets('konu arşivleniyor, SİLİNMİYOR', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.byKey(const Key('catalog-subject-$subjectId')));
      await tester.pumpAndSettle();

      await tapKey(tester, 'catalog-topic-archive-$topicId');

      final t = await db.subjectDao.findTopic(topicId);
      expect(t, isNotNull);
      expect(t!.isArchived, isTrue);
    });
  });

  group('çalışma türleri', () {
    testWidgets('tür sekmesi listeleniyor', (tester) async {
      await pumpCatalog(tester);

      await tester.tap(find.text('Türler'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('catalog-activity-$activityId')),
        findsOneWidget,
      );
    });

    testWidgets('tür ekleniyor', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.text('Türler'));
      await tester.pumpAndSettle();

      final before = (await db.select(db.activityTypes).get()).length;

      await tester.tap(find.byKey(const Key('catalog-add-activity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'Tekrar',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
      await tester.pumpAndSettle();

      final after = await db.select(db.activityTypes).get();
      expect(after.length, before + 1);
      expect(after.any((a) => a.name == 'Tekrar'), isTrue);
    });

    testWidgets('tür arşivleniyor, SİLİNMİYOR', (tester) async {
      await pumpCatalog(tester);
      await tester.tap(find.text('Türler'));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const Key('catalog-activity-archive-$activityId')));
      await tester.pumpAndSettle();

      final types = await db.select(db.activityTypes).get();
      final a = types.where((t) => t.id == activityId).firstOrNull;
      expect(a, isNotNull, reason: 'kayıt DURUYOR');
      expect(a!.isArchived, isTrue);
    });
  });

  testWidgets('arşivlenen ders oturum kurulumunda GÖRÜNMÜYOR', (tester) async {
    // Yönetim ekranı arşivlenmişi gösterebilir; oturum kurulumunu besleyen
    // `subjectsProvider` göstermemeli.
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    await db.subjectDao.setArchived(subjectId, archived: true);
    final visible = await container.read(subjectsProvider.future);

    expect(visible.any((s) => s.id == subjectId), isFalse);
  });
}
