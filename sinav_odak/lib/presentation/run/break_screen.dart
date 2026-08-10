// DOĞRULANMADI — flutter test/analyze bekliyor.
// Gerekli komutlar (sırayla):
//   dart run build_runner build --delete-conflicting-outputs
//   flutter analyze
//   flutter test

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/app_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/session_state.dart';
import '../../domain/services/schedule_modifier.dart';
import '../ads/native_ad_slot.dart';
import 'run_controller.dart';

/// Mola ekranı İSKELETİ.
///
/// **Reklam açısından doğal an:** öğrenci zaten dinleniyor. Bu ekranda
/// büyük native kart gösterilebilir (Adım 6) — ancak:
/// - Ses **kapalı** başlar
/// - Kart 1200 ms gecikmeyle görünür (göz yormasın)
/// - Reklam ile butonlar arasında en az 48dp boşluk
/// - Mola 3 dakikadan kısaysa reklam gösterilmez
class BreakScreen extends ConsumerWidget {
  const BreakScreen({super.key});

  /// Molayı +5 dk uzatır.
  ///
  /// Limit aşımında domain `PlanFailure` fırlatır; kullanıcıya mesajı
  /// gösterilir. Buton zaten pasifleşiyor ama yarış durumuna karşı
  /// (iki hızlı dokunuş) burada da yakalanıyor.
  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(runControllerProvider).extendBreak();
    } on AppFailure catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runStateProvider);

    // Mola bitince otomatik olarak çalışma ekranına dön.
    if (state is SessionInBlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.run);
      });
    }

    if (state is! SessionInBreak) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final remainingExtensions =
        (ScheduleModifier.maxTotalExtensionS ~/ 300) - state.extensionsUsed;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.breakMode.withOpacity(0.08),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Text('MOLA'),
              const Spacer(),
              Text(
                formatClock(state.remainingSeconds),
                style: AppTheme.counterStyle,
              ),
              const SizedBox(height: 8),
              const Text('kalan mola'),
              const Spacer(),

              // Mola, reklam için doğal andır: öğrenci zaten dinleniyor.
              // Kurallar NativeAdSlot ve AdPolicyEngine içinde zorlanıyor:
              // ses KAPALI, 1200 ms gecikme, "Sponsorlu" etiketi,
              // butonlardan >= 48dp, mola 3 dakikadan kısaysa GÖSTERİLMEZ.
              const NativeAdSlot(
                key: Key('break-ad-slot'),
                placement: AdPlacement.breakNative,
              ),

              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(context).viewPadding.bottom + 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('break-extend'),
                        // Uzatma hakkı bitince pasifleşir (toplam +10 dk).
                        onPressed: remainingExtensions > 0
                            ? () => _extend(context, ref)
                            : null,
                        child: Text('+5 dk ($remainingExtensions hak)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('break-skip'),
                        onPressed: () =>
                            ref.read(runControllerProvider).skipBreak(),
                        child: const Text('Molayı Bitir'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
