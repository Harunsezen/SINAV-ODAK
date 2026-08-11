import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/ports/haptic_gateway.dart';
import 'package:sinav_odak/presentation/run/done_screen.dart';
import 'package:sinav_odak/presentation/run/pending_finish_controller.dart';

import '../unit/usecase_helpers.dart';

/// Titreşim çağrılarını kaydeden sahte kapı.
class RecordingHaptic implements HapticGateway {
  final List<String> calls = [];

  @override
  Future<void> success() async => calls.add('success');

  @override
  Future<void> celebrate() async => calls.add('celebrate');
}

/// FAZ 8 — Tebrik ekranında YENİ rozet kutlaması.
///
/// Rozetler `SessionRepository.save()` yolunda açılıyordu ama kullanıcı
/// Ayarlar > Rozetler'e girmedikçe kazandığından haberi olmuyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingHaptic haptic;

  setUp(() {
    db = newDb();
    haptic = RecordingHaptic();
  });
  tearDown(() async => db.close());

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/done',
        routes: [
          GoRoute(path: '/run/done', builder: (_, __) => const DoneScreen()),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('ANA PANEL')),
          ),
          GoRoute(
            path: '/session/subject',
            builder: (_, __) => const Scaffold(body: Text('DERS')),
          ),
          GoRoute(
            path: '/achievements',
            builder: (_, __) => const Scaffold(body: Text('ROZETLER')),
          ),
        ],
      );

  Future<ProviderContainer> pumpDone(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        hapticGatewayProvider.overrideWithValue(haptic),
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
        child: MaterialApp.router(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(savedResultProvider.notifier).set(
          sessionId: 's1',
          focusScore: 88,
          dateKey: '2025-08-06',
        );
    await tester.pumpAndSettle();
    return container;
  }

  // -------------------------------------------------------------------

  testWidgets('yeni rozet YOKSA kutlama kartı ÇIKMIYOR', (tester) async {
    await pumpDone(tester);

    expect(find.byKey(const Key('done-new-achievements')), findsNothing);
    expect(haptic.calls, isEmpty);
  });

  testWidgets('yeni rozet VARSA kart görünüyor', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpDone(tester);

    expect(find.byKey(const Key('done-new-achievements')), findsOneWidget);
    expect(find.text('İlk Adım'), findsOneWidget);
  });

  testWidgets('kutlama TİTREŞİMİ tetikleniyor', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpDone(tester);

    expect(haptic.calls, contains('celebrate'));
  });

  testWidgets('gösterilen rozet GÖRÜLDÜ işaretleniyor', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpDone(tester);

    expect(
      await db.achievementDao.unseenCount(),
      0,
      reason: 'işaretlenmezse her tebrik ekranında yeniden kutlanırdı',
    );
  });

  testWidgets('görülmüş rozet tekrar KUTLANMIYOR', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await db.achievementDao.markSeen('first_session');
    await pumpDone(tester);

    expect(find.byKey(const Key('done-new-achievements')), findsNothing);
    expect(haptic.calls, isEmpty);
  });

  testWidgets('birden fazla rozet birlikte listeleniyor', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
    await pumpDone(tester);

    expect(find.text('İlk Adım'), findsOneWidget);
    expect(find.text('Üç Gün Üst Üste'), findsOneWidget);
  });

  testWidgets('rozetleri gör bağlantısı çalışıyor', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpDone(tester);

    await tester.tap(find.byKey(const Key('done-see-achievements')));
    await tester.pumpAndSettle();

    expect(find.text('ROZETLER'), findsOneWidget);
  });

  testWidgets('kutlama kartı ana panele geçişi ENGELLEMİYOR', (tester) async {
    await db.achievementDao.unlock(code: 'first_session', unlockedAtMs: t0);
    await pumpDone(tester);

    await tester.tap(find.byKey(const Key('done-home')));
    await tester.pumpAndSettle();

    expect(find.text('ANA PANEL'), findsOneWidget);
  });
}
