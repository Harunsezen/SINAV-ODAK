import '../../core/utils/date_key.dart';
import '../../data/local/database.dart';
import '../../domain/entities/report_data.dart';

/// Bir tarih aralığı için rapor verisini toplar (FAZ 3.1).
///
/// **Neden ayrı use-case:** PDF çizimi (`PdfReportBuilder`) yalnızca
/// biçimlendirme yapıyor; "hangi sayı nereden geliyor" kararı burada.
/// Böylece rapor içeriği PDF paketine dokunmadan test edilebiliyor.
///
/// **Hiçbir ağ çağrısı yok.** Tüm veri cihazdaki SQLite'tan; raporun
/// altındaki gizlilik kaşesi bu yüzden doğru bir ifade.
class BuildReportUseCase {
  const BuildReportUseCase(this._db);

  final AppDatabase _db;

  Future<ReportData> call({
    required ReportAudience audience,
    required DateTime from,
    required DateTime to,
  }) async {
    final summary = await _db.statsDao.summaryFor(from, to);
    final breakdown = await _db.statsDao.subjectBreakdown(from, to);
    final settings = await _db.settingsDao.ensure();
    final achievements = await _db.achievementDao.unlockedCodes();

    // Zayıf konular YALNIZCA eğitimci raporunda.
    //
    // Veliye "çocuğunuzun en kötü olduğu 10 konu" listesi göndermek,
    // uygulamanın amacının (öğrenciyi motive etmek) tam tersi olurdu.
    // Bu, biçim değil **içerik** kararı; o yüzden burada, PDF katmanında
    // değil.
    final weak = audience == ReportAudience.teacher
        ? await _db.statsDao.weakestTopics(from, to)
        : const <({String topicName, String subjectName, int wrongCount})>[];

    // Günlük döküm: aralıktaki HER gün, çalışılmayanlar 0 ile.
    // Eksik günleri atlamak grafikte yanıltıcı bir süreklilik yaratırdı.
    final days = <ReportDayLine>[];
    for (final key in dateKeyRange(from, to)) {
      final d = dateKeyToLocal(key);
      final dayStats = await _db.statsDao.summaryFor(d, d);
      days.add(ReportDayLine(dateKey: key, studyS: dayStats.totalStudyS));
    }

    final total = summary.totalStudyS;
    return ReportData(
      audience: audience,
      fromKey: dateKeyOf(from),
      toKey: dateKeyOf(to),
      totalStudyS: total,
      sessionCount: summary.sessionCount,
      questionCount: summary.questionCount,
      correctCount: summary.correctCount,
      wrongCount: summary.wrongCount,
      emptyCount: summary.emptyCount,
      net: summary.net,
      avgFocusScore: summary.avgFocusScore,
      currentStreak: settings.currentStreak,
      longestStreak: settings.longestStreak,
      achievementCount: achievements.length,
      subjects: [
        for (final b in breakdown)
          ReportSubjectLine(
            name: b.subjectName,
            studyS: b.studyS,
            questionCount: b.questionCount,
            net: b.net,
            share: total == 0 ? 0 : b.studyS / total,
          ),
      ],
      days: days,
      weakTopics: [
        for (final w in weak)
          ReportWeakTopic(
            topicName: w.topicName,
            subjectName: w.subjectName,
            wrongCount: w.wrongCount,
          ),
      ],
    );
  }
}
