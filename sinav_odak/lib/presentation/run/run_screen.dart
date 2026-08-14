import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/session_state.dart';
import '../ads/banner_ad_slot.dart';
import 'minimize_session.dart';
import 'pending_finish_controller.dart';
import '../../core/di/ad_providers.dart';

/// "Bitir" diyaloğunun üç yolu (FAZ 1.3).
///
/// v1.0'da yalnızca Vazgeç/Evet vardı: yanlışlıkla başlatılan bir oturumu
/// istatistiklere karıştırmadan kapatmanın hiçbir yolu yoktu.
enum EarlyFinishChoice {
  /// Oturuma devam et — hiçbir şey değişmez.
  keepGoing,

  /// Özet formuna git ve kaydet.
  save,

  /// Hiç kaydetme, oturumu sil (ikinci onaydan geçer).
  discard,
}

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
        // **Ön plandayken geçiş uygulamanın İÇİNDE olur (v1.0.2).**
        // Kullanıcı ekrana bakıyorsa haber kanalı sistem bildirimi değil,
        // bu şerit. Bildirim tarafını `ForegroundNotificationGuard`
        // susturuyor; burada kullanıcıyı bilgilendiriyoruz.
        //
        // Snackbar router'ın DIŞINDAKİ `ScaffoldMessenger`'a gidiyor, bu
        // yüzden hemen ardından gelen `context.go` onu düşürmüyor.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              key: const Key('phase-change-banner'),
              content: Text(L10n.of(context).breakStarted),
              duration: const Duration(seconds: 4),
            ),
          );
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
      // Geri tuşu oturumu BİTİRMEZ ve kazara çıkış olmaz; onay diyaloğundan
      // geçer. v1.0'da burada yalnızca "çıkamazsın" snackbar'ı vardı ve
      // kullanıcının hiçbir çıkış yolu yoktu (FAZ 1.1).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(confirmMinimizeSession(context, ref));
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Odaklı ekran: başlık yok, yalnızca çıkış kapısı.
          leading: IconButton(
            key: const Key('run-minimize'),
            icon: const Icon(Icons.arrow_back),
            tooltip: L10n.of(context).runMinimizeConfirm,
            onPressed: () => confirmMinimizeSession(context, ref),
          ),
        ),
        body: SafeArea(
          // FAZ 4.5 — yatay odak modu.
          //
          // Dikeyde sayaç ortada, kontroller altta. Yatayda ekran alçalıp
          // genişliyor: aynı düzen sayacı kontrollerin üstüne sıkıştırıp
          // okunmaz hâle getiriyordu. Yatayda sayaç ortada kalıyor,
          // kontroller SAĞA geçiyor.
          child: OrientationBuilder(
            builder: (context, orientation) => switch (state) {
              SessionInBlock() => _RunningBody(
                  state: state,
                  landscape: orientation == Orientation.landscape,
                ),
              SessionClockMovedBack() => const _ClockMovedBackBody(),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ),
      ),
    );
  }
}

class _RunningBody extends ConsumerWidget {
  const _RunningBody({required this.state, this.landscape = false});

  final SessionInBlock state;

  /// Yatay mod: sayaç ortada, kontroller sağda (FAZ 4.5).
  final bool landscape;

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
    final choice = await showDialog<EarlyFinishChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('run-early-dialog'),
        title: Text(l.runEarlyTitle),
        content: Text(
          l.runEarlyBody(
            formatDurationShort(state.schedule.totalStudyS),
            formatDurationShort(
              elapsedS.clamp(0, state.schedule.totalStudyS),
            ),
          ),
        ),
        // **Sıra kasıtlı: YIKICI eylem en solda, birincilden en uzakta.**
        //
        // İlk hâlinde "Sil" ortadaydı, yani "Kaydet"in hemen yanında.
        // Ekran görüntüsü incelemesinde (UX_REVIEW §1.3) görüldü ki dar
        // ekranda eylemler alt alta geçiyor ve "Sil" doğrudan "Kaydet"in
        // ÜSTÜNE düşüyor — yanlış dokunuş oturumu geri alınamaz şekilde
        // silebilirdi. Ayrıca hepsine 48 px asgari dokunma alanı verildi;
        // "Sil" çıplak metin olarak ~30 px genişliğindeydi.
        actions: [
          TextButton(
            key: const Key('run-early-delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(88, 48),
            ),
            onPressed: () => Navigator.of(ctx).pop(EarlyFinishChoice.discard),
            child: Text(l.runEarlyDelete),
          ),
          TextButton(
            key: const Key('run-early-continue'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(ctx).pop(EarlyFinishChoice.keepGoing),
            child: Text(l.runEarlyContinue),
          ),
          FilledButton(
            key: const Key('run-early-save'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(ctx).pop(EarlyFinishChoice.save),
            child: Text(l.runEarlySave),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    switch (choice) {
      case null:
      case EarlyFinishChoice.keepGoing:
        return;

      case EarlyFinishChoice.save:
        // Erken bitirmede süre, onayın verildiği ana kadar hesaplanır.
        ref.read(pendingFinishProvider.notifier).set(
              early: true,
              endMs: ref.read(clockProvider)(),
            );
        context.go(Routes.runSummary);

      case EarlyFinishChoice.discard:
        await _confirmDiscard(context, ref);
    }
  }

  /// Oturumu kaydetmeden siler. **İkinci onay şart:** geri alınamaz ve
  /// kullanıcının çalıştığı süre tamamen kaybolur.
  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('run-discard-dialog'),
        title: Text(l.runEarlyDeleteConfirmTitle),
        content: Text(l.runEarlyDeleteConfirmBody),
        actions: [
          TextButton(
            key: const Key('run-discard-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('run-discard-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 48),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.runEarlyDelete),
          ),
        ],
      ),
    );

    if (sure != true || !context.mounted) return;

    await ref.read(discardSessionProvider)(state.sessionId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('run-discarded-banner'),
        content: Text(l.runEarlyDeleted),
      ),
    );
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final schedule = state.schedule;
    final ordinal = schedule.studyOrdinalOf(state.blockIndex);
    final isLastBlock = state.blockIndex == schedule.blockCount - 1;

    // --- YATAY: sayaç ortada, kontroller sağ sütunda ---
    if (landscape) {
      final bannerPos = ref.watch(bannerPositionProvider);

      return Row(
        key: const Key('run-landscape'),
        children: [
          // FAZ 4.4 — "Yatayda yan" seçiliyse banner SOL sütunda.
          // Ayarın gerçekten bir etkisi olması şart: hiçbir yerde
          // okunmayan bir ayar, bu projede defalarca sessiz hataya yol
          // açtı (keepScreenOn, daily_stats, achievements...).
          if (bannerPos == BannerPosition.sideLandscape)
            const SizedBox(
              width: 120,
              child: Center(
                child: BannerAdSlot(placement: AdPlacement.runBanner),
              ),
            ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BlockChips(
                  total: schedule.studyBlockCount,
                  current: ordinal,
                  label: l.runBlockOf(ordinal, schedule.studyBlockCount),
                ),
                const SizedBox(height: 16),
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
              ],
            ),
          ),
          // Kontroller sağ sütunda, dikey yığın.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastBlock ? l.runLastBlock : l.runNextBreak,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAndStartSummary(context, ref),
                    icon: const Icon(Icons.stop),
                    label: Text(l.runFinish),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: null,
                    child: Text(l.runSkipBreak),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // --- DİKEY: v1.0 düzeni ---
    return Column(
      children: [
        if (ref.watch(bannerPositionProvider) == BannerPosition.top) ...[
          const BannerAdSlot(placement: AdPlacement.runBanner),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
        // FAZ 2.4 — kademe çipleri.
        //
        // Eskiden düz metindi ("1. blok / 2"). Çipler ilerlemeyi bir
        // bakışta veriyor: geçilen bloklar dolu, aktif olan vurgulu,
        // gelecekler soluk. Metin de erişilebilirlik için duruyor.
        _BlockChips(
          total: schedule.studyBlockCount,
          current: ordinal,
          label: l.runBlockOf(ordinal, schedule.studyBlockCount),
        ),
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
        // Konum "üst" ise banner yukarıda çizildi; burada tekrar yok.
        if (ref.watch(bannerPositionProvider) != BannerPosition.top) ...[
          const BannerAdSlot(placement: AdPlacement.runBanner),
          const SizedBox(height: 16),
        ],

        _ControlBar(onFinish: () => _confirmAndStartSummary(context, ref)),
      ],
    );
  }
}

/// Cihaz saati geriye alındığında gösterilir.
/// Çalışma bloğu kademe göstergesi (FAZ 2.4).
///
/// `Wrap` kullanılıyor: 10+ bloklu uzun planlarda çipler alt satıra
/// geçiyor, `Row` olsaydı taşardı.
class _BlockChips extends StatelessWidget {
  const _BlockChips({
    required this.total,
    required this.current,
    required this.label,
  });

  final int total;

  /// 1 tabanlı sıra. 0 = şu an molada.
  final int current;

  /// Ekran okuyucuya okunacak metin ("1. blok / 3").
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        children: [
          // **Metin KALIYOR.** İlk denemede yalnızca çipler bırakılmıştı;
          // ekran görüntüsünde görüldü ki gören kullanıcı "kaçıncı blok"
          // bilgisini tamamen kaybediyor — çipler konumu veriyor ama
          // sayıyı vermiyor (UX_REVIEW FAZ 2 §2.4).
          Text(label),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 1; i <= total; i++)
                Container(
                  key: Key('block-chip-$i'),
                  width: i == current ? 26 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: switch (i) {
                      _ when i == current => scheme.primary,
                      _ when i < current => scheme.primary.withOpacity(0.45),
                      _ => scheme.outlineVariant,
                    },
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

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
