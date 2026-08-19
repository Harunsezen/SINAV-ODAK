import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/goal_progress_calculator.dart';
import 'goal_form_sheet.dart';
import 'goal_labels.dart';

/// Hedefler ekranı (FAZ 7B).
///
/// Aktif ve tamamlanan hedefler tek listede; aktifler üstte (`watchAll`
/// duruma göre sıralıyor).
///
/// İlerleme `goals.currentValue`'dan okunuyor — bu alanı
/// `SessionRepository.recomputeGoals()` KAYDET yolunda yazıyor.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final goals = ref.watch(allGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.goalsTitle)),
      body: goals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();

          final active =
              list.where((g) => g.status == GoalStatus.active).toList();
          final done =
              list.where((g) => g.status != GoalStatus.active).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel(text: l.goalsActive),
                for (final g in active)
                  _GoalCard(
                    id: g.id,
                    type: g.type,
                    current: g.currentValue,
                    target: g.targetValue,
                    isCompleted: false,
                  ),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionLabel(text: l.goalsCompleted),
                for (final g in done)
                  _GoalCard(
                    id: g.id,
                    type: g.type,
                    current: g.currentValue,
                    target: g.targetValue,
                    isCompleted: true,
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('goals-add'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const GoalFormSheet(),
        ),
        icon: const Icon(Icons.add),
        label: Text(l.goalsAdd),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// Tek hedef kartı: ilerleme çubuğu + değer/hedef.
class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.id,
    required this.type,
    required this.current,
    required this.target,
    required this.isCompleted,
  });

  final String id;
  final GoalType type;
  final double current;
  final double target;
  final bool isCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ratio = GoalProgressCalculator.ratio(current, target);
    final unit = goalUnitLabel(l, type);

    return Card(
      key: Key('goal-card-$id'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isCompleted ? scheme.primary : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goalTypeLabel(l, type),
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: Key('goal-delete-$id'),
                  tooltip: l.goalsDelete,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: l.a11yGoalProgress(
                goalTypeLabel(l, type),
                (ratio * 100).round(),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: Key('goal-progress-$id'),
                  value: ratio,
                  minHeight: 10,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // **`Expanded` şart.** İki metin de kendi doğal genişliğini
                // isteyince 320 px'lik ekranda satır 14 px taşıyordu
                // ("120 / 240 dakika" + "%50"). Ölçüldü: `responsive_test`
                // yalnızca bu kombinasyonda düşüyordu.
                //
                // Sol taraf esner ve gerekirse kısalır; yüzde/"Ulaşıldı"
                // hiçbir zaman kırpılmaz — asıl bilgi o.
                Expanded(
                  child: Text(
                    '${l.goalsProgress(_fmt(current), _fmt(target))} $unit',
                    key: Key('goal-value-$id'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isCompleted ? l.goalsReached : '%${(ratio * 100).round()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? scheme.primary : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tam sayı hedeflerde ".0" göstermemek için.
  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('goal-delete-dialog'),
        content: Text(l.goalsDeleteConfirm),
        actions: [
          TextButton(
            key: const Key('goal-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('goal-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.goalsDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(goalDaoProvider).deleteGoal(id);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      key: const Key('goals-empty'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_outlined, size: 48),
            const SizedBox(height: 12),
            Text(l.goalsEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              l.goalsEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
