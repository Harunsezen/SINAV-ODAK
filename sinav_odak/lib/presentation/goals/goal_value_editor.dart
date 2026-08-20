import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/services/goal_input.dart';

/// Hedef değerinin ölçü birimi.
enum GoalValueKind {
  /// Süre — dakika olarak saklanıyor, "2sa 8dk" gibi yazılabiliyor.
  duration,

  /// Adet (soru).
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
/// ## Tek serbest metin alanı
///
/// Önce ayrı Saat/Dakika alanları denendi: belirsizlik yoktu ama iki alan
/// arasında gezinmeye zorluyordu. Tek alan + esnek ayrıştırma daha az
/// sürtünme — "2sa 8dk", "148dk", "148" ve "2:08" hepsi kabul ediliyor
/// (bkz. [GoalInput.parseDuration]).
///
/// Alan **mevcut değerle dolu** açılıyor: klavye ile stepper aynı sayıyı
/// gösteriyor.
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
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    // Alan MEVCUT değerle dolu açılıyor: klavye ile stepper aynı sayıyı
    // gösteriyor (senkron), kullanıcı sıfırdan yazmak zorunda değil.
    _a = TextEditingController(
      text: widget.kind == GoalValueKind.duration
          ? _durationText(widget.current)
          : '${widget.current}',
    );
  }

  /// 128 → "2sa 8dk" · 45 → "45dk" · 120 → "2sa"
  static String _durationText(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}dk';
    if (m == 0) return '${h}sa';
    return '${h}sa ${m}dk';
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.kind == GoalValueKind.duration
        ? GoalInput.parseDuration(_a.text)
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
          _field(
            key: isDuration
                ? const Key('goal-value-duration')
                : const Key('goal-value-count'),
            controller: _a,
            label: isDuration ? l.goalsEditDurationLabel : l.goalsEditCount,
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
  }) {
    return TextField(
      key: key,
      controller: controller,
      autofocus: true,
      // `digitsOnly` YOK: "2sa 8dk" yazılabilmeli. Doğrulama zaten
      // `GoalInput`'ta ve geçersizde eski değer korunuyor.
      keyboardType: TextInputType.text,
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
