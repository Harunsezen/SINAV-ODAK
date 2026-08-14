// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod, pdf paketi import etmez.

/// Raporun kime gösterileceği.
///
/// **Neden iki ayrı rapor:** veliye "çocuğun ne kadar çalıştı" yeter ve
/// gurur veren bir özet ister; eğitimciye zayıf konu listesi, ders
/// dağılımı ve odak eğilimi lazım. Tek bir rapor ikisini de kötü yapardı.
enum ReportAudience {
  /// Veli — tek sayfa, gurur tablosu, jargon yok.
  parent,

  /// Eğitimci — çok sayfa, analitik, zayıf konular.
  teacher,
}

/// Rapordaki bir ders satırı.
class ReportSubjectLine {
  const ReportSubjectLine({
    required this.name,
    required this.studyS,
    required this.questionCount,
    required this.net,
    required this.share,
  });

  final String name;
  final int studyS;
  final int questionCount;
  final double net;

  /// Toplam süre içindeki payı (0..1).
  final double share;
}

/// Bir günün toplamı (grafik ve tablo için).
class ReportDayLine {
  const ReportDayLine({required this.dateKey, required this.studyS});

  final String dateKey;
  final int studyS;
}

/// Gelişim gereken konu (yalnızca eğitimci raporunda).
class ReportWeakTopic {
  const ReportWeakTopic({
    required this.topicName,
    required this.subjectName,
    required this.wrongCount,
  });

  final String topicName;
  final String subjectName;
  final int wrongCount;
}

/// PDF'e dökülecek her şey — **hesaplanmış**, biçimlenmemiş.
///
/// Biçimleme (tarih formatı, "2 sa 30 dk" gibi) sunum katmanının işi;
/// burada ham sayılar duruyor ki hesap testlerde saf Dart'la
/// doğrulanabilsin.
class ReportData {
  const ReportData({
    required this.audience,
    required this.fromKey,
    required this.toKey,
    required this.totalStudyS,
    required this.sessionCount,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.emptyCount,
    required this.net,
    required this.avgFocusScore,
    required this.currentStreak,
    required this.longestStreak,
    required this.achievementCount,
    required this.subjects,
    required this.days,
    required this.weakTopics,
  });

  final ReportAudience audience;
  final String fromKey;
  final String toKey;

  final int totalStudyS;
  final int sessionCount;
  final int questionCount;
  final int correctCount;
  final int wrongCount;
  final int emptyCount;
  final double net;
  final double avgFocusScore;

  final int currentStreak;
  final int longestStreak;
  final int achievementCount;

  final List<ReportSubjectLine> subjects;
  final List<ReportDayLine> days;
  final List<ReportWeakTopic> weakTopics;

  /// Hiç oturum yoksa rapor üretmenin anlamı yok.
  bool get isEmpty => sessionCount == 0;

  /// Doğru / (doğru+yanlış) — boşlar hariç. Veri yoksa 0.
  ///
  /// **Boşlar neden hariç:** "başarı" bilinen soruların doğruluk oranı.
  /// Boşları paydaya katmak, temkinli davranıp boş bırakan öğrenciyi
  /// cezalandırırdı.
  double get successRate {
    final answered = correctCount + wrongCount;
    if (answered == 0) return 0;
    return correctCount / answered;
  }

  /// Rapor kaç günü kapsıyor (dahil).
  int get dayCount => days.length;

  /// Çalışılan gün sayısı (süresi sıfır olmayanlar).
  int get activeDayCount => days.where((d) => d.studyS > 0).length;

  /// Günlük ortalama — **çalışılan günlere** bölünür, takvim gününe değil.
  ///
  /// Takvim gününe bölmek, hafta sonu dinlenen öğrencinin ortalamasını
  /// düşürüp raporu haksızca kötü gösterirdi.
  int get avgStudyPerActiveDayS =>
      activeDayCount == 0 ? 0 : totalStudyS ~/ activeDayCount;

  /// Aralıktaki en uzun çalışılan günün süresi.
  int get bestDayS => days.isEmpty
      ? 0
      : days.map((d) => d.studyS).reduce((a, b) => a > b ? a : b);

  /// En uzun çalışılan **günün kendisi**; hiç çalışma yoksa `null`.
  ///
  /// **Neden gerekli:** rapordaki etiket "En iyi gün" diyor ama yalnızca
  /// [bestDayS] basılırsa okuyan bir süre görüyor, gün göremiyor —
  /// "1 sa 30 dk" hangi gündü? Eğitimci o günü takvimle eşleştiremiyor.
  /// Eşitlikte ilk gün kazanır (aralık zaten kronolojik).
  String? get bestDayKey {
    ReportDayLine? best;
    for (final d in days) {
      if (d.studyS <= 0) continue;
      if (best == null || d.studyS > best.studyS) best = d;
    }
    return best?.dateKey;
  }
}
