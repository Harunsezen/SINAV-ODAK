import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/presentation/calendar/calendar_screen.dart';

import '../unit/usecase_helpers.dart';

/// FAZ 7B — Takvim ekranı.
///
/// `t0` = 2025-08-06 (Ağustos 2025). Açılış ayı ve "bugün" vurgusu bu sabit
/// üzerinden doğrulanıyor; `DateTime.now()` KULLANILMIYOR.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> seedDay({
    required String id,
    required String dateKey,
    int actualDurationS = 2880,
  }) async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: id,
            dateKey: dateKey,
            startedAt: t0,
            plannedDurationS: 2880,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: Value(actualDurationS),
            endedAt: Value(t0 + actualDurationS * 1000),
          ),
        );
    await db.statsDao.recomputeDay(dateKey);
  }

  Future<ProviderContainer> pumpCalendar(WidgetTester tester) async {
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
          // Ürünün TÜRKÇE metnini doğruluyoruz; locale verilmezse
          // cihaz diline (testte en_US) düşülüyor.
          locale: Locale('tr'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // -------------------------------------------------------------------

  testWidgets('açılışta İÇİNDE BULUNULAN ay gösteriliyor', (tester) async {
    await pumpCalendar(tester);

    expect(find.text('Ağustos 2025'), findsOneWidget);
    expect(find.byKey(const Key('calendar-grid')), findsOneWidget);
  });

  testWidgets('ay ızgarası doğru gün sayısını çiziyor', (tester) async {
    await pumpCalendar(tester);

    // Ağustos 31 gün.
    expect(find.byKey(const Key('calendar-day-1')), findsOneWidget);
    expect(find.byKey(const Key('calendar-day-31')), findsOneWidget);
    expect(find.byKey(const Key('calendar-day-32')), findsNothing);
  });

  testWidgets('kayıt yoksa boş durum, özet YOK', (tester) async {
    await pumpCalendar(tester);

    expect(find.byKey(const Key('calendar-empty')), findsOneWidget);
    expect(find.byKey(const Key('calendar-summary')), findsNothing);
  });

  testWidgets('kayıt varsa özet görünüyor, boş durum YOK', (tester) async {
    await seedDay(id: 's1', dateKey: '2025-08-06');
    await pumpCalendar(tester);

    expect(find.byKey(const Key('calendar-summary')), findsOneWidget);
    expect(find.byKey(const Key('calendar-empty')), findsNothing);
  });

  testWidgets('ay toplamı doğru hesaplanıyor', (tester) async {
    // 48 dk + 48 dk = 96 dk = 1 sa 36 dk
    await seedDay(id: 's1', dateKey: '2025-08-06');
    await seedDay(id: 's2', dateKey: '2025-08-07');
    await pumpCalendar(tester);

    // v1.2/E: tek süre biçimi (boşluksuz), bkz. format_l10n.dart.
    expect(find.text('1sa 36dk'), findsOneWidget);
    expect(find.text('2 gün çalışıldı'), findsOneWidget);
  });

  group('ay gezinme', () {
    testWidgets('geri: önceki aya gidiyor', (tester) async {
      await pumpCalendar(tester);

      await tester.tap(find.byKey(const Key('calendar-prev')));
      await tester.pumpAndSettle();

      expect(find.text('Temmuz 2025'), findsOneWidget);
    });

    testWidgets('yıl sınırını doğru geçiyor', (tester) async {
      await pumpCalendar(tester);

      // Ağustos'tan 8 ay geri: Aralık 2024.
      for (var i = 0; i < 8; i++) {
        await tester.tap(find.byKey(const Key('calendar-prev')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Aralık 2024'), findsOneWidget);
    });

    testWidgets('içinde bulunulan ayda İLERİ pasif', (tester) async {
      await pumpCalendar(tester);

      final next = tester.widget<IconButton>(
        find.byKey(const Key('calendar-next')),
      );
      expect(
        next.onPressed,
        isNull,
        reason: 'gelecek ayda veri olamaz; boş ızgarada gezdirmek anlamsız',
      );
    });

    testWidgets('geri gidince İLERİ aktifleşiyor', (tester) async {
      await pumpCalendar(tester);
      await tester.tap(find.byKey(const Key('calendar-prev')));
      await tester.pumpAndSettle();

      final next = tester.widget<IconButton>(
        find.byKey(const Key('calendar-next')),
      );
      expect(next.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pumpAndSettle();
      expect(find.text('Ağustos 2025'), findsOneWidget);
    });

    testWidgets('başka aydaki kayıt bu ayda GÖRÜNMÜYOR', (tester) async {
      await seedDay(id: 's1', dateKey: '2025-07-15');
      await pumpCalendar(tester);

      expect(
        find.byKey(const Key('calendar-empty')),
        findsOneWidget,
        reason: 'Temmuz kaydı Ağustos ızgarasına girmemeli',
      );

      await tester.tap(find.byKey(const Key('calendar-prev')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('calendar-summary')), findsOneWidget);
    });
  });

  // =====================================================================
  // v1.5.2 — KİTAP OKUNAN GÜN TAKVİMDE GÖRÜNÜYOR
  //
  // Seri hesabı (`recomputeStreak`) yalnızca tarihe bakıyor: kitap okunan
  // gün seriyi sürdürüyor. Takvim ise yalnızca `totalStudyS`e bakıyordu.
  // Sonuç: pazar günü bir saat kitap okuyan öğrencinin serisi devam
  // ediyor ama takvimde pazar BOMBOŞ görünüyordu — iki ekran aynı veri
  // için birbirine zıt şey söylüyordu.
  // =====================================================================
  testWidgets('SADECE kitap okunan gün takvimde DOLU görünüyor',
      (tester) async {
    const day = '2025-08-04';
    await db.into(db.bookSessions).insert(
          BookSessionsCompanion.insert(
            id: 'bk1',
            dateKey: day,
            mode: BookMode.duration,
            startedAt: t0,
            status: SessionStatus.completed,
            actualDurationS: const Value(3600),
            pagesRead: const Value(40),
            endedAt: const Value(t0 + 3600000),
          ),
        );
    await db.statsDao.recomputeDay(day);

    // Önce veri katmanını doğrula: o gün için satır var ve okuma yazılmış.
    final row = await (db.select(db.dailyStats)
          ..where((t) => t.dateKey.equals(day)))
        .getSingleOrNull();
    expect(row, isNotNull, reason: 'kitap günü daily_stats satırı üretmeli');
    expect(row!.readingS, 3600);
    expect(row.totalStudyS, 0, reason: 'okuma ÇALIŞMA süresine eklenmiyor');

    await pumpCalendar(tester);

    // Boş durum çıkmamalı: o ayda bir şey yapılmış.
    expect(find.byKey(const Key('calendar-empty')), findsNothing);
    expect(find.byKey(const Key('calendar-summary')), findsOneWidget);

    // Hücrede GÖRÜNEN tek metin gün numarası; süre ipucunda ve
    // erişilebilirlik etiketinde taşınıyor, ekranda dolgu rengiyle
    // anlatılıyor. Bu yüzden metin değil, ipucu ve renk sorgulanıyor.
    final tip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(const Key('calendar-day-4')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(
      tip.message,
      contains('1sa'),
      reason: 'kitap okunan gün BOŞ değil, bir saatlik gün',
    );

    Color cellColor(int day) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(Key('calendar-day-$day')),
              matching: find.byType(Container),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    expect(
      cellColor(4),
      isNot(cellColor(5)),
      reason: 'okunan gün, hiçbir şey yapılmayan günden AYRI görünmeli',
    );
  });
}
