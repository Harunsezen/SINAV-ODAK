import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/streak_calculator.dart';

/// FAZ 5 — Ardışık çalışma günü (streak).
///
/// Şemadaki üç kolon (`currentStreak`, `longestStreak`, `lastStudyDate`)
/// Adım 1'den beri duruyordu ama yazan kod yoktu. Bu dosya hesabın gece
/// yarısı, boş gün ve saat geri alma senaryolarındaki davranışını kilitler.
void main() {
  StreakResult run({
    required String day,
    String? last,
    int current = 0,
    int longest = 0,
  }) =>
      StreakCalculator.onStudyDay(
        studyDate: day,
        lastStudyDate: last,
        currentStreak: current,
        longestStreak: longest,
      );

  group('ilk kayıt', () {
    test('hiç çalışılmamışsa streak 1', () {
      final r = run(day: '2025-08-06');
      expect(r.currentStreak, 1);
      expect(r.longestStreak, 1);
      expect(r.lastStudyDate, '2025-08-06');
    });

    test('lastStudyDate var ama streak 0 ise yeniden 1', () {
      // Zincir daha önce kopmuş ve sıfırlanmış olabilir.
      final r = run(day: '2025-08-06', last: '2025-07-01', longest: 9);
      expect(r.currentStreak, 1);
      expect(r.longestStreak, 9, reason: 'rekor korunur');
    });
  });

  group('aynı gün', () {
    test('ikinci oturum streak\'i ARTIRMIYOR', () {
      final r = run(day: '2025-08-06', last: '2025-08-06', current: 3, longest: 5);
      expect(r.currentStreak, 3);
      expect(r.lastStudyDate, '2025-08-06');
    });

    test('aynı gün tekrarında rekor gerideyse güncelleniyor', () {
      final r = run(day: '2025-08-06', last: '2025-08-06', current: 7, longest: 2);
      expect(r.longestStreak, 7);
    });
  });

  group('GECE YARISI geçişi — ardışık gün', () {
    test('dün çalışılmışsa streak +1', () {
      final r = run(day: '2025-08-07', last: '2025-08-06', current: 3, longest: 5);
      expect(r.currentStreak, 4);
      expect(r.lastStudyDate, '2025-08-07');
    });

    test('ay sınırı: 31 Temmuz -> 1 Ağustos ardışık sayılıyor', () {
      final r = run(day: '2025-08-01', last: '2025-07-31', current: 2);
      expect(r.currentStreak, 3);
    });

    test('yıl sınırı: 31 Aralık -> 1 Ocak ardışık sayılıyor', () {
      final r = run(day: '2026-01-01', last: '2025-12-31', current: 10, longest: 10);
      expect(r.currentStreak, 11);
      expect(r.longestStreak, 11);
    });

    test('artık yıl: 28 Şubat -> 29 Şubat ardışık sayılıyor', () {
      final r = run(day: '2024-02-29', last: '2024-02-28', current: 4);
      expect(r.currentStreak, 5);
    });

    test('yaz saati geçiş haftası ardışıklığı bozmuyor', () {
      // TR'de yaz saati kalktı ama kural genel: gün anahtarı üzerinden
      // hesaplandığı için 23/25 saatlik günler etkilemiyor.
      final r = run(day: '2025-03-31', last: '2025-03-30', current: 6);
      expect(r.currentStreak, 7);
    });
  });

  group('BOŞ GÜN — zincir kopması', () {
    test('bir gün atlanırsa streak 1\'e döner', () {
      final r = run(day: '2025-08-08', last: '2025-08-06', current: 9, longest: 9);
      expect(r.currentStreak, 1, reason: '07 boş geçti');
      expect(r.longestStreak, 9, reason: 'rekor SİLİNMEZ');
    });

    test('uzun aradan sonra streak 1', () {
      final r = run(day: '2025-09-20', last: '2025-08-06', current: 12, longest: 12);
      expect(r.currentStreak, 1);
      expect(r.longestStreak, 12);
    });

    test('rekor yalnızca aşıldığında güncelleniyor', () {
      final r = run(day: '2025-08-07', last: '2025-08-06', current: 5, longest: 5);
      expect(r.currentStreak, 6);
      expect(r.longestStreak, 6);
    });
  });

  group('SAAT GERİ ALMA / geçmişe dönük kayıt', () {
    test('geçmiş bir güne kayıt zinciri BOZMUYOR', () {
      final r = run(day: '2025-08-04', last: '2025-08-06', current: 5, longest: 5);
      expect(r.currentStreak, 5, reason: 'ne artar ne sıfırlanır');
      expect(
        r.lastStudyDate,
        '2025-08-06',
        reason: 'en ileri tarih korunur; aksi halde ertesi gün zincir kopardı',
      );
    });

    test('geçmişe kayıt rekoru düşürmüyor', () {
      final r = run(day: '2025-01-01', last: '2025-08-06', current: 3, longest: 20);
      expect(r.longestStreak, 20);
    });

    test('bozuk gün anahtarı çökertmiyor', () {
      final r = run(day: 'bozuk', last: '2025-08-06', current: 4, longest: 8);
      expect(r.currentStreak, 4);
      expect(r.longestStreak, 8);
    });
  });

  group('displayStreak — ana panelde gösterim', () {
    test('bugün çalışılmışsa zincir canlı', () {
      expect(
        StreakCalculator.displayStreak(
          lastStudyDate: '2025-08-06',
          currentStreak: 4,
          today: '2025-08-06',
        ),
        4,
      );
    });

    test('dün çalışılmışsa zincir HÂLÂ canlı (bugün henüz başlamadı)', () {
      expect(
        StreakCalculator.displayStreak(
          lastStudyDate: '2025-08-06',
          currentStreak: 4,
          today: '2025-08-07',
        ),
        4,
      );
    });

    test('iki gün geçmişse 0 gösteriliyor', () {
      expect(
        StreakCalculator.displayStreak(
          lastStudyDate: '2025-08-06',
          currentStreak: 4,
          today: '2025-08-08',
        ),
        0,
      );
    });

    test('hiç çalışılmamışsa 0', () {
      expect(
        StreakCalculator.displayStreak(
          lastStudyDate: null,
          currentStreak: 0,
          today: '2025-08-06',
        ),
        0,
      );
    });

    test('saat geri alınmışsa mevcut değer korunuyor', () {
      expect(
        StreakCalculator.displayStreak(
          lastStudyDate: '2025-08-06',
          currentStreak: 4,
          today: '2025-08-01',
        ),
        4,
      );
    });
  });

  test('StreakResult eşitliği değer bazlı', () {
    const a = StreakResult(
      currentStreak: 3,
      longestStreak: 5,
      lastStudyDate: '2025-08-06',
    );
    const b = StreakResult(
      currentStreak: 3,
      longestStreak: 5,
      lastStudyDate: '2025-08-06',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
