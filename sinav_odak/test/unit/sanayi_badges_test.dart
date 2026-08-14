import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/achievement_calculator.dart';

/// FAZ 2.2 — Sanayi Evreni rozetleri.
///
/// Dosya SAF DART test ediyor: rozet kuralları `AchievementCalculator`
/// içinde, Flutter'a dokunmadan.
void main() {
  AchievementMetrics m({
    int totalStudyS = 0,
    int totalQuestions = 0,
    int weekStudyS = 0,
    int prevWeekStudyS = 0,
    int? daysSinceLastSession,
  }) =>
      AchievementMetrics(
        totalStudyS: totalStudyS,
        totalQuestions: totalQuestions,
        weekStudyS: weekStudyS,
        prevWeekStudyS: prevWeekStudyS,
        daysSinceLastSession: daysSinceLastSession,
      );

  group('🏭 Sanayiden Kurtuldun', () {
    test('150 saatte açılıyor, 149 saatte açılmıyor', () {
      expect(
        AchievementCalculator.earned(m(totalStudyS: 150 * 3600)),
        contains('industry_escape'),
      );
      expect(
        AchievementCalculator.earned(m(totalStudyS: 149 * 3600 + 3599)),
        isNot(contains('industry_escape')),
      );
    });

    test('MERDİVEN: 100 saatte yalnızca hours_100, 150 saatte ikisi de', () {
      // Koordinatör kararı: önce teknik kademe, sonra hikâye rozeti.
      // İlk sürümde ikisi de 100 saatteydi ve aynı anda patlıyordu.
      // Bu test merdiveni KİLİTLİYOR — eşiklerden biri diğerine kayarsa
      // düşer.
      final at100 = AchievementCalculator.earned(m(totalStudyS: 100 * 3600));
      expect(at100, contains('hours_100'));
      expect(
        at100,
        isNot(contains('industry_escape')),
        reason: '100 saatte hikâye rozeti HENÜZ açılmamalı',
      );

      final at150 = AchievementCalculator.earned(m(totalStudyS: 150 * 3600));
      expect(at150, containsAll(['hours_100', 'industry_escape']));
    });
  });

  group('🔧 Şanzımanı İndir', () {
    test('sert düşüşte açılıyor (10sa -> 4sa)', () {
      expect(
        AchievementCalculator.earned(
          m(prevWeekStudyS: 10 * 3600, weekStudyS: 4 * 3600),
        ),
        contains('downshift'),
      );
    });

    test('küçük dalgalanma DÜŞÜŞ SAYILMIYOR (10sa -> 6sa)', () {
      expect(
        AchievementCalculator.earned(
          m(prevWeekStudyS: 10 * 3600, weekStudyS: 6 * 3600),
        ),
        isNot(contains('downshift')),
      );
    });

    test('önceki hafta zayıfsa açılmıyor (1sa -> 0)', () {
      // Koruma olmasaydı bir saatlik haftadan sıfıra düşen herkes rozet
      // alırdı — anlamsız olurdu.
      expect(
        AchievementCalculator.earned(m(prevWeekStudyS: 3600, weekStudyS: 0)),
        isNot(contains('downshift')),
      );
    });

    test('tam sınırda: 5sa -> 2sa açılıyor, 5sa -> 2.5sa açılmıyor', () {
      expect(
        AchievementCalculator.earned(
          m(prevWeekStudyS: 5 * 3600, weekStudyS: 2 * 3600),
        ),
        contains('downshift'),
      );
      expect(
        AchievementCalculator.earned(
          m(prevWeekStudyS: 5 * 3600, weekStudyS: 9000),
        ),
        isNot(contains('downshift')),
      );
    });
  });

  group('🔩 Mehmet Usta Seni Bekliyor', () {
    test('5 gün arada açılıyor, 4 günde açılmıyor', () {
      expect(
        AchievementCalculator.earned(m(daysSinceLastSession: 5)),
        contains('master_waits'),
      );
      expect(
        AchievementCalculator.earned(m(daysSinceLastSession: 4)),
        isNot(contains('master_waits')),
      );
    });

    test('İLK oturumda açılmıyor (öncesi yok)', () {
      // `daysSinceLastSession` null = ilk oturum. 0 kabul edilseydi sorun
      // olmazdı ama null'ı yanlışlıkla 0'a çevirmek ileride kolay bir hata;
      // bu test onu kilitliyor.
      expect(
        AchievementCalculator.earned(m()),
        isNot(contains('master_waits')),
      );
    });
  });

  group('🏆 15.000 Soru', () {
    test('15000\'de açılıyor, 14999\'da açılmıyor', () {
      expect(
        AchievementCalculator.earned(m(totalQuestions: 15000)),
        contains('questions_15000'),
      );
      expect(
        AchievementCalculator.earned(m(totalQuestions: 14999)),
        isNot(contains('questions_15000')),
      );
    });
  });

  test('rozet kodları BENZERSİZ ve katalog 16 rozet', () {
    final codes = [for (final d in AchievementCalculator.catalog) d.code];
    expect(codes.toSet().length, codes.length, reason: 'kod tekrarı var');
    // 11 (v1.0) + 4 (Sanayi Evreni) + 1 (balto_friend, FAZ 4.3).
    expect(codes.length, 16);
  });

  test('açılmış rozet TEKRAR açılmıyor', () {
    final newly = AchievementCalculator.evaluate(
      metrics: m(totalQuestions: 15000),
      already: {'questions_15000'},
    );
    expect(newly, isNot(contains('questions_15000')));
  });
}
