import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/achievement_calculator.dart';

/// FAZ 7B — Rozet hesabı (saf domain).
void main() {
  AchievementMetrics m({
    int currentStreak = 0,
    int longestStreak = 0,
    int totalSessions = 0,
    int totalStudyS = 0,
    int totalQuestions = 0,
    int daySessionCount = 0,
    int dayStudyS = 0,
    double dayFocusScore = 0,
    int? startHour,
  }) =>
      AchievementMetrics(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalSessions: totalSessions,
        totalStudyS: totalStudyS,
        totalQuestions: totalQuestions,
        daySessionCount: daySessionCount,
        dayStudyS: dayStudyS,
        dayFocusScore: dayFocusScore,
        startHour: startHour,
      );

  group('katalog', () {
    test('en az 6 rozet tanımlı', () {
      expect(AchievementCalculator.catalog.length, greaterThanOrEqualTo(6));
    });

    test('kodlar BENZERSİZ', () {
      final codes = AchievementCalculator.catalog.map((d) => d.code).toList();
      expect(
        codes.toSet().length,
        codes.length,
        reason: 'aynı kod iki rozete verilirse biri asla açılmaz',
      );
    });

    test('byCode tanımı buluyor', () {
      expect(AchievementCalculator.byCode('streak_7')?.iconKey, isNotNull);
      expect(AchievementCalculator.byCode('yok_boyle_bir_kod'), isNull);
    });

    test('boş ölçümde HİÇBİR rozet açılmıyor', () {
      expect(AchievementCalculator.earned(m()), isEmpty);
    });
  });

  group('seri rozetleri', () {
    test('3 gün -> streak_3', () {
      expect(
        AchievementCalculator.earned(m(currentStreak: 3)),
        contains('streak_3'),
      );
    });

    test('2 gün -> streak_3 YOK', () {
      expect(
        AchievementCalculator.earned(m(currentStreak: 2)),
        isNot(contains('streak_3')),
      );
    });

    test('7 gün -> streak_3 ve streak_7 birlikte', () {
      final e = AchievementCalculator.earned(m(currentStreak: 7));
      expect(e, containsAll(['streak_3', 'streak_7']));
      expect(e, isNot(contains('streak_30')));
    });

    test('30 gün -> üçü birden', () {
      expect(
        AchievementCalculator.earned(m(currentStreak: 30)),
        containsAll(['streak_3', 'streak_7', 'streak_30']),
      );
    });
  });

  group('toplam rozetleri', () {
    test('ilk oturum', () {
      expect(
        AchievementCalculator.earned(m(totalSessions: 1)),
        contains('first_session'),
      );
    });

    test('10 saat sınırı TAM değerde açılıyor', () {
      expect(
        AchievementCalculator.earned(m(totalStudyS: 10 * 3600)),
        contains('hours_10'),
        reason: 'tam 10 saat çalışana "olmadı" demek yanlış',
      );
    });

    test('9 sa 59 dk -> hours_10 YOK', () {
      expect(
        AchievementCalculator.earned(m(totalStudyS: 10 * 3600 - 60)),
        isNot(contains('hours_10')),
      );
    });

    test('100 saat -> hours_10 da açık', () {
      expect(
        AchievementCalculator.earned(m(totalStudyS: 100 * 3600)),
        containsAll(['hours_10', 'hours_100']),
      );
    });

    test('1000 soru', () {
      expect(
        AchievementCalculator.earned(m(totalQuestions: 1000)),
        contains('questions_1000'),
      );
      expect(
        AchievementCalculator.earned(m(totalQuestions: 999)),
        isNot(contains('questions_1000')),
      );
    });
  });

  group('tek gün rozetleri', () {
    test('6 saat -> maraton', () {
      expect(
        AchievementCalculator.earned(m(dayStudyS: 6 * 3600)),
        contains('marathon_day'),
      );
    });

    test('odak 90 + oturum var -> focus_90', () {
      expect(
        AchievementCalculator.earned(m(daySessionCount: 1, dayFocusScore: 90)),
        contains('focus_90'),
      );
    });

    test('oturum YOKKEN odak puanı rozeti AÇMIYOR', () {
      // `avgFocusScore` oturum yokken anlamsız; bedava rozet olurdu.
      expect(
        AchievementCalculator.earned(
          m(daySessionCount: 0, dayFocusScore: 100),
        ),
        isNot(contains('focus_90')),
      );
    });

    test('odak 89 -> rozet YOK', () {
      expect(
        AchievementCalculator.earned(m(daySessionCount: 2, dayFocusScore: 89)),
        isNot(contains('focus_90')),
      );
    });
  });

  group('saat rozetleri', () {
    test('07:00 -> erken kuş', () {
      expect(
        AchievementCalculator.earned(m(startHour: 7)),
        contains('early_bird'),
      );
    });

    test('08:00 -> erken kuş YOK (aralık dışı)', () {
      expect(
        AchievementCalculator.earned(m(startHour: 8)),
        isNot(contains('early_bird')),
      );
    });

    test('01:00 -> gece kuşu', () {
      expect(
        AchievementCalculator.earned(m(startHour: 1)),
        contains('night_owl'),
      );
    });

    test('04:00 -> gece kuşu YOK', () {
      expect(
        AchievementCalculator.earned(m(startHour: 4)),
        isNot(contains('night_owl')),
      );
    });

    test('saat bilinmiyorsa saat rozeti YOK', () {
      final e = AchievementCalculator.earned(m(totalSessions: 1));
      expect(e, isNot(contains('early_bird')));
      expect(e, isNot(contains('night_owl')));
    });
  });

  group('evaluate — yalnızca YENİ açılanlar', () {
    test('zaten açık rozet tekrar dönmüyor', () {
      final newly = AchievementCalculator.evaluate(
        metrics: m(currentStreak: 7),
        already: {'streak_3'},
      );
      expect(newly, contains('streak_7'));
      expect(
        newly,
        isNot(contains('streak_3')),
        reason: 'her kayıtta yeniden yazılsa unlockedAt sürekli güncellenirdi',
      );
    });

    test('hepsi açıksa boş dönüyor', () {
      expect(
        AchievementCalculator.evaluate(
          metrics: m(currentStreak: 30),
          already: {'streak_3', 'streak_7', 'streak_30'},
        ),
        isEmpty,
      );
    });

    test('rozet GERİ ALINMIYOR: seri bozulsa da hesap kapatma önermiyor', () {
      // Seri 0'a düştü ama kullanıcı streak_7'yi daha önce açmıştı.
      // `evaluate` yalnızca eklenecekleri döner — çıkarma diye bir kavram yok.
      final newly = AchievementCalculator.evaluate(
        metrics: m(currentStreak: 0),
        already: {'streak_7'},
      );
      expect(newly, isEmpty);
    });
  });
}
