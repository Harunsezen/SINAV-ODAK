import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/csv_builder.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';

import '../qa/qa_harness.dart';
import '../unit/usecase_helpers.dart';

/// v1.2/E — DİL SEÇİMİ.
///
/// İki ayrı soru, iki ayrı kurulum:
///
/// 1. **Satır çalışıyor mu?** `SettingsScreen` doğrudan kuruluyor.
///    Kabuk üzerinden gidilemiyor: `Routes.settings` debug derlemede
///    `DbHealthPage`e çıkıyor (`settingsPageFor(debug: kDebugMode)`) ve
///    testler debug modda koşuyor — o yoldan giden bir iddia ayarlar
///    ekranını değil geliştirici sayfasını doğrulardı.
/// 2. **Uygulama ayarı izliyor mu?** `qa_harness` ile GERÇEK ağaç.
///    Harness dili `app.dart` ile aynı yerden okuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> setLanguage(AppLanguage l) =>
      db.settingsDao.patchSettings(UserSettingsCompanion(language: Value(l)));

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
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

    tester.view.physicalSize = const Size(900, 2200);
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
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder inLanguageRow(String text) => find.descendant(
        of: find.byKey(const Key('settings-language')),
        matching: find.text(text),
      );

  Future<void> tapLanguage(WidgetTester tester, String text) async {
    final f = inLanguageRow(text);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('ayarlardaki dil satırı', () {
    testWidgets('üç seçenek de var: Sistem / Türkçe / English', (tester) async {
      await pumpSettings(tester);
      for (final label in ['Sistem', 'Türkçe', 'English']) {
        expect(inLanguageRow(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('İngilizce seçilince ayara YAZILIYOR', (tester) async {
      await pumpSettings(tester);
      expect((await db.settingsDao.read()).language, AppLanguage.tr);

      await tapLanguage(tester, 'English');

      expect((await db.settingsDao.read()).language, AppLanguage.en);
    });

    testWidgets('Türkçeye geri dönülebiliyor', (tester) async {
      await setLanguage(AppLanguage.en);
      await pumpSettings(tester, locale: const Locale('en'));

      await tapLanguage(tester, 'Türkçe');

      expect((await db.settingsDao.read()).language, AppLanguage.tr);
    });

    testWidgets('Sistem seçilebiliyor', (tester) async {
      await pumpSettings(tester);
      await tapLanguage(tester, 'Sistem');
      expect((await db.settingsDao.read()).language, AppLanguage.system);
    });

    testWidgets('satır İngilizce arayüzde de bulunuyor', (tester) async {
      await setLanguage(AppLanguage.en);
      await pumpSettings(tester, locale: const Locale('en'));

      expect(find.text('Language'), findsWidgets);
      // Dil adları KENDİ dillerinde: seçiciyi arayan kişi uygulamanın o an
      // konuştuğu dili anlamıyor olabilir.
      expect(inLanguageRow('Türkçe'), findsOneWidget);
      expect(inLanguageRow('English'), findsOneWidget);
    });
  });

  group('uygulama ayarı izliyor', () {
    testWidgets('varsayılan TÜRKÇE', (tester) async {
      await QaSeed.activeUser(db);
      await pumpQaApp(tester, db);

      expect(find.text('Bugün'), findsWidgets);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('ayar İngilizce ise ana panel İNGİLİZCE', (tester) async {
      await QaSeed.activeUser(db);
      await setLanguage(AppLanguage.en);
      await pumpQaApp(tester, db);

      expect(find.text('Today'), findsWidgets);
      expect(find.text('Bugün'), findsNothing);
    });

    testWidgets(
      'dil değişince arayüz ANINDA dönüyor — yeniden başlatma YOK',
      (tester) async {
        await QaSeed.activeUser(db);
        final c = await pumpQaApp(tester, db);
        expect(find.text('Bugün'), findsWidgets);

        await c.read(settingsControllerProvider).setLanguage(AppLanguage.en);
        await tester.pumpAndSettle();

        expect(find.text('Today'), findsWidgets);
        expect(find.text('Bugün'), findsNothing);
      },
    );

    testWidgets('müfredat ekranı İngilizce, KONU ADLARI Türkçe', (
      tester,
    ) async {
      await QaSeed.activeUser(db);
      await setLanguage(AppLanguage.en);
      final c = await pumpQaApp(tester, db);
      c.read(appRouterProviderForQa).go(Routes.curriculum);
      await tester.pumpAndSettle();

      expect(find.text('Curriculum'), findsWidgets);
      // Müfredat içeriği çeviri konusu değil, VERİ. Ayarlardaki not da
      // ("Ders ve konu adları Türkçe kalır") bunu söylüyor.
      expect(find.text('Matematik'), findsWidgets);
    });
  });

  group('onboarding dil seçici', () {
    testWidgets('ilk ekranda görünüyor ve ayarı yazıyor', (tester) async {
      final c = await pumpQaApp(tester, db);
      c.read(appRouterProviderForQa).go(Routes.onboarding);
      await tester.pumpAndSettle();

      final picker = find.byKey(const Key('onboarding-language'));
      expect(picker, findsOneWidget);

      await tester.tap(
        find.descendant(of: picker, matching: find.text('English')),
      );
      await tester.pumpAndSettle();

      expect((await db.settingsDao.read()).language, AppLanguage.en);
      // Karşılama metni de anında İngilizceye döndü.
      expect(find.text('Continue'), findsWidgets);
    });

    testWidgets('adım sayısı DEĞİŞMEDİ — seçici ayrı bir adım değil', (
      tester,
    ) async {
      // Dil için 6. bir adım eklemek, ilk açılışta okuyamadığı bir dilde
      // "Devam" arayan kullanıcıya bir ekran daha eklerdi.
      final c = await pumpQaApp(tester, db);
      c.read(appRouterProviderForQa).go(Routes.onboarding);
      await tester.pumpAndSettle();

      expect(find.textContaining('1/5'), findsWidgets);
    });
  });

  group('arayüz dışı metinler de dille geliyor', () {
    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
        ],
      );
      addTearDown(c.dispose);
      await c.read(settingsStreamProvider.future);
      return c;
    }

    test('bildirim metinleri', () async {
      // Bildirimi kuran servisin `BuildContext`i yok; metin yine de
      // arayüzle AYNI dilden gelmeli.
      final c = await container();
      expect(c.read(notificationStringsProvider).breakTitle, 'Mola zamanı');

      await db.settingsDao.patchSettings(
        const UserSettingsCompanion(language: Value(AppLanguage.en)),
      );
      await pumpEventQueue();

      expect(c.read(notificationStringsProvider).breakTitle, 'Break time');
    });

    test('CSV başlıkları', () async {
      final c = await container();
      expect(c.read(csvHeadersProvider).first, 'Tarih');

      await db.settingsDao.patchSettings(
        const UserSettingsCompanion(language: Value(AppLanguage.en)),
      );
      await pumpEventQueue();

      expect(c.read(csvHeadersProvider).first, 'Date');
    });

    test('CSV ayracı dile göre DEĞİŞMİYOR', () {
      // Bilinçli: dosyayı açan Excel kurulumu büyük ihtimalle Türkçe.
      // Başlık kullanıcının OKUDUĞU şey; ayraç Excel'in okuduğu şey.
      expect(CsvBuilder.delimiter, ';');
    });
  });
}
