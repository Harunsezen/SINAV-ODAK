import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/utils/formatters.dart';

/// Onboarding 3/5 — Günlük hedef.
///
/// Sınırlar bilinçli: 60 dk'nın altı ölçmeye değmez, 480 dk'nın (8 saat)
/// üstü sürdürülemez bir hedef koyup kullanıcıyı ilk haftada başarısız
/// hissettirir. Aynı gerekçeyle soru hedefi 20–500 arası.
///
/// v1.2'de i18n (FAZ 6 / K7).
class GoalStep extends StatelessWidget {
  const GoalStep({
    required this.minutes,
    required this.questions,
    required this.onMinutes,
    required this.onQuestions,
    super.key,
  });

  final int minutes;
  final int questions;
  final ValueChanged<int> onMinutes;
  final ValueChanged<int> onQuestions;

  static const minMinutes = 60;
  static const maxMinutes = 480;
  static const stepMinutes = 30;

  static const minQuestions = 20;
  static const maxQuestions = 500;
  static const stepQuestions = 10;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding-step-goal'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          L10n.of(context).onboardingGoalTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).onboardingGoalNote,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 24),
        _Stepper(
          slug: 'minutes',
          label: L10n.of(context).onboardingGoalMinutes,
          display: formatDurationShort(minutes * 60),
          onDec: minutes > minMinutes
              ? () => onMinutes(minutes - stepMinutes)
              : null,
          onInc: minutes < maxMinutes
              ? () => onMinutes(minutes + stepMinutes)
              : null,
        ),
        const SizedBox(height: 16),
        _Stepper(
          slug: 'questions',
          label: L10n.of(context).onboardingGoalQuestions,
          display: '$questions soru',
          onDec: questions > minQuestions
              ? () => onQuestions(questions - stepQuestions)
              : null,
          onInc: questions < maxQuestions
              ? () => onQuestions(questions + stepQuestions)
              : null,
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.slug,
    required this.label,
    required this.display,
    required this.onDec,
    required this.onInc,
  });

  final String slug;
  final String label;
  final String display;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              key: Key('onboarding-goal-$slug-dec'),
              onPressed: onDec,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 88,
              child: Text(
                display,
                key: Key('onboarding-goal-$slug-value'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              key: Key('onboarding-goal-$slug-inc'),
              onPressed: onInc,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
