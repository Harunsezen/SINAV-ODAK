import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sinav_odak/application/schedule_writer.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/session_activity_tracker.dart';
import 'package:sinav_odak/domain/ports/session_notifier.dart';
import 'package:sinav_odak/presentation/run/summary_form.dart';

import '../unit/usecase_helpers.dart';

/// v1.3 YAMASI — **"Bu yanlışlar hangi konuya ait?"**
///
/// ## Neden var
///
/// v1.2/D ile bir oturuma birden fazla konu seçilebiliyor ama yanlış
/// kaydı hep **birincil konuya** (listenin ilkine) yazılıyordu. Sorunun
/// iki yüzü vardı:
///
/// 1. **Yanlış defteri** yanlış konuyu gösteriyordu.
/// 2. **"Gelişim gereken konular"** istatistiği kullanıcıya çalışması
///    gereken konuyu değil, o gün ilk seçtiği konuyu öne çıkarıyordu.
///
/// Bu dosya ikisini birden kilitliyor — üçüncü test yanlış defterini,
/// beşinci test istatistiği zorluyor.
///
/// ## Kırmızı çizgi: SÜRTÜNME
///
/// Seçici forma **gömülü**; ek adım YOK. Tek konulu oturumda ve yanlış
/// 0 iken hiç görünmüyor — yaygın durum bir dokunuş bile yavaşlamıyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late int fakeNow;

  const turev = 'top_sub_yks_1_22';
  const integral = 'top_sub_yks_1_23';
  const temel = 'top_sub_yks_1_0';

  setUp(() {
    db = newDb();
    fakeNow = t0;
  });
  tearDown(() async => db.close());

  /// Çok konulu, çizelgesi BİTMİŞ bir oturum yazar.
  ///
  /// `seedRunningSession` tek konulu; burada `session_topics` de dolu
  /// olmalı, çünkü seçicinin varlığı tam olarak ona bakıyor.
  Future<void> seedMultiTopic(List<String> topicIds) async {
    final sch = schedule();
    await db.sessionDao.createSession(
      StudySessionsCompanion.insert(
        id: 's1',
        dateKey: '2025-08-06',
        startedAt: sch.firstStartMs,
        plannedDurationS: sch.totalStudyS,
        subjectId: subjectId,
        topicId: Value(topicIds.isEmpty ? null : topicIds.first),
        activityTypeId: activityId,
        status: SessionStatus.running,
        scheduleJson: jsonEncode(sch.toJson()),
      ),
      ScheduleWriter.blocksOf('s1', sch),
      topicIds: topicIds,
    );
    fakeNow = lastEnd + 1000;
  }

  GoRouter buildRouter() => GoRouter(
        initialLocation: '/run/summary',
        routes: [
          GoRoute(
            path: '/run/summary',
            builder: (_, __) => const SummaryForm(),
          ),
          GoRoute(
            path: '/run/done',
            builder: (_, __) => const Scaffold(body: Text('DONE')),
          ),
        ],
      );

  Future<ProviderContainer> pumpForm(WidgetTester tester) async {
    // Form uzun: seçici eklendikten sonra KAYDET görünür alanın dışında
    // kalıyordu ve dokunuşlar hedefe ulaşmıyordu.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => fakeNow),
        sessionNotifierProvider
            .overrideWithValue(FakeNotifier() as SessionNotifier),
        activityTrackerProvider
            .overrideWithValue(FakeTracker() as SessionActivityTracker),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          routerConfig: buildRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Yanlış sayacını [times] kez artırır.
  ///
  /// **Önce soru sayısı giriliyor:** `NetCalculator` "yanlış, soru
  /// sayısını aşamaz" değişmezini uyguluyor ve aşıldığında KAYDET
  /// pasifleşiyor. Soru girilmeseydi bu testler kaydedemeden düşerdi —
  /// ilk denemede tam bu oldu.
  Future<void> bumpWrong(WidgetTester tester, int times) async {
    await tester.tap(find.byKey(const Key('summary-q-plus20')));
    await tester.pump();
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byKey(const Key('summary-wrong-inc')));
      await tester.pump();
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('summary-save')));
    await tester.pumpAndSettle();
  }

  /// Oturumdan doğan (auto) yanlış kaydı.
  Future<WrongItem?> autoWrong() async {
    final rows = await db.select(db.wrongItems).get();
    final auto = rows.where((r) => r.source == WrongItemSource.auto).toList();
    return auto.isEmpty ? null : auto.first;
  }

  // -------------------------------------------------------------------

  testWidgets('TEK KONULU oturumda seçici YOK', (tester) async {
    await seedMultiTopic([turev]);
    await pumpForm(tester);
    await bumpWrong(tester, 3);

    expect(
      find.byKey(const Key('summary-wrong-topic')),
      findsNothing,
      reason: 'cevabı belli olan bir soru sorulmamalı',
    );
  });

  testWidgets('YANLIŞ 0 iken seçici YOK (çok konulu olsa bile)',
      (tester) async {
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);

    expect(find.byKey(const Key('summary-wrong-topic')), findsNothing);
  });

  testWidgets('yanlış girilince seçici BELİRİYOR, 0a dönünce KAYBOLUYOR',
      (tester) async {
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);

    expect(find.byKey(const Key('summary-wrong-topic')), findsNothing);

    await bumpWrong(tester, 1);
    expect(find.byKey(const Key('summary-wrong-topic')), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary-wrong-dec')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-wrong-topic')), findsNothing);
  });

  testWidgets('ÜÇ KONU + yanlış: seçim wrong_items.topic_id\'ye YAZILIYOR',
      (tester) async {
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);
    await bumpWrong(tester, 4);

    // Üç konu + "emin değilim" = dört seçenek.
    expect(find.byKey(const Key('wrong-topic-$turev')), findsOneWidget);
    expect(find.byKey(const Key('wrong-topic-$integral')), findsOneWidget);
    expect(find.byKey(const Key('wrong-topic-$temel')), findsOneWidget);
    expect(find.byKey(const Key('wrong-topic-unsure')), findsOneWidget);

    // ÜÇÜNCÜ konu işaretleniyor — hata gerçekte oradaydı.
    await tester.tap(find.byKey(const Key('wrong-topic-$temel')));
    await tester.pumpAndSettle();
    await save(tester);

    final w = await autoWrong();
    expect(w, isNotNull, reason: 'yanlış kaydı hiç oluşmadıysa test boş');
    expect(
      w!.topicId,
      temel,
      reason: 'işaretlenen konu yazılmalı, birincil konu DEĞİL',
    );
    expect(w.wrongCount, 4);

    // Oturumun BİRİNCİL konusu değişmiyor: `topic_id` "bu oturumda ne
    // çalışıldı" sorusunu cevaplıyor, "hata neredeydi" sorusunu değil.
    expect((await db.sessionDao.findById('s1'))!.topicId, turev);
  });

  testWidgets('"EMİN DEĞİLİM": birincil konuya yazılıyor (v1.2 davranışı)',
      (tester) async {
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);
    await bumpWrong(tester, 2);

    // Önce başka bir konu seçilip sonra "emin değilim"e dönülüyor:
    // seçimin geri alınabildiği de kanıtlanıyor.
    await tester.tap(find.byKey(const Key('wrong-topic-$integral')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wrong-topic-unsure')));
    await tester.pumpAndSettle();
    await save(tester);

    expect((await autoWrong())!.topicId, turev, reason: 'birincil konu');
  });

  testWidgets('HİÇ DOKUNMADAN kaydetmek de birincil konuya yazıyor',
      (tester) async {
    // Varsayılan "emin değilim": hızlı yol bozulmuyor.
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);
    await bumpWrong(tester, 2);
    await save(tester);

    expect((await autoWrong())!.topicId, turev);
  });

  testWidgets('seçilen konu GELİŞİM GEREKEN KONULAR listesine düşüyor',
      (tester) async {
    // Sorunun ikinci ve daha sinsi yüzü: yanlış defteri düzelse bile
    // istatistik `study_sessions.topic_id` okuduğu sürece kullanıcıya
    // yine ilk seçtiği konuyu gösterirdi.
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);
    await bumpWrong(tester, 5);

    await tester.tap(find.byKey(const Key('wrong-topic-$temel')));
    await tester.pumpAndSettle();
    await save(tester);

    final day = DateTime(2025, 8, 6);
    final weakest = await db.statsDao.weakestTopics(day, day);

    expect(weakest, hasLength(1));
    expect(
      weakest.single.topicName,
      'Temel Kavramlar',
      reason: 'istatistik işaretlenen konuyu göstermeli, Türev\'i değil',
    );
    expect(weakest.single.wrongCount, 5, reason: 'sayı oturumdan geliyor');
  });

  testWidgets('seçim yapılmazsa istatistik ESKİSİ GİBİ birincil konuda',
      (tester) async {
    await seedMultiTopic([turev, integral, temel]);
    await pumpForm(tester);
    await bumpWrong(tester, 3);
    await save(tester);

    final day = DateTime(2025, 8, 6);
    final weakest = await db.statsDao.weakestTopics(day, day);
    expect(weakest.single.topicName, 'Türev');
    expect(weakest.single.wrongCount, 3);
  });
}
