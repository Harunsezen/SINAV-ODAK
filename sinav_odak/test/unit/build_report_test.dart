import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/build_report.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/report_data.dart';

import 'usecase_helpers.dart';

/// FAZ 3.1 — rapor verisi toplama.
///
/// **Neden ayrı test:** hangi sayının nereden geldiği ve veliye NE
/// GÖSTERİLMEYECEĞİ bir içerik kararı. PDF çizimini test etmek bunu
/// kanıtlamaz.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = newDb();
    await db.settingsDao.ensure();
  });
  tearDown(() async => db.close());

  Future<void> seedDay(
    String dateKey, {
    required int studyS,
    int questions = 20,
    int correct = 15,
    int wrong = 4,
    int empty = 1,
  }) async {
    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'r_$dateKey',
            dateKey: dateKey,
            startedAt: t0,
            plannedDurationS: studyS,
            subjectId: subjectId,
            topicId: const Value(topicId),
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: Value(studyS),
            questionCount: Value(questions),
            correctCount: Value(correct),
            wrongCount: Value(wrong),
            emptyCount: Value(empty),
            net: Value(correct - wrong / 4),
            focusScore: const Value(80),
            endedAt: Value(t0 + studyS * 1000),
          ),
        );
    await db.statsDao.recomputeDay(dateKey);
  }

  final from = DateTime(2025, 8, 4);
  final to = DateTime(2025, 8, 6);

  // =====================================================================

  test('VELİ raporunda zayıf konu listesi YOK', () async {
    await seedDay('2025-08-04', studyS: 3600);
    await db.wrongItemDao.addManual(
      id: 'w1',
      subjectId: subjectId,
      topicId: topicId,
      note: 'zayıf konu',
    );

    final parent = await BuildReportUseCase(db)(
      audience: ReportAudience.parent,
      from: from,
      to: to,
    );

    expect(
      parent.weakTopics,
      isEmpty,
      reason: 'veliye "en kötü olduğu konular" listesi gönderilmez',
    );
  });

  test('EĞİTİMCİ raporunda zayıf konular VAR', () async {
    await seedDay('2025-08-04', studyS: 3600);
    await db.wrongItemDao.addManual(
      id: 'w1',
      subjectId: subjectId,
      topicId: topicId,
      note: 'zayıf konu',
    );

    final teacher = await BuildReportUseCase(db)(
      audience: ReportAudience.teacher,
      from: from,
      to: to,
    );

    // Zayıf konu sorgusu yanlış defterinden besleniyor; kayıt varsa liste
    // dolu olmalı.
    expect(teacher.audience, ReportAudience.teacher);
    expect(teacher.weakTopics, isNotEmpty);
  });

  test('günlük döküm ÇALIŞILMAYAN günleri de içeriyor (0 ile)', () async {
    await seedDay('2025-08-04', studyS: 3600);
    await seedDay('2025-08-06', studyS: 1800);

    final r = await BuildReportUseCase(db)(
      audience: ReportAudience.teacher,
      from: from,
      to: to,
    );

    expect(r.days.length, 3, reason: '4,5,6 — üç gün');
    expect(r.days[0].studyS, 3600);
    expect(
      r.days[1].studyS,
      0,
      reason: 'boş günü atlamak grafikte yanıltıcı süreklilik yaratırdı',
    );
    expect(r.days[2].studyS, 1800);
    expect(r.activeDayCount, 2);
  });

  test('toplamlar ve ders payları doğru', () async {
    await seedDay('2025-08-04', studyS: 3600);
    await seedDay('2025-08-06', studyS: 1800);

    final r = await BuildReportUseCase(db)(
      audience: ReportAudience.parent,
      from: from,
      to: to,
    );

    expect(r.totalStudyS, 5400);
    expect(r.sessionCount, 2);
    expect(r.questionCount, 40);
    expect(r.isEmpty, isFalse);

    expect(r.subjects, isNotEmpty);
    final total = r.subjects.fold<double>(0, (a, s) => a + s.share);
    expect(total, closeTo(1.0, 0.001), reason: 'paylar toplamı 1 olmalı');
  });

  test('hiç oturum yoksa rapor BOŞ işaretleniyor', () async {
    final r = await BuildReportUseCase(db)(
      audience: ReportAudience.parent,
      from: from,
      to: to,
    );

    expect(r.isEmpty, isTrue);
    expect(r.subjects, isEmpty);
    // Boş aralıkta bile gün listesi dolu (hepsi 0) — grafik ekseni bozulmasın.
    expect(r.days.length, 3);
  });
}
