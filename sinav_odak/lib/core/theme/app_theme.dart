import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      // ⚠️ `Size.fromHeight(56)` = `Size(double.infinity, 56)`.
      //
      // Kasıtlı: `Column` içindeki birincil butonlar bu sayede tam genişlik
      // oluyor. AMA genişliği **sınırsız** veren bir kapsayıcının (en sık
      // `Row`; esnek olmayan çocuklarını sonsuz genişlikle ölçer) içine
      // konursa sonsuz asgari genişlik geçerli olmayan bir kısıta dönüşür,
      // buton yerleşemez ve **hiç çizilmez** — release'de sessizce.
      //
      // Onboarding alt barı tam olarak bu yüzden bozulmuştu (bkz.
      // ONBOARDING_BUG.md). Bir `Row` içine `FilledButton` koyacaksan
      // asgari genişliği yerel olarak ez:
      //   `style: FilledButton.styleFrom(minimumSize: const Size(88, 56))`
      // veya butonu `Expanded`/`Flexible` ile sınırla.
      //
      // `test/widget/theme_button_constraints_test.dart` bu tuzağı
      // bekçiliyor.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// Sayaç rakamlarının her saniye zıplamaması için tabular figures şart.
  static const counterStyle = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.w700,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
