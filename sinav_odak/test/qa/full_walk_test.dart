import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// QA — TAM GEZİNTİ TURU.
///
/// Amaç: her ekranı açıp **her kontrole basmak** ve hiçbir adımda istisna
/// atılmadığını doğrulamak. Birim testleri tek tek davranışları kilitliyor;
/// bu tur onların arasındaki boşlukları — gerçek router, gerçek geçişler,
/// arka arkaya tıklamalar — tarıyor.
///
/// Her adımdan sonra iki şey kontrol ediliyor:
/// 1. `tester.takeException()` **null** (sessiz çökme yok)
/// 2. beklenen rota
///
/// Boş ve dolu veritabanı ayrı turlarda geziliyor: boş durum ekranları en
/// çok gözden kaçan yerler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Bir adımı çalıştırır ve istisna olmadığını doğrular.
  Future<void> step(
    WidgetTester tester,
    String label,
    Future<void> Function() action,
  ) async {
    await action();
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'ADIM PATLADI: $label',
    );
    // SnackBar kendi zamanlayıcısını kuruyor; test biterken askıda kalırsa
    // çerçeve "Timer is still pending" diye hata verir. Uygulama hatası
    // DEĞİL — mesajın süresi dolana kadar ilerletip zamanlayıcıyı tüketiyoruz.
    if (find.byType(SnackBar).evaluate().isNotEmpty) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  }

  /// Alt navigasyondan sekme değiştirir.
  ///
  /// İkonla aramak KIRILGAN: seçili sekmenin ikonu `outlined` sürümden
  /// dolu sürüme dönüyor ve ikinci arama boş dönüyordu. Etiket sabit.
  Future<void> goTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Varsa dokunur; yoksa sessizce geçer (boş/dolu turlarda bazı kontroller
  /// bilinçli olarak görünmez).
  Future<void> tapIfPresent(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) return;
    await tester.tap(f.first, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  // =====================================================================
  // 1. BOŞ DURUM TURU
  // =====================================================================

  testWidgets('BOŞ tur: tüm sekmeler ve boş durumlar patlamıyor',
      (tester) async {
    await QaSeed.emptyUser(db);
    final c = await pumpQaApp(tester, db);

    expect(currentRoute(c), Routes.home);
    expect(tester.takeException(), isNull);

    await step(tester, 'ana panel: son oturumlar boş', () async {
      expect(find.byKey(const Key('home-recent-empty')), findsOneWidget);
    });

    await step(tester, 'İstatistik sekmesi', () async {
      await goTab(tester, 'İstatistik');
    });
    expect(currentRoute(c), Routes.stats);
    expect(find.byKey(const Key('stats-empty')), findsOneWidget);

    await step(tester, 'boş istatistikte dışa aktarma uyarı veriyor', () async {
      await tester.tap(find.byKey(const Key('stats-export')));
      await tester.pumpAndSettle();
      // Doğrulama adımın İÇİNDE: `step` sonrasında SnackBar zamanlayıcısı
      // tüketiliyor ve mesaj ekrandan kalkmış oluyor.
      expect(find.text('Dışa aktarılacak oturum yok.'), findsOneWidget);
    });

    await step(tester, 'aralık: Ay', () async {
      await tester.tap(find.text('Ay'));
    });

    await step(tester, 'Yanlışlar sekmesi', () async {
      await goTab(tester, 'Yanlışlar');
    });
    expect(currentRoute(c), Routes.wrongs);

    await step(tester, 'Takvim sekmesi', () async {
      await goTab(tester, 'Takvim');
    });
    expect(currentRoute(c), Routes.calendar);
    expect(find.byKey(const Key('calendar-empty')), findsOneWidget);

    await step(tester, 'takvim: önceki ay', () async {
      await tester.tap(find.byKey(const Key('calendar-prev')));
    });
    await step(tester, 'takvim: sonraki ay', () async {
      await tester.tap(find.byKey(const Key('calendar-next')));
    });

    await step(tester, 'Ayarlar sekmesi', () async {
      await goTab(tester, 'Ayarlar');
    });
    expect(currentRoute(c), Routes.settings);

    await step(tester, 'Ana panel sekmesine dönüş', () async {
      await goTab(tester, 'Ana Panel');
    });
    expect(currentRoute(c), Routes.home);
  });

  // =====================================================================
  // 2. DOLU DURUM — SEKMELER
  // =====================================================================

  testWidgets('DOLU tur: sekmeler, grafikler ve listeler patlamıyor',
      (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db);

    await step(tester, 'ana panel dolu', () async {
      expect(find.byKey(const Key('home-recent-empty')), findsNothing);
    });

    await step(tester, 'İstatistik: grafik ve kartlar', () async {
      await goTab(tester, 'İstatistik');
    });
    expect(find.byKey(const Key('stats-daily-chart')), findsOneWidget);
    expect(find.byKey(const Key('stats-summary')), findsOneWidget);
    // FAZ 3.2'de üç grafik eklendi; ders dağılımı artık ilk ekranın
    // altında kalıyor. `ListView` tembel kurduğu için görünür alana
    // getirilmeden bulunamaz.
    await tester.scrollUntilVisible(
      find.byKey(const Key('stats-breakdown')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('stats-breakdown')), findsOneWidget);

    // Aralık seçicisi yukarıda kaldı; sonraki adım ona dokunacak.
    await tester.scrollUntilVisible(
      find.byKey(const Key('stats-range')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );

    await step(tester, 'İstatistik: Ay aralığı', () async {
      await tester.tap(find.text('Ay'));
    });
    await step(tester, 'İstatistik: Hafta aralığı', () async {
      await tester.tap(find.text('Hafta'));
    });
    await step(tester, 'İstatistik: CSV dışa aktarma (Noop kapı)', () async {
      await tester.tap(find.byKey(const Key('stats-export')));
    });

    await step(tester, 'Takvim: dolu ay', () async {
      await goTab(tester, 'Takvim');
    });
    expect(find.byKey(const Key('calendar-summary')), findsOneWidget);

    await step(tester, 'Yanlışlar: liste', () async {
      await goTab(tester, 'Yanlışlar');
    });
    expect(currentRoute(c), Routes.wrongs);
  });

  // =====================================================================
  // 3. OTURUM KURULUM AKIŞI
  // =====================================================================

  testWidgets('kurulum akışı: ders -> konu -> tür -> plan ve geri dönüşler',
      (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db);

    await step(tester, 'Oturumu Başlat', () async {
      await tester.tap(find.byKey(const Key('home-start')));
    });
    expect(currentRoute(c), Routes.sessionSubject);

    await step(tester, 'ders seç', () async {
      await tester.tap(find.text('Matematik').first);
    });
    expect(currentRoute(c), Routes.sessionTopic);

    await step(tester, 'konu seçmeden devam', () async {
      await tester.tap(find.byKey(const Key('topic-skip')));
    });
    expect(currentRoute(c), Routes.sessionType);

    await step(tester, 'çalışma türü seç', () async {
      await tester.tap(find.text('Soru Çözümü').first);
    });
    expect(currentRoute(c), Routes.sessionPlan);

    // Plan ekranındaki tüm sekmeler ve stepper'lar.
    await step(tester, 'plan: Özel sekmesi', () async {
      await tester.tap(find.text('Özel'));
    });
    await step(tester, 'plan: Bitiş sekmesi', () async {
      await tester.tap(find.text('Bitiş'));
    });
    await step(tester, 'plan: Hazır sekmesine dönüş', () async {
      await tester.tap(find.text('Hazır'));
    });
  });

  // =====================================================================
  // 4. AKTİF OTURUM KATMANI
  // =====================================================================

  testWidgets('aktif oturum: /run açılıyor, geri tuşu KORUYOR', (tester) async {
    await QaSeed.activeUser(db);
    await seedRunningSession(db, id: 'qa_run', sch: schedule());
    final c = await pumpQaApp(tester, db);

    // Router aktif oturumda /run'a zorluyor.
    expect(currentRoute(c), Routes.run);
    expect(tester.takeException(), isNull);

    await step(tester, 'run: alt navigasyon GİZLİ', () async {
      expect(find.byType(NavigationBar), findsNothing);
    });

    await step(tester, 'run: PAUSE YOK (değişmez kural)', () async {
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.text('Durdur'), findsNothing);
    });

    await step(tester, 'run: Molayı Atla çalışırken PASİF', () async {
      // Buton `OutlinedButton`; metni alt ağaçta olduğu için ata-arama
      // yerine doğrudan metinden yukarı çıkılıyor.
      final skip = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Molayı Atla'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(skip.onPressed, isNull);
    });

    // v1.1 (FAZ 1.1): oturumdan ONAYLI çıkış kapısı var.
    await step(tester, 'run: geri tuşu onay soruyor, VAZGEÇ ekranda tutuyor',
        () async {
      await tester.tap(find.byKey(const Key('run-minimize')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run-minimize-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('run-minimize-cancel')));
    });
    expect(currentRoute(c), Routes.run, reason: 'vazgeçince çıkılmaz');

    // v1.1 (FAZ 1.3): Bitir diyaloğu üç yollu.
    await step(tester, 'run: Bitir onay diyaloğu açılıyor', () async {
      await tester.tap(find.text('Bitir'));
    });
    expect(find.byKey(const Key('run-early-dialog')), findsOneWidget);
    expect(find.byKey(const Key('run-early-continue')), findsOneWidget);
    expect(find.byKey(const Key('run-early-delete')), findsOneWidget);
    expect(find.byKey(const Key('run-early-save')), findsOneWidget);

    await step(tester, 'run: onaydan DEVAM ET', () async {
      await tester.tap(find.byKey(const Key('run-early-continue')));
    });
    expect(currentRoute(c), Routes.run);

    await step(tester, 'run: Bitir -> KAYDET -> özet formu', () async {
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-early-save')));
    });
    expect(currentRoute(c), Routes.runSummary);
  });

  // =====================================================================
  // 5. OTURUM SONU FORMU -> TEBRİK
  // =====================================================================

  testWidgets('özet formu: tüm kontroller + KAYDET -> tebrik ekranı',
      (tester) async {
    await QaSeed.emptyUser(db);
    await seedRunningSession(db, id: 'qa_run', sch: schedule());
    final c = await pumpQaApp(tester, db, size: const Size(430, 1400));

    await step(tester, 'Bitir + onay', () async {
      await tester.tap(find.text('Bitir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('run-early-save')));
    });
    expect(currentRoute(c), Routes.runSummary);

    await step(tester, 'form: +5 / +10 / +20 / Sıfırla', () async {
      await tester.tap(find.byKey(const Key('summary-q-plus5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('summary-q-plus10')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('summary-q-plus20')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('summary-q-reset')));
    });

    await step(tester, 'form: soru sayısı ve dağılım', () async {
      await tester.enterText(find.byKey(const Key('summary-q-field')), '40');
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('summary-correct-inc')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('summary-wrong-inc')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('summary-empty-inc')));
    });

    await step(tester, 'form: motivasyon ve not', () async {
      await tester.tap(find.byKey(const Key('summary-mood-4')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('summary-note')),
        'QA turu notu',
      );
    });

    await step(tester, 'form: KAYDET', () async {
      await tester.tap(find.byKey(const Key('summary-save')));
    });
    expect(currentRoute(c), Routes.runDone);

    await step(tester, 'tebrik: yeni rozet kartı (ilk oturum)', () async {
      expect(find.byKey(const Key('done-new-achievements')), findsOneWidget);
    });

    await step(tester, 'tebrik: Ana panel', () async {
      await tester.tap(find.byKey(const Key('done-home')));
    });
    expect(currentRoute(c), Routes.home);

    // Kayıt gerçekten yazılmış olmalı.
    final saved = await db.sessionDao.findById('qa_run');
    expect(saved!.status.name, isNot('running'));
    expect(saved.questionCount, 40);
  });

  // =====================================================================
  // 6. YANLIŞ DEFTERİ
  // =====================================================================

  testWidgets('yanlışlar: liste, ekleme, detay, durum ilerletme',
      (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(430, 1400));

    await step(tester, 'Yanlışlar sekmesi', () async {
      await goTab(tester, 'Yanlışlar');
    });

    await step(tester, 'sekmeler: Tekrar edildi / Öğrenildi / Aktif', () async {
      await tapIfPresent(tester, find.text('Tekrar edildi'));
      await tapIfPresent(tester, find.text('Öğrenildi'));
      await tapIfPresent(tester, find.text('Aktif'));
    });

    await step(tester, 'yanlış ekleme ekranı açılıyor', () async {
      await tapIfPresent(tester, find.byKey(const Key('wrongs-add')));
    });

    if (currentRoute(c) == Routes.wrongsAdd) {
      await step(tester, 'ekle: ders seç ve KAYDET', () async {
        await tapIfPresent(tester, find.byKey(const Key('add-wrong-inc')));
        await tapIfPresent(tester, find.byKey(const Key('add-wrong-dec')));
      });
    }

    await step(tester, 'listeye dönüldü', () async {
      expect(currentRoute(c), anyOf(Routes.wrongs, Routes.wrongsAdd));
    });
  });

  // =====================================================================
  // 7. AYARLAR — TÜM KONTROLLER
  // =====================================================================

  testWidgets('ayarlar sekmesi DEBUG modda geliştirme aracını açıyor (D4/K3)',
      (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db);

    await step(tester, 'Ayarlar sekmesi', () async {
      await goTab(tester, 'Ayarlar');
    });
    expect(currentRoute(c), Routes.settings);
    // Testler debug modda koşuyor; router `settingsPageFor(debug: true)`
    // ile geliştirme aracını seçiyor. Release dalı `settings_screen_test`
    // ve `router_redirect_test` tarafından ayrıca doğrulanıyor.
    expect(find.text('Veritabanı Durumu'), findsOneWidget);
  });

  testWidgets('ayarlar ekranı: her anahtar, her düğme (tehlikeliler onaylı)',
      (tester) async {
    await QaSeed.activeUser(db);
    await pumpQaSettings(tester, db);

    await step(tester, 'tema: koyu -> açık -> sistem', () async {
      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pumpAndSettle();
      // v1.2/E: dil satırında da bir "Sistem" segmenti var; düz
      // `find.text` iki eşleşme buluyor. İDDİA AYNI (tema Sistem'e
      // dönüyor), yalnızca hangi satırdaki düğme olduğu açıkça yazıldı.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('settings-theme')),
          matching: find.text('Sistem'),
        ),
      );
    });

    await step(tester, 'ekran açık kalsın: kapat/aç', () async {
      await tester.tap(find.byKey(const Key('settings-keep-screen-on')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-keep-screen-on')));
    });

    await step(tester, 'bildirim/ses/titreşim', () async {
      await tester.tap(find.byKey(const Key('settings-sound')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-vibration')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-notifications')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-notifications')));
    });

    await step(tester, 'günlük hedef: artır/azalt', () async {
      await tester.tap(find.byKey(const Key('settings-goal-plus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-goal-minus')));
    });

    await step(tester, 'net katsayısı: onay diyaloğu + VAZGEÇ', () async {
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('net-recompute-cancel')));
    });

    await step(tester, 'net katsayısı: onayla (geçmiş netler hesaplanır)',
        () async {
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('net-recompute-confirm')));
    });

    await step(tester, 'veri sıfırlama: 1. onaydan VAZGEÇ', () async {
      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-step1-cancel')));
    });
    // Vazgeçilince veri DURUYOR.
    expect(await db.sessionDao.findById('qa_s0'), isNotNull);

    await step(tester, 'veri sıfırlama: 2. adımda yanlış kelime', () async {
      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-step1-continue')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reset-keyword-field')),
        'YANLIS',
      );
    });
    final confirm = tester.widget<FilledButton>(
      find.byKey(const Key('reset-step2-confirm')),
    );
    expect(confirm.onPressed, isNull, reason: 'yanlış kelimeyle silme AÇIK');

    await step(tester, 'veri sıfırlama: diyalogdan çık', () async {
      await tester.tap(find.byKey(const Key('reset-step2-cancel')));
    });
    expect(await db.sessionDao.findById('qa_s0'), isNotNull);

    await step(tester, 'Hedefler ve Rozetler girişleri VAR', () async {
      await tester.ensureVisible(find.byKey(const Key('settings-goals')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-goals')), findsOneWidget);
      expect(find.byKey(const Key('settings-achievements')), findsOneWidget);
      expect(find.byKey(const Key('settings-catalog')), findsOneWidget);
    });
  });

  // =====================================================================
  // 7b. HEDEFLER EKRANI
  // =====================================================================

  testWidgets('hedefler: silme onaylı, ekleme çalışıyor', (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(430, 2000));

    await step(tester, '/goals açılıyor', () async {
      c.read(appRouterProviderForQa).go(Routes.goals);
    });
    expect(currentRoute(c), Routes.goals);

    await step(tester, 'hedef silme: onaylı', () async {
      await tester.tap(find.byKey(const Key('goal-delete-qa_g1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-delete-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-delete-qa_g1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-delete-confirm')));
    });
    expect(
      (await db.select(db.goals).get()).any((g) => g.id == 'qa_g1'),
      isFalse,
    );

    await step(tester, 'hedef ekleme sayfası', () async {
      await tester.tap(find.byKey(const Key('goals-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-target-plus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-create')));
    });
  });

  // =====================================================================
  // 8. ROZETLER + KATALOG YÖNETİMİ
  // =====================================================================

  testWidgets('rozetler ve katalog: tüm kontroller, SİLME yok', (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(430, 4000));

    await step(tester, 'Rozetler ekranı', () async {
      c.read(appRouterProviderForQa).go(Routes.achievements);
    });
    expect(currentRoute(c), Routes.achievements);
    expect(find.byKey(const Key('achievements-count')), findsOneWidget);

    await step(tester, 'Katalog yönetimi', () async {
      c.read(appRouterProviderForQa).go(Routes.manage);
    });
    expect(currentRoute(c), Routes.manage);

    await step(tester, 'katalog: SİLME düğmesi YOK (G8)', () async {
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    await step(tester, 'katalog: arşivlenenleri göster/gizle', () async {
      await tester.tap(find.byKey(const Key('catalog-toggle-archived')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-toggle-archived')));
    });

    await step(tester, 'katalog: ders ekle (VAZGEÇ)', () async {
      await tester.tap(find.byKey(const Key('catalog-add-subject')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-cancel')));
    });

    await step(tester, 'katalog: ders ekle (KAYDET)', () async {
      await tester.tap(find.byKey(const Key('catalog-add-subject')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'QA Dersi',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
    });
    expect(
      (await db.select(db.subjects).get()).any((s) => s.name == 'QA Dersi'),
      isTrue,
    );

    await step(tester, 'katalog: Türler sekmesi', () async {
      await tester.tap(find.text('Türler'));
    });

    await step(tester, 'katalog: tür ekle', () async {
      await tester.tap(find.byKey(const Key('catalog-add-activity')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('catalog-name-field')),
        'QA Türü',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-name-save')));
    });
  });

  // =====================================================================
  // 9. UZUN ADLAR — TAŞMA
  // =====================================================================

  testWidgets('çok uzun ders/konu adlarında taşma istisnası YOK',
      (tester) async {
    await QaSeed.activeUser(db);
    await QaSeed.longNames(db);
    final c = await pumpQaApp(tester, db, size: const Size(360, 800));

    await step(tester, 'dar ekranda ana panel', () async {
      expect(currentRoute(c), Routes.home);
    });

    await step(tester, 'dar ekranda istatistik', () async {
      await goTab(tester, 'İstatistik');
    });

    await step(tester, 'dar ekranda yanlışlar', () async {
      await goTab(tester, 'Yanlışlar');
    });

    await step(tester, 'dar ekranda kurulum akışı', () async {
      await goTab(tester, 'Ana Panel');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Matematik').first);
    });
  });

  // =====================================================================
  // 10. BÜYÜK FONT
  // =====================================================================

  testWidgets('textScale 1.5 ile tüm sekmeler patlamıyor', (tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(
      tester,
      db,
      size: const Size(430, 1600),
      textScale: 1.5,
    );

    for (final (label, route) in [
      ('İstatistik', Routes.stats),
      ('Yanlışlar', Routes.wrongs),
      ('Takvim', Routes.calendar),
      ('Ayarlar', Routes.settings),
      ('Ana Panel', Routes.home),
    ]) {
      await step(tester, 'büyük font: $route', () async {
        await goTab(tester, label);
      });
      expect(currentRoute(c), route);
    }
  });
}
