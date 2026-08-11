import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/services/achievement_calculator.dart';
import 'package:sinav_odak/presentation/achievements/achievements_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 7B — Rozet listesi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpAchievements(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: AchievementsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // -------------------------------------------------------------------

  testWidgets('KİLİTLİ rozetler de listeleniyor', (tester) async {
    await pumpAchievements(tester);

    // Neyin peşinde olduğunu görmeyen kullanıcı için rozet motive edici
    // olmaz; katalogdaki her rozetin bir satırı olmalı.
    for (final def in AchievementCalculator.catalog) {
      expect(
        find.byKey(Key('achievement-${def.code}')),
        findsOneWidget,
        reason: '${def.code} listede yok',
      );
    }
  });

  testWidgets('hiçbiri açılmamışken sayaç 0', (tester) async {
    await pumpAchievements(tester);

    expect(
      find.text('0 / ${AchievementCalculator.catalog.length} rozet'),
      findsOneWidget,
    );
  });

  testWidgets('kilitli rozetin AÇIKLAMASI gizli', (tester) async {
    await pumpAchievements(tester);

    expect(find.text('3 gün arka arkaya çalıştın.'), findsNothing);
    expect(find.text('Kilitli'), findsWidgets);
  });

  testWidgets('açılan rozetin başlığı ve açıklaması görünüyor', (tester) async {
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await pumpAchievements(tester);

    expect(find.text('Üç Gün Üst Üste'), findsOneWidget);
    expect(find.text('3 gün arka arkaya çalıştın.'), findsOneWidget);
  });

  testWidgets('sayaç açılan rozet sayısını gösteriyor', (tester) async {
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpAchievements(tester);

    expect(
      find.text('2 / ${AchievementCalculator.catalog.length} rozet'),
      findsOneWidget,
    );
  });

  testWidgets('görülmemiş rozette YENİ rozeti var', (tester) async {
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await pumpAchievements(tester);

    expect(
      find.byKey(const Key('achievement-new-streak_3')),
      findsOneWidget,
    );
  });

  testWidgets('görüldü işaretlenince YENİ rozeti kalkıyor', (tester) async {
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await db.achievementDao.markSeen('streak_3');
    await pumpAchievements(tester);

    expect(find.byKey(const Key('achievement-new-streak_3')), findsNothing);
  });

  testWidgets('açık rozette kilit ikonu YOK', (tester) async {
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await pumpAchievements(tester);

    final tile = find.byKey(const Key('achievement-streak_3'));
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.byIcon(Icons.lock_outline)),
      findsNothing,
    );
  });

  test('her katalog kodunun ARB metni TANIMLI', () {
    // Bu test widget kurmadan çalışır: eşleşmeyen kod "Bilinmeyen rozet"
    // olarak görünürdü ve kimse fark etmezdi.
    for (final def in AchievementCalculator.catalog) {
      expect(
        _hasText(def.code),
        isTrue,
        reason: '${def.code} için ARB metni yok',
      );
    }
  });

  test('her katalog ikonu SABİT bir IconData ile eşleşiyor', () {
    // `IconData(codePoint)` --tree-shake-icons derlemesini kırıyor;
    // eşleşmeyen anahtar sessizce varsayılana düşerdi.
    for (final def in AchievementCalculator.catalog) {
      expect(
        achievementIcon(def.iconKey),
        isNot(Icons.emoji_events),
        reason: '${def.iconKey} eşleşmiyor, varsayılana düştü',
      );
    }
  });
}

/// `achievementText` switch'inde kodun bir dalı var mı?
///
/// L10n örneği olmadan çağrılamıyor; bilinen kod listesiyle karşılaştırmak
/// aynı korumayı sağlıyor.
bool _hasText(String code) => const {
      'streak_3',
      'streak_7',
      'streak_30',
      'first_session',
      'hours_10',
      'hours_100',
      'questions_1000',
      'marathon_day',
      'focus_90',
      'early_bird',
      'night_owl',
    }.contains(code);
