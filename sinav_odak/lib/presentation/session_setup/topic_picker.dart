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
/// **Atlanabilir:** "Konu seçmeden devam et" ile konu listesi boş kalır.
/// Oturum konusuz da kaydedilebilir; şema bunu destekliyor.
///
/// v1.2/C'de düz liste yerine **üç seviyeli ağaç** geldi (müfredat
/// tohumlandıktan sonra bir derste 80'e yakın konu var).
///
/// ## v1.2/D — çoklu konu, tek dokunuşu BOZMADAN
///
/// Bir oturumda birden fazla konuya çalışılabiliyor. Ama yaygın durum
/// hâlâ tek konu ve o yol bir dokunuş olarak kalmalı:
///
/// | Eylem | Sonuç |
/// | --- | --- |
/// | **Satıra dokun** | o konu seçilir ve BİR SONRAKİ adıma geçilir (v1.1'deki gibi) |
/// | **Kutucuğa dokun** | konu listeye eklenir, ekranda kalınır |
/// | alt çubuktaki **Devam** | seçili listeyle ilerlenir |
///
/// Çoklu seçimi ayrı bir "moda" girmek gerekmiyor: kutucuk hep orada,
/// isteyen kullanır. Uzun basma gibi görünmez bir kısayola bağlanmadı —
/// keşfedilmeyen özellik, olmayan özellik.
class TopicPicker extends ConsumerWidget {
  const TopicPicker({super.key});

  static const continueKey = Key('topic-multi-continue');
  static const selectedBarKey = Key('topic-multi-bar');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final setup = ref.watch(setupProvider);
    final subjectId = setup.subjectId;

    if (subjectId == null) {
      // Doğrudan bu yola gelinmişse akışın başına dön.
      return _MissingSubject(onBack: () => context.go(Routes.sessionSubject));
    }

    final topics = ref.watch(topicsProvider(subjectId));
    final selected = setup.topicIds.toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(setup.subjectName ?? l.setupTopicTitle),
        leading: IconButton(
          key: const Key('setup-back-topic'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l.commonBack,
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
              error: (e, _) => Center(child: Text(l.setupTopicsFailed('$e'))),
              data: (list) => TopicTreeView(
                topics: list,
                selectedId: setup.topicId,
                emptyMessage: l.setupNoTopics,
                onTapTopic: (t) {
                  // Alt dal da seçilebiliyor: "Mitoz" çalışan kullanıcı
                  // oturumu "Hücre Bölünmeleri" diye kaydetmek zorunda
                  // kalmamalı. Şema açısından ikisi de bir konu satırı.
                  ref
                      .read(setupProvider.notifier)
                      .selectTopic(id: t.id, name: t.name);
                  context.go(Routes.sessionType);
                },
                trailingBuilder: (t) {
                  final on = selected.contains(t.id);
                  return IconButton(
                    key: Key('topic-check-${t.id}'),
                    tooltip: on ? l.setupTopicRemove : l.setupTopicAdd,
                    icon: Icon(
                      on ? Icons.check_box : Icons.check_box_outline_blank,
                      color: on ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onPressed: () => ref
                        .read(setupProvider.notifier)
                        .toggleTopic(id: t.id, name: t.name),
                  );
                },
              ),
            ),
          ),
          _BottomBar(names: setup.topicNames),
        ],
      ),
    );
  }
}

/// Alt çubuk: seçim yokken "atla", seçim varken "N konu · Devam".
///
/// İki ayrı düğme yan yana konmadı: seçim yokken "Devam" ne yapacağı
/// belirsiz bir düğme, seçim varken "atla" yanlışlıkla basılacak bir
/// tuzak. Duruma göre TEK birincil eylem var.
class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final hasSelection = names.isNotEmpty;
    final count = names.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSelection)
              Padding(
                key: TopicPicker.selectedBarKey,
                padding: const EdgeInsets.only(bottom: 8),
                // SAYI YETMİYOR: seçilen konu listede yukarı kayınca
                // kullanıcının elinde yalnızca "3 konu seçildi" kalıyordu
                // ve hangileri olduğunu görmek için listeyi baştan
                // taraması gerekiyordu. Adlar tek satırda, sığmazsa
                // kısaltılarak yazılıyor.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.setupTopicSelected(count),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      names.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.setupTopicMultiHint,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: hasSelection
                  ? FilledButton(
                      key: TopicPicker.continueKey,
                      onPressed: () => context.go(Routes.sessionType),
                      child: Text(l.setupTopicContinue),
                    )
                  : OutlinedButton(
                      key: const Key('topic-skip'),
                      onPressed: () {
                        ref.read(setupProvider.notifier).skipTopic();
                        context.go(Routes.sessionType);
                      },
                      child: Text(l.setupSkipTopic),
                    ),
            ),
          ],
        ),
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
