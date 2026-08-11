import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/session_state.dart';
import '../ads/banner_ad_slot.dart';
import 'pending_finish_controller.dart';

/// Aktif çalışma ekranı (S08).
///
/// **Ürünün en katı ekranı. Değişmez kurallar:**
/// - **PAUSE BUTONU YOK.** Yalnızca "Oturumu Bitir" var ve onay ister.
/// - Geri tuşu yakalanır; kullanıcı kazara çıkamaz.
/// - Alt navigasyon gizlidir (route shell dışında tanımlı).
/// - **TAM EKRAN REKLAM ASLA GÖSTERİLMEZ.** Yalnızca kontrol çubuğunun
///   üstünde, 16dp boşlukla ayrılmış ince banner olabilir (Adım 6).
/// - "Molayı Atla" çalışma sırasında PASİFTİR.
///
/// Sayaç bir `Timer` değildir: [runStateProvider] her tikte
/// `ScheduleResolver.resolve(now)` ile yeniden hesaplanır.
class RunScreen extends ConsumerStatefulWidget {
  const RunScreen({super.key});

  @override
  ConsumerState<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends ConsumerState<RunScreen> {
  @override
  Widget build(BuildContext context) {
    // Otomatik geçişler `listen` ile yapılır: `build` içinde
    // addPostFrameCallback kullanılsaydı her yeniden çizimde (yani her
    // saniye) yeni bir gezinme kuyruğa girerdi.
    ref.listen<SessionState>(runStateProvider, (previous, next) {
      if (!mounted) return;
      if (next is SessionInBreak) {
        context.go(Routes.runBreak);
      } else if (next is SessionSummarizing) {
        // Çizelge normal bitti: bitiş anı planlanan bitiştir. Kullanıcı formu
        // ne kadar geç doldurursa doldursun kayıtlı süre değişmez (KARAR D1).
        ref.read(pendingFinishProvider.notifier).set(
              early: false,
              endMs: next.schedule.plannedEndAtMs,
            );
        context.go(Routes.runSummary);
      }
    });

    final state = ref.watch(runStateProvider);

    return PopScope(
      // Geri tuşu oturumu bitirmez; kullanıcı bilinçli olarak "Bitir"e basmalı.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).runBackBlocked),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (state) {
            SessionInBlock() => _RunningBody(state: state),
            SessionClockMovedBack() => const _ClockMovedBackBody(),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _RunningBody extends ConsumerWidget {
  const _RunningBody({required this.state});

  final SessionInBlock state;

  /// Erken bitirme onayı. Ürün kuralı: tek tıkla oturum kapanmaz.
  ///
  /// **Onay oturumu KAPATMAZ (KARAR D1).** Burada `finishSession`
  /// çağrılsaydı oturum, kullanıcı henüz soru sayılarını girmeden kapanır ve
  /// form ikinci bir yazım turu gerektirirdi. Onay yalnızca bitiş bağlamını
  /// [pendingFinishProvider]'a yazar; kayıt tek yoldan, formun KAYDET
  /// butonundan geçer.
  Future<void> _confirmAndStartSummary(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final elapsedS = state.schedule.totalStudyS - state.remainingMs ~/ 1000;

    final l = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.runConfirmTitle),
        content: Text(
          l.runConfirmBody(
            formatDurationShort(state.schedule.totalStudyS),
            formatDurationShort(
              elapsedS.clamp(0, state.schedule.totalStudyS),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.runConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.runConfirmYes),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Erken bitirmede süre, onayın verildiği ana kadar hesaplanır.
    ref.read(pendingFinishProvider.notifier).set(
          early: true,
          endMs: ref.read(clockProvider)(),
        );

    if (context.mounted) context.go(Routes.runSummary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final schedule = state.schedule;
    final ordinal = schedule.studyOrdinalOf(state.blockIndex);
    final isLastBlock = state.blockIndex == schedule.blockCount - 1;

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(l.runBlockOf(ordinal, schedule.studyBlockCount)),
        const Spacer(),
        // Sayaç ekran okuyucuya "24:00" diye okutulursa anlaşılmıyor;
        // canlı bölge olarak dakika/saniye sözle veriliyor.
        Semantics(
          liveRegion: true,
          label: l.a11yRemaining(
            state.remainingSeconds ~/ 60,
            state.remainingSeconds % 60,
          ),
          excludeSemantics: true,
          child: Text(
            formatClock(state.remainingSeconds),
            style: AppTheme.counterStyle,
          ),
        ),
        const SizedBox(height: 8),
        Text(l.runRemaining),
        const SizedBox(height: 16),
        Text(
          isLastBlock ? l.runLastBlock : l.runNextBreak,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),

        // Bu ekranda YALNIZCA ince banner olabilir. Tam ekran reklam burada
        // ASLA gösterilmez; kontrol AdPolicyEngine ve AdGateway içinde
        // `isInStudyBlock` ile zorlanıyor, çağıran katmanda değil.
        const BannerAdSlot(placement: AdPlacement.runBanner),
        const SizedBox(height: 16),

        _ControlBar(onFinish: () => _confirmAndStartSummary(context, ref)),
      ],
    );
  }
}

/// Cihaz saati geriye alındığında gösterilir.
class _ClockMovedBackBody extends StatelessWidget {
  const _ClockMovedBackBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          L10n.of(context).runClockMovedBack,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Alt kontrol çubuğu.
///
/// **"Durdur" butonu YOKTUR** ve eklenmeyecektir. Regresyon testi bu ekranda
/// `find.text('Durdur')` ve `find.byIcon(Icons.pause)` aramalarının
/// `findsNothing` dönmesini bekler.
class _ControlBar extends StatelessWidget {
  const _ControlBar({required this.onFinish});

  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.stop),
              label: Text(l.runFinish),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            // Çalışma sırasında PASİF; yalnızca molada aktif olur.
            child: OutlinedButton(
              onPressed: null,
              child: Text(l.runSkipBreak),
            ),
          ),
        ],
      ),
    );
  }
}
