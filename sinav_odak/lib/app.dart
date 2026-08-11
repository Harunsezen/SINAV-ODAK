import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/di/app_providers.dart';
import 'domain/entities/enums.dart';

class SinavOdakApp extends ConsumerWidget {
  const SinavOdakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStreamProvider);

    final themeMode = switch (settings.valueOrNull?.themeMode) {
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.dark => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    // Ekran kilidi: ayar açık VE aktif oturum varken ekran kapanmasın.
    // Tek yerde dinleniyor — RunScreen/BreakScreen'e ayrı ayrı konsaydı
    // ekranlar arası geçişte kilit bırakılıp yeniden alınırdı.
    ref.listen<bool>(shouldKeepScreenOnProvider, (previous, next) {
      ref.read(screenWakeGatewayProvider).setEnabled(enabled: next);
    });

    return MaterialApp.router(
      title: 'Sınav Odak',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(appRouterProvider),
      // FAZ 6: metinler `lib/l10n/*.arb`'den geliyor. Şablon dil TÜRKÇE;
      // EN dosyası altyapının çalıştığını gösteren iskelet, tam çeviri
      // v1.2'ye ait (K8). Uygulama şimdilik TR'ye sabit.
      locale: const Locale('tr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
