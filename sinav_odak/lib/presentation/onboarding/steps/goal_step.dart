import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../../core/l10n/format_l10n.dart';

import '../../goals/goal_value_editor.dart';
import '../../goals/hold_repeat_button.dart';

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
          display: L10n.of(context).durationShort(minutes * 60),
          kind: GoalValueKind.duration,
          value: minutes,
          onTyped: onMinutes,
          step: stepMinutes,
          canDec: minutes > minMinutes,
          canInc: minutes < maxMinutes,
          onDec: (by) =>
              onMinutes((minutes - by).clamp(minMinutes, maxMinutes)),
          onInc: (by) =>
              onMinutes((minutes + by).clamp(minMinutes, maxMinutes)),
        ),
        const SizedBox(height: 16),
        _Stepper(
          slug: 'questions',
          label: L10n.of(context).onboardingGoalQuestions,
          display: L10n.of(context).onboardingQuestionsValue(questions),
          kind: GoalValueKind.count,
          value: questions,
          onTyped: onQuestions,
          step: stepQuestions,
          canDec: questions > minQuestions,
          canInc: questions < maxQuestions,
          onDec: (by) =>
              onQuestions((questions - by).clamp(minQuestions, maxQuestions)),
          onInc: (by) =>
              onQuestions((questions + by).clamp(minQuestions, maxQuestions)),
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
    required this.kind,
    required this.value,
    required this.onTyped,
    required this.step,
    required this.canDec,
    required this.canInc,
    required this.onDec,
    required this.onInc,
  });

  final String slug;
  final String label;
  final String display;

  /// Elle girişte hangi diyalog açılacak.
  final GoalValueKind kind;

  /// Diyaloga verilecek mevcut değer (süre için dakika).
  final int value;

  /// Elle girilen geçerli değer. Geçersizse HİÇ çağrılmıyor —
  /// eski değer korunuyor.
  final ValueChanged<int> onTyped;

  final int step;
  final bool canDec;
  final bool canInc;
  final ValueChanged<int> onDec;
  final ValueChanged<int> onInc;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            HoldRepeatButton(
              key: Key('onboarding-goal-$slug-dec'),
              icon: Icons.remove,
              enabled: canDec,
              step: step,
              onStep: onDec,
            ),
            // **Değere dokununca elle giriş açılıyor.** Stepper duruyor:
            // yakın değer için dokun, uzak değer için yaz.
            SizedBox(
              width: 88,
              child: InkWell(
                key: Key('onboarding-goal-$slug-edit'),
                onTap: () async {
                  final typed = await showGoalValueEditor(
                    context,
                    kind: kind,
                    current: value,
                  );
                  if (typed != null) onTyped(typed);
                },
                child: Padding(
                  // Dokunma hedefi en az 48 px yüksek olsun.
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    display,
                    key: Key('onboarding-goal-$slug-value'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
              ),
            ),
            HoldRepeatButton(
              key: Key('onboarding-goal-$slug-inc'),
              icon: Icons.add,
              enabled: canInc,
              step: step,
              onStep: onInc,
            ),
          ],
        ),
      ),
    );
  }
}
