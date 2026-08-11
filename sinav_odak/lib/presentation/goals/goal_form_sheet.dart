import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/app_providers.dart';
import '../../domain/entities/enums.dart';
import 'goal_labels.dart';

/// Hedef oluşturma sayfası (alt sayfa).
///
/// **Sınırlar S8 ile uyumlu** (`plan_setup` custom stepper'ı): süre en fazla
/// **480 dk**, soru en fazla **500**. Oturum kurulumunda 480 dk tavanı varken
/// hedefte 2000 dk'ya izin vermek, kullanıcıya asla ulaşamayacağı bir hedef
/// kurdurmak olurdu.
class GoalFormSheet extends ConsumerStatefulWidget {
  const GoalFormSheet({super.key});

  /// Formda sunulan hedef tipleri.
  ///
  /// `topicCompletion`, `net` ve `streak` DIŞARIDA: ilk üçü kullanıcının
  /// doğrudan kurabileceği türler değil (konu tamamlama katalogdan,
  /// seri kendiliğinden ilerliyor). Şemada duruyorlar ve
  /// `GoalProgressCalculator` hepsini hesaplıyor — yalnızca form onları
  /// sunmuyor.
  static const List<GoalType> offered = [
    GoalType.dailyMinutes,
    GoalType.weeklyMinutes,
    GoalType.dailyQuestions,
    GoalType.weeklyQuestions,
    GoalType.subjectMinutes,
  ];

  @override
  ConsumerState<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<GoalFormSheet> {
  GoalType _type = GoalType.dailyMinutes;
  int _target = 120;
  String? _subjectId;
  bool _busy = false;

  bool get _isQuestions =>
      _type == GoalType.dailyQuestions || _type == GoalType.weeklyQuestions;

  bool get _needsSubject => _type == GoalType.subjectMinutes;

  // S8 sınırları.
  int get _min => _isQuestions ? 10 : 15;
  int get _max => _isQuestions ? 500 : 480;
  int get _step => _isQuestions ? 10 : 15;

  void _selectType(GoalType next) {
    setState(() {
      _type = next;
      // Sınırlar tipe göre değişiyor: soru hedefinden süreye geçince
      // 500 gibi bir değer 480 tavanını aşardı.
      _target = _target.clamp(_min, _max);
      // Adıma hizala, aksi halde stepper 125 gibi bir değerde takılır.
      _target = (_target ~/ _step) * _step;
      if (_target < _min) _target = _min;
      if (!_needsSubject) _subjectId = null;
    });
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    await ref.read(goalDaoProvider).createGoal(
          id: const Uuid().v4(),
          type: _type,
          target: _target.toDouble(),
          subjectId: _subjectId,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final subjects = ref.watch(subjectsProvider).valueOrNull ?? const [];

    // Ders bazlı hedefte ders seçilmeden oluşturulamaz: `subjectId` null
    // kalırsa hedef hiçbir dersle eşleşmez ve ilerlemesi sonsuza kadar
    // 0 kalırdı.
    final canCreate = !_busy && (!_needsSubject || _subjectId != null);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.goalsNew, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(l.goalsTypeLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GoalFormSheet.offered)
                ChoiceChip(
                  key: Key('goal-type-${t.name}'),
                  label: Text(goalTypeLabel(l, t)),
                  selected: _type == t,
                  onSelected: (_) => _selectType(t),
                ),
            ],
          ),
          if (_needsSubject) ...[
            const SizedBox(height: 16),
            Text(l.goalsSubjectLabel, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('goal-subject'),
              value: _subjectId,
              isExpanded: true,
              items: [
                for (final s in subjects)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(l.goalsTargetLabel)),
              IconButton(
                key: const Key('goal-target-minus'),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _target <= _min
                    ? null
                    : () => setState(() => _target -= _step),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$_target',
                  key: const Key('goal-target-value'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('goal-target-plus'),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _target >= _max
                    ? null
                    : () => setState(() => _target += _step),
              ),
              const SizedBox(width: 4),
              Text(goalUnitLabel(l, _type)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('goal-cancel'),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(l.commonCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('goal-create'),
                onPressed: canCreate ? _create : null,
                child: Text(l.goalsCreate),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
