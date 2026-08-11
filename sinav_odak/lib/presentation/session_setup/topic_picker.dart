import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import 'setup_controller.dart';

/// S05 — Konu Seç.
///
/// **Atlanabilir:** "Konu seçmeden devam et" ile `topicId` null kalır.
/// Oturum konusuz da kaydedilebilir; şema bunu destekliyor.
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
      ),
      body: Column(
        children: [
          Expanded(
            child: topics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(L10n.of(context).setupTopicsFailed('$e'))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        L10n.of(context).setupNoTopics,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return ListTile(
                      title: Text(t.name),
                      trailing: t.isCompleted
                          ? const Icon(Icons.check_circle, size: 20)
                          : null,
                      onTap: () {
                        ref
                            .read(setupProvider.notifier)
                            .selectTopic(id: t.id, name: t.name);
                        context.go(Routes.sessionType);
                      },
                    );
                  },
                );
              },
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
