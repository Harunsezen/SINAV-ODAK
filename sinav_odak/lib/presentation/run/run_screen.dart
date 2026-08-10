import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/session_state.dart';
import 'run_controller.dart';

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
          const SnackBar(
            content: Text('Oturumu bitirmek için "Bitir"e bas.'),
            duration: Duration(seconds: 2),
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
  Future<void> _confirmAndFinish(BuildContext context, WidgetRef ref) async {
    final elapsedS =
        state.schedule.totalStudyS - state.remainingMs ~/ 1000;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oturumu bitirelim mi?'),
        content: Text(
          '${formatDurationShort(state.schedule.totalStudyS)} planın '
          '${formatDurationShort(elapsedS.clamp(0, state.schedule.totalStudyS))} '
          'kadarı tamamlandı.\n'
          "Bu oturum 'erken bitirildi' olarak kaydedilecek.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Evet, bitir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(runControllerProvider).finish(
          sessionId: state.sessionId,
          early: true,
        );

    if (context.mounted) context.go(Routes.runSummary);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = state.schedule;
    final ordinal = schedule.studyOrdinalOf(state.blockIndex);
    final isLastBlock = state.blockIndex == schedule.blockCount - 1;

    return Column(
      children: [
        const SizedBox(height: 16),
        Text('$ordinal. blok / ${schedule.studyBlockCount}'),
        const Spacer(),
        Text(
          formatClock(state.remainingSeconds),
          style: AppTheme.counterStyle,
        ),
        const SizedBox(height: 8),
        const Text('kalan'),
        const SizedBox(height: 16),
        Text(
          isLastBlock ? 'Son blok' : 'Sonraki: mola',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Spacer(),

        // ADIM 6: buraya YALNIZCA ince banner gelebilir. Tam ekran reklam
        // bu ekranda ASLA gösterilmez; kontrol AdGateway içinde
        // `isInStudyBlock` ile zorlanacak.
        const SizedBox(height: 16),

        _ControlBar(onFinish: () => _confirmAndFinish(context, ref)),
      ],
    );
  }
}

/// Cihaz saati geriye alındığında gösterilir.
class _ClockMovedBackBody extends StatelessWidget {
  const _ClockMovedBackBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Cihaz saati değişmiş görünüyor.\n'
          'Oturumun doğru sürdürülebilmesi için saati kontrol et.',
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
              label: const Text('Bitir'),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            // Çalışma sırasında PASİF; yalnızca molada aktif olur.
            child: OutlinedButton(
              onPressed: null,
              child: Text('Molayı Atla'),
            ),
          ),
        ],
      ),
    );
  }
}
