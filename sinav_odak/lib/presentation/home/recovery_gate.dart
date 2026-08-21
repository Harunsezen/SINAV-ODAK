import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/l10n/format_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/recovery_service.dart';
import '../../core/di/app_providers.dart';

/// S18 — Kurtarma diyaloğu kapısı (KARAR D2).
///
/// [pendingRecoveryProvider] açılışta `main()` içinde hesaplanıyordu ama
/// **hiçbir yerde tüketilmiyordu**: yarıda kalan oturum kullanıcıya hiç
/// sorulmadan `interrupted` yazılıyordu. Bu kapı ana paneli sarar ve sonucu
/// **tek kez** tüketir.
///
/// Dallar:
/// - `needsDecision` → oturum zaten `interrupted` olarak KAYITLIDIR.
///   [Koru] yalnızca diyaloğu kapatır; [Sil] kaydı tamamen siler.
///   (S4: etiket "Kaydet" idi; kayıt zaten yazılı olduğu için
///   "şimdi kaydedilecek" izlenimi veriyordu.)
/// - `clockMovedBack` → oturum hâlâ açıktır. [Devam et] kapatır;
///   [Oturumu kes] [RecoveryService.interruptNow] ile kapatır.
/// - `resume` → çizelge sürüyor; router zaten /run'a yönlendirir, diyalog yok.
class RecoveryGate extends ConsumerStatefulWidget {
  const RecoveryGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RecoveryGate> createState() => _RecoveryGateState();
}

class _RecoveryGateState extends ConsumerState<RecoveryGate> {
  @override
  void initState() {
    super.initState();
    // build içinde açılamaz: diyalog Navigator'a dokunur ve ana panel her
    // yeniden çizildiğinde yenisi kuyruğa girerdi.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consume());
  }

  Future<void> _consume() async {
    if (!mounted) return;
    if (ref.read(recoveryConsumedProvider)) return;

    final result = ref.read(pendingRecoveryProvider);
    final session = result.session;

    // Hangi dala girilirse girilsin sonuç tüketilmiş sayılır; aksi halde
    // sekme değişimlerinde diyalog tekrar tekrar açılırdı.
    ref.read(recoveryConsumedProvider.notifier).consume();

    if (session == null) return;

    switch (result.outcome) {
      case RecoveryOutcome.none:
      case RecoveryOutcome.resume:
        return;
      case RecoveryOutcome.needsDecision:
        await _askInterrupted(session.id, result.recoveredStudyS);
      case RecoveryOutcome.clockMovedBack:
        await _askClockMovedBack(session.id);
    }
  }

  Future<void> _askInterrupted(String sessionId, int recoveredStudyS) async {
    final l = L10n.of(context);
    final delete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('recovery-interrupted-dialog'),
        title: Text(l.recoveryInterruptedTitle),
        content: Text(
          l.recoveryInterruptedBody(l.durationShort(recoveredStudyS)),
        ),
        actions: [
          TextButton(
            key: const Key('recovery-delete'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.recoveryDelete),
          ),
          FilledButton(
            key: const Key('recovery-keep'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.recoveryKeep),
          ),
        ],
      ),
    );

    // Kayıt zaten `interrupted` olarak yazılı; "Koru" ek işlem gerektirmez.
    if (delete != true) return;
    await ref.read(sessionRepositoryProvider).delete(sessionId);
  }

  Future<void> _askClockMovedBack(String sessionId) async {
    final l = L10n.of(context);
    final stop = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('recovery-clock-dialog'),
        title: Text(l.recoveryClockTitle),
        content: Text(l.recoveryClockBody),
        actions: [
          TextButton(
            key: const Key('recovery-stop-session'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.recoveryStopSession),
          ),
          FilledButton(
            key: const Key('recovery-continue'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.recoveryContinue),
          ),
        ],
      ),
    );

    if (stop != true) return;
    await ref.read(recoveryServiceProvider).interruptNow(
          sessionId: sessionId,
          nowMs: ref.read(clockProvider)(),
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
