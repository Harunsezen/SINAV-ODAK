// DOĞRULANMADI — flutter test/analyze bekliyor.
// Gerekli komutlar (sırayla):
//   dart run build_runner build --delete-conflicting-outputs
//   flutter analyze
//   flutter test

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';

/// Onboarding İSKELETİ.
///
/// Adım 4 kapsamında yalnızca `onboardingCompleted` bayrağını yazan minimal
/// hali var; router redirect'inin hedefi olması için gerekli.
///
/// **Adım 4'te tamamlanacak 5 adım:**
/// 1. Vaat ekranı
/// 2. Sınav türü seçimi (`examType` → seed ders seti)
/// 3. Günlük hedef (süre + soru)
/// 4. **UMP rıza formu** — KVKK/GDPR zorunlu, `personalizedAdsConsent`
///    varsayılan `false` kalmalı
/// 5. Bildirim izni (reddedilirse akış DURMAZ)
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sınav Odak',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ne kadar çalıştığını tahmin etmeyi bırak.\n'
                'Süre tut, soru gir, gelişimini gör.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const Text(
                'İSKELET — Adım 4: sınav türü, hedef, UMP rızası, '
                'bildirim izni adımları buraya gelecek.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  await ref.read(completeOnboardingProvider)();
                  if (context.mounted) context.go(Routes.home);
                },
                child: const Text('Başla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
