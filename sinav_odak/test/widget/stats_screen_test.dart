import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/share_gateway.dart';
import 'package:sinav_odak/presentation/stats/stats_screen.dart';

import '../unit/usecase_helpers.dart';

/// Paylaşımı kaydeden sahte kapı — gerçek dosya/paylaşım katmanı testte
/// platform kanalı istiyor ve hiç tamamlanmıyor.
class RecordingShareGateway implements ShareGateway {
  final List<({String content, String fileName})> shared = [];
  bool result = true;

  /// Paylaşılan PDF'ler (FAZ 3.1).
  final List<({List<int> bytes, String fileName, String mimeType})>
      sharedFiles = [];

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async {
    shared.add((content: content, fileName: fileName));
    return result;
  }

  @override
  Future<bool> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    sharedFiles.add((bytes: bytes, fileName: fileName, mimeType: mimeType));
    return result;
  }
}

/// FAZ 7A — İstatistik ekranı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecordingShareGateway share;

  setUp(() {
    db = newDb();
    share = RecordingShareGateway();
  });
  tearDown(() async => db.close());

  /// `t0` = 2025-08-06 (Çarşamba). Hafta görünümü Pazartesi'den başlar,
  /// yani 2025-08-04..2025-08-06 aralığı.
  Future<void> seedSession({
    required String id,
    String dateKey = '2025-08-06',
    int actualDurationS = 2880,
    int questionCount = 40,
    int correctCount = 30,
    int wrongCount = 8,
    int emptyCount = 2,
    double net = 28,
    String subject = subjectId,
    String? topic = topicId,
  }) async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: id,
            dateKey: dateKey,
            startedAt: t0,
            plannedDurationS: 2880,
            subjectId: subject,
            topicId: Value(topic),
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: Value(actualDurationS),
            questionCount: Value(questionCount),
            correctCount: Value(correctCount),
            wrongCount: Value(wrongCount),
            emptyCount: Value(emptyCount),
            net: Value(net),
            focusScore: const Value(80),
            endedAt: Value(t0 + actualDurationS * 1000),
          ),
        );
    await db.statsDao.recomputeDay(dateKey);
  }

  Future<ProviderContainer> pumpStats(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        shareGatewayProvider.overrideWithValue(share),
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
          home: StatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // -------------------------------------------------------------------

  group('boş durum', () {
    testWidgets('kayıt yoksa boş durum gösteriliyor', (tester) async {
      await pumpStats(tester);

      expect(find.byKey(const Key('stats-empty')), findsOneWidget);
      expect(find.byKey(const Key('stats-daily-chart')), findsNothing);
    });

    testWidgets('boşken dışa aktarma UYARI veriyor, paylaşım YOK',
        (tester) async {
      await pumpStats(tester);

      await tester.tap(find.byKey(const Key('stats-export')));
      await tester.pumpAndSettle();

      expect(share.shared, isEmpty);
      expect(find.text('Dışa aktarılacak oturum yok.'), findsOneWidget);
    });
  });

  group('dolu durum', () {
    testWidgets('grafik ve özet görünüyor', (tester) async {
      await seedSession(id: 's1');
      await pumpStats(tester);

      expect(find.byKey(const Key('stats-daily-chart')), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byKey(const Key('stats-summary')), findsOneWidget);
      expect(find.byKey(const Key('stats-empty')), findsNothing);
    });

    testWidgets('toplam çalışma süresi doğru biçimleniyor', (tester) async {
      // 2880 sn = 48 dk
      await seedSession(id: 's1', actualDurationS: 2880);
      await pumpStats(tester);

      expect(find.text('48 dk'), findsWidgets);
    });

    testWidgets('bir saati aşan süre "sa dk" biçiminde', (tester) async {
      // 5400 sn = 1 sa 30 dk
      await seedSession(id: 's1', actualDurationS: 5400);
      await pumpStats(tester);

      expect(find.text('1 sa 30 dk'), findsWidgets);
    });

    testWidgets('ders dağılımı gösteriliyor', (tester) async {
      await seedSession(id: 's1');
      await pumpStats(tester);

      expect(find.byKey(const Key('stats-breakdown')), findsOneWidget);
    });

    testWidgets('yanlış yapılan konular listeleniyor', (tester) async {
      await seedSession(id: 's1', wrongCount: 8);
      await pumpStats(tester);

      expect(find.byKey(const Key('stats-weakest')), findsOneWidget);
    });
  });

  group('aralık seçimi', () {
    testWidgets('hafta DIŞINDAKİ gün haftalık görünümde YOK', (tester) async {
      // 2025-08-06 Çarşamba; 2025-08-01 (Cuma) önceki haftaya ait.
      await seedSession(id: 'oncekiHafta', dateKey: '2025-08-01');
      await pumpStats(tester);

      expect(
        find.byKey(const Key('stats-empty')),
        findsOneWidget,
        reason: 'haftalık görünüm yalnızca Pazartesi..bugün aralığını alır',
      );
    });

    testWidgets('AY seçilince önceki gün görünüyor', (tester) async {
      await seedSession(id: 'oncekiHafta', dateKey: '2025-08-01');
      await pumpStats(tester);

      await tester.tap(find.text('Ay'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stats-daily-chart')), findsOneWidget);
      expect(find.byKey(const Key('stats-empty')), findsNothing);
    });
  });

  group('CSV dışa aktarma', () {
    testWidgets('paylaşım çağrılıyor ve dosya adı aralığı taşıyor',
        (tester) async {
      await seedSession(id: 's1');
      await pumpStats(tester);

      await tester.tap(find.byKey(const Key('stats-export')));
      await tester.pumpAndSettle();

      expect(share.shared, hasLength(1));
      expect(
        share.shared.first.fileName,
        'sinav-odak-2025-08-04_2025-08-06.csv',
      );
    });

    testWidgets('CSV içeriği oturum verisini taşıyor', (tester) async {
      await seedSession(id: 's1');
      await pumpStats(tester);

      await tester.tap(find.byKey(const Key('stats-export')));
      await tester.pumpAndSettle();

      final content = share.shared.first.content;
      expect(content, contains('Tarih'), reason: 'başlık satırı');
      expect(content, contains('2025-08-06'));
      expect(content, contains('Matematik'), reason: 'ders ADI, kimliği değil');
    });

    testWidgets('paylaşım başarısızsa kullanıcıya bildiriliyor',
        (tester) async {
      await seedSession(id: 's1');
      share.result = false;
      await pumpStats(tester);

      await tester.tap(find.byKey(const Key('stats-export')));
      await tester.pumpAndSettle();

      expect(find.text('Dışa aktarma yapılamadı.'), findsOneWidget);
    });
  });
}
