import 'package:flutter/material.dart';

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
          'Hazırsın',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Bunları sonradan ayarlardan değiştirebilirsin.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Sınav'),
                trailing: Text(
                  examType == null ? '—' : ExamStep.labelOf(examType!),
                  key: const Key('onboarding-summary-exam'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Günlük süre'),
                trailing: Text(
                  formatDurationShort(minutes * 60),
                  key: const Key('onboarding-summary-minutes'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Günlük soru'),
                trailing: Text(
                  '$questions',
                  key: const Key('onboarding-summary-questions'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Kişiselleştirilmiş reklam'),
                trailing: Text(
                  consent ? 'Açık' : 'Kapalı',
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
