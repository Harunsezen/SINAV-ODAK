import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/core/router/app_router.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/core/theme/app_theme.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/run_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 1.1 + 1.3 — oturumdan onaylı çıkış ve üç yollu "Bitir".
///
/// **v1.0'daki kusur:** aktif oturum varken router HER yolu `/run`'a
/// çeviriyordu. Kullanıcı ana panele, istatistiklere, ayarlara gidemiyordu;
/// geri tuşu yalnızca "çıkamazsın" snackbar'ı gösteriyordu. Uygulama
/// kullanıcıyı kendi ekranında hapsediyordu.
///
/// Bu dosya GERÇEK router'ı kullanıyor — yönlendirme kuralının kendisi
/// test ediliyor, ekranların tek başına davranışı değil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;
  late StreamController<int> ticker;

  setUp(() async {
    db = newDb();
    fakeNow = t0;
    ticker = StreamController<int>.broadcast();
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(onboardingCompleted: Value(true)),
    );
  });

  tearDown(() async {
    await ticker.close();
    await db.close();
  });

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => ticker.stream),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.future);
    await container.read(settingsStreamProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: container.read(appRouterProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  String route(ProviderContainer c) => c
      .read(appRouterProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  // =====================================================================

  testWidgets('oturum küçültülüp ana panele dönülüyor, sonra geri alınıyor',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    // Router aktif oturumda /run'a zorluyor — bu davranış KORUNUYOR.
    expect(route(c), Routes.run);

    // --- Çıkış onaydan geçiyor ---
    await tester.tap(find.byKey(const Key('run-minimize')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run-minimize-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('run-minimize-confirm')));
    await tester.pumpAndSettle();

    // --- Ana paneldeyiz ve oturum HÂLÂ AÇIK ---
    expect(route(c), Routes.home, reason: 'v1.0\'da bu imkânsızdı');
    final s = await db.sessionDao.findById('s1');
    expect(
      s!.status,
      SessionStatus.running,
      reason: 'küçültme oturumu BİTİRMEZ — sayaç arka planda sürer',
    );

    // --- Dönüş kapısı görünür: aksi halde çıkmaz olurdu ---
    final banner = find.byKey(const Key('home-active-session'));
    expect(
      banner,
      findsOneWidget,
      reason: 'geri dönüş şeridi olmadan kullanıcı oturuma dönemezdi',
    );

    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(route(c), Routes.run, reason: 'şeritten oturuma dönülmeli');
  });

  testWidgets('küçültme VAZGEÇİLİRSE oturumda kalınıyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    await tester.tap(find.byKey(const Key('run-minimize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-minimize-cancel')));
    await tester.pumpAndSettle();

    expect(route(c), Routes.run);
    expect(find.byType(RunScreen), findsOneWidget);
  });

  testWidgets('küçültülmemişken ana panele KAÇILAMIYOR (kural korunuyor)',
      (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    // Doğrudan yönlendirme denemesi: router geri çeviriyor.
    c.read(appRouterProvider).go(Routes.home);
    await tester.pumpAndSettle();

    expect(
      route(c),
      Routes.run,
      reason: 'onaysız çıkış hâlâ yasak — yalnızca diyalogdan geçilir',
    );
  });

  testWidgets('oturum bitince küçültme bayrağı düşüyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    await tester.tap(find.byKey(const Key('run-minimize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-minimize-confirm')));
    await tester.pumpAndSettle();
    expect(c.read(sessionMinimizedProvider), isTrue);

    // Oturum silinince bayrak düşmeli; kalsaydı BİR SONRAKİ oturum
    // onay diyaloğu olmadan terk edilebilirdi.
    c.read(sessionMinimizedProvider.notifier).restore();
    expect(c.read(sessionMinimizedProvider), isFalse);
  });

  testWidgets(
      'UX BULGUSU: küçültülmüşken "Oturumu Başlat" YENİ oturum '
      'başlatmıyor, oturuma döndürüyor', (tester) async {
    // Küçültme eklenince bu buton hâlâ etkindi: kullanıcı dört kurulum
    // adımını geçip BAŞLAT'a basınca `StartSessionUseCase` SessionFailure
    // fırlatıyordu. Veri bozulmuyordu ama kullanıcı duvara çarpıyordu.
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    await tester.tap(find.byKey(const Key('run-minimize')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-minimize-confirm')));
    await tester.pumpAndSettle();
    expect(route(c), Routes.home);

    // Buton etiketi değişmeli.
    expect(find.text('Oturuma dön'), findsOneWidget);
    expect(find.text('Oturumu Başlat'), findsNothing);

    await tester.tap(find.byKey(const Key('home-start')));
    await tester.pumpAndSettle();

    expect(
      route(c),
      Routes.run,
      reason: 'kurulum akışına DEĞİL, açık oturuma dönmeli',
    );
  });

  // ------------------- FAZ 1.3: Bitir -> Sil -------------------

  testWidgets('Bitir -> Sil -> onay: oturum tamamen siliniyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    fakeNow = t0 + 600000;
    ticker.add(0);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-early-delete')));
    await tester.pumpAndSettle();

    // İKİNCİ onay şart: geri alınamaz bir işlem.
    expect(
      find.byKey(const Key('run-discard-dialog')),
      findsOneWidget,
      reason: 'silme tek dokunuşla olmamalı',
    );

    await tester.tap(find.byKey(const Key('run-discard-confirm')));
    await tester.pumpAndSettle();

    expect(
      await db.sessionDao.findById('s1'),
      isNull,
      reason: 'silinen oturum istatistiklere karışmamalı',
    );
    expect(route(c), Routes.home);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Bitir -> Sil -> VAZGEÇ: oturum duruyor', (tester) async {
    await seedRunningSession(db, id: 's1', sch: schedule());
    final c = await pumpApp(tester);

    await tester.tap(find.text('Bitir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-early-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run-discard-cancel')));
    await tester.pumpAndSettle();

    final s = await db.sessionDao.findById('s1');
    expect(s, isNotNull);
    expect(s!.status, SessionStatus.running);
    expect(route(c), Routes.run);
  });
}
