import 'package:flutter/material.dart';
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
      appBar: AppBar(title: Text(setup.subjectName ?? 'Konu Seç')),
      body: Column(
        children: [
          Expanded(
            child: topics.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Konular yüklenemedi: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Bu derste henüz konu yok.\n'
                        'Konu seçmeden devam edebilirsin.',
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
                  child: const Text('Konu seçmeden devam et'),
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
            const Text('Önce ders seçmen gerekiyor.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onBack, child: const Text('Ders Seç')),
          ],
        ),
      ),
    );
  }
}
