// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

/// Streak hesabının sonucu.
class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastStudyDate,
  });

  final int currentStreak;
  final int longestStreak;

  /// 'YYYY-MM-DD' — en son çalışılan gün.
  final String? lastStudyDate;

  @override
  bool operator ==(Object other) =>
      other is StreakResult &&
      other.currentStreak == currentStreak &&
      other.longestStreak == longestStreak &&
      other.lastStudyDate == lastStudyDate;

  @override
  int get hashCode => Object.hash(currentStreak, longestStreak, lastStudyDate);

  @override
  String toString() =>
      'StreakResult(current: $currentStreak, longest: $longestStreak, '
      'last: $lastStudyDate)';
}

/// Ardışık çalışma günü (streak) hesabı.
///
/// **Neden saf Dart?** Şemada `currentStreak`, `longestStreak` ve
/// `lastStudyDate` kolonları Adım 1'den beri duruyordu ama **yazan kod
/// yoktu** — üç kolon da hep 0/null kalıyordu. Hesabı Flutter ve Drift'ten
/// bağımsız tutmak, gece yarısı ve saat değişimi gibi ancak testle
/// yakalanabilen kenar durumların kilitlenebilmesini sağlıyor.
///
/// **Girdi `dateKey` (YYYY-MM-DD) metnidir, zaman damgası değil.** Streak
/// "kaç GÜN üst üste" sorusudur; saat/dakika bilgisiyle uğraşmak yaz saati
/// geçişlerinde bir günü 23 veya 25 saat yapıp hesabı bozardı. Gün anahtarı
/// `dateKeyOf` ile yerel güne göre üretilir (G9).
abstract final class StreakCalculator {
  /// Yeni bir çalışma günü kaydedildiğinde streak'i günceller.
  ///
  /// [studyDate] kaydedilen oturumun gün anahtarı (oturumun BAŞLADIĞI gün).
  /// [lastStudyDate] daha önce çalışılan son gün; hiç yoksa `null`.
  ///
  /// Kurallar:
  /// - İlk kayıt → streak 1
  /// - Aynı gün ikinci oturum → streak DEĞİŞMEZ (gün başına bir kez sayılır)
  /// - Dün çalışılmış → streak + 1
  /// - Arada boş gün var → streak 1'e döner (zincir koptu)
  /// - [studyDate] geçmişte kalıyorsa (saat geri alınmış, geçmiş oturum
  ///   düzenlenmiş) → mevcut streak KORUNUR, `lastStudyDate` ileri
  ///   tarihte kalır
  static StreakResult onStudyDay({
    required String studyDate,
    required String? lastStudyDate,
    required int currentStreak,
    required int longestStreak,
  }) {
    // İlk çalışma günü.
    if (lastStudyDate == null || currentStreak <= 0) {
      return StreakResult(
        currentStreak: 1,
        longestStreak: longestStreak < 1 ? 1 : longestStreak,
        lastStudyDate: studyDate,
      );
    }

    // Aynı gün tekrar kaydedildi: streak gün başına bir kez artar.
    if (studyDate == lastStudyDate) {
      return StreakResult(
        currentStreak: currentStreak,
        longestStreak:
            longestStreak < currentStreak ? currentStreak : longestStreak,
        lastStudyDate: lastStudyDate,
      );
    }

    final gap = _dayGap(lastStudyDate, studyDate);

    // Geçmişe dönük kayıt (saat geri alınmış veya eski oturum düzenlenmiş).
    // Zinciri ne uzatır ne kırar; en ileri tarih korunur.
    if (gap <= 0) {
      return StreakResult(
        currentStreak: currentStreak,
        longestStreak:
            longestStreak < currentStreak ? currentStreak : longestStreak,
        lastStudyDate: lastStudyDate,
      );
    }

    // Dün çalışılmışsa zincir uzar; aksi halde bugünden yeniden başlar.
    final next = gap == 1 ? currentStreak + 1 : 1;

    return StreakResult(
      currentStreak: next,
      longestStreak: longestStreak < next ? next : longestStreak,
      lastStudyDate: studyDate,
    );
  }

  /// Streak'in [today] itibarıyla hâlâ canlı olup olmadığı.
  ///
  /// Ana panelde gösterim için: dün veya bugün çalışılmışsa zincir canlıdır.
  /// Daha eskiyse kullanıcıya 0 gösterilir — DB'deki değer, kullanıcı yeniden
  /// çalışana kadar dokunulmadan kalır (yazma yolu yalnızca kayıt anıdır).
  static int displayStreak({
    required String? lastStudyDate,
    required int currentStreak,
    required String today,
  }) {
    if (lastStudyDate == null || currentStreak <= 0) return 0;
    final gap = _dayGap(lastStudyDate, today);
    if (gap < 0) return currentStreak; // saat geri alınmış
    return gap <= 1 ? currentStreak : 0;
  }

  /// İki gün anahtarı arasındaki tam gün farkı ([from] → [to]).
  ///
  /// `DateTime.difference` yerine **UTC'ye sabitlenmiş** tarihler kullanılıyor:
  /// yaz saati geçişinde yerel gün 23 veya 25 saat sürer ve `inDays` bir
  /// günü yutabilir. Gün anahtarı zaten yerel güne göre üretildiği için
  /// burada yalnızca takvim farkı gerekiyor.
  static int _dayGap(String from, String to) {
    final a = _parse(from);
    final b = _parse(to);
    if (a == null || b == null) return 0;
    return b.difference(a).inDays;
  }

  static DateTime? _parse(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime.utc(y, m, d);
  }
}
