import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/l10n/format_l10n.dart';
import '../../core/router/routes.dart';
import '../../application/usecases/finish_book_session.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/book_input.dart';
import 'book_controller.dart';

/// S22 — OKUMA SONU FORMU (v1.3).
///
/// **Okuma oturumunun kaydedildiği TEK yer.** "Bitti" ve "Emin misin?"
/// onayı oturumu kapatmaz; yalnızca bitiş anını [pendingBookFinishProvider]
/// içine yazıp bu ekranı açar. Çalışma oturumundaki KARAR D1'in aynısı:
/// tek yazım, `daily_stats` bir kez hesaplanıyor.
///
/// **Bu ekranda REKLAM YOKTUR.** Kullanıcı veri girerken bölünmemeli;
/// oturum sonu formuyla aynı değişmez kural.
///
/// **Doğru/yanlış/net YOK.** Sorulan iki şey var: kitap adı (boş
/// bırakılabilir) ve okunan sayfa.
///
/// ## Geri tuşu kapalı
///
/// `PopScope(canPop: false)`: kullanıcı yazdığı kitap adını kazara geri
/// dokunuşuyla kaybetmemeli. Formdan çıkışın tek yolu KAYDET.
class BookSummaryForm extends ConsumerStatefulWidget {
  const BookSummaryForm({super.key});

  static const saveKey = Key('book-summary-save');

  @override
  ConsumerState<BookSummaryForm> createState() => _BookSummaryFormState();
}

class _BookSummaryFormState extends ConsumerState<BookSummaryForm> {
  final _titleCtrl = TextEditingController();
  final _pagesCtrl = TextEditingController(text: '0');

  int _pages = 0;
  bool _pagesCapped = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _pagesCtrl.dispose();
    super.dispose();
  }

  void _setPages(int value) {
    final clamped = BookInput.clampPagesRead(value);
    setState(() {
      _pages = clamped;
      _pagesCapped = value > BookInput.maxPages;
    });
    final text = clamped.toString();
    if (_pagesCtrl.text != text) {
      _pagesCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  Future<void> _save({
    required String sessionId,
    required int endMs,
    required int durationS,
  }) async {
    setState(() => _saving = true);
    final l = L10n.of(context);
    final duration = l.durationShort(durationS);

    try {
      await ref.read(finishBookSessionProvider)(
        sessionId: sessionId,
        nowMs: endMs,
        pagesRead: _pages,
        bookTitle: _titleCtrl.text,
      );
      ref.read(pendingBookFinishProvider.notifier).clear();
      // Okuma bitti: küçültme bayrağı sıfırlanmalı, yoksa bir sonraki
      // oturumda router "zaten küçültülmüş" sanardı.
      ref.read(sessionMinimizedProvider.notifier).restore();
      unawaited(ref.read(hapticGatewayProvider).success());

      if (!mounted) return;
      // Tebrik ekranı YOK: okuma oturumunda odak skoru ve rozet ekranı
      // yok, gösterilecek bir "skor" da yok. Onay tek satırda veriliyor.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('book-saved-banner'),
          content: Text(l.bookSummarySaved(_pages, duration)),
        ),
      );
      context.go(Routes.home);
    } on AppFailure catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final session = ref.watch(activeBookSessionProvider).valueOrNull;
    final pending = ref.watch(pendingBookFinishProvider);

    if (session == null || pending == null) {
      if (_saving) {
        return const Scaffold(
          key: Key('book-summary-saving'),
          body: Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        key: const Key('book-summary-empty'),
        body: Center(child: Text(l.bookSummaryEmpty)),
      );
    }

    // Gösterilen süre kaydedilen süreyle AYNI kaynaktan: iki ayrı hesap
    // yazılsaydı biri değiştiğinde ekran ile kayıt sessizce ayrışırdı.
    final durationS =
        FinishBookSessionUseCase.measuredDurationS(session, pending.endMs);

    final target = session.pageTarget;
    final isPageMode = session.mode == BookMode.pageTarget;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.bookSummaryTitle),
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          key: const Key('book-summary-form'),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              key: const Key('book-summary-header'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kartın başlığı SÜRENİN KENDİSİ.
                    //
                    // İlk halinde burada da "Okuma Bitti" yazıyordu ve
                    // ekran görüntüsünde başlık çubuğuyla birlikte aynı
                    // cümle iki kez görünüyordu. Kartın söyleyecek daha
                    // iyi bir şeyi var: ne kadar okundu.
                    Row(
                      children: [
                        const Icon(Icons.menu_book_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.bookSummaryDuration(l.durationShort(durationS)),
                            key: const Key('book-summary-duration'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (isPageMode && target != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        l.bookSummaryTargetLine(target, _pages),
                        key: const Key('book-summary-target'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pages >= target
                            ? l.bookSummaryTargetReached
                            : l.bookSummaryTargetMissed(target - _pages),
                        key: const Key('book-summary-target-diff'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _NameCard(controller: _titleCtrl),
            const SizedBox(height: 16),
            _PagesCard(
              controller: _pagesCtrl,
              capped: _pagesCapped,
              target: isPageMode ? target : null,
              onQuick: (add) => _setPages(_pages + add),
              onReset: () => _setPages(0),
              onManual: (text) => _setPages(int.tryParse(text.trim()) ?? 0),
              onTarget: target == null ? null : () => _setPages(target),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: BookSummaryForm.saveKey,
              onPressed: _saving
                  ? null
                  : () => _save(
                        sessionId: session.id,
                        endMs: pending.endMs,
                        durationS: durationS,
                      ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.commonSave),
            ),
            const SizedBox(height: 8),
            Text(
              l.summaryNoAds,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kitap adı — **boş bırakılabilir**.
class _NameCard extends StatelessWidget {
  const _NameCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.bookSummaryNameTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('book-summary-name'),
              controller: controller,
              maxLength: BookInput.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.bookSummaryNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            // Zorunlu olmadığı AÇIKÇA yazıyor: boş bırakılabilen bir alanın
            // yanında hiçbir şey yazmasa kullanıcı doldurmak zorunda
            // sanırdı.
            Text(
              l.bookSummaryNameHint,
              key: const Key('book-summary-name-hint'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Kaç sayfa okudun?" — hızlı düğmeler + elle giriş.
class _PagesCard extends StatelessWidget {
  const _PagesCard({
    required this.controller,
    required this.capped,
    required this.target,
    required this.onQuick,
    required this.onReset,
    required this.onManual,
    required this.onTarget,
  });

  final TextEditingController controller;
  final bool capped;

  /// Sayfa hedefi modunda hedef; süre modunda `null`.
  final int? target;
  final void Function(int add) onQuick;
  final VoidCallback onReset;
  final void Function(String text) onManual;

  /// "Hedefe ulaştım" — tek dokunuşla hedefi yazar.
  ///
  /// Alan hedefle ÖNCEDEN doldurulmuyor: kullanıcının okumadığı sayfayı
  /// varsayılan yapmak, hiç dokunmadan yanlış veri kaydetmesi demekti.
  /// Bu düğme aynı kolaylığı **açık bir eylem** olarak veriyor.
  final VoidCallback? onTarget;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.bookSummaryPagesTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('book-pages-plus5'),
                  onPressed: () => onQuick(5),
                  child: const Text('+5'),
                ),
                OutlinedButton(
                  key: const Key('book-pages-plus10'),
                  onPressed: () => onQuick(10),
                  child: const Text('+10'),
                ),
                OutlinedButton(
                  key: const Key('book-pages-plus20'),
                  onPressed: () => onQuick(20),
                  child: const Text('+20'),
                ),
                // **"20 sayfa" DEĞİL "Hedefe ulaştım".** İlk halinde
                // düğmenin üstünde hedefin kendisi ("20 sayfa") yazıyordu
                // ve hemen yanındaki "+20" ile karışıyordu: ekran
                // görüntüsünde ikisi aynı sıradaki iki artırma düğmesi
                // gibi okunuyor.
                if (onTarget != null && target != null)
                  OutlinedButton(
                    key: const Key('book-pages-target'),
                    onPressed: onTarget,
                    child: Text(l.bookSummaryReached),
                  ),
                TextButton(
                  key: const Key('book-pages-reset'),
                  onPressed: onReset,
                  child: Text(l.summaryReset),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('book-pages-field'),
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l.bookSummaryPagesLabel,
                border: const OutlineInputBorder(),
              ),
              onChanged: onManual,
            ),
            if (capped) ...[
              const SizedBox(height: 6),
              Text(
                l.bookInvalidPages,
                key: const Key('book-pages-capped'),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
