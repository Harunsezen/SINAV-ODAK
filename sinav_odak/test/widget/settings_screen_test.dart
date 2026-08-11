import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/presentation/settings/settings_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 7A — Ayarlar ekranı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    // Ayar akışı ısıtılmadan ekran yükleniyor göstergesinde kalır.
    await container.read(settingsStreamProvider.future);

    // Ayarlar uzun bir liste: varsayılan 800x600 yüzeyde alttaki kartlar
    // hiç kurulmuyor ve `find` boş dönüyor.
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
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<UserSetting> settings() => db.settingsDao.read();

  // -------------------------------------------------------------------

  testWidgets('bölümler görünüyor', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Çalışma'), findsOneWidget);
    expect(find.text('Bildirim ve ses'), findsOneWidget);
    expect(find.text('Veri'), findsOneWidget);
    expect(find.text('Hakkında'), findsOneWidget);
  });

  group('tema', () {
    testWidgets('koyu tema seçilince ayara YAZILIYOR', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byIcon(Icons.dark_mode_outlined));
      await tester.pumpAndSettle();

      expect((await settings()).themeMode, ThemeModeSetting.dark);
    });

    testWidgets('açık tema seçilebiliyor', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byIcon(Icons.light_mode_outlined));
      await tester.pumpAndSettle();

      expect((await settings()).themeMode, ThemeModeSetting.light);
    });
  });

  group('ekran açık kalsın', () {
    testWidgets('kapatılınca ayara yazılıyor', (tester) async {
      await pumpSettings(tester);
      expect((await settings()).keepScreenOn, isTrue);

      await tester.tap(find.byKey(const Key('settings-keep-screen-on')));
      await tester.pumpAndSettle();

      expect((await settings()).keepScreenOn, isFalse);
    });
  });

  group('bildirim / ses / titreşim', () {
    testWidgets('bildirim kapatılınca ses ve titreşim PASİF', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-notifications')));
      await tester.pumpAndSettle();

      expect((await settings()).notificationEnabled, isFalse);

      final sound = tester.widget<SwitchListTile>(
        find.byKey(const Key('settings-sound')),
      );
      final vibration = tester.widget<SwitchListTile>(
        find.byKey(const Key('settings-vibration')),
      );
      expect(
        sound.onChanged,
        isNull,
        reason: 'kapalı bildirimin sesi olmaz',
      );
      expect(vibration.onChanged, isNull);
    });

    testWidgets('ses kapatılabiliyor', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-sound')));
      await tester.pumpAndSettle();

      expect((await settings()).soundEnabled, isFalse);
    });
  });

  group('günlük hedef', () {
    testWidgets('artırma 30 dk adımla yazıyor', (tester) async {
      await pumpSettings(tester);
      expect((await settings()).dailyGoalMinutes, 240);

      await tester.tap(find.byKey(const Key('settings-goal-plus')));
      await tester.pumpAndSettle();

      expect((await settings()).dailyGoalMinutes, 270);
    });

    testWidgets('azaltma çalışıyor', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-goal-minus')));
      await tester.pumpAndSettle();

      expect((await settings()).dailyGoalMinutes, 210);
    });

    testWidgets('alt sınırda azaltma PASİF', (tester) async {
      await db.settingsDao.ensure();
      await db.settingsDao.patchSettings(
        const UserSettingsCompanion(dailyGoalMinutes: Value(30)),
      );
      await pumpSettings(tester);

      final minus = tester.widget<IconButton>(
        find.byKey(const Key('settings-goal-minus')),
      );
      expect(minus.onPressed, isNull);
    });
  });

  group('net katsayısı (KARAR: geçmiş netler yeniden hesaplanır)', () {
    /// Katsayı 4 ile kaydedilmiş bir oturum: 30 doğru, 8 yanlış → net 28.
    Future<void> seedSession() async {
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's1',
              dateKey: '2025-08-06',
              startedAt: t0,
              plannedDurationS: 2880,
              subjectId: subjectId,
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              actualDurationS: const Value(2880),
              questionCount: const Value(40),
              correctCount: const Value(30),
              wrongCount: const Value(8),
              emptyCount: const Value(2),
              net: const Value(28),
              endedAt: const Value(t0 + 2880000),
            ),
          );
      await db.statsDao.recomputeDay('2025-08-06');
    }

    testWidgets('katsayı değişimi ONAY istiyor', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('net-recompute-dialog')), findsOneWidget);
    });

    testWidgets('VAZGEÇ: katsayı da net de DEĞİŞMİYOR', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('net-recompute-cancel')));
      await tester.pumpAndSettle();

      expect((await settings()).netPenaltyCoefficient, 4.0);
      expect((await db.sessionDao.findById('s1'))!.net, closeTo(28, 0.001));
    });

    testWidgets('ONAY: katsayı yazılıyor ve geçmiş net yeniden hesaplanıyor',
        (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('net-recompute-confirm')));
      await tester.pumpAndSettle();

      expect((await settings()).netPenaltyCoefficient, 3.0);
      // 30 - 8/3 = 27.333...
      expect(
        (await db.sessionDao.findById('s1'))!.net,
        closeTo(27.3333, 0.001),
        reason: 'onaylandıysa geçmiş netler yeni katsayıya göre olmalı',
      );
    });
  });

  group('verileri sıfırla (ÇİFT ONAY)', () {
    Future<void> seedSession() async {
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 's1',
              dateKey: '2025-08-06',
              startedAt: t0,
              plannedDurationS: 2880,
              subjectId: subjectId,
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              endedAt: const Value(t0 + 2880000),
            ),
          );
    }

    testWidgets('ilk onayda VAZGEÇ: veri duruyor', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset-step1-dialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-step1-cancel')));
      await tester.pumpAndSettle();

      expect(await db.sessionDao.findById('s1'), isNotNull);
    });

    testWidgets('ikinci onay kelime yazılmadan PASİF', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-step1-continue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset-step2-dialog')), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('reset-step2-confirm')),
      );
      expect(
        confirm.onPressed,
        isNull,
        reason: 'kelime yazılmadan silme düğmesi aktif olmamalı',
      );
    });

    testWidgets('YANLIŞ kelime: silme düğmesi PASİF kalıyor', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-step1-continue')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reset-keyword-field')),
        'SIL',
      );
      await tester.pumpAndSettle();

      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('reset-step2-confirm')),
      );
      expect(confirm.onPressed, isNull);
      expect(await db.sessionDao.findById('s1'), isNotNull);
    });

    testWidgets('DOĞRU kelime + onay: veriler siliniyor', (tester) async {
      await seedSession();
      await pumpSettings(tester);

      await tester.tap(find.byKey(const Key('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('reset-step1-continue')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('reset-keyword-field')),
        'SIFIRLA',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reset-step2-confirm')));
      await tester.pumpAndSettle();

      expect(await db.sessionDao.findById('s1'), isNull);
      expect(
        (await settings()).onboardingCompleted,
        isFalse,
        reason: 'sıfırlama sonrası onboarding baştan başlamalı',
      );
    });
  });

  group('hakkında', () {
    testWidgets('sürüm gösteriliyor', (tester) async {
      await pumpSettings(tester);
      expect(find.byKey(const Key('settings-version')), findsOneWidget);
      expect(find.text(kAppVersion), findsOneWidget);
    });

    testWidgets('test reklam kimliği uyarısı görünüyor', (tester) async {
      // Varsayılan derlemede TEST kimlikleri kullanılıyor; uyarı burada
      // olmazsa yanlışlıkla test kimlikleriyle yayına çıkılır.
      await pumpSettings(tester);
      expect(
        find.byKey(const Key('settings-test-ads-warning')),
        findsOneWidget,
      );
    });
  });
}
