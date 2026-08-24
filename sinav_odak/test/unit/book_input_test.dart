import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/book_input.dart';

/// v1.3 — KİTAP OKUMA giriş kuralları. Saf Dart, Flutter kurulmuyor.
///
/// Buradaki testlerin koruduğu şey bir fonksiyon değil, üç ÜRÜN KURALI:
/// kitap adı boş bırakılabilir, süre 5 dk – 12 saat arası, sayfa 1–2000.
void main() {
  group('parseMinutes', () {
    test('birimsiz sayı DAKİKA sayılıyor', () {
      expect(BookInput.parseMinutes('45'), 45);
    });

    test('Türkçe ve İngilizce birimler', () {
      expect(BookInput.parseMinutes('45dk'), 45);
      expect(BookInput.parseMinutes('1sa 30dk'), 90);
      expect(BookInput.parseMinutes('1h 30m'), 90);
      expect(BookInput.parseMinutes('1:30'), 90);
    });

    test('ALT SINIR 5 dakika: 4 reddediliyor, 5 kabul', () {
      // Süresi olmayan bir okuma oturumu ölçmediği bir şeyi kaydeder.
      expect(BookInput.parseMinutes('4'), isNull);
      expect(BookInput.parseMinutes('5'), 5);
      expect(BookInput.parseMinutes('0'), isNull);
    });

    test('ÜST SINIR 12 saat', () {
      expect(BookInput.parseMinutes('720'), 720);
      expect(BookInput.parseMinutes('721'), isNull);
      expect(BookInput.parseMinutes('13sa'), isNull);
    });

    test('sınır dışı KIRPILMIYOR, reddediliyor', () {
      // Sessizce kırpmak "20 saat yazdım, 12 kaydedildi" demekti.
      expect(BookInput.parseMinutes('2000'), isNull);
    });

    test('anlamsız metin reddediliyor', () {
      expect(BookInput.parseMinutes(''), isNull);
      expect(BookInput.parseMinutes('abc'), isNull);
      expect(BookInput.parseMinutes('45dk abc'), isNull);
    });
  });

  group('parsePages', () {
    test('sayı ve birimli yazım', () {
      expect(BookInput.parsePages('120'), 120);
      expect(BookInput.parsePages('120 sayfa'), 120);
      expect(BookInput.parsePages('120 pages'), 120);
      expect(BookInput.parsePages('120sf'), 120);
    });

    test('büyük İ/I sorunlu Türkçe yazım da okunuyor', () {
      expect(BookInput.parsePages('120 SAYFA'), 120);
    });

    test('sınırlar: 0 ve 2001 reddediliyor', () {
      expect(BookInput.parsePages('0'), isNull);
      expect(BookInput.parsePages('1'), 1);
      expect(BookInput.parsePages('2000'), 2000);
      expect(BookInput.parsePages('2001'), isNull);
    });

    test('anlamsız metin reddediliyor', () {
      expect(BookInput.parsePages('elli'), isNull);
      expect(BookInput.parsePages('-5'), isNull);
    });
  });

  group('normalizeTitle — KİTAP ADI BOŞ BIRAKILABİLİR', () {
    test('boş ve yalnızca boşluk → null', () {
      expect(BookInput.normalizeTitle(null), isNull);
      expect(BookInput.normalizeTitle(''), isNull);
      expect(BookInput.normalizeTitle('   '), isNull);
      expect(BookInput.normalizeTitle('\n\t '), isNull);
    });

    test('baş/son boşluk kırpılıyor, iç boşluk teke iniyor', () {
      expect(BookInput.normalizeTitle('  Sefiller '), 'Sefiller');
      expect(BookInput.normalizeTitle('Suç   ve   Ceza'), 'Suç ve Ceza');
    });

    test('80 karakterde kesiliyor — şema sınırıyla AYNI', () {
      final long = 'a' * 200;
      final result = BookInput.normalizeTitle(long);
      expect(result, hasLength(BookInput.maxTitleLength));
    });

    test('tam sınırdaki ad DOKUNULMADAN geçiyor', () {
      final exact = 'b' * BookInput.maxTitleLength;
      expect(BookInput.normalizeTitle(exact), exact);
    });
  });

  group('süre tavanı', () {
    test('12 saatin üstü tavana çekiliyor', () {
      expect(
        BookInput.capReadingS(BookInput.maxReadingS + 1),
        BookInput.maxReadingS,
      );
      expect(BookInput.isReadingCapped(BookInput.maxReadingS + 1), isTrue);
    });

    test('tavanın altı DOKUNULMUYOR', () {
      expect(BookInput.capReadingS(3600), 3600);
      expect(BookInput.isReadingCapped(3600), isFalse);
    });

    test('negatif süre 0', () {
      expect(BookInput.capReadingS(-5), 0);
    });
  });

  group('clampPagesRead', () {
    test('0 GEÇERLİ: açtım ama okuyamadım', () {
      expect(BookInput.clampPagesRead(0), 0);
    });

    test('negatif 0a, tavan üstü 2000e', () {
      expect(BookInput.clampPagesRead(-3), 0);
      expect(BookInput.clampPagesRead(9999), BookInput.maxPages);
    });
  });
}
