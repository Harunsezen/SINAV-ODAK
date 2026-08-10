import 'package:flutter/material.dart';

/// Tasarım dili: sade, göz yormayan, odak dostu.
abstract final class AppColors {
  static const seed = Color(0xFF4F5BD5); // indigo

  static const correct = Color(0xFF2E9E6B);
  static const wrong = Color(0xFFD9534F);
  static const empty = Color(0xFF8A8F98);
  static const warning = Color(0xFFE08D3C);
  static const breakMode = Color(0xFF2FA3A0);
  static const streak = Color(0xFFE9603A);

  /// Ders renk paleti (kullanıcı ders eklerken bu havuzdan seçer).
  static const subjectPalette = <String>[
    '#4F5BD5', '#2E9E6B', '#D9534F', '#E08D3C', '#2FA3A0',
    '#7B4FD5', '#C2417F', '#3C7DE0', '#8A9A2B', '#5C6B7A',
  ];
}
