import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../domain/services/book_input.dart';

/// Klavyeyle girilen değerin türü.
enum BookValueKind {
  /// Okuma süresi — dakika olarak saklanıyor, "1sa 30dk" yazılabiliyor.
  minutes,

  /// Sayfa sayısı.
  pages,
}

/// Okuma süresini / sayfa sayısını **elle** girdiren diyalog (v1.3).
///
/// Koordinatörün istediği üç yoldan **birincisi: klavye**. Diğer ikisi
/// (tek dokunuş +5, basılı tut) `HoldRepeatButton` ile aynı satırda
/// duruyor.
///
/// `showGoalValueEditor` ile aynı desen ve aynı gerekçelerle: alan mevcut
/// değerle DOLU açılıyor (klavye ile stepper aynı sayıyı gösteriyor),
/// geçersiz girişte diyalog KAPANMIYOR (kullanıcı ne yazdığını görüp
/// düzeltebilsin — kapatıp sessizce eski değere dönmek "kaydettim sandım"
/// hatası üretirdi).
///
/// Neden ayrı dosya, `goal_value_editor` yeniden kullanılmadı: hedef
/// düzenleyicisinin sınırları hedefe ait (süre 0–12 saat, adet 1–2000
/// soru) ve metinleri hedef diliyle yazılmış. Okuma süresinin alt sınırı
/// 5 dakika ve alan adı "sayfa". Aynı diyaloğa iki ayrı kural kümesi
/// koymak, ikisini de okunmaz hale getirirdi.
Future<int?> showBookValueEditor(
  BuildContext context, {
  required BookValueKind kind,
  required int current,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _BookValueDialog(kind: kind, current: current),
  );
}

class _BookValueDialog extends StatefulWidget {
  const _BookValueDialog({required this.kind, required this.current});

  final BookValueKind kind;
  final int current;

  @override
  State<_BookValueDialog> createState() => _BookValueDialogState();
}

class _BookValueDialogState extends State<_BookValueDialog> {
  late final TextEditingController _field;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _field = TextEditingController(text: '${widget.current}');
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.kind == BookValueKind.minutes
        ? BookInput.parseMinutes(_field.text)
        : BookInput.parsePages(_field.text);

    if (value == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final isMinutes = widget.kind == BookValueKind.minutes;

    return AlertDialog(
      key: const Key('book-value-dialog'),
      title: Text(
        isMinutes ? l.bookEditDurationTitle : l.bookEditPagesTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('book-value-field'),
            controller: _field,
            autofocus: true,
            // `digitsOnly` YOK: "1sa 30dk" ve "40 sayfa" yazılabilmeli.
            // Doğrulama `BookInput`'ta ve geçersizde değer korunuyor.
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: isMinutes ? l.bookDurationLabel : l.bookPagesLabel,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMinutes ? l.bookEditDurationHint : l.bookEditPagesHint,
            style: const TextStyle(fontSize: 12),
          ),
          if (_invalid) ...[
            const SizedBox(height: 8),
            Text(
              isMinutes ? l.bookInvalidDuration : l.bookInvalidPages,
              key: const Key('book-value-error'),
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
          key: const Key('book-value-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('book-value-save'),
          onPressed: _submit,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
