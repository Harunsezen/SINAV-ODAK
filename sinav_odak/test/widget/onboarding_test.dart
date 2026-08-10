import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/onboarding/onboarding_screen.dart';
import 'package:sinav_odak/services/notifications/notification_service.dart';

import '../unit/usecase_helpers.dart';

/// İzin isteğini SAYAN sahte servis.
///
/// `NotificationService` platform kanalı kullanıyor; host testinde gerçek
/// çağrı `MissingPluginException` atardı. Alt sınıf yalnızca
/// `requestPermission`'ı değiştiriyor, geri kalan davranış aynı kalıyor.
class FakeNotificationService extends NotificationService {
  FakeNotificationService({this.granted = true});

  final bool granted;
  int requestCount = 0;

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    return granted;
  }
}

/// FAZ 3 — Onboarding 5 adım + KVKK/GDPR rızası.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeNotificationService notifications;

  setUp(() {
    db = newDb();
    notifications = FakeNotificationService();
  });
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: Routes.onboarding,
        routes: [
          GoRoute(
            path: Routes.onboarding,
            builder: (_, __) => const OnboardingScreen(),
          ),
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
          ),
        ],
      );

  Future<ProviderContainer> pumpOnboarding(WidgetTester tester) async {
    // Rıza metni + kartlar uzun; varsayılan 800x600 yüzeyde alt butonlar
    // görünür alanın dışında kalıyor.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        notificationServiceProvider.overrideWithValue(notifications),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
  }

  /// Vaat → sınav türü (YKS seçili) → hedef adımına kadar ilerler.
  Future<void> gotoGoalStep(WidgetTester tester) async {
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-exam-yks')));
    await tester.pumpAndSettle();
    await tapNext(tester);
  }

  /// Özet adımına kadar ilerler.
  Future<void> gotoSummary(WidgetTester tester) async {
    await gotoGoalStep(tester);
    await tapNext(tester); // hedef -> rıza
    await tapNext(tester); // rıza -> özet
  }

  // ---------------------------------------------------------------------

  testWidgets('1) beş adımın hepsi sırayla görünüyor', (tester) async {
    await pumpOnboarding(tester);
    expect(find.byKey(const Key('onboarding-step-promise')), findsOneWidget);

    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-step-exam')), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-exam-yks')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-step-goal')), findsOneWidget);

    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-step-consent')), findsOneWidget);

    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-step-summary')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-start')), findsOneWidget);
  });

  testWidgets('2) ilerleme göstergesi adımla değişiyor', (tester) async {
    await pumpOnboarding(tester);

    expect(find.text('1/5'), findsOneWidget);
    var bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('onboarding-progress')),
    );
    expect(bar.value, closeTo(0.2, 0.001));

    await tapNext(tester);
    expect(find.text('2/5'), findsOneWidget);
    bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('onboarding-progress')),
    );
    expect(bar.value, closeTo(0.4, 0.001));
  });

  testWidgets('2b) Geri butonu bir önceki adıma dönüyor', (tester) async {
    await pumpOnboarding(tester);
    expect(
      find.byKey(const Key('onboarding-back')),
      findsNothing,
      reason: 'ilk adımda geri yok',
    );

    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-step-promise')), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('3) sınav türü seçimi ayara yazılıyor', (tester) async {
    await pumpOnboarding(tester);

    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-exam-lgs')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await tapNext(tester);
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    final s = await db.settingsDao.read();
    expect(s.examType, ExamType.lgs);
  });

  testWidgets('4) sınav türü seçilmeden Devam PASİF', (tester) async {
    await pumpOnboarding(tester);
    await tapNext(tester);

    var btn = tester
        .widget<FilledButton>(find.byKey(const Key('onboarding-next')));
    expect(btn.onPressed, isNull, reason: 'ders listesi buna bağlı');

    await tester.tap(find.byKey(const Key('onboarding-exam-kpss')));
    await tester.pumpAndSettle();

    btn = tester
        .widget<FilledButton>(find.byKey(const Key('onboarding-next')));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('5) günlük hedef stepper\'ları çalışıyor', (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);

    // Varsayılanlar: 240 dk, 100 soru.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-goal-minutes-value')))
          .data,
      '4sa',
    );

    await tester.tap(find.byKey(const Key('onboarding-goal-minutes-dec')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-goal-minutes-value')))
          .data,
      '3sa 30dk',
      reason: '30 dakikalık adım',
    );

    await tester.tap(find.byKey(const Key('onboarding-goal-questions-inc')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('onboarding-goal-questions-value')),
          )
          .data,
      '110 soru',
      reason: '10 soruluk adım',
    );
  });

  testWidgets('5b) hedef sınırları aşılmıyor', (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);

    // 240 -> 60 (alt sınır): 6 kez azalt.
    for (var i = 0; i < 6; i++) {
      final dec = tester.widget<IconButton>(
        find.byKey(const Key('onboarding-goal-minutes-dec')),
      );
      if (dec.onPressed == null) break;
      await tester.tap(find.byKey(const Key('onboarding-goal-minutes-dec')));
      await tester.pumpAndSettle();
    }

    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-goal-minutes-value')))
          .data,
      '1sa',
    );
    final dec = tester.widget<IconButton>(
      find.byKey(const Key('onboarding-goal-minutes-dec')),
    );
    expect(dec.onPressed, isNull, reason: '60 dk alt sınır');
  });

  testWidgets('6) rıza varsayılan KAPALI (KVKK)', (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('onboarding-consent-toggle')),
    );
    expect(
      toggle.value,
      isFalse,
      reason: 'açık rıza pasif kabulle alınamaz',
    );
  });

  testWidgets('7) rıza açılıp kapatılabiliyor ve kayda geçiyor',
      (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    await tester.tap(find.byKey(const Key('onboarding-consent-toggle')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('onboarding-consent-toggle')),
          )
          .value,
      isTrue,
    );

    await tapNext(tester);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-summary-consent')))
          .data,
      'Açık',
    );

    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    final s = await db.settingsDao.read();
    expect(s.personalizedAdsConsent, isTrue);
  });

  testWidgets('7b) rıza dokunulmazsa false kaydediliyor', (tester) async {
    await pumpOnboarding(tester);
    await gotoSummary(tester);

    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    final s = await db.settingsDao.read();
    expect(s.personalizedAdsConsent, isFalse);
  });

  testWidgets('8) bildirim izni butonu requestPermission çağırıyor',
      (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    expect(notifications.requestCount, 0);
    await tester.tap(find.byKey(const Key('onboarding-notif-request')));
    await tester.pumpAndSettle();

    expect(notifications.requestCount, 1);
    expect(find.text('Bildirim izni verildi.'), findsOneWidget);
  });

  testWidgets('9) izin REDDEDİLSE bile Devam ile özete geçiliyor',
      (tester) async {
    notifications = FakeNotificationService(granted: false);
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    await tester.tap(find.byKey(const Key('onboarding-notif-request')));
    await tester.pumpAndSettle();

    expect(notifications.requestCount, 1);
    expect(
      find.textContaining('sorun değil, devam edebilirsin'),
      findsOneWidget,
      reason: 'akış DURMAZ',
    );

    await tapNext(tester);
    expect(find.byKey(const Key('onboarding-step-summary')), findsOneWidget);
  });

  testWidgets('10) Atla izin İSTEMEDEN sonraki adıma geçiyor',
      (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    await tester.tap(find.byKey(const Key('onboarding-notif-skip')));
    await tester.pumpAndSettle();

    expect(notifications.requestCount, 0, reason: 'izin İSTENMEMELİ');
    expect(find.byKey(const Key('onboarding-step-summary')), findsOneWidget);
  });

  testWidgets('11) özet ekranı seçilen değerleri gösteriyor', (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);

    await tester.tap(find.byKey(const Key('onboarding-goal-minutes-inc')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-goal-questions-dec')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await tapNext(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-summary-exam')))
          .data,
      'YKS',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-summary-minutes')))
          .data,
      '4sa 30dk',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-summary-questions')))
          .data,
      '90',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('onboarding-summary-consent')))
          .data,
      'Kapalı',
    );
  });

  testWidgets('12) Başla: ayarlar yazılıyor ve ana panele gidiliyor',
      (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);

    await tester.tap(find.byKey(const Key('onboarding-goal-minutes-inc')));
    await tester.pumpAndSettle();
    await tapNext(tester);
    await tapNext(tester);
    await tester.tap(find.byKey(const Key('onboarding-start')));
    await tester.pumpAndSettle();

    final s = await db.settingsDao.read();
    expect(s.onboardingCompleted, isTrue);
    expect(s.examType, ExamType.yks);
    expect(s.dailyGoalMinutes, 270);
    expect(s.dailyGoalQuestions, 100);
    expect(s.personalizedAdsConsent, isFalse);

    expect(find.text('ANA PANEL'), findsOneWidget);
  });

  testWidgets('12b) yarıda bırakılan onboarding ayar YAZMIYOR',
      (tester) async {
    await pumpOnboarding(tester);
    await gotoGoalStep(tester);
    await tapNext(tester);

    // Kullanıcı [Başla]'ya hiç basmadı.
    final s = await db.settingsDao.read();
    expect(s.onboardingCompleted, isFalse);
    expect(
      s.dailyGoalMinutes,
      240,
      reason: 'seçimler yalnızca son adımda yazılır',
    );
  });
}
