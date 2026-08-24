import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v1.3 YAMASI — **KULLANICIYA GİDEN METİNDE EMOJİ YOK.**
///
/// ## Neden bir kural, tek seferlik bir temizlik değil
///
/// Emoji yazı tipi **cihaza ait**, uygulamaya değil. Emoji fontu
/// olmayan ya da o kod noktasını taşımayan bir Android sürümünde emoji
/// **boş kutu (▯)** olarak çiziliyor — hata vermeden, sessizce. Bu tur
/// öncesinde oturum sonu formundaki duygu seçicisi (`😖 😕 😐 🙂 😄`)
/// tam olarak buydu: kontrolün TEK içeriği beş boş kutuya dönüşüyordu.
///
/// Bir kez temizlemek yetmez; bir sonraki metin yine emojiyle gelir.
/// Bu test kuralı **kalıcı** yapıyor.
///
/// ## Nerede aranıyor
///
/// - `lib/l10n/*.arb` — kullanıcıya giden metinlerin tamamı
/// - `lib/**/*.dart` **string sabitleri** — yorumlar hariç
///
/// Yorumlar hariç, çünkü geliştirici notu cihazda çizilmiyor;
/// `achievement_calculator.dart` başlıklarındaki 🏭 🔧 orada kalabilir.
///
/// ## Yerine ne konuyor
///
/// Material ikonu (uygulamanın kendi font varlığından geliyor, cihazdan
/// bağımsız) ya da hiçbir şey. Ok (`→`), tire (`—`), orta nokta (`·`) ve
/// matematik işaretleri emoji DEĞİL; onlar tipografi ve Roboto'da var.
void main() {
  /// Emoji ve piktogram kod noktaları.
  ///
  /// `0x2600-0x27BF` çeşitli semboller ve dingbatlar (☀ ✂ ✅ ...);
  /// `0x1F000-0x1FAFF` asıl emoji blokları; `0xFE0F` varyasyon seçici,
  /// `0x200D` ZWJ (birleşik emoji) — ikisi de tek başına emoji
  /// bulunduğunun işareti.
  bool isEmoji(int c) =>
      (c >= 0x1F000 && c <= 0x1FAFF) ||
      (c >= 0x2600 && c <= 0x27BF) ||
      c == 0xFE0F ||
      c == 0x200D ||
      c == 0x2B50 ||
      c == 0x2B55;

  String emojiIn(String value) {
    final found = value.runes.where(isEmoji).map(
          (r) => 'U+${r.toRadixString(16).toUpperCase()} '
              '(${String.fromCharCode(r)})',
        );
    return found.join(', ');
  }

  test('ARB metinlerinde emoji YOK', () {
    final problems = <String>[];

    for (final name in ['app_tr.arb', 'app_en.arb']) {
      final file = File('lib/l10n/$name');
      expect(
        file.existsSync(),
        isTrue,
        reason: '$name bulunamadı — test yanlış dizinden koşuyor',
      );

      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in map.entries) {
        // `@key` girdileri meta veri (açıklama, placeholder tipleri);
        // cihazda çizilmiyor.
        if (entry.key.startsWith('@')) continue;
        final value = entry.value;
        if (value is! String) continue;

        final found = emojiIn(value);
        if (found.isNotEmpty) {
          problems.add('$name → ${entry.key}: $found\n      "$value"');
        }
      }
    }

    expect(
      problems,
      isEmpty,
      reason: 'Emoji fontu olmayan cihazda BOŞ KUTU çıkar. Material '
          'ikonuyla değiştir ya da kaldır:\n   ${problems.join("\n   ")}',
    );
  });

  test('lib/ içindeki string SABİTLERİNDE emoji YOK', () {
    final problems = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      // Üretilen kod hariç: kaynağı ARB ve o zaten yukarıda taranıyor.
      if (file.path.endsWith('.g.dart')) continue;

      final lines = _withoutComments(file.readAsStringSync()).split('\n');
      for (var i = 0; i < lines.length; i++) {
        final found = emojiIn(lines[i]);
        if (found.isNotEmpty) {
          problems.add('${file.path}:${i + 1}: $found\n      '
              '${lines[i].trim()}');
        }
      }
    }

    expect(
      problems,
      isEmpty,
      reason: 'Kod içindeki metinde emoji:\n   ${problems.join("\n   ")}',
    );
  });

  test('tarayıcı GERÇEKTEN buluyor (karşıt kontrol)', () {
    // Bu olmadan yukarıdaki iki iddia, "hiçbir şey bulamayan bozuk bir
    // arama" ile de geçerdi.
    expect(emojiIn('Hedefe ulaştın 🎉'), contains('U+1F389'));
    expect(emojiIn('😖'), isNotEmpty);
    expect(emojiIn('☀'), isNotEmpty);

    // Tipografi emoji DEĞİL — yanlış alarm vermemeli.
    expect(emojiIn('v1 → v2 · 25 dk — bitti · ≈ ≥ − ▯ İşte şu ğ'), isEmpty);
  });

  test('yorum ayıklayıcı çalışıyor', () {
    expect(_withoutComments('// 🎉 yorum\nvar a = 1;').contains('🎉'), isFalse);
    expect(_withoutComments('/// 🎉 doc\nvar a = 1;').contains('🎉'), isFalse);
    expect(_withoutComments('/* 🎉 */ var a = 1;').contains('🎉'), isFalse);
    // Ama koddaki metin KALMALI, yoksa test hiçbir şey kanıtlamaz.
    expect(_withoutComments("var a = '🎉';").contains('🎉'), isTrue);
  });
}

/// Yorumları söker, satır sayısını KORUR (satır numarası doğru kalsın).
///
/// Tam bir Dart ayrıştırıcısı değil; `//` içeren bir string sabiti
/// ('http://...') yanlışlıkla kesilebilir. Bu testin işi için yeterli:
/// amaç emoji taşıyan bir string'i kaçırmamak, ve `://` sonrasında
/// emoji bulunan bir URL bu projede yok.
String _withoutComments(String source) {
  final withoutBlocks = source.replaceAllMapped(
    RegExp(r'/\*.*?\*/', dotAll: true),
    // Blok yorumun satır sayısı korunuyor.
    (m) => '\n' * '\n'.allMatches(m.group(0)!).length,
  );
  return withoutBlocks.split('\n').map((line) {
    final i = line.indexOf('//');
    return i < 0 ? line : line.substring(0, i);
  }).join('\n');
}
