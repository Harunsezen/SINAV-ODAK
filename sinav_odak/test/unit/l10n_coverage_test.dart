import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// v1.2/E — ARB DOSYALARININ BEKÇİSİ.
///
/// v1.1'de `app_en.arb` bir **iskeletti**: 439 anahtarın 421'i Türkçe
/// metnin kopyasıydı. `flutter gen-l10n` bundan şikâyet etmiyor, uygulama
/// derleniyor, testler yeşil kalıyor — İngilizceye alınan kullanıcı
/// arayüzü Türkçe görüyordu. Bu dosya o sessiz durumu **hataya** çeviriyor.
///
/// ARB'ler JSON olarak okunuyor, üretilmiş sınıf üzerinden değil: sorun
/// üretimden ÖNCE, kaynak dosyada.
void main() {
  Map<String, dynamic> load(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  final tr = load('lib/l10n/app_tr.arb');
  final en = load('lib/l10n/app_en.arb');

  List<String> keysOf(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toList();

  /// TR ve EN'de **aynı olması doğru olan** anahtarlar.
  ///
  /// Marka adı, sınav kısaltmaları, yalnızca yer tutucudan oluşan biçim
  /// dizeleri ve iki dilde de aynı yazılan terimler. Liste kısa ve
  /// gerekçeli: uzarsa çeviri unutulmuş demektir.
  const identicalOnPurpose = <String>{
    // Marka
    'appTitle', 'onboardingPromiseTitle',
    // Sınav kısaltmaları — Türkiye'ye özgü, çevrilmez
    'examYks', 'examLgs', 'examKpss', 'examAles', 'examDgs',
    'curriculumLevelTyt', 'curriculumLevelAyt',
    // İki dilde de aynı terim
    'summaryNet', 'statsNet', 'homeNet', 'goalsUnitNet', 'csvNet',
    'planTitle',
    // Dil adları kendi dillerinde yazılır
    'languageTurkish', 'languageEnglish', 'onboardingLanguage',
    // Yalnızca yer tutucu + noktalama
    'goalsProgress', 'homeProgressOf', 'onboardingStepOf',
    'setupBreadcrumb', 'wrongsSubjectTopic', 'setupTopicPlus',
    // Bilerek boş (kilitli rozetin gövdesi yok)
    'achUnknownBody',
  };

  /// `{ad}` biçimindeki yer tutucular. ICU `select` gövdesindeki seçenek
  /// adları (`1{Ocak}`) hariç: onlar çeviriye TABİ.
  ///
  /// **Liste döner, küme değil:** Dart'ta `Set` `==` operatörünü
  /// geçersiz kılmıyor; iki ayrı boş küme `!=` karşılaştırmasında farklı
  /// çıkıyor ve test her anahtarda düşüyordu.
  List<String> placeholders(String value) {
    // ICU `select` seçenek gövdelerini ÖNCE at: `monthName` içindeki
    // `1{Ocak}` bir yer tutucu değil, çevrilecek metin. Atılmazsa test
    // "Ocak != January" diye düşüyor ve doğru çeviriyi hata sayıyor.
    final stripped = value
        .replaceAll(RegExp(r'\d+\{[^}]*\}'), '')
        .replaceAll(RegExp(r'other\{[^}]*\}'), '');

    final out = <String>{};
    for (final m in RegExp(r'\{(\w+)(?=[},])').allMatches(stripped)) {
      out.add(m.group(1)!);
    }
    return out.toList()..sort();
  }

  test('@@locale her dosyada KENDİ dilini söylüyor', () {
    // Bu satır yanlışken `flutter gen-l10n` "Current @@locale value: tr /
    // filename extension: en" diye uyarıyor ama HATA vermiyor; İngilizce
    // dosya Türkçe locale'a üretiliyordu.
    expect(tr['@@locale'], 'tr');
    expect(en['@@locale'], 'en');
  });

  test('iki dosyada da AYNI anahtarlar var', () {
    final trKeys = keysOf(tr).toSet();
    final enKeys = keysOf(en).toSet();

    expect(
      trKeys.difference(enKeys),
      isEmpty,
      reason: 'EN dosyasında karşılığı olmayan anahtar: uygulama İngilizce '
          'açıldığında bu metinler Türkçe kalır',
    );
    expect(
      enKeys.difference(trKeys),
      isEmpty,
      reason: 'TR dosyasında karşılığı olmayan anahtar: şablon dil TR, '
          'oradan silinen anahtar EN\'de öksüz kalmış',
    );
  });

  test('İngilizce metinler Türkçe kopyası DEĞİL', () {
    final copied = <String>[];
    for (final k in keysOf(tr)) {
      if (identicalOnPurpose.contains(k)) continue;
      if (tr[k] == en[k]) copied.add(k);
    }
    expect(
      copied,
      isEmpty,
      reason: 'Bu anahtarların İngilizcesi Türkçesiyle birebir aynı. '
          'Ya çevrilmemiş ya da bilerek aynıysa `identicalOnPurpose` '
          'listesine gerekçesiyle eklenmeli.',
    );
  });

  test('yer tutucular iki dilde de AYNI', () {
    // Eksik yer tutucu derleme hatası vermiyor; `{count}` düşmüş bir
    // çeviri çalışma zamanında sayıyı hiç göstermiyor.
    final mismatched = <String>[];
    for (final k in keysOf(tr)) {
      final a = placeholders(tr[k] as String);
      final b = placeholders(en[k] as String);
      if (a.join(',') != b.join(',')) {
        mismatched.add('$k: $a != $b');
      }
    }
    expect(mismatched, isEmpty);
  });

  test('yer tutucu tanımları (@anahtar) iki dosyada da tutarlı', () {
    // `@anahtar` bloğu yalnızca ŞABLON dosyada zorunlu; ama EN'de de
    // varsa TR ile aynı yer tutucuları saymalı.
    for (final k in keysOf(tr)) {
      final meta = en['@$k'];
      if (meta == null) continue;
      final enPh = ((meta as Map)['placeholders'] as Map?)?.keys.toList() ?? [];
      final trMeta = tr['@$k'] as Map?;
      final trPh =
          (trMeta?['placeholders'] as Map?)?.keys.toList() ?? <dynamic>[];
      expect(enPh, trPh, reason: k);
    }
  });

  test('boş çeviri yok', () {
    final empty = keysOf(en)
        .where((k) => (en[k] as String).isEmpty && k != 'achUnknownBody')
        .toList();
    expect(empty, isEmpty);
  });

  test('çeviri sayısı v1.1 seviyesinin altına DÜŞMÜYOR', () {
    // Kilit: birisi anahtar silerse burada görünür.
    expect(keysOf(tr).length, greaterThanOrEqualTo(469));
  });
}
