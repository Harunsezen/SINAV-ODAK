import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/utils/color_hex.dart';

/// Elle yanlış kaydı ekleme (S: yanlış defteri).
///
/// Diyalog değil **route**: ders + konu seçimi iki uzun liste gerektiriyor,
/// diyalog içinde klavye açıldığında kullanılamaz hale geliyordu.
class AddWrongScreen extends ConsumerStatefulWidget {
  const AddWrongScreen({super.key});

  @override
  ConsumerState<AddWrongScreen> createState() => _AddWrongScreenState();
}

class _AddWrongScreenState extends ConsumerState<AddWrongScreen> {
  String? _subjectId;
  String? _topicId;
  int _wrongCount = 1;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final subjectId = _subjectId;
    if (subjectId == null) return;

    setState(() => _saving = true);
    final note = _noteCtrl.text.trim();
    await ref.read(wrongItemDaoProvider).addManual(
          id: const Uuid().v4(),
          subjectId: subjectId,
          topicId: _topicId,
          wrongCount: _wrongCount,
          note: note.isEmpty ? null : note,
        );
    if (mounted) context.go(Routes.wrongs);
  }

  @override
  Widget build(BuildContext context) {
    // Tip çıkarımı ile tüketiliyor; data katmanı import edilmiyor.
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];
    final topics = _subjectId == null
        ? const []
        : ref.watch(topicsProvider(_subjectId!)).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Yanlış Ekle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Ders', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in subjects)
                ChoiceChip(
                  key: Key('add-wrong-subject-${s.id}'),
                  label: Text(s.name),
                  selected: _subjectId == s.id,
                  avatar: CircleAvatar(
                    radius: 6,
                    backgroundColor: colorFromHex(
                      s.colorHex,
                      fallback: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  onSelected: (_) => setState(() {
                    // Ders değişince önceki konu seçimi geçersizdir.
                    _subjectId = s.id;
                    _topicId = null;
                  }),
                ),
            ],
          ),

          if (_subjectId != null) ...[
            const SizedBox(height: 20),
            Text(
              'Konu (opsiyonel)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in topics)
                  ChoiceChip(
                    key: Key('add-wrong-topic-${t.id}'),
                    label: Text(t.name),
                    selected: _topicId == t.id,
                    onSelected: (sel) =>
                        setState(() => _topicId = sel ? t.id : null),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          Text('Yanlış sayısı', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              IconButton(
                key: const Key('add-wrong-dec'),
                onPressed: _wrongCount > 1
                    ? () => setState(() => _wrongCount--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_wrongCount',
                  key: const Key('add-wrong-count'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const Key('add-wrong-inc'),
                onPressed: () => setState(() => _wrongCount++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextField(
            key: const Key('add-wrong-note'),
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Not (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            key: const Key('add-wrong-save'),
            // Ders ZORUNLU; seçilmeden kayıt açılmaz.
            onPressed: _subjectId == null || _saving ? null : _save,
            child: const Text('KAYDET'),
          ),
        ],
      ),
    );
  }
}
