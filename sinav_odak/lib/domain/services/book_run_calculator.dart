// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import 'book_input.dart';

/// Okuma sayacının bir andaki görüntüsü.
class BookRunSnapshot {
  const BookRunSnapshot({
    required this.elapsedS,
    required this.remainingS,
    required this.expired,
    required this.capped,
  });

  /// Başlangıçtan bu yana geçen, **tavana çekilmiş** süre.
  final int elapsedS;

  /// Süre modunda kalan saniye. Sayfa modunda `null` — o modda planlanmış
  /// bir bitiş YOK ve uydurulmuyor.
  final int? remainingS;

  /// Süre modunda süre doldu mu?
  final bool expired;

  /// Ölçülen süre `BookInput.maxReadingS` tavanına dayandı mı?
  ///
  /// Arayüz bunu kullanıcıya **söylüyor**. Sessiz kırpma, sayacı açık
  /// unutan kullanıcının farkında olmadan yanlış veri kaydetmesi demekti.
  final bool capped;
}

/// Okuma sayacı — **`Timer` değil, duvar saati**.
///
/// Çalışma oturumundaki `ScheduleResolver` ile aynı ilke: durum
/// saklanmıyor, her karede `now - startedAt` ile yeniden hesaplanıyor.
/// Ticker dursa, gecikse veya uygulama tamamen kapansa bile süre doğru
/// kalıyor — ve "pause yok" kuralı kendiliğinden korunuyor, çünkü
/// duraklatılabilecek bir sayaç yok.
abstract final class BookRunCalculator {
  static BookRunSnapshot resolve({
    required int startedAtMs,
    required int nowMs,
    int? plannedDurationS,
  }) {
    // Cihaz saati geriye alındıysa negatif süre çıkar; 0'a çekiliyor.
    // Çalışma oturumunda bu durum ayrı bir ekrana (`clockMovedBack`)
    // gidiyor çünkü orada çizelgenin tamamı güvenilmez hale geliyor;
    // burada tek ölçü başlangıç anı, "henüz hiç okumadın" doğru cevap.
    final rawS = nowMs <= startedAtMs ? 0 : (nowMs - startedAtMs) ~/ 1000;

    if (plannedDurationS == null) {
      return BookRunSnapshot(
        elapsedS: BookInput.capReadingS(rawS),
        remainingS: null,
        expired: false,
        capped: BookInput.isReadingCapped(rawS),
      );
    }

    final bounded = rawS > plannedDurationS ? plannedDurationS : rawS;
    return BookRunSnapshot(
      elapsedS: BookInput.capReadingS(bounded),
      remainingS: plannedDurationS - bounded,
      expired: rawS >= plannedDurationS,
      capped: BookInput.isReadingCapped(bounded),
    );
  }
}
