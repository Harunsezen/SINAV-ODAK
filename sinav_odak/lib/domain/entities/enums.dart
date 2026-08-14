/// Uygulama genelinde kullanılan sabit kümeler.
/// Drift bunları `textEnum<T>()` ile enum ADI olarak saklar; sıraları
/// değiştirmek güvenlidir, ADLARI değiştirmek migration gerektirir.
library;

enum ExamType { yks, lgs, kpss, ales, dgs, other }

enum SessionStatus {
  /// Çizelge devam ediyor (kurtarma bu duruma bakar).
  running,

  /// Tüm bloklar planlandığı gibi tamamlandı.
  completed,

  /// Kullanıcı "Oturumu Bitir" dedi.
  earlyFinished,

  /// Uygulama/telefon kapandı, oturum yarıda kaldı.
  interrupted,
}

enum BlockType { study, breakTime }

enum GoalType {
  dailyMinutes,
  weeklyMinutes,
  dailyQuestions,
  weeklyQuestions,
  subjectMinutes,
  topicCompletion,
  net,
  streak,
}

enum GoalStatus { active, completed, missed, archived }

/// Yanlış defteri kaydının yaşam döngüsü.
enum WrongItemStatus {
  /// Henüz üzerine çalışılmadı.
  active,

  /// Tekrar edildi ama pekişmedi.
  reviewed,

  /// Öğrenildi, listeden düşer.
  mastered,
}

/// Kaydın nereden geldiği.
enum WrongItemSource {
  /// Oturum sonu formunda wrong_count > 0 olduğu için otomatik oluştu.
  auto,

  /// Kullanıcı elle ekledi.
  manual,
}

enum ThemeModeSetting { system, light, dark }

enum AdKind { banner, native, interstitial, rewarded }

/// Banner'ın ekranda durduğu yer (FAZ 4.4).
///
/// Deneme amaçlı: hangi konumun daha az rahatsız ettiğini beta geri
/// bildirimiyle öğreneceğiz. Varsayılan **alt** — v1.0 davranışı.
enum BannerPosition {
  bottom,
  top,

  /// Yalnızca YATAY modda sol yarıya alınır; dikeyde alta düşer.
  sideLandscape,
}
