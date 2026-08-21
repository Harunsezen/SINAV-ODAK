import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';
import '../../../domain/entities/enums.dart';

/// Onboarding 1/5 — Vaat.
///
/// **Dil seçici burada** (v1.2/E): kullanıcının uygulamayla ilk teması bu
/// ekran. Dili ayrı bir 6. adım yapmak, ilk açılışta okuyamadığı bir dilde
/// "Devam" düğmesi arayan kullanıcıya bir ekran daha eklerdi; buraya
/// koymak aynı işi bir dokunuşla, sıfır ek adımla yapıyor.
///
/// Etiket iki dilde birden yazılı ("Dil / Language"): seçiciyi arayan
/// kişi, uygulamanın o an konuştuğu dili zaten anlamıyor olabilir.
class PromiseStep extends ConsumerWidget {
  const PromiseStep({super.key});

  static const languageKey = Key('onboarding-language');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final language = ref.watch(settingsStreamProvider).valueOrNull?.language ??
        AppLanguage.tr;

    return ListView(
      key: const Key('onboarding-step-promise'),
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l.onboardingLanguage,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(height: 4),
              SegmentedButton<AppLanguage>(
                key: languageKey,
                segments: [
                  ButtonSegment(
                    value: AppLanguage.tr,
                    label: Text(l.languageTurkish),
                  ),
                  ButtonSegment(
                    value: AppLanguage.en,
                    label: Text(l.languageEnglish),
                  ),
                ],
                selected: {
                  // "Sistem" ayarı bu seçicide GÖSTERİLMİYOR: ilk açılışta
                  // kullanıcı somut bir dil görmek istiyor, "sistem" ise
                  // hangi dile denk geldiği ekranda zaten yazılı. Ayarlar
                  // ekranında üç seçenek de var.
                  language == AppLanguage.en ? AppLanguage.en : AppLanguage.tr,
                },
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                onSelectionChanged: (v) =>
                    ref.read(settingsControllerProvider).setLanguage(v.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Icon(
          Icons.timer_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          l.onboardingPromiseTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(l.onboardingPromiseBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Text(
          l.onboardingPromiseRules,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
