import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';

/// Oturumu **arka plana alma** onayı (v1.1 / FAZ 1.1).
///
/// v1.0'da aktif oturum sırasında uygulamadan çıkışın hiçbir yolu yoktu:
/// router her yolu `/run`'a çeviriyor, geri tuşu "çıkamazsın" snackbar'ı
/// gösteriyordu. Kullanıcı kendi uygulamasında kilitliydi — koordinatörün
/// "geri dönme butonu yoktu" tespiti buydu.
///
/// **"Pause yok" kuralı korunuyor.** Bu diyalog sayacı DURDURMAZ; yalnızca
/// kullanıcının başka ekranlara bakmasına izin verir. Oturum duvar saatiyle
/// işlemeye devam eder ve ana panelde kalıcı bir "oturuma dön" şeridi kalır.
/// Metin de bunu açıkça söylüyor: *"Sayaç durmaz."*
///
/// Kazara çıkış hâlâ imkânsız: hem sistem geri tuşu hem AppBar geri tuşu
/// buradan geçer ve varsayılan seçenek **Vazgeç**'tir.
Future<void> confirmMinimizeSession(BuildContext context, WidgetRef ref) async {
  final l = L10n.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('run-minimize-dialog'),
      title: Text(l.runMinimizeTitle),
      content: Text(l.runMinimizeBody),
      actions: [
        TextButton(
          key: const Key('run-minimize-cancel'),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('run-minimize-confirm'),
          // `Row` içinde tema sonsuz asgari genişlik veriyor; yerel sınır
          // şart (bkz. ONBOARDING_BUG.md).
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.runMinimizeConfirm),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  if (!context.mounted) return;

  // Bayrak ÖNCE yazılmalı: router yönlendirmesi bunu okuyor.
  ref.read(sessionMinimizedProvider.notifier).minimize();
  context.go(Routes.home);
}

/// Ana paneldeki şeritten oturuma dönüş.
void returnToSession(BuildContext context, WidgetRef ref) {
  ref.read(sessionMinimizedProvider.notifier).restore();
  context.go(Routes.run);
}
