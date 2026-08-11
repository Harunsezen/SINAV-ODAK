import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../domain/entities/enums.dart';

/// Onboarding 2/5 — Sınav türü.
///
/// Seçim `subjectsProvider`'a filtre olarak akar: LGS öğrencisine YKS
/// dersleri gösterilmemeli. Bu yüzden **seçim zorunludur** ve seçilmeden
/// ileri butonu pasif kalır.
///
/// v1.2'de i18n (FAZ 6 / K7).
class ExamStep extends StatelessWidget {
  const ExamStep({required this.selected, required this.onSelect, super.key});

  final ExamType? selected;
  final ValueChanged<ExamType> onSelect;

  static String labelOf(L10n l, ExamType t) => switch (t) {
        ExamType.yks => l.examYks,
        ExamType.lgs => l.examLgs,
        ExamType.kpss => l.examKpss,
        ExamType.ales => l.examAles,
        ExamType.dgs => l.examDgs,
        ExamType.other => l.examOther,
      };

  static String descriptionOf(L10n l, ExamType t) => switch (t) {
        ExamType.yks => l.examYksNote,
        ExamType.lgs => l.examLgsNote,
        ExamType.kpss => l.examKpssNote,
        ExamType.ales => l.examAlesNote,
        ExamType.dgs => l.examDgsNote,
        ExamType.other => l.examOtherNote,
      };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ListView(
      key: const Key('onboarding-step-exam'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l.onboardingExamTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l.onboardingExamNote, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 20),
        for (final t in ExamType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              color: selected == t
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                key: Key('onboarding-exam-${t.name}'),
                title: Text(labelOf(l, t)),
                subtitle: Text(descriptionOf(l, t)),
                trailing: selected == t ? const Icon(Icons.check) : null,
                onTap: () => onSelect(t),
              ),
            ),
          ),
      ],
    );
  }
}
