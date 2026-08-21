import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import '../unit/usecase_helpers.dart';
import 'qa_harness.dart';

/// EVRENSEL EKRAN DESTEĞİ — taşma matrisi.
///
/// Her ana ekranı, hedef cihaz yelpazesinin her boyutunda **hem dikey hem
/// yatay** kurup taşma olup olmadığını ölçüyor.
///
/// **Neden bu test var:** "yatayda çalışıyor mu" sorusu gözle
/// yanıtlanamaz — 9 boyut × 8 ekran × 2 yön = 144 kombinasyon. Flutter
/// taşmayı `RenderFlex overflowed` hatasıyla bildiriyor ve bu testte
/// `tester.takeException()` ile yakalanıyor.
///
/// Boyutlar **logical piksel**; düzen kararlarını belirleyen ölçü bu.
/// Fiziksel çözünürlük cihaz piksel oranıyla değişir, düzen değişmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// (ad, dikey logical boyut)
  const devices = <(String, Size)>[
    // En dar gerçekçi Android — taşmanın ilk görüleceği yer.
    ('kucuk-320', Size(320, 568)),
    // Galaxy J7 Prime: 720x1280 fiziksel, dpr 2 → 360x640 logical.
    ('j7prime-360', Size(360, 640)),
    ('telefon-411', Size(411, 731)),
    ('buyuk-480', Size(480, 853)),
    // S26 Ultra sınıfı: çok uzun yüzey.
    ('ultra-480x1040', Size(480, 1040)),
    ('tablet-800', Size(800, 1280)),
    ('chromebook-768', Size(768, 1366)),
    ('monitor-1080', Size(1080, 1920)),
  ];

  const screens = <(String, String)>[
    ('ana-panel', Routes.home),
    ('istatistik', Routes.stats),
    ('yanlislar', Routes.wrongs),
    ('takvim', Routes.calendar),
    ('rozetler', Routes.achievements),
    ('hedefler', Routes.goals),
    ('calisma', Routes.run),
    // v1.2: ders çubuğu + seviye sekmeleri + ağaç — üç kaydırılabilir
    // şerit alt alta. Dar ekranda taşmaya en açık düzen.
    ('mufredat', Routes.curriculum),
  ];
  // ------------------------------------------------------------------
  // EDGE-TO-EDGE / SİSTEM ÇUBUKLARI
  // ------------------------------------------------------------------
  //
  // Android 15+ edge-to-edge'i zorunlu kılıyor: uygulama durum çubuğunun
  // ve gezinme çubuğunun ALTINA çiziliyor, güvenli alanı `MediaQuery
  // .padding` bildiriyor. Bu padding düzeni daraltıyor — dar ekranda
  // taşmayı tetikleyebilecek yer tam da burası.
  //
  // Yatayda kenar payları sola/sağa geçiyor (çentik + jest çubuğu);
  // dikeyde üste/alta. İkisi de ayrı ayrı kuruluyor.
  group('edge-to-edge · sistem çubuğu payı altında taşma yok', () {
    const tight = <(String, Size, FakeViewPadding)>[
      (
        'kucuk-320 dikey',
        Size(320, 568),
        FakeViewPadding(top: 48, bottom: 48),
      ),
      (
        'kucuk-320 yatay (çentik)',
        Size(568, 320),
        FakeViewPadding(left: 48, right: 48, bottom: 24),
      ),
      (
        'j7prime-360 dikey',
        Size(360, 640),
        FakeViewPadding(top: 48, bottom: 48),
      ),
      (
        'j7prime-360 yatay (çentik)',
        Size(640, 360),
        FakeViewPadding(left: 48, right: 48, bottom: 24),
      ),
    ];

    for (final (name, size, padding) in tight) {
      for (final (screenName, route) in screens) {
        testWidgets('$name · $screenName', (tester) async {
          await QaSeed.activeUser(db);
          if (route == Routes.run) {
            await seedRunningSession(db, id: 'inset', sch: schedule());
          }

          // `pumpQaApp` dpr'yi 1.0 yapıyor → fiziksel = logical piksel.
          tester.view.padding = padding;
          tester.view.viewPadding = padding;
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetViewPadding);

          final c = await pumpQaApp(tester, db, size: size);
          if (route != Routes.home) {
            c.read(appRouterProviderForQa).go(route);
            await tester.pumpAndSettle();
          }

          expect(
            tester.takeException(),
            isNull,
            reason: '$name · $screenName sistem çubuğu payıyla taştı',
          );
        });
      }
    }
  });

  for (final (devName, portrait) in devices) {
    for (final (orientName, size) in [
      ('dikey', portrait),
      // Yatay = aynı yüzeyin çevrilmiş hâli.
      ('yatay', Size(portrait.height, portrait.width)),
    ]) {
      group(
          '$devName · $orientName (${size.width.toInt()}x'
          '${size.height.toInt()})', () {
        for (final (screenName, route) in screens) {
          testWidgets('$screenName taşmıyor', (tester) async {
            await QaSeed.activeUser(db);
            if (route == Routes.run) {
              await seedRunningSession(db, id: 'resp', sch: schedule());
            }

            final c = await pumpQaApp(tester, db, size: size);
            if (route != Routes.home) {
              c.read(appRouterProviderForQa).go(route);
              await tester.pumpAndSettle();
            }

            expect(
              tester.takeException(),
              isNull,
              reason: '$screenName · $devName · $orientName '
                  '(${size.width.toInt()}x${size.height.toInt()}) taştı',
            );
          });
        }
      });
    }
  }

  // ------------------------------------------------------------------
  // İNGİLİZCE ARAYÜZ (v1.2/E)
  // ------------------------------------------------------------------
  //
  // İngilizce metinler Türkçesinden UZUN: "Konu seçmeden devam et" 24
  // karakter, "Continue without a topic" 24 ama "Ayarlar" 7'ye karşı
  // "Settings" 8, "Yanlışlar" 9'a karşı "Mistakes" 8... tek tek değil,
  // TOPLAMDA farklılar ve taşma dar ekranda çıkıyor.
  //
  // Tüm matris iki kez koşturulmuyor: taşmanın gerçekten olduğu iki EN DAR
  // yüzey, iki yönde. Sekiz cihazı ikiye katlamak testin süresini iki
  // katına çıkarır, bulduğu hatayı iki katına çıkarmaz.
  group('İngilizce arayüz · dar ekranda taşma yok', () {
    const tightest = <(String, Size)>[
      ('kucuk-320 dikey', Size(320, 568)),
      ('kucuk-320 yatay', Size(568, 320)),
      ('j7prime-360 dikey', Size(360, 640)),
      ('j7prime-360 yatay', Size(640, 360)),
    ];

    for (final (name, size) in tightest) {
      for (final (screenName, route) in screens) {
        testWidgets('$name · $screenName', (tester) async {
          await QaSeed.activeUser(db);
          await db.settingsDao.patchSettings(
            const UserSettingsCompanion(language: Value(AppLanguage.en)),
          );
          if (route == Routes.run) {
            await seedRunningSession(db, id: 'resp-en', sch: schedule());
          }

          final c = await pumpQaApp(tester, db, size: size);
          if (route != Routes.home) {
            c.read(appRouterProviderForQa).go(route);
            await tester.pumpAndSettle();
          }

          expect(
            tester.takeException(),
            isNull,
            reason: 'İngilizce · $name · $screenName taştı',
          );
        });
      }
    }
  });
}
