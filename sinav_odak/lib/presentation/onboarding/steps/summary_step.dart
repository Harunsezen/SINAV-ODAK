import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/utils/formatters.dart';
import '../../../domain/entities/enums.dart';
import 'exam_step.dart';

/// Onboarding 5/5 — Özet.
///
/// Kullanıcı [Başla]'ya basmadan önce ne kaydedileceğini görür; rıza
/// tercihinin de burada tekrar görünmesi KVKK açısından bilinçli
/// (kullanıcı neyi onayladığını hatırlamalı).
///
/// v1.2'de i18n (FAZ 6 / K7).
class SummaryStep extends StatelessWidget {
  const SummaryStep({
    required this.examType,
    required this.minutes,
    required this.questions,
    required this.consent,
    super.key,
  });

  final ExamType? examType;
  final int minutes;
  final int questions;
  final bool consent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding-step-summary'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          L10n.of(context).onboardingSummaryTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).onboardingSummaryNote,
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(L10n.of(context).onboardingSummaryExam),
                trailing: Text(
                  examType == null
                      ? '—'
                      : ExamStep.labelOf(L10n.of(context), examType!),
                  key: const Key('onboarding-summary-exam'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(L10n.of(context).onboardingSummaryMinutes),
                trailing: Text(
                  formatDurationShort(minutes * 60),
                  key: const Key('onboarding-summary-minutes'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(L10n.of(context).onboardingSummaryQuestions),
                trailing: Text(
                  '$questions',
                  key: const Key('onboarding-summary-questions'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(L10n.of(context).onboardingAdsTitle),
                trailing: Text(
                  consent
                      ? L10n.of(context).commonOn
                      : L10n.of(context).commonOff,
                  key: const Key('onboarding-summary-consent'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
