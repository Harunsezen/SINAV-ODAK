import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/enums.dart';

/// Kitap okuma akışının ekranlar arası state'i (v1.3).
///
/// `setup_controller.dart` ve `pending_finish_controller.dart` ile aynı
/// desen: veri katmanına hiç dokunmuyor, yalnızca kurulum ekranı → sayaç
/// → oturum sonu formu arasında bilgi taşıyor.

// ---------------------------------------------------------------------------
// Kurulum seçimi
// ---------------------------------------------------------------------------

/// Kurulum ekranında biriken seçim.
///
/// **İki modun değeri AYRI tutuluyor.** Kullanıcı süre modunda 45 dakika
/// seçip sayfa moduna geçip geri döndüğünde 45'i orada bulmalı; tek alan
/// paylaşılsaydı "45 sayfa" ile "45 dakika" birbirinin üstüne yazardı.
class BookSetupSelection {
  const BookSetupSelection({
    this.mode = BookMode.duration,
    this.minutes = defaultMinutes,
    this.pages = defaultPages,
  });

  /// 30 dakika: hazır plan şablonlarının (25+5) ortasına denk gelen,
  /// "bir oturumluk okuma" için makul bir başlangıç.
  static const defaultMinutes = 30;

  /// 20 sayfa — yarım saatlik okumanın kabaca karşılığı.
  static const defaultPages = 20;

  final BookMode mode;
  final int minutes;
  final int pages;

  int get durationS => minutes * 60;

  BookSetupSelection copyWith({BookMode? mode, int? minutes, int? pages}) {
    return BookSetupSelection(
      mode: mode ?? this.mode,
      minutes: minutes ?? this.minutes,
      pages: pages ?? this.pages,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BookSetupSelection &&
      other.mode == mode &&
      other.minutes == minutes &&
      other.pages == pages;

  @override
  int get hashCode => Object.hash(mode, minutes, pages);
}

class BookSetupNotifier extends Notifier<BookSetupSelection> {
  @override
  BookSetupSelection build() => const BookSetupSelection();

  void selectMode(BookMode mode) => state = state.copyWith(mode: mode);

  void setMinutes(int minutes) => state = state.copyWith(minutes: minutes);

  void setPages(int pages) => state = state.copyWith(pages: pages);

  /// Okuma başlatıldığında çağrılır: bir sonraki kurulum temiz açılsın.
  void reset() => state = const BookSetupSelection();
}

/// **autoDispose DEĞİL:** kurulum ekranı sayaç ekranına geçerken yıkılıyor.
final bookSetupProvider =
    NotifierProvider<BookSetupNotifier, BookSetupSelection>(
  BookSetupNotifier.new,
);

// ---------------------------------------------------------------------------
// Bitiş bağlamı — TEK KAYIT YOLU
// ---------------------------------------------------------------------------

/// Okumanın bittiği **an**.
///
/// "Bitti" onayı oturumu KAPATMAZ; yalnızca bu anı yazıp formu açar. Kayıt
/// formun KAYDET düğmesinden geçiyor. Bu alan olmasaydı kullanıcının kitap
/// adını yazma süresi okuma süresine eklenirdi (çalışma oturumundaki
/// KARAR D1'in aynısı).
typedef PendingBookFinish = ({int endMs});

class PendingBookFinishNotifier extends Notifier<PendingBookFinish?> {
  @override
  PendingBookFinish? build() => null;

  void set(int endMs) => state = (endMs: endMs);

  void clear() => state = null;
}

final pendingBookFinishProvider =
    NotifierProvider<PendingBookFinishNotifier, PendingBookFinish?>(
  PendingBookFinishNotifier.new,
);
