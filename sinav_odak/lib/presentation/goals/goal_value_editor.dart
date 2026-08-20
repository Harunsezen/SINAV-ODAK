import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/services/goal_input.dart';

/// Hedef değerinin ölçü birimi.
enum GoalValueKind {
  /// Süre — saat + dakika olarak iki alan.
  duration,

  /// Adet (soru) — tek alan.
  count,
}

/// Hedef değerini **elle** girdiren diyalog.
///
/// ## Neden stepper'ın yanında
///
/// Stepper küçük ayarlar için hızlı ama uzak değerler için işkence:
/// 60 dk'dan 8 saate çıkmak 14 dokunuş. Zehra'nın geri bildirimi tam
/// buydu. Stepper **kalıyor** — ikisi bir arada: yakın değer için dokun,
/// uzak değer için yaz.
///
/// ## Neden serbest metin değil, iki sayı alanı
///
/// "2sa 10dk" gibi bir metni ayrıştırmak dile ve yazıma bağımlı olurdu
/// ("2 saat 10 dakika", "2:10", "2s10d"…). Saat ve dakika ayrı alanlar
/// olunca belirsizlik yok; klavye de sayısal açılıyor.
///
/// Geçersiz girişte diyalog `null` döndürüyor ve çağıran **eski değeri
/// koruyor** (bkz. [GoalInput]).
Future<int?> showGoalValueEditor(
  BuildContext context, {
  required GoalValueKind kind,
  required int current,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _GoalValueDialog(kind: kind, current: current),
  );
}

class _GoalValueDialog extends StatefulWidget {
  const _GoalValueDialog({required this.kind, required this.current});

  final GoalValueKind kind;

  /// Süre için **dakika**, adet için doğrudan sayı.
  final int current;

  @override
  State<_GoalValueDialog> createState() => _GoalValueDialogState();
}

class _GoalValueDialogState extends State<_GoalValueDialog> {
  late final TextEditingController _a;
  late final TextEditingController _b;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == GoalValueKind.duration) {
      _a = TextEditingController(text: '${widget.current ~/ 60}');
      _b = TextEditingController(text: '${widget.current % 60}');
    } else {
      _a = TextEditingController(text: '${widget.current}');
      _b = TextEditingController();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.kind == GoalValueKind.duration
        ? GoalInput.parseDuration(hours: _a.text, minutes: _b.text)
        : GoalInput.parseCount(_a.text);

    if (value == null) {
      // Diyalog KAPANMIYOR: kullanıcı ne yazdığını görüp düzeltebilsin.
      // Kapatıp sessizce eski değere dönmek "kaydettim sandım" hatası
      // üretirdi.
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final isDuration = widget.kind == GoalValueKind.duration;

    return AlertDialog(
      key: const Key('goal-value-dialog'),
      title: Text(
        isDuration ? l.goalsEditDurationTitle : l.goalsEditCountTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDuration)
            Row(
              children: [
                Expanded(
                  child: _field(
                    key: const Key('goal-value-hours'),
                    controller: _a,
                    label: l.goalsEditHours,
                    autofocus: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    key: const Key('goal-value-minutes'),
                    controller: _b,
                    label: l.goalsEditMinutes,
                  ),
                ),
              ],
            )
          else
            _field(
              key: const Key('goal-value-count'),
              controller: _a,
              label: l.goalsEditCount,
              autofocus: true,
            ),
          const SizedBox(height: 8),
          Text(
            isDuration ? l.goalsEditDurationHint : l.goalsEditCountHint,
            style: const TextStyle(fontSize: 12),
          ),
          if (_invalid) ...[
            const SizedBox(height: 8),
            Text(
              l.goalsEditInvalid,
              key: const Key('goal-value-error'),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('goal-value-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('goal-value-save'),
          onPressed: _submit,
          child: Text(l.commonSave),
        ),
      ],
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    bool autofocus = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      // Yalnızca rakam: eksi/nokta/virgül girilemesin. Doğrulama yine de
      // `GoalInput`'ta — yapıştırma bu filtreyi atlayabiliyor.
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
