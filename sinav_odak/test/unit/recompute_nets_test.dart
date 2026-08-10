import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/recompute_nets.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// FAZ 7A — Net katsayısı değişince GEÇMİŞ netlerin yeniden hesaplanması.
///
/// `study_sessions.net` denormalize: kaydedilirken o anki katsayıyla
/// yazılıyor. Katsayı değişince bu alan güncellenmezse toplam net iki farklı
/// katsayının karışımı olur ve hata SESSİZ kalır.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  /// Tamamlanmış bir oturum yazar. [net] BİLEREK dışarıdan veriliyor:
  /// "eski katsayıyla hesaplanmış" durumu böyle kuruluyor.
  Future<void> seedCompleted({
    required String id,
    String dateKey = '2025-08-06',
    int questionCount = 40,
    int correctCount = 30,
    int wrongCount = 8,
    int emptyCount = 2,
    required double net,
    int actualDurationS = 2880,
  }) async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: id,
            dateKey: dateKey,
            startedAt: t0,
            plannedDurationS: 2880,
            subjectId: subjectId,
            topicId: const Value(topicId),
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: Value(actualDurationS),
            questionCount: Value(questionCount),
            correctCount: Value(correctCount),
            wrongCount: Value(wrongCount),
            emptyCount: Value(emptyCount),
            net: Value(net),
            endedAt: const Value(t0 + 2880000),
            focusScore: const Value(80),
          ),
        );
    await db.statsDao.recomputeDay(dateKey);
  }

  Future<double> netOf(String id) async =>
      (await db.sessionDao.findById(id))!.net;

  /// Dart yerel *getter* tanımına izin vermiyor; yardımcı bir fonksiyon.
  Future<int> recompute(double coefficient) =>
      RecomputeNetsUseCase(db)(coefficient: coefficient);

  // -------------------------------------------------------------------

  test('katsayı 4 -> 3: net yeniden hesaplanıyor', () async {
    // 30 doğru, 8 yanlış, katsayı 4 => 30 - 8/4 = 28
    await seedCompleted(id: 's1', net: 28);

    final updated = await recompute(3);

    // 30 - 8/3 = 27.333...
    expect(await netOf('s1'), closeTo(27.3333, 0.001));
    expect(updated, 1);
  });

  test('günlük özet de güncelleniyor', () async {
    await seedCompleted(id: 's1', net: 28);
    expect((await db.statsDao.summaryFor(day, day)).net, closeTo(28, 0.001));

    await recompute(3);

    expect(
      (await db.statsDao.summaryFor(day, day)).net,
      closeTo(27.3333, 0.001),
      reason: 'daily_stats güncellenmezse grafikler eski netle çizilir',
    );
  });

  test('birden fazla gün: hepsi güncelleniyor', () async {
    await seedCompleted(id: 's1', dateKey: '2025-08-06', net: 28);
    await seedCompleted(id: 's2', dateKey: '2025-08-07', net: 28);

    final updated = await recompute(3);

    expect(updated, 2);
    expect(await netOf('s1'), closeTo(27.3333, 0.001));
    expect(await netOf('s2'), closeTo(27.3333, 0.001));
  });

  test('aynı katsayı: hiçbir şey değişmiyor', () async {
    await seedCompleted(id: 's1', net: 28);

    final updated = await recompute(4);

    expect(updated, 0, reason: 'değer aynıysa yazma yapılmamalı');
    expect(await netOf('s1'), closeTo(28, 0.001));
  });

  test('soru girilmemiş oturum ATLANIYOR', () async {
    await seedCompleted(
      id: 's1',
      questionCount: 0,
      correctCount: 0,
      wrongCount: 0,
      emptyCount: 0,
      net: 0,
    );

    final updated = await recompute(3);

    expect(updated, 0);
    expect(await netOf('s1'), 0);
  });

  test('devam eden oturuma DOKUNULMUYOR', () async {
    await seedRunningSession(db, id: 'run1', sch: schedule());

    final updated = await recompute(3);

    expect(updated, 0);
    final s = await db.sessionDao.findById('run1');
    expect(s!.status, SessionStatus.running);
  });

  test('hiç oturum yoksa 0 dönüyor', () async {
    expect(await recompute(3), 0);
  });

  test('yanlış yoksa net katsayıdan ETKİLENMİYOR', () async {
    // 30 doğru, 0 yanlış => katsayı ne olursa olsun net 30.
    await seedCompleted(
      id: 's1',
      questionCount: 32,
      correctCount: 30,
      wrongCount: 0,
      emptyCount: 2,
      net: 30,
    );

    final updated = await recompute(3);

    expect(updated, 0);
    expect(await netOf('s1'), closeTo(30, 0.001));
  });

  test('katsayı 3 -> 5: net YÜKSELİYOR', () async {
    await seedCompleted(id: 's1', net: 27.3333333);

    await recompute(5);

    // 30 - 8/5 = 28.4
    expect(await netOf('s1'), closeTo(28.4, 0.001));
  });

  test('kesinti ile biten oturum da güncelleniyor', () async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'int1',
            dateKey: '2025-08-06',
            startedAt: t0,
            plannedDurationS: 2880,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.interrupted,
            scheduleJson: '{}',
            actualDurationS: const Value(1200),
            questionCount: const Value(20),
            correctCount: const Value(15),
            wrongCount: const Value(4),
            emptyCount: const Value(1),
            net: const Value(14),
            endedAt: const Value(t0 + 1200000),
          ),
        );

    final updated = await recompute(3);

    expect(updated, 1, reason: 'yarıda kesilen oturum da istatistiğe giriyor');
    // 15 - 4/3 = 13.666...
    expect(await netOf('int1'), closeTo(13.6667, 0.001));
  });
}

/// Testlerde sabit gün — `DateTime.now()` KULLANILMAZ.
final day = DateTime.parse('2025-08-06');
