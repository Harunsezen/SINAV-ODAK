import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/presentation/goals/goal_form_sheet.dart';
import 'package:sinav_odak/presentation/goals/goals_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 7B — Hedefler ekranı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> seedGoal({
    required String id,
    GoalType type = GoalType.dailyMinutes,
    double target = 240,
    double current = 0,
    GoalStatus status = GoalStatus.active,
    String? subject,
  }) async {
    await db.goalDao.createGoal(
      id: id,
      type: type,
      target: target,
      subjectId: subject,
    );
    if (current > 0) await db.goalDao.setProgress(id, current);
    if (status != GoalStatus.active) await db.goalDao.setStatus(id, status);
  }

  Future<ProviderContainer> pumpGoals(WidgetTester tester) async {
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
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: GoalsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // -------------------------------------------------------------------

  testWidgets('hedef yoksa boş durum', (tester) async {
    await pumpGoals(tester);
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
  });

  testWidgets('aktif hedef kartı ve ilerleme çubuğu görünüyor', (tester) async {
    await seedGoal(id: 'g1', target: 240, current: 120);
    await pumpGoals(tester);

    expect(find.byKey(const Key('goal-card-g1')), findsOneWidget);
    expect(find.byKey(const Key('goal-progress-g1')), findsOneWidget);
    expect(find.byKey(const Key('goals-empty')), findsNothing);
  });

  testWidgets('ilerleme çubuğu ORANI doğru', (tester) async {
    await seedGoal(id: 'g1', target: 240, current: 120);
    await pumpGoals(tester);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('goal-progress-g1')),
    );
    expect(bar.value, closeTo(0.5, 0.001));
  });

  testWidgets('değer/hedef ve BİRİM gösteriliyor', (tester) async {
    await seedGoal(id: 'g1', target: 240, current: 120);
    await pumpGoals(tester);

    // Birim sözleşmesi: süre hedefleri DAKİKA.
    expect(find.text('120 / 240 dk'), findsOneWidget);
  });

  testWidgets('soru hedefinin birimi "soru"', (tester) async {
    await seedGoal(
      id: 'g1',
      type: GoalType.dailyQuestions,
      target: 100,
      current: 40,
    );
    await pumpGoals(tester);

    expect(find.text('40 / 100 soru'), findsOneWidget);
  });

  testWidgets('hedef aşılsa bile çubuk 1.0 ile SINIRLI', (tester) async {
    await seedGoal(id: 'g1', target: 100, current: 250);
    await pumpGoals(tester);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('goal-progress-g1')),
    );
    expect(bar.value, 1.0);
  });

  testWidgets('aktif ve tamamlanan AYRI bölümlerde', (tester) async {
    await seedGoal(id: 'aktif', target: 240, current: 60);
    await seedGoal(
      id: 'bitti',
      target: 100,
      current: 100,
      status: GoalStatus.completed,
    );
    await pumpGoals(tester);

    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Tamamlanan'), findsOneWidget);
    expect(find.text('Tamamlandı'), findsOneWidget);
  });

  group('hedef silme', () {
    testWidgets('VAZGEÇ: hedef duruyor', (tester) async {
      await seedGoal(id: 'g1');
      await pumpGoals(tester);

      await tester.tap(find.byKey(const Key('goal-delete-g1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-delete-cancel')));
      await tester.pumpAndSettle();

      expect(await db.select(db.goals).get(), hasLength(1));
    });

    testWidgets('ONAY: hedef siliniyor', (tester) async {
      await seedGoal(id: 'g1');
      await pumpGoals(tester);

      await tester.tap(find.byKey(const Key('goal-delete-g1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-delete-confirm')));
      await tester.pumpAndSettle();

      expect(await db.select(db.goals).get(), isEmpty);
    });
  });

  group('hedef oluşturma (S8 sınırları)', () {
    Future<void> openForm(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('goals-add')));
      await tester.pumpAndSettle();
    }

    testWidgets('form açılıyor ve varsayılan tip günlük süre', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      expect(find.byType(GoalFormSheet), findsOneWidget);
      expect(find.byKey(const Key('goal-target-value')), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('hedef oluşturuluyor ve listeye geliyor', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-create')));
      await tester.pumpAndSettle();

      final goals = await db.select(db.goals).get();
      expect(goals, hasLength(1));
      expect(goals.first.type, GoalType.dailyMinutes);
      expect(goals.first.targetValue, 120);
    });

    testWidgets('süre hedefi 15 dk adımlarla artıyor', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-target-plus')));
      await tester.pumpAndSettle();

      expect(find.text('135'), findsOneWidget);
    });

    testWidgets('süre TAVANI 480 (S8)', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      // 120 -> 480: 24 adım. Fazlası artmamalı.
      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byKey(const Key('goal-target-plus')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('480'), findsOneWidget);
      final plus = tester.widget<IconButton>(
        find.byKey(const Key('goal-target-plus')),
      );
      expect(plus.onPressed, isNull, reason: 'tavanda artırma pasif olmalı');
    });

    testWidgets('soru TAVANI 500 (S8)', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-type-dailyQuestions')));
      await tester.pumpAndSettle();

      for (var i = 0; i < 60; i++) {
        await tester.tap(find.byKey(const Key('goal-target-plus')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('soru -> süre geçişinde değer TAVANA kırpılıyor',
        (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-type-dailyQuestions')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 60; i++) {
        await tester.tap(find.byKey(const Key('goal-target-plus')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('500'), findsOneWidget);

      // Süreye dön: 500 > 480 tavanı.
      await tester.tap(find.byKey(const Key('goal-type-dailyMinutes')));
      await tester.pumpAndSettle();

      expect(
        find.text('500'),
        findsNothing,
        reason: '500 dk hedefi 480 tavanını aşıyor',
      );
      expect(find.text('480'), findsOneWidget);
    });

    testWidgets('ders bazlı hedefte ders seçilmeden OLUŞTUR pasif',
        (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-type-subjectMinutes')));
      await tester.pumpAndSettle();

      final create = tester.widget<FilledButton>(
        find.byKey(const Key('goal-create')),
      );
      expect(
        create.onPressed,
        isNull,
        reason: 'dersi olmayan ders hedefi sonsuza kadar 0 kalırdı',
      );
    });

    testWidgets('VAZGEÇ hedef oluşturmuyor', (tester) async {
      await pumpGoals(tester);
      await openForm(tester);

      await tester.tap(find.byKey(const Key('goal-cancel')));
      await tester.pumpAndSettle();

      expect(await db.select(db.goals).get(), isEmpty);
    });
  });
}
