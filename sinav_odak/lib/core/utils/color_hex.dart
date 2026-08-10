import 'package:flutter/material.dart';

/// `'#4F5BD5'` → [Color]. Bozuk/eksik değerde [fallback] döner.
///
/// Ders renkleri DB'de metin olarak tutuluyor (kullanıcı ders ekleyebildiği
/// için palet sabit değil). Çözümleme birden çok ekranda gerektiğinden
/// burada tek yerde duruyor; her ekranın kendi kopyasını taşıması, bozuk
/// değer davranışının ekrandan ekrana ayrışmasına yol açardı.
Color colorFromHex(String hex, {required Color fallback}) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
