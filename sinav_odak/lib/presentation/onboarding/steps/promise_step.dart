import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Onboarding 1/5 — Vaat.
///
/// v1.2'de i18n: metinler `AppLocalizations`'a taşınacak (FAZ 6 / K7).
class PromiseStep extends StatelessWidget {
  const PromiseStep({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding-step-promise'),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.timer_outlined,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          L10n.of(context).onboardingPromiseTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          L10n.of(context).onboardingPromiseBody,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          L10n.of(context).onboardingPromiseRules,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
