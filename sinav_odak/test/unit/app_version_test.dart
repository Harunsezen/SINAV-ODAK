import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/constants/app_info.dart';

/// SÜRÜM ETİKETİ — `pubspec.yaml` ile eşit mi?
///
/// **Neden var:** v1.3'e kadar bu eşitlik yorum satırıyla "elde takip
/// ediliyor" deniyordu ve kaçtı — mağazada 1.3.0 yayındayken Ayarlar
/// ekranı "1.0.0" gösteriyordu, üretilen yedek dosyası da yanlış sürümle
/// etiketlenirdi. Kullanıcı destek istediğinde hangi sürümde olduğunu
/// yanlış söylerdi. Artık sürüm yükseltmeyi unutmak testi düşürüyor.
void main() {
  test('kAppVersion, pubspec.yaml sürümüyle aynı', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m =
        RegExp(r'^version:\s*([^\s+]+)', multiLine: true).firstMatch(pubspec);

    expect(m, isNotNull, reason: 'pubspec.yaml içinde version: yok');
    expect(
      kAppVersion,
      m!.group(1),
      reason: 'pubspec sürümü değişti; lib/core/constants/app_info.dart '
          'içindeki kAppVersion da güncellenmeli',
    );
  });
}
