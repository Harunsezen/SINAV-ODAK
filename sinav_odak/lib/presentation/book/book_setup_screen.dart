import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/app_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/l10n/format_l10n.dart';
import '../../core/router/routes.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/book_input.dart';
import '../goals/hold_repeat_button.dart';
import 'book_controller.dart';
import 'book_value_editor.dart';

/// S20 — KİTAP OKUMA KURULUMU (v1.3).
///
/// ## İki mod, tek ekran
///
/// | Mod | Önceden belirlenen | Sayaç |
/// | --- | --- | --- |
/// | **Süre** | okuma süresi | geri sayar, süre dolunca biter |
/// | **Sayfa hedefi** | sayfa sayısı | ileri sayar, bitişi kullanıcı verir |
///
/// Ayrı iki ekrana bölünmedi: aradaki tek fark girilen sayı ve birimi.
/// İki ekran, kullanıcının "hangisindeydim" diye başa dönmesi demekti.
///
/// ## Değer girmenin ÜÇ yolu (koordinatör kuralı)
///
/// ```
/// sayıya dokun   → klavye açılır        (uzak değer: 30 → 90)
/// [+] tek dokunuş → +5 dk / +5 sayfa    (yakın değer)
/// [+] basılı tut  → akan sayaç, hızlanır (arada kalan değer)
/// ```
///
/// Üçü de aynı sayıyı gösteriyor; hangisini kullanırsa kullansın kullanıcı
/// aynı yere varıyor. Akan sayaç `HoldRepeatButton` — hedef ekranında
/// yazılmış ve test edilmiş bileşen.
///
/// ## Doğru/yanlış YOK
///
/// Ekranın altındaki not bunu açıkça söylüyor: kitap oturumu süre ve
/// sayfa ölçüyor. Kullanıcı oturum sonunda soru sayacı arayıp bulamasın.
class BookSetupScreen extends ConsumerStatefulWidget {
  const BookSetupScreen({super.key});

  /// Testlerin ve QA turunun tutunduğu düğme.
  static const startKey = Key('book-start');

  @override
  ConsumerState<BookSetupScreen> createState() => _BookSetupScreenState();
}

class _BookSetupScreenState extends ConsumerState<BookSetupScreen> {
  bool _starting = false;

  Future<void> _start() async {
    final setup = ref.read(bookSetupProvider);
    setState(() => _starting = true);
    try {
      await ref.read(startBookSessionProvider)(
        sessionId: const Uuid().v4(),
        mode: setup.mode,
        nowMs: ref.read(clockProvider)(),
        durationS: setup.durationS,
        pageTarget: setup.pages,
      );
      ref.read(bookSetupProvider.notifier).reset();
      // Bitiş bağlamı yeni okumaya SIZMASIN: önceki oturumdan kalmış bir
      // `endMs`, sayaç ekranını açılır açılmaz forma yollardı.
      ref.read(pendingBookFinishProvider.notifier).clear();
      if (mounted) context.go(Routes.bookRun);
    } on AppFailure {
      if (!mounted) return;
      setState(() => _starting = false);
      // Ham `e.message` GÖSTERİLMİYOR: use-case mesajları Türkçe sabit,
      // arayüz iki dilli. Metin ARB'den geliyor.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('book-already-running'),
          content: Text(L10n.of(context).bookAlreadyRunning),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final setup = ref.watch(bookSetupProvider);
    final isDuration = setup.mode == BookMode.duration;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.bookSetupTitle),
        leading: IconButton(
          key: const Key('book-setup-back'),
          icon: const Icon(Icons.arrow_back),
          tooltip: l.commonBack,
          // `context.go` yığını değiştirdiği için `Navigator.canPop()`
          // daima false ve otomatik geri tuşu HİÇ çizilmiyor; önceki
          // adım açıkça veriliyor (kurulum akışıyla aynı çözüm).
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: ListView(
        key: const Key('book-setup-body'),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<BookMode>(
            key: const Key('book-mode'),
            segments: [
              ButtonSegment(
                value: BookMode.duration,
                icon: const Icon(Icons.timer_outlined),
                label: Text(l.bookModeDuration),
              ),
              ButtonSegment(
                value: BookMode.pageTarget,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l.bookModePages),
              ),
            ],
            selected: {setup.mode},
            onSelectionChanged: (s) =>
                ref.read(bookSetupProvider.notifier).selectMode(s.first),
          ),
          const SizedBox(height: 24),
          if (isDuration)
            _ValueCard(
              slug: 'duration',
              label: l.bookDurationLabel,
              hint: l.bookDurationHint,
              display: l.durationShort(setup.durationS),
              value: setup.minutes,
              min: BookInput.minDurationMinutes,
              max: BookInput.maxDurationMinutes,
              onChanged: ref.read(bookSetupProvider.notifier).setMinutes,
              kind: BookValueKind.minutes,
            )
          else
            _ValueCard(
              slug: 'pages',
              label: l.bookPagesLabel,
              hint: l.bookPagesHint,
              display: l.bookPagesUnit(setup.pages),
              value: setup.pages,
              min: BookInput.minPages,
              max: BookInput.maxPages,
              onChanged: ref.read(bookSetupProvider.notifier).setPages,
              kind: BookValueKind.pages,
            ),
          const SizedBox(height: 24),
          FilledButton(
            key: BookSetupScreen.startKey,
            onPressed: _starting ? null : _start,
            child: Text(l.bookStart),
          ),
          const SizedBox(height: 12),
          Text(
            l.bookNoQuestionsNote,
            key: const Key('book-no-questions-note'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Değer kartı: büyük sayı + [-] [+] + klavye.
class _ValueCard extends StatelessWidget {
  const _ValueCard({
    required this.slug,
    required this.label,
    required this.hint,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.kind,
  });

  final String slug;
  final String label;
  final String hint;

  /// Ekranda görünen biçimlenmiş değer ("45 dk", "20 sayfa").
  final String display;

  /// Ham değer — dakika veya sayfa.
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final BookValueKind kind;

  void _step(int delta) {
    final next = value + delta;
    onChanged(next < min ? min : (next > max ? max : next));
  }

  Future<void> _keyboard(BuildContext context) async {
    final result = await showBookValueEditor(
      context,
      kind: kind,
      current: value,
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('book-$slug-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                HoldRepeatButton(
                  key: Key('book-$slug-minus'),
                  icon: Icons.remove,
                  enabled: value > min,
                  onStep: (step) => _step(-step),
                ),
                // **Sayı dokunulabilir** (noktalı altı çizili): v1.2/A'da
                // hedef alanına eklenen "dokun ve yaz" ile aynı jest.
                Expanded(
                  child: InkWell(
                    key: Key('book-$slug-value'),
                    onTap: () => _keyboard(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          display,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                HoldRepeatButton(
                  key: Key('book-$slug-plus'),
                  icon: Icons.add,
                  enabled: value < max,
                  onStep: _step,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
