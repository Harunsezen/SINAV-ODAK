import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/l10n/format_l10n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/book_run_calculator.dart';
import 'book_controller.dart';

/// "Bitti" onayının üç yolu.
enum BookFinishChoice {
  /// Okumaya devam — hiçbir şey değişmez, sayaç durmaz.
  keepReading,

  /// Oturum sonu formuna git.
  finish,

  /// Hiç kaydetme, oturumu sil (ikinci onaydan geçer).
  discard,
}

/// S21 — OKUMA SAYACI (v1.3).
///
/// **Çalışma ekranının kurallarını aynen izliyor:**
/// - **PAUSE BUTONU YOK.** Sayaç duvar saatiyle işliyor; duraklatılabilecek
///   bir sayaç zaten yok (bkz. `BookRunCalculator`).
/// - Geri tuşu yakalanıyor; kullanıcı kazara çıkamıyor.
/// - Alt navigasyon gizli (route shell dışında).
/// - Tam ekran reklam YOK.
///
/// **Reklam hiç yok, banner bile.** Çalışma ekranında ince banner var;
/// burada o da yok: kitap okuyan öğrencinin ekranı, okuduğu sürenin
/// tamamı boyunca açık kalıyor ve sürekli görünen bir reklam alanı
/// olurdu. Karar bilinçli, unutulmuş bir alan değil.
///
/// ## İki mod, iki sayaç yönü
///
/// | Mod | Sayaç | Bitiş |
/// | --- | --- | --- |
/// | Süre | GERİ sayar | süre dolunca kendiliğinden forma gider |
/// | Sayfa hedefi | İLERİ sayar | yalnızca "Bitti" ile |
class BookRunScreen extends ConsumerStatefulWidget {
  const BookRunScreen({super.key});

  static const finishKey = Key('book-run-finish');

  @override
  ConsumerState<BookRunScreen> createState() => _BookRunScreenState();
}

class _BookRunScreenState extends ConsumerState<BookRunScreen> {
  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final session = ref.watch(activeBookSessionProvider).valueOrNull;
    final snapshot = ref.watch(bookRunSnapshotProvider);

    if (session == null || snapshot == null) {
      return const Scaffold(
        key: Key('book-run-empty'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // SÜRE DOLDU → forma.
    //
    // `build` içinde doğrudan `context.go` çağrılsaydı her saniyelik
    // yeniden çizimde yeni bir gezinme kuyruğa girerdi; tek karelik
    // geri çağrı ve `pendingBookFinish` bayrağı ikisi birden koruyor.
    if (snapshot.expired && ref.read(pendingBookFinishProvider) == null) {
      final endMs = session.startedAt + (session.plannedDurationS ?? 0) * 1000;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Kaydedilen süre, sayacın DOLDUĞU ana dayanıyor — kullanıcının
        // ekrana ne zaman döndüğüne değil.
        ref.read(pendingBookFinishProvider.notifier).set(endMs);
        context.go(Routes.bookSummary);
      });
    }

    final isDuration = session.mode == BookMode.duration;
    final counter = isDuration ? snapshot.remainingS ?? 0 : snapshot.elapsedS;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_confirmMinimize(context));
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const Key('book-run-minimize'),
            icon: const Icon(Icons.arrow_back),
            tooltip: l.runMinimizeConfirm,
            onPressed: () => _confirmMinimize(context),
          ),
        ),
        body: SafeArea(
          // **`width: double.infinity` ŞART.** `Scaffold` gövdeye GEVŞEK
          // genişlik veriyor (`0 <= w <= 411`), tam genişlik değil. Bu
          // `Column` en geniş çocuğu kadar daralıyordu: ekran görüntüsü
          // denetiminde sayaç ekranın soluna yapışmış ve "23:00"un ilk
          // hanesi kırpılmış çıktı. Çalışma ekranında sorun görünmüyor
          // çünkü orada tam genişlik kaplayan bir çocuk (banner) var —
          // yani orada da kural yazılı değil, tesadüf.
          child: SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                const Spacer(),
                Icon(
                  Icons.menu_book_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  label: l.a11yRemaining(counter ~/ 60, counter % 60),
                  excludeSemantics: true,
                  // `FittedBox`: 320 px'te ve büyük yazı ölçeğinde 72
                  // punto sayaç ekrana sığmıyor. Sarmak yerine küçültmek
                  // rakamı bütün bırakıyor — ana paneldeki `_Metric` ile
                  // aynı ders.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        formatClock(counter),
                        key: const Key('book-run-counter'),
                        maxLines: 1,
                        softWrap: false,
                        style: AppTheme.counterStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isDuration ? l.bookRunRemaining : l.bookRunElapsed,
                  key: const Key('book-run-counter-label'),
                ),
                const SizedBox(height: 16),
                if (!isDuration && session.pageTarget != null)
                  Text(
                    l.bookRunTarget(session.pageTarget!),
                    key: const Key('book-run-target'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (snapshot.capped)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Text(
                      l.bookRunCapped,
                      key: const Key('book-run-capped'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: OutlinedButton.icon(
                    key: BookRunScreen.finishKey,
                    onPressed: () => _confirmFinish(context, snapshot),
                    icon: const Icon(Icons.stop),
                    label: Text(l.bookRunFinish),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Emin misin?" — koordinatörün istediği onay.
  ///
  /// **Hayır → hiçbir şey kaybolmaz.** Diyalog kapanır, sayaç kaldığı
  /// yerden görünür (zaten hiç durmadı — duvar saatiyle işliyor), oturum
  /// açık kalır. Onayın yıkıcı olmayan tarafı kesinlikle veri
  /// kaybettirmemeli.
  ///
  /// **Sil** seçeneği çalışma oturumundaki FAZ 1.3 kararının aynısı:
  /// yanlışlıkla başlatılan bir okuma istatistiğe ve seriye karışmamalı.
  /// Sıra kasıtlı — yıkıcı eylem en solda, birincilden en uzakta.
  Future<void> _confirmFinish(
    BuildContext context,
    BookRunSnapshot snapshot,
  ) async {
    final l = L10n.of(context);
    final choice = await showDialog<BookFinishChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('book-sure-dialog'),
        title: Text(l.bookRunSureTitle),
        content: Text(l.bookRunSureBody(l.durationShort(snapshot.elapsedS))),
        actions: [
          TextButton(
            key: const Key('book-sure-delete'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(88, 48),
            ),
            onPressed: () => Navigator.of(ctx).pop(BookFinishChoice.discard),
            child: Text(l.bookRunDiscard),
          ),
          TextButton(
            key: const Key('book-sure-no'),
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () =>
                Navigator.of(ctx).pop(BookFinishChoice.keepReading),
            child: Text(l.bookRunSureNo),
          ),
          FilledButton(
            key: const Key('book-sure-yes'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(ctx).pop(BookFinishChoice.finish),
            child: Text(l.bookRunSureYes),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    switch (choice) {
      case null:
      case BookFinishChoice.keepReading:
        // Hiçbir şey olmuyor: oturum açık, süre duruyor, veri yerinde.
        return;

      case BookFinishChoice.finish:
        // Süre onayın verildiği ana kadar hesaplanıyor; formu doldurma
        // süresi okumaya eklenmiyor.
        ref
            .read(pendingBookFinishProvider.notifier)
            .set(ref.read(clockProvider)());
        context.go(Routes.bookSummary);

      case BookFinishChoice.discard:
        await _confirmDiscard(context);
    }
  }

  /// Kaydetmeden siler. **İkinci onay şart:** geri alınamaz.
  Future<void> _confirmDiscard(BuildContext context) async {
    final l = L10n.of(context);
    final sessionId = ref.read(activeBookSessionProvider).valueOrNull?.id;
    if (sessionId == null) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('book-discard-dialog'),
        title: Text(l.bookRunDiscardTitle),
        content: Text(l.bookRunDiscardBody),
        actions: [
          TextButton(
            key: const Key('book-discard-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('book-discard-confirm'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 48),
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.bookRunDiscard),
          ),
        ],
      ),
    );

    if (sure != true || !context.mounted) return;

    await ref.read(discardBookSessionProvider)(sessionId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const Key('book-discarded-banner'),
        content: Text(l.bookRunDiscarded),
      ),
    );
    context.go(Routes.home);
  }

  /// Okumayı arka plana alma onayı.
  ///
  /// Çalışma oturumundaki `confirmMinimizeSession` ile aynı metin ve aynı
  /// bayrak (`sessionMinimizedProvider`): router iki katman için de aynı
  /// izni okuyor. İki ayrı bayrak, "hangisi küçültülmüştü" sorusunu
  /// cevaplamak zorunda kalan bir yönlendirme demekti.
  Future<void> _confirmMinimize(BuildContext context) async {
    final l = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('book-minimize-dialog'),
        title: Text(l.runMinimizeTitle),
        content: Text(l.runMinimizeBody),
        actions: [
          TextButton(
            key: const Key('book-minimize-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('book-minimize-confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.runMinimizeConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    ref.read(sessionMinimizedProvider.notifier).minimize();
    context.go(Routes.home);
  }
}
