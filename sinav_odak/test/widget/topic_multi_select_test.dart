import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/router/routes.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/session_setup/setup_controller.dart';
import 'package:sinav_odak/presentation/curriculum/topic_tree_view.dart';
import 'package:sinav_odak/presentation/session_setup/topic_picker.dart';

import '../qa/qa_harness.dart';
import '../unit/usecase_helpers.dart';

/// v1.2/D — KONU SEÇİCİDE ÇOKLU SEÇİM.
///
/// En önemli iddia ilk testte: **tek dokunuş yolu bozulmadı.** Çoklu konu
/// eklerken yaygın durumu (tek konu, bir dokunuş, ilerle) yavaşlatmak
/// özelliği kazanç değil kayıp yapardı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  const turev = 'top_sub_yks_1_22';
  const integral = 'top_sub_yks_1_23';
  const temel = 'top_sub_yks_1_0';

  /// Ders seçiminden konu seçiciye kadar akışı yürütür.
  Future<dynamic> openPicker(WidgetTester tester) async {
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(411, 900));
    c.read(appRouterProviderForQa).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matematik'));
    await tester.pumpAndSettle();
    expect(currentRoute(c), Routes.sessionTopic);
    return c;
  }

  /// Konunun kutucuğuna dokunur.
  ///
  /// Önce KAYDIRIYOR: `ListView.builder` görünmeyen satırı hiç kurmuyor
  /// ve `ensureVisible` var olmayan öğede `StateError` atıyor. Türev
  /// listenin 22. sırasında.
  Future<void> check(WidgetTester tester, String topicId) async {
    final box = find.byKey(Key('topic-check-$topicId'));
    final list = find.descendant(
      of: find.byKey(TopicTreeView.listKey),
      matching: find.byType(Scrollable),
    );

    // Önce EN ÜSTE dön, sonra aşağı tara. Tek yönlü arama, listede
    // yukarıda kalan bir konuyu ararken sonsuza kadar aşağı kaydırıyordu
    // (ilk denemede "Temel Kavramlar"a geri dönüş tam böyle düştü).
    await tester.drag(list, const Offset(0, 4000));
    await tester.pumpAndSettle();
    if (box.evaluate().isEmpty) {
      await tester.scrollUntilVisible(box, 200, scrollable: list);
    }

    await tester.ensureVisible(box);
    await tester.pumpAndSettle();
    await tester.tap(box);
    await tester.pumpAndSettle();
  }

  testWidgets('TEK DOKUNUŞ: satıra dokun → seçilir ve İLERLENİR', (
    tester,
  ) async {
    final c = await openPicker(tester);

    await tester.tap(find.text('Temel Kavramlar'));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.sessionType, reason: 'v1.1 yolu aynen');
    expect(c.read(setupProvider).topicIds, [temel]);
  });

  testWidgets('kutucuğa dokun: EKRANDA KALINIR, sayaç görünür', (tester) async {
    final c = await openPicker(tester);

    await check(tester, temel);

    expect(currentRoute(c), Routes.sessionTopic, reason: 'ilerlemiyor');
    expect(c.read(setupProvider).topicIds, [temel]);
    expect(find.byKey(TopicPicker.selectedBarKey), findsOneWidget);
    expect(find.text('1 konu seçildi'), findsOneWidget);
  });

  testWidgets('üç konu seçilip Devam ile ilerleniyor', (tester) async {
    final c = await openPicker(tester);

    await check(tester, temel);
    await check(tester, turev);
    await check(tester, integral);

    expect(find.text('3 konu seçildi'), findsOneWidget);

    await tester.tap(find.byKey(TopicPicker.continueKey));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.sessionType);
    expect(c.read(setupProvider).topicIds, [temel, turev, integral]);
    expect(
      c.read(setupProvider).topicId,
      temel,
      reason: 'ilk seçilen birincil konu',
    );
  });

  testWidgets('kutucuğa tekrar dokununca ÇIKARILIYOR', (tester) async {
    final c = await openPicker(tester);

    await check(tester, temel);
    await check(tester, turev);
    await check(tester, temel);

    expect(c.read(setupProvider).topicIds, [turev]);
    expect(find.text('1 konu seçildi'), findsOneWidget);
  });

  testWidgets('hepsi çıkarılınca ATLA düğmesi geri geliyor', (tester) async {
    // Seçim yokken "Devam" ne yapacağı belirsiz bir düğme olurdu.
    final c = await openPicker(tester);

    expect(find.byKey(const Key('topic-skip')), findsOneWidget);
    expect(find.byKey(TopicPicker.continueKey), findsNothing);

    await check(tester, temel);
    expect(find.byKey(TopicPicker.continueKey), findsOneWidget);
    expect(find.byKey(const Key('topic-skip')), findsNothing);

    await check(tester, temel);
    expect(find.byKey(const Key('topic-skip')), findsOneWidget);
    expect(c.read(setupProvider).topicIds, isEmpty);
  });

  testWidgets('ATLA: konusuz devam ediliyor', (tester) async {
    final c = await openPicker(tester);

    await tester.tap(find.byKey(const Key('topic-skip')));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.sessionType);
    expect(c.read(setupProvider).topicIds, isEmpty);
  });

  testWidgets('ALT DAL da çoklu seçime giriyor', (tester) async {
    // "Mitoz" çalışan kullanıcı oturumu "Hücre Bölünmeleri" diye
    // kaydetmek zorunda kalmamalı — alt dal da bir konu satırı.
    await QaSeed.activeUser(db);
    final c = await pumpQaApp(tester, db, size: const Size(411, 900));
    c.read(appRouterProviderForQa).go(Routes.sessionSubject);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biyoloji'));
    await tester.pumpAndSettle();

    final toggle = find.byKey(const Key('topic-expand-top_sub_yks_5_1'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final child = await db.subjectDao.findTopic('top_sub_yks_5_2');
    expect(child?.name, 'Madde Geçişleri', reason: 'v1.1 kimliği duruyor');

    await check(tester, child!.id);
    expect(c.read(setupProvider).topicIds, [child.id]);
  });

  testWidgets('seçim oturuma YAZILIYOR: plan → BAŞLAT', (tester) async {
    final c = await openPicker(tester);

    await check(tester, temel);
    await check(tester, turev);
    await tester.tap(find.byKey(TopicPicker.continueKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();
    expect(currentRoute(c), Routes.sessionPlan);

    await tester.tap(find.byKey(const Key('plan-start')));
    await tester.pumpAndSettle();

    final active = await db.sessionDao.findActiveSession();
    expect(active, isNotNull);
    expect(active!.topicId, temel, reason: 'birincil konu');

    final topics = await db.sessionDao.topicsOf(active.id);
    expect(topics.map((t) => t.id), [temel, turev]);
  });

  testWidgets('plan başlığında "+1" rozeti', (tester) async {
    final c = await openPicker(tester);

    await check(tester, temel);
    await check(tester, turev);
    await tester.tap(find.byKey(TopicPicker.continueKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Soru Çözümü'));
    await tester.pumpAndSettle();

    expect(currentRoute(c), Routes.sessionPlan);
    // Üç konu adını yan yana yazmak başlığı taşırıyordu; ilk konu + sayı.
    expect(find.textContaining('+1'), findsWidgets);
  });
}
