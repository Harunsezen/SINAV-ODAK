import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../curriculum/topic_tree_view.dart';
import 'setup_controller.dart';

/// S05 — Konu Seç.
///
/// **Atlanabilir:** "Konu seçmeden devam et" ile `topicId` null kalır.
/// Oturum konusuz da kaydedilebilir; şema bunu destekliyor.
///
/// v1.2'de düz liste yerine **üç seviyeli ağaç**: müfredat tohumlandıktan
/// sonra bir derste 80'e yakın konu var ve düz liste okunamaz hâle geldi.
/// Arama ve seviye sekmeleri [TopicTreeView] içinde.
class TopicPicker extends ConsumerWidget {
  const TopicPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(setupProvider);
    final subjectId = setup.subjectId;

    if (subjectId == null) {
      // Doğrudan bu yola gelinmişse akışın başına dön.
      return _MissingSubject(onBack: () => context.go(Routes.sessionSubject));
    }

    final topics = ref.watch(topicsProvider(subjectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(setup.subjectName ?? L10n.of(context).setupTopicTitle),
        leading: IconButton(
          key: const Key('setup-back-topic'),
          icon: const Icon(Icons.arrow_back),
          tooltip: L10n.of(context).commonBack,
          // `context.go` yığını DEĞİŞTİRDİĞİ için `Navigator.canPop()`
          // daima false ve AppBar'ın otomatik geri tuşu HİÇ çizilmiyordu
          // (v1.0'da dört kurulum adımının hiçbirinde geri yoktu).
          // Bu yüzden önceki adım açıkça veriliyor.
          onPressed: () => context.go(Routes.sessionSubject),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: topics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(L10n.of(context).setupTopicsFailed('$e'))),
              data: (list) => TopicTreeView(
                topics: list,
                selectedId: setup.topicId,
                emptyMessage: L10n.of(context).setupNoTopics,
                onTapTopic: (t) {
                  // Alt dal da seçilebiliyor: "Mitoz" çalışan kullanıcı
                  // oturumu "Hücre Bölünmeleri" diye kaydetmek zorunda
                  // kalmamalı. Şema açısından ikisi de bir konu satırı.
                  ref
                      .read(setupProvider.notifier)
                      .selectTopic(id: t.id, name: t.name);
                  context.go(Routes.sessionType);
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('topic-skip'),
                  onPressed: () {
                    ref.read(setupProvider.notifier).skipTopic();
                    context.go(Routes.sessionType);
                  },
                  child: Text(L10n.of(context).setupSkipTopic),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingSubject extends StatelessWidget {
  const _MissingSubject({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(L10n.of(context).setupPickSubjectFirst),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onBack,
              child: Text(L10n.of(context).setupSubjectTitle),
            ),
          ],
        ),
      ),
    );
  }
}
