import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';

/// "Verileri sıfırla" — **çift onaylı**.
///
/// Tek onaylı bir diyalog bu iş için yeterli değil: işlem geri alınamaz ve
/// kullanıcının aylarca biriktirdiği çalışma geçmişini siliyor. İki adım:
///
/// 1. Ne silineceğini anlatan uyarı → *Devam et*
/// 2. `SIFIRLA` kelimesini **elle yazma** → *Kalıcı olarak sil*
///
/// İkinci adım bilinçli olarak yazma gerektiriyor; arka arkaya iki kez
/// "onayla"ya basmak refleks hâline gelebiliyor, kelime yazmak gelmiyor.
class ResetDataTile extends ConsumerStatefulWidget {
  const ResetDataTile({super.key});

  @override
  ConsumerState<ResetDataTile> createState() => _ResetDataTileState();
}

class _ResetDataTileState extends ConsumerState<ResetDataTile> {
  bool _busy = false;

  Future<void> _start() async {
    final l = L10n.of(context);

    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('reset-step1-dialog'),
        icon: const Icon(Icons.warning_amber_outlined),
        title: Text(l.settingsResetStep1Title),
        content: Text(l.settingsResetStep1Body),
        actions: [
          TextButton(
            key: const Key('reset-step1-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            key: const Key('reset-step1-continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.settingsResetStep1Continue),
          ),
        ],
      ),
    );

    if (step1 != true || !mounted) return;

    final keyword = l.settingsResetKeyword;
    final step2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => _KeywordConfirmDialog(keyword: keyword),
    );

    if (step2 != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(databaseProvider).resetAllData();
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.settingsResetDone)),
    );
    // Yönlendirme YAPILMIYOR: `onboardingCompleted` sıfırlandığı için
    // router'ın kendi redirect kuralı /onboarding'e götürüyor. Buradan
    // ayrıca `go` çağırmak iki yönlendirmenin yarışması demekti.
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.settingsResetNote, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('settings-reset'),
          onPressed: _busy ? null : _start,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever_outlined),
          label: Text(l.settingsReset),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error),
          ),
        ),
      ],
    );
  }
}

/// İkinci onay: kelimeyi elle yazdırır.
class _KeywordConfirmDialog extends StatefulWidget {
  const _KeywordConfirmDialog({required this.keyword});

  final String keyword;

  @override
  State<_KeywordConfirmDialog> createState() => _KeywordConfirmDialogState();
}

class _KeywordConfirmDialogState extends State<_KeywordConfirmDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      key: const Key('reset-step2-dialog'),
      title: Text(l.settingsResetStep2Title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsResetStep2Body(widget.keyword)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('reset-keyword-field'),
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: widget.keyword),
            // Büyük/küçük harf duyarsız: kullanıcı "sıfırla" yazdığında
            // niyeti aynı, klavyeyle savaştırmanın anlamı yok.
            onChanged: (v) => setState(
              () => _matches =
                  v.trim().toLowerCase() == widget.keyword.toLowerCase(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('reset-step2-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('reset-step2-confirm'),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l.settingsResetConfirm),
        ),
      ],
    );
  }
}
