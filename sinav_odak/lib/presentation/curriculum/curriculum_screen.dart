import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../data/local/database.dart';
import '../shell/app_shell.dart';
import 'topic_tree_view.dart';

/// MÜFREDAT — ders > konu > alt dal ağacını gezme ekranı.
///
/// ## Neden kurulum akışından ayrı bir ekran
///
/// Konu seçici bir oturum kurarken açılıyor ve tek iş yapıyor: konuyu
/// seçip ilerlemek. Müfredata bakmak ise oturum kurmadan yapılan bir iş —
/// "9. sınıf fizikte ne kalmış?" sorusunun cevabı. İkisini tek ekrana
/// sıkıştırmak, oturum kurmak isteyen kullanıcıyı işaretleme düğmeleriyle
/// yavaşlatırdı.
///
/// **Silme yok (G8).** Bu ekran yalnızca "çalışıldı" işaretini
/// değiştiriyor; konu ekleme/arşivleme KATALOG ekranında.
class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  static const subjectBarKey = Key('curriculum-subjects');

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  String? _subjectId;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.curriculumTitle)),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.curriculumPickSubject),
              ),
            );
          }

          // Seçili ders arşivlenmişse listeden düşüyor; ilk derse dön.
          final selected =
              list.any((s) => s.id == _subjectId) ? _subjectId! : list.first.id;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SubjectBar(
                subjects: list,
                selectedId: selected,
                onSelect: (id) => setState(() => _subjectId = id),
              ),
              const Divider(height: 1),
              Expanded(child: _Tree(subjectId: selected)),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({
    required this.subjects,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Subject> subjects;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Ağaçla aynı içerik sınırı: ders şeridi ekranın tamamına yayılıp
    // altındaki listeyle hizasını kaybetmesin.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppShell.maxContentWidth),
        child: SingleChildScrollView(
          key: CurriculumScreen.subjectBarKey,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final s in subjects)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('curriculum-subject-${s.id}'),
                    label: Text(s.name),
                    selected: s.id == selectedId,
                    onSelected: (_) => onSelect(s.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tree extends ConsumerWidget {
  const _Tree({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final topics = ref.watch(topicsProvider(subjectId));

    return topics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) => TopicTreeView(
        // Ders değişince ağacın arama kutusu ve açık dalları sıfırlansın:
        // önceki dersin araması yeni derste sessizce boş liste gösteriyordu.
        key: ValueKey(subjectId),
        topics: list,
        onTapTopic: (t) => _toggle(ref, t),
        trailingBuilder: (t) => IconButton(
          key: Key('curriculum-done-${t.id}'),
          tooltip: t.isCompleted
              ? l.curriculumMarkNotStudied
              : l.curriculumMarkStudied,
          icon: Icon(
            t.isCompleted ? Icons.check_circle : Icons.circle_outlined,
          ),
          onPressed: () => _toggle(ref, t),
        ),
      ),
    );
  }

  void _toggle(WidgetRef ref, Topic t) {
    ref
        .read(subjectDaoProvider)
        .setTopicCompleted(t.id, completed: !t.isCompleted);
  }
}
