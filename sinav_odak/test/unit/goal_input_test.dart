import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/goal_input.dart';

/// v1.2 — manuel hedef girişinin **serbest metin** ayrıştırıcısı.
///
/// SAF DART: kural domain katmanında, Flutter kurmadan test ediliyor.
void main() {
  group('süre — GEÇERLİ', () {
    test('koordinatörün örnekleri', () {
      expect(GoalInput.parseDuration('2sa 8dk'), 128);
      expect(GoalInput.parseDuration('148dk'), 148);
      expect(GoalInput.parseDuration('148'), 148, reason: 'birimsiz = dakika');
    });

    test('yalnızca saat', () {
      expect(GoalInput.parseDuration('2sa'), 120);
      expect(GoalInput.parseDuration('2 saat'), 120);
    });

    test('yalnızca dakika', () {
      expect(GoalInput.parseDuration('45dk'), 45);
      expect(GoalInput.parseDuration('45 dakika'), 45);
    });

    test('saat:dakika biçimi', () {
      expect(GoalInput.parseDuration('2:08'), 128);
      expect(GoalInput.parseDuration('0:45'), 45);
    });

    test('İngilizce birimler (klavye dili arayüzden bağımsız olabilir)', () {
      expect(GoalInput.parseDuration('2h 8m'), 128);
      expect(GoalInput.parseDuration('2 hours 8 minutes'), 128);
      expect(GoalInput.parseDuration('90 min'), 90);
    });

    test('büyük harf ve fazla boşluk', () {
      expect(GoalInput.parseDuration('  2SA   8DK  '), 128);
      // Türkçe büyük İ: `toLowerCase()` yerel bağımsız ve "İ" → birleşik
      // noktalı i üretiyor; normalizasyon bunu elle çözüyor.
      expect(GoalInput.parseDuration('45 DAKİKA'), 45);
    });

    test('sınırlar dahil: 0 ve 12 saat', () {
      expect(GoalInput.parseDuration('0'), 0);
      expect(GoalInput.parseDuration('12sa'), 720);
      expect(GoalInput.parseDuration('720dk'), 720);
    });

    test('dakika 59\'u aşabilir — sınırı TOPLAM belirliyor', () {
      expect(GoalInput.parseDuration('0sa 90dk'), 90);
    });
  });

  group('süre — GEÇERSİZ (eski değer korunur)', () {
    test('boş', () {
      expect(GoalInput.parseDuration(''), isNull);
      expect(GoalInput.parseDuration('   '), isNull);
    });

    test('12 saati aşıyor — KIRPILMIYOR', () {
      // Kırpmak sessiz bir yalan olurdu: "20 saat" yazan kullanıcı 12
      // saat kaydedildiğini fark etmeden ekrandan çıkardı.
      expect(GoalInput.parseDuration('13sa'), isNull);
      expect(GoalInput.parseDuration('721'), isNull);
      expect(GoalInput.parseDuration('12sa 1dk'), isNull);
      expect(GoalInput.parseDuration('20 hours'), isNull);
    });

    test('anlamsız metin', () {
      expect(GoalInput.parseDuration('iki saat'), isNull);
      expect(GoalInput.parseDuration('abc'), isNull);
      expect(GoalInput.parseDuration('sa dk'), isNull);
    });

    test('ayrıştırılamayan artık varsa geçersiz', () {
      // "2sa abc" sessizce 120 olmamalı; kullanıcı bir şey yazmış ve o
      // şey anlaşılmamış.
      expect(GoalInput.parseDuration('2sa abc'), isNull);
      expect(GoalInput.parseDuration('2sa 8dk fazla'), isNull);
    });

    test('ondalık ve işaret', () {
      expect(GoalInput.parseDuration('1.5sa'), isNull);
      expect(GoalInput.parseDuration('1,5'), isNull);
      expect(GoalInput.parseDuration('-30'), isNull);
    });
  });

  group('soru — GEÇERLİ', () {
    test('koordinatörün örneği', () {
      expect(GoalInput.parseCount('75 soru'), 75);
      expect(GoalInput.parseCount('75'), 75);
    });

    test('İngilizce birim', () {
      expect(GoalInput.parseCount('75 questions'), 75);
      expect(GoalInput.parseCount('75 question'), 75);
    });

    test('sınırlar dahil: 1 ve 2000', () {
      expect(GoalInput.parseCount('1'), 1);
      expect(GoalInput.parseCount('2000'), 2000);
    });
  });

  group('soru — GEÇERSİZ (eski değer korunur)', () {
    test('boş', () {
      expect(GoalInput.parseCount(''), isNull);
      expect(GoalInput.parseCount('  '), isNull);
    });

    test('sıfır ve sınır dışı — KIRPILMIYOR', () {
      expect(GoalInput.parseCount('0'), isNull);
      expect(GoalInput.parseCount('2001'), isNull);
      expect(GoalInput.parseCount('999999'), isNull);
    });

    test('anlamsız metin / ondalık / işaret', () {
      expect(GoalInput.parseCount('abc'), isNull);
      expect(GoalInput.parseCount('75 tane'), isNull);
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
