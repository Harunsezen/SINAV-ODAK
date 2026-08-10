/// Uygulamadaki TÜM zaman işlemleri buradan geçer.
///
/// Mimari kural: sayaç bir `Timer` değildir. Doğruluk kaynağı sırası:
///   1) [nowMs] (cihaz duvar saati)
///   2) DB'deki çizelge (schedule)
///   3) UI ticker  <- asla state ilerletmez, sadece boyar
library;

/// Şu anın epoch milisaniye değeri.
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Epoch ms -> yerel DateTime.
DateTime msToLocal(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

/// DateTime -> epoch ms.
int toMs(DateTime dt) => dt.millisecondsSinceEpoch;

extension DateTimeMsX on DateTime {
  int get ms => millisecondsSinceEpoch;
}
