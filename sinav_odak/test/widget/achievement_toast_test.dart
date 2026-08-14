import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/achievements/achievement_toast.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 2.1 — rozet şeridi ("Minecraft başarımı").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = newDb();
    await db.settingsDao.ensure();
  });
  tearDown(() async => db.close());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const AchievementToastLayer(
            child: Scaffold(body: Center(child: Text('EKRAN'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // =====================================================================

  testWidgets('rozet kazanılınca kart beliriyor, süre dolunca kayboluyor',
      (tester) async {
    final c = await pump(tester);
    expect(find.byKey(const Key('achievement-toast')), findsNothing);

    c.read(achievementToastQueueProvider.notifier).enqueue(['first_session']);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('achievement-toast')), findsOneWidget);
    expect(find.text('İlk Adım'), findsOneWidget);
    expect(find.text('Yeni rozet!'), findsOneWidget);

    // Kart kendi kendine düşüyor.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('achievement-toast')), findsNothing);
  });

  testWidgets('birden fazla rozet SIRAYLA gösteriliyor', (tester) async {
    // Tek kayıt birden fazla rozet açabiliyor (hours_100 + industry_escape
    // AYNI eşikte). Üst üste binmemeli.
    final c = await pump(tester);

    c.read(achievementToastQueueProvider.notifier).enqueue(
      ['hours_100', 'industry_escape'],
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('achievement-toast')),
      findsOneWidget,
      reason: 'aynı anda YALNIZCA bir kart',
    );
    expect(find.text('100 Saat'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      find.text('Sanayiden Kurtuldun'),
      findsOneWidget,
      reason: 'ikinci rozet sırayla gelmeli',
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('achievement-toast')), findsNothing);
  });

  testWidgets('karta dokununca hemen kapanıyor', (tester) async {
    final c = await pump(tester);
    c.read(achievementToastQueueProvider.notifier).enqueue(['streak_3']);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('achievement-toast')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('achievement-toast')), findsNothing);
  });

  testWidgets('ayardan KAPATILINCA kart hiç görünmüyor', (tester) async {
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(achievementToastEnabled: Value(false)),
    );
    final c = await pump(tester);

    c.read(achievementToastQueueProvider.notifier).enqueue(['first_session']);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('achievement-toast')), findsNothing);
  });

  testWidgets('kartın ALTINDAKİ ekran kullanılabilir kalıyor', (tester) async {
    // Şerit kullanıcının işini engellememeli.
    final c = await pump(tester);
    c.read(achievementToastQueueProvider.notifier).enqueue(['streak_3']);
    await tester.pumpAndSettle();

    expect(find.text('EKRAN'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('aynı rozet iki kez kuyruğa girmiyor', (tester) async {
    final c = await pump(tester);
    final q = c.read(achievementToastQueueProvider.notifier);
    q.enqueue(['streak_3']);
    q.enqueue(['streak_3']);
    expect(c.read(achievementToastQueueProvider).length, 1);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
