// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

/// Rozet kazanımının değerlendirileceği anlık ölçümler.
///
/// Hangi pencerenin toplamı olduğu **çağıranın** sorumluluğu; bu dosya
/// yalnızca "hangi ölçüm hangi rozeti açar" kuralını bilir.
class AchievementMetrics {
  const AchievementMetrics({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalSessions = 0,
    this.totalStudyS = 0,
    this.totalQuestions = 0,
    this.daySessionCount = 0,
    this.dayStudyS = 0,
    this.dayFocusScore = 0,
    this.startHour,
    this.weekStudyS = 0,
    this.prevWeekStudyS = 0,
    this.daysSinceLastSession,
  });

  final int currentStreak;
  final int longestStreak;

  /// Tüm zamanların toplamları.
  final int totalSessions;
  final int totalStudyS;
  final int totalQuestions;

  /// Değerlendirilen GÜNE ait ölçümler.
  final int daySessionCount;
  final int dayStudyS;

  /// O günün ortalama odak puanı (0..100).
  final double dayFocusScore;

  /// Son biten oturumun başlangıç saati (0..23). Gece/sabah rozetleri için.
  final int? startHour;

  /// Bu haftanın ve bir önceki haftanın toplam çalışma süresi.
  /// "Şanzımanı İndir" düşüşü bu ikisinin oranından çıkıyor.
  final int weekStudyS;
  final int prevWeekStudyS;

  /// Bu oturumdan ÖNCEKİ son çalışma gününden bu yana geçen gün sayısı.
  ///
  /// `null` = ilk oturum (öncesi yok). Sıfır olsaydı "5 gün ara verdin"
  /// rozeti ilk oturumda yanlışlıkla değerlendirilirdi.
  final int? daysSinceLastSession;
}

/// Tek bir rozetin tanımı.
///
/// [code] veritabanına yazılan **sabit** koddur; asla değiştirilmez —
/// değiştirilirse kullanıcı daha önce açtığı rozeti kaybeder.
class AchievementDef {
  const AchievementDef({
    required this.code,
    required this.iconKey,
    required this.test,
  });

  final String code;

  /// Materyal ikon ADI (string). `IconData` sabit olmadığında
  /// `--tree-shake-icons` derlemesi kırılıyor — bu yüzden string.
  final String iconKey;

  /// Ölçümler bu rozeti açıyor mu?
  final bool Function(AchievementMetrics m) test;
}

/// Rozet kataloğu ve kazanım hesabı.
///
/// **Neden saf Dart?** `achievements` tablosu Adım 1'den beri şemada
/// duruyordu ama **yazan kod yoktu** — tablo sonsuza kadar boş kalıyordu.
/// `streak` ve `goals` ile aynı hikâye; çözüm de aynı desen: hesap saf,
/// yazma `SessionRepository.save()` yolunda.
///
/// **Rozetler geri ALINMAZ.** Bir kez açılan rozet, sonradan seri bozulsa
/// bile kayıtlı kalır: kazanılmış bir başarıyı geri almak cezalandırma
/// olurdu. Bu yüzden [evaluate] yalnızca "yeni açılanları" döner, kapatma
/// diye bir kavram yok.
abstract final class AchievementCalculator {
  /// Rozet kataloğu. Kodlar sabittir.
  static const List<AchievementDef> catalog = [
    // --- Seri ---
    AchievementDef(
      code: 'streak_3',
      iconKey: 'local_fire_department',
      test: _streak3,
    ),
    AchievementDef(
      code: 'streak_7',
      iconKey: 'local_fire_department',
      test: _streak7,
    ),
    AchievementDef(
      code: 'streak_30',
      iconKey: 'whatshot',
      test: _streak30,
    ),

    // --- Toplam çalışma ---
    AchievementDef(
      code: 'first_session',
      iconKey: 'flag',
      test: _firstSession,
    ),
    AchievementDef(
      code: 'hours_10',
      iconKey: 'schedule',
      test: _hours10,
    ),
    AchievementDef(
      code: 'hours_100',
      iconKey: 'military_tech',
      test: _hours100,
    ),

    // --- Soru ---
    AchievementDef(
      code: 'questions_1000',
      iconKey: 'quiz',
      test: _questions1000,
    ),

    // --- Tek gün ---
    AchievementDef(
      code: 'marathon_day',
      iconKey: 'directions_run',
      test: _marathonDay,
    ),
    AchievementDef(
      code: 'focus_90',
      iconKey: 'center_focus_strong',
      test: _focus90,
    ),
    AchievementDef(
      code: 'early_bird',
      iconKey: 'wb_twilight',
      test: _earlyBird,
    ),
    AchievementDef(
      code: 'night_owl',
      iconKey: 'nightlight',
      test: _nightOwl,
    ),

    // --- SANAYİ EVRENİ (v1.1 / FAZ 2.2) ---
    //
    // Balto'nun sesi: sanayide çırak olmakla sınava çalışmak arasındaki
    // espri. Kodlar sabit; metinler ARB'de.
    AchievementDef(
      code: 'industry_escape',
      iconKey: 'factory',
      test: _industryEscape,
    ),
    AchievementDef(
      code: 'downshift',
      iconKey: 'build',
      test: _downshift,
    ),
    AchievementDef(
      code: 'master_waits',
      iconKey: 'hardware',
      test: _masterWaits,
    ),
    AchievementDef(
      code: 'questions_15000',
      // 'emoji_events' DEĞİL: o, eşleşmeyen anahtarların düştüğü
      // VARSAYILAN. Gerçek bir rozet onu kullanırsa "ikon eşleşiyor mu"
      // bekçisi anlamını yitirirdi.
      iconKey: 'workspace_premium',
      test: _questions15000,
    ),
  ];

  // Testler ayrı fonksiyon: `catalog` const olabilsin diye (kapanış
  // ifadeleri const bağlamda kullanılamıyor).
  static bool _streak3(AchievementMetrics m) => m.currentStreak >= 3;
  static bool _streak7(AchievementMetrics m) => m.currentStreak >= 7;
  static bool _streak30(AchievementMetrics m) => m.currentStreak >= 30;

  static bool _firstSession(AchievementMetrics m) => m.totalSessions >= 1;
  static bool _hours10(AchievementMetrics m) => m.totalStudyS >= 10 * 3600;
  static bool _hours100(AchievementMetrics m) => m.totalStudyS >= 100 * 3600;

  static bool _questions1000(AchievementMetrics m) => m.totalQuestions >= 1000;

  /// Tek günde 6 saat net çalışma.
  static bool _marathonDay(AchievementMetrics m) => m.dayStudyS >= 6 * 3600;

  /// Günün ortalama odak puanı 90+.
  ///
  /// `daySessionCount > 0` şartı kritik: hiç oturum yokken `avgFocusScore`
  /// 0 gelir ama tek bir kötü okuma 90'ı geçerse rozet bedava açılırdı.
  static bool _focus90(AchievementMetrics m) =>
      m.daySessionCount > 0 && m.dayFocusScore >= 90;

  /// Sabah 06:00–08:00 arasında başlayan oturum.
  static bool _earlyBird(AchievementMetrics m) {
    final h = m.startHour;
    return h != null && h >= 6 && h < 8;
  }

  /// Gece 00:00–04:00 arasında başlayan oturum.
  static bool _nightOwl(AchievementMetrics m) {
    final h = m.startHour;
    return h != null && h >= 0 && h < 4;
  }

  // --- Sanayi Evreni ---

  /// 🏭 Sanayiden Kurtuldun — toplam 100 saat.
  ///
  /// **DİKKAT:** `hours_100` ile AYNI eşikte. İkisi birlikte açılıyor;
  /// bilinçli bir ürün kararı olarak bırakıldı (biri sayısal kademe, biri
  /// Balto rozeti) ama toast sistemi ikisini üst üste gösterecek şekilde
  /// kuyruğa alıyor. Bkz. UX_REVIEW FAZ 2 §2.2.
  static bool _industryEscape(AchievementMetrics m) =>
      m.totalStudyS >= 100 * 3600;

  /// 🔧 Şanzımanı İndir — haftalık performans DÜŞÜŞÜ.
  ///
  /// Bu bir ödül değil, dostça bir dürtme. İki koruma var:
  /// - Önceki hafta anlamlı olmalı (≥5 saat). Yoksa bir saatlik haftadan
  ///   yarım saatlik haftaya düşen herkes rozet alırdı.
  /// - Düşüş sert olmalı (yarıdan aşağı). Küçük dalgalanma düşüş değildir.
  static bool _downshift(AchievementMetrics m) =>
      m.prevWeekStudyS >= 5 * 3600 && m.weekStudyS * 2 < m.prevWeekStudyS;

  /// 🔩 Mehmet Usta Seni Bekliyor — 5+ gün ara verip GERİ DÖNDÜN.
  ///
  /// Rozetler yalnızca oturum kaydedilirken değerlendiriliyor; yani bu
  /// rozet "ara verdiğin an" değil, **döndüğün an** açılıyor. Mesajın
  /// anlamı da bu: tezgâh seni bekliyordu, geldin.
  static bool _masterWaits(AchievementMetrics m) {
    final d = m.daysSinceLastSession;
    return d != null && d >= 5;
  }

  /// 🏆 15.000 Soru.
  static bool _questions15000(AchievementMetrics m) =>
      m.totalQuestions >= 15000;

  /// [m] ile açılması gereken rozet kodları.
  static Set<String> earned(AchievementMetrics m) => {
        for (final d in catalog)
          if (d.test(m)) d.code,
      };

  /// [already] açılmışken [m] ile **YENİ** açılan rozetler.
  ///
  /// Zaten açık olanlar dışarıda bırakılıyor: aksi halde her oturum kaydında
  /// aynı rozet yeniden yazılır ve `unlockedAt` sürekli güncellenirdi —
  /// kullanıcı "10 saat" rozetini 300. saatte kazanmış görünürdü.
  static Set<String> evaluate({
    required AchievementMetrics metrics,
    required Set<String> already,
  }) =>
      earned(metrics).difference(already);

  static AchievementDef? byCode(String code) {
    for (final d in catalog) {
      if (d.code == code) return d;
    }
    return null;
  }
}
