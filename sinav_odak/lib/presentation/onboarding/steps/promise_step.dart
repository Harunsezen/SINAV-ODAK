import 'package:flutter/material.dart';

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
          'Sınav Odak',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Ne kadar çalıştığını tahmin etmeyi bırak.\n'
          'Süre tut, soru gir, gelişimini gör.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          'Sayaç duraklatılamaz: başladığın bloğu bitirirsin.\n'
          'Uygulama %100 ücretsizdir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
