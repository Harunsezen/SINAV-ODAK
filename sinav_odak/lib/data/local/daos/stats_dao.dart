import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/utils/date_key.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/services/csv_builder.dart';
import '../database.dart';

part 'stats_dao.g.dart';

/// Bir gün/aralık için toplu özet.
class StatsSummary {
  const StatsSummary({
    required this.totalStudyS,
    required this.totalBreakS,
    required this.sessionCount,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.emptyCount,
    required this.net,
    required this.avgFocusScore,
  });

  factory StatsSummary.empty() => const StatsSummary(
        totalStudyS: 0,
        totalBreakS: 0,
        sessionCount: 0,
        questionCount: 0,
        correctCount: 0,
        wrongCount: 0,
        emptyCount: 0,
        net: 0,
        avgFocusScore: 0,
      );

  final int totalStudyS;
  final int totalBreakS;
  final int sessionCount;
  final int questionCount;
  final int correctCount;
  final int wrongCount;
  final int emptyCount;
  final double net;
  final double avgFocusScore;

  /// Doğru / (Doğru + Yanlış + Boş)
  double get successRate {
    final total = correctCount + wrongCount + emptyCount;
    return total == 0 ? 0 : correctCount / total;
  }
}

/// Ders kırılımı satırı (pasta/bar/radar grafikleri besler).
class SubjectBreakdownRow {
  const SubjectBreakdownRow({
    required this.subjectId,
    required this.subjectName,
    required this.colorHex,
    required this.studyS,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.emptyCount,
    required this.net,
  });

  final String subjectId;
  final String subjectName;
  final String colorHex;
  final int studyS;
  final int questionCount;
  final int correctCount;
  final int wrongCount;
  final int emptyCount;
  final double net;
}

@DriftAccessor(tables: [StudySessions, DailyStats])
class StatsDao extends DatabaseAccessor<AppDatabase> with _$StatsDaoMixin {
  StatsDao(super.db);

  /// Bir günün özetini oturumlardan YENİDEN hesaplar ve daily_stats'a yazar.
  /// Oturum kaydedildiğinde, düzenlendiğinde ve silindiğinde çağrılır.
  Future<void> recomputeDay(String dayKey) async {
    final rows = await (select(studySessions)
          ..where(
            (t) =>
                t.dateKey.equals(dayKey) &
                t.status.equalsValue(SessionStatus.running).not(),
          ))
        .get();

    if (rows.isEmpty) {
      await (delete(dailyStats)..where((t) => t.dateKey.equals(dayKey))).go();
      return;
    }

    var studyS = 0,
        breakS = 0,
        q = 0,
        correct = 0,
        wrong = 0,
        empty = 0,
        focusSum = 0,
        focusCount = 0;
    var net = 0.0;
    final bySubject = <String, int>{};

    for (final s in rows) {
      studyS += s.actualDurationS;
      breakS += s.totalBreakS;
      q += s.questionCount;
      correct += s.correctCount;
      wrong += s.wrongCount;
      empty += s.emptyCount;
      net += s.net;
      if (s.focusScore != null) {
        focusSum += s.focusScore!;
        focusCount++;
      }
      bySubject.update(
        s.subjectId,
        (v) => v + s.actualDurationS,
        ifAbsent: () => s.actualDurationS,
      );
    }

    await into(dailyStats).insertOnConflictUpdate(
      DailyStatsCompanion.insert(
        dateKey: dayKey,
        totalStudyS: Value(studyS),
        totalBreakS: Value(breakS),
        sessionCount: Value(rows.length),
        questionCount: Value(q),
        correctCount: Value(correct),
        wrongCount: Value(wrong),
        emptyCount: Value(empty),
        net: Value(net),
        avgFocusScore: Value(focusCount == 0 ? 0 : focusSum / focusCount),
        subjectBreakdownJson: Value(jsonEncode(bySubject)),
      ),
    );
  }

  Stream<DailyStat?> watchDay(String dayKey) {
    return (select(dailyStats)..where((t) => t.dateKey.equals(dayKey)))
        .watchSingleOrNull();
  }

  Stream<List<DailyStat>> watchRange(DateTime from, DateTime to) {
    final f = dateKeyOf(from);
    final t = dateKeyOf(to);
    return (select(dailyStats)
          ..where(
            (r) =>
                r.dateKey.isBiggerOrEqualValue(f) &
                r.dateKey.isSmallerOrEqualValue(t),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.dateKey)]))
        .watch();
  }

  /// Aralık toplamı — haftalık/aylık özet kartları için.
  Future<StatsSummary> summaryFor(DateTime from, DateTime to) async {
    final rows = await (select(dailyStats)
          ..where(
            (r) =>
                r.dateKey.isBiggerOrEqualValue(dateKeyOf(from)) &
                r.dateKey.isSmallerOrEqualValue(dateKeyOf(to)),
          ))
        .get();
    if (rows.isEmpty) return StatsSummary.empty();

    var studyS = 0, breakS = 0, sc = 0, q = 0, c = 0, w = 0, e = 0;
    var net = 0.0, focus = 0.0;
    var focusDays = 0;
    for (final r in rows) {
      studyS += r.totalStudyS;
      breakS += r.totalBreakS;
      sc += r.sessionCount;
      q += r.questionCount;
      c += r.correctCount;
      w += r.wrongCount;
      e += r.emptyCount;
      net += r.net;
      if (r.avgFocusScore > 0) {
        focus += r.avgFocusScore;
        focusDays++;
      }
    }
    return StatsSummary(
      totalStudyS: studyS,
      totalBreakS: breakS,
      sessionCount: sc,
      questionCount: q,
      correctCount: c,
      wrongCount: w,
      emptyCount: e,
      net: net,
      avgFocusScore: focusDays == 0 ? 0 : focus / focusDays,
    );
  }

  /// Ders bazlı kırılım. Radar / pasta / bar grafiklerinin ortak kaynağı.
  Future<List<SubjectBreakdownRow>> subjectBreakdown(
    DateTime from,
    DateTime to,
  ) async {
    final result = await customSelect(
      '''
      SELECT s.id            AS subject_id,
             s.name          AS subject_name,
             s.color_hex     AS color_hex,
             SUM(ss.actual_duration_s) AS study_s,
             SUM(ss.question_count)    AS q,
             SUM(ss.correct_count)     AS c,
             SUM(ss.wrong_count)       AS w,
             SUM(ss.empty_count)       AS e,
             SUM(ss.net)               AS net
      FROM study_sessions ss
      JOIN subjects s ON s.id = ss.subject_id
      WHERE ss.date_key >= ? AND ss.date_key <= ? AND ss.status != ?
      GROUP BY s.id
      ORDER BY study_s DESC
      ''',
      variables: [
        Variable<String>(dateKeyOf(from)),
        Variable<String>(dateKeyOf(to)),
        // Enum adı yeniden adlandırılırsa Dart tarafı derlenir ama SQL
        // sessizce yanlış sonuç dönerdi; değeri enum'dan bind ediyoruz.
        Variable<String>(SessionStatus.running.name),
      ],
      readsFrom: {studySessions, attachedDatabase.subjects},
    ).get();

    return result
        .map(
          (r) => SubjectBreakdownRow(
            subjectId: r.read<String>('subject_id'),
            subjectName: r.read<String>('subject_name'),
            colorHex: r.read<String>('color_hex'),
            studyS: r.read<int?>('study_s') ?? 0,
            questionCount: r.read<int?>('q') ?? 0,
            correctCount: r.read<int?>('c') ?? 0,
            wrongCount: r.read<int?>('w') ?? 0,
            emptyCount: r.read<int?>('e') ?? 0,
            net: r.read<double?>('net') ?? 0,
          ),
        )
        .toList();
  }

  /// En çok yanlış yapılan konular — "gelişim gerektiren konular" listesi.
  Future<List<({String topicName, String subjectName, int wrongCount})>>
      weakestTopics(DateTime from, DateTime to, {int limit = 10}) async {
    final rows = await customSelect(
      '''
      SELECT t.name AS topic_name,
             s.name AS subject_name,
             SUM(ss.wrong_count) AS wrongs
      FROM study_sessions ss
      JOIN topics t   ON t.id = ss.topic_id
      JOIN subjects s ON s.id = ss.subject_id
      WHERE ss.date_key >= ? AND ss.date_key <= ?
        AND ss.status != ? AND ss.wrong_count > 0
      GROUP BY t.id
      ORDER BY wrongs DESC
      LIMIT ?
      ''',
      variables: [
        Variable<String>(dateKeyOf(from)),
        Variable<String>(dateKeyOf(to)),
        Variable<String>(SessionStatus.running.name),
        Variable<int>(limit),
      ],
      readsFrom: {
        studySessions,
        attachedDatabase.topics,
        attachedDatabase.subjects,
      },
    ).get();

    return rows
        .map(
          (r) => (
            topicName: r.read<String>('topic_name'),
            subjectName: r.read<String>('subject_name'),
            wrongCount: r.read<int?>('wrongs') ?? 0,
          ),
        )
        .toList();
  }

  /// CSV dışa aktarma için oturumları **domain tipine** çevirerek döner.
  ///
  /// Ders/konu/tür adları JOIN ile geliyor: dışa aktarılan dosyada kullanıcı
  /// kimlik (`subject_id`) değil isim görmeli. Arşivlenmiş ders/konu da
  /// gelmeli — geçmiş oturum arşivleme yüzünden dosyadan düşemez.
  Future<List<SessionExportRow>> exportRows(DateTime from, DateTime to) async {
    final rows = await customSelect(
      '''
      SELECT ss.date_key, ss.started_at, ss.planned_duration_s,
             ss.actual_duration_s, ss.total_break_s, ss.question_count,
             ss.correct_count, ss.wrong_count, ss.empty_count, ss.net,
             ss.focus_score, ss.mood, ss.note, ss.status,
             s.name AS subject_name,
             t.name AS topic_name,
             a.name AS activity_name
      FROM study_sessions ss
      JOIN subjects s       ON s.id = ss.subject_id
      JOIN activity_types a ON a.id = ss.activity_type_id
      LEFT JOIN topics t    ON t.id = ss.topic_id
      WHERE ss.date_key >= ? AND ss.date_key <= ? AND ss.status != ?
      ORDER BY ss.started_at ASC
      ''',
      variables: [
        Variable<String>(dateKeyOf(from)),
        Variable<String>(dateKeyOf(to)),
        Variable<String>(SessionStatus.running.name),
      ],
      readsFrom: {
        studySessions,
        attachedDatabase.subjects,
        attachedDatabase.topics,
        attachedDatabase.activityTypes,
      },
    ).get();

    return rows
        .map(
          (r) => SessionExportRow(
            dateKey: r.read<String>('date_key'),
            startedAt:
                DateTime.fromMillisecondsSinceEpoch(r.read<int>('started_at')),
            subjectName: r.read<String>('subject_name'),
            topicName: r.read<String?>('topic_name'),
            activityTypeName: r.read<String>('activity_name'),
            plannedDurationS: r.read<int>('planned_duration_s'),
            actualDurationS: r.read<int>('actual_duration_s'),
            totalBreakS: r.read<int>('total_break_s'),
            questionCount: r.read<int>('question_count'),
            correctCount: r.read<int>('correct_count'),
            wrongCount: r.read<int>('wrong_count'),
            emptyCount: r.read<int>('empty_count'),
            net: r.read<double>('net'),
            focusScore: r.read<int?>('focus_score'),
            mood: r.read<int?>('mood'),
            note: r.read<String?>('note'),
            status: r.read<String>('status'),
          ),
        )
        .toList();
  }
}
