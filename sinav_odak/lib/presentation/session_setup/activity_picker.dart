import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import 'setup_controller.dart';

/// S06 — Çalışma Türü Seç.
///
/// Özel tür ekleme bu turun kapsamı dışında (KARAR K4).
class ActivityPicker extends ConsumerWidget {
  const ActivityPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(activityTypesProvider);
    final setup = ref.watch(setupProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).setupActivityTitle),
        leading: IconButton(
          key: const Key('setup-back-activity'),
          icon: const Icon(Icons.arrow_back),
          tooltip: L10n.of(context).commonBack,
          // `context.go` yığını DEĞİŞTİRDİĞİ için `Navigator.canPop()`
          // daima false ve AppBar'ın otomatik geri tuşu HİÇ çizilmiyordu
          // (v1.0'da dört kurulum adımının hiçbirinde geri yoktu).
          // Bu yüzden önceki adım açıkça veriliyor.
          onPressed: () => context.go(Routes.sessionTopic),
        ),
      ),
      body: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(L10n.of(context).setupActivitiesFailed('$e'))),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              setup.topicName == null
                  ? setup.subjectName ?? ''
                  : L10n.of(context).setupBreadcrumb(
                      setup.subjectName ?? '',
                      setup.topicName ?? '',
                    ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in list)
                  ChoiceChip(
                    label: Text(t.name),
                    selected: setup.activityTypeId == t.id,
                    onSelected: (_) {
                      ref
                          .read(setupProvider.notifier)
                          .selectActivityType(id: t.id, name: t.name);
                      context.go(Routes.sessionPlan);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
