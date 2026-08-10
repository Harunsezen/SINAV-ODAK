import '../entities/schedule_codec_exception.dart';
import '../entities/session_schedule.dart';
import '../entities/session_state.dart';

/// Çizelge + `nowMs` → [SessionState].
///
/// **Uygulamanın zaman mimarisinin kalbi.** Sayaç bir `Timer` değildir;
/// oturumun hangi blokta olduğu her seferinde burada yeniden hesaplanır.
/// Bu sayede uygulama öldürülse, telefon kapansa veya iOS arka planda kodu
/// durdursa bile oturum doğru yerden devam eder.
///
/// Saf fonksiyondur: `DateTime.now()` çağırmaz, tüm zamanlar parametredir.
abstract final class ScheduleResolver {
  /// Cihaz saatindeki küçük geri sıçramalar için tolerans.
  ///
  /// NTP senkronizasyonu saati birkaç yüz milisaniye geri alabilir. Katı
  /// karşılaştırma yapılsaydı bu, oturumu gereksiz yere
  /// [SessionState.clockMovedBack] durumuna düşürürdü.
  static const int clockSkewToleranceMs = 3000;

  /// [nowMs] anında oturumun durumunu hesaplar.
  ///
  /// Kurallar:
  /// - `now < firstStart - tolerans` → [SessionState.clockMovedBack]
  /// - `firstStart - tolerans <= now < firstStart` → ilk blok
  /// - `now == block.endMs` → **sonraki bloğa geçmiş sayılır**
  /// - `now >= plannedEndAt` → [SessionState.summarizing]
  ///
  /// [SessionState.beforeStart] **asla döndürülmez** (KARAR 2); o durum
  /// yalnızca UI'ın "çizelge yazılıyor" geçiş anı içindir.
  static SessionState resolve({
    required String sessionId,
    required SessionSchedule schedule,
    required int nowMs,
  }) {
    // SessionSchedule private constructor'a sahip ve fromBlocks/fromJson boş
    // listeyi reddediyor; bu guard pratikte ERİŞİLEMEZ. Kaldırılmıyor çünkü
    // çizelge modeli ileride değişirse tek koruma bu.
    // coverage:ignore-line
    if (schedule.blockCount == 0) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.emptyBlocks,
        'Boş çizelge çözümlenemez',
      );
    }

    if (nowMs < schedule.firstStartMs - clockSkewToleranceMs) {
      return SessionState.clockMovedBack(
        sessionId: sessionId,
        schedule: schedule,
      );
    }

    if (nowMs >= schedule.plannedEndAtMs) {
      return SessionState.summarizing(
        sessionId: sessionId,
        schedule: schedule,
      );
    }

    // Bloklar kesintisiz olduğu için `now < endMs` koşulunu sağlayan İLK blok
    // aranan bloktur. `now == endMs` durumunda bu koşul sağlanmaz ve
    // otomatik olarak sonraki bloğa geçilir.
    for (final block in schedule.blocks) {
      if (nowMs < block.endMs) {
        // Tolerans penceresindeyken kalan süre planlanan süreyi aşmasın.
        final remainingMs = block.endMs - (nowMs < block.startMs ? block.startMs : nowMs);

        return block.isStudy
            ? SessionState.inBlock(
                sessionId: sessionId,
                blockIndex: block.index,
                blockEndsAtMs: block.endMs,
                remainingMs: remainingMs < 0 ? 0 : remainingMs,
                schedule: schedule,
              )
            : SessionState.inBreak(
                sessionId: sessionId,
                blockIndex: block.index,
                breakEndsAtMs: block.endMs,
                remainingMs: remainingMs < 0 ? 0 : remainingMs,
                extensionsUsed: block.extensionsUsed,
                schedule: schedule,
              );
      }
    }

    // Buraya normalde ulaşılmaz: plannedEndAt kontrolü yukarıda yapıldı ve
    // plannedEndAt daima son bloğun endMs değerine eşittir (validate garantisi).
    return SessionState.summarizing(sessionId: sessionId, schedule: schedule);
  }
}
