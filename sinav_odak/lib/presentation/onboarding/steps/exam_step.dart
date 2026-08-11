import 'package:flutter/material.dart';

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

  static String labelOf(ExamType t) => switch (t) {
        ExamType.yks => 'YKS',
        ExamType.lgs => 'LGS',
        ExamType.kpss => 'KPSS',
        ExamType.ales => 'ALES',
        ExamType.dgs => 'DGS',
        ExamType.other => 'Diğer',
      };

  static String descriptionOf(ExamType t) => switch (t) {
        ExamType.yks => 'Üniversite sınavı',
        ExamType.lgs => 'Liseye geçiş',
        ExamType.kpss => 'Kamu personeli',
        ExamType.ales => 'Akademik personel',
        ExamType.dgs => 'Dikey geçiş',
        ExamType.other => 'Kendi ders listeni kurarsın',
      };

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding-step-exam'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Hangi sınava hazırlanıyorsun?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Ders listen buna göre kurulur. Sonradan ayarlardan '
          'değiştirebilirsin.',
          style: TextStyle(fontSize: 12),
        ),
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
                title: Text(labelOf(t)),
                subtitle: Text(descriptionOf(t)),
                trailing: selected == t ? const Icon(Icons.check) : null,
                onTap: () => onSelect(t),
              ),
            ),
          ),
      ],
    );
  }
}
