import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/goal_input.dart';

/// v1.2 — manuel hedef girişinin doğrulama kuralları.
///
/// SAF DART: kural domain katmanında, Flutter kurmadan test ediliyor.
void main() {
  group('süre — GEÇERLİ', () {
    test('"2" + "10" → 130 dk (koordinatörün örneği)', () {
      expect(GoalInput.parseDuration(hours: '2', minutes: '10'), 130);
    });

    test('yalnızca saat yazmak yeter: "2" + "" → 120', () {
      // Kullanıcıyı ikinci alanı doldurmaya zorlamak gereksiz sürtünme.
      expect(GoalInput.parseDuration(hours: '2', minutes: ''), 120);
    });

    test('yalnızca dakika yazmak yeter: "" + "45" → 45', () {
      expect(GoalInput.parseDuration(hours: '', minutes: '45'), 45);
    });

    test('dakika 59\'u aşabilir: "0" + "90" → 90', () {
      // Sınırı TOPLAM belirliyor, tek tek alanlar değil.
      expect(GoalInput.parseDuration(hours: '0', minutes: '90'), 90);
    });

    test('alt sınır 0 ve üst sınır 12 saat kabul ediliyor', () {
      expect(GoalInput.parseDuration(hours: '0', minutes: '0'), 0);
      expect(GoalInput.parseDuration(hours: '12', minutes: '0'), 720);
    });

    test('boşluklar kırpılıyor', () {
      expect(GoalInput.parseDuration(hours: ' 1 ', minutes: ' 30 '), 90);
    });
  });

  group('süre — GEÇERSİZ (eski değer korunur)', () {
    test('iki alan da boş', () {
      expect(GoalInput.parseDuration(hours: '', minutes: ''), isNull);
      expect(GoalInput.parseDuration(hours: '  ', minutes: ''), isNull);
    });

    test('12 saati aşıyor', () {
      expect(GoalInput.parseDuration(hours: '12', minutes: '1'), isNull);
      expect(GoalInput.parseDuration(hours: '13', minutes: '0'), isNull);
      // Dakikadan taşırmak da aynı kapıya çıkıyor.
      expect(GoalInput.parseDuration(hours: '0', minutes: '721'), isNull);
    });

    test('harf / sembol', () {
      expect(GoalInput.parseDuration(hours: 'iki', minutes: '10'), isNull);
      expect(GoalInput.parseDuration(hours: '2', minutes: 'on'), isNull);
      expect(GoalInput.parseDuration(hours: '1.5', minutes: '0'), isNull);
      expect(GoalInput.parseDuration(hours: '1,5', minutes: '0'), isNull);
    });

    test('işaretli sayı reddediliyor', () {
      // `int.tryParse` "+2" ve "-2"yi kabul ediyor; hedef alanında ikisi
      // de anlamsız. Sessizce tuhaf bir değer üretmektense geçersiz say.
      expect(GoalInput.parseDuration(hours: '-2', minutes: '0'), isNull);
      expect(GoalInput.parseDuration(hours: '+2', minutes: '0'), isNull);
    });
  });

  group('soru — GEÇERLİ', () {
    test('"75" → 75 (koordinatörün örneği)', () {
      expect(GoalInput.parseCount('75'), 75);
    });

    test('sınırlar dahil: 1 ve 2000', () {
      expect(GoalInput.parseCount('1'), 1);
      expect(GoalInput.parseCount('2000'), 2000);
    });

    test('boşluklar kırpılıyor', () {
      expect(GoalInput.parseCount(' 120 '), 120);
    });
  });

  group('soru — GEÇERSİZ (eski değer korunur)', () {
    test('boş', () {
      expect(GoalInput.parseCount(''), isNull);
      expect(GoalInput.parseCount('   '), isNull);
    });

    test('sıfır ve sınır dışı', () {
      // 0 soruluk hedef anlamsız; alt sınır 1.
      expect(GoalInput.parseCount('0'), isNull);
      expect(GoalInput.parseCount('2001'), isNull);
      expect(GoalInput.parseCount('999999'), isNull);
    });

    test('harf / sembol / işaret', () {
      expect(GoalInput.parseCount('abc'), isNull);
      expect(GoalInput.parseCount('75 soru'), isNull);
      expect(GoalInput.parseCount('7.5'), isNull);
      expect(GoalInput.parseCount('-5'), isNull);
    });
  });

  test('sınır sabitleri koordinatörün verdiği aralıkla aynı', () {
    // Bu iddia sabitleri KİLİTLİYOR: biri 12 saati 8'e çekerse burada
    // düşer ve karar bilinçli alınmış olur.
    expect(GoalInput.minDurationMinutes, 0);
    expect(GoalInput.maxDurationMinutes, 12 * 60);
    expect(GoalInput.minCount, 1);
    expect(GoalInput.maxCount, 2000);
  });
}
