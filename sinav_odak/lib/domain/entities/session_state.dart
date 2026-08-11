import 'package:freezed_annotation/freezed_annotation.dart';

import 'session_schedule.dart';

part 'session_state.freezed.dart';

/// Bir çalışma oturumunun anlık durumu.
///
/// **Bu tip asla saklanmaz.** Kalıcı doğruluk kaynağı `SessionSchedule` ile
/// `nowMs`'in karşılaştırılmasıdır; [SessionState] her seferinde
/// `ScheduleResolver.resolve()` tarafından yeniden üretilir. UI ticker'ı
/// yalnızca aynı state'i yeniden boyar, state'i **ilerletmez**.
///
/// `sealed` olduğu için tüm `switch` ifadeleri derleme zamanında
/// eksiksizlik (exhaustiveness) denetimine tabidir: yeni bir state eklendiğinde
/// onu ele almayan her `switch` derleme hatası verir. Bu yüzden aşağıdaki
/// getter'larda `_ =>` joker dalı **bilinçli olarak kullanılmamıştır**.
///
/// Tasarım notu: [idle] ve [configuring] bilinçli olarak çizelge TAŞIMAZ.
/// Bu iki durumda henüz çizelge yoktur; boş bir sentinel çizelge taşımak
/// (`SessionSchedule.empty` gibi) yapay bir ihtiyaç yaratır ve
/// "doğrulanmamış çizelge" üretme kapısı açardı.
@freezed
sealed class SessionState with _$SessionState {
  const SessionState._();

  /// Aktif oturum yok. Uygulamanın varsayılan durumu.
  const factory SessionState.idle() = SessionIdle;

  /// Kullanıcı ders/konu/tür/plan seçiyor. Çizelge henüz kurulmadı.
  const factory SessionState.configuring() = SessionConfiguring;

  /// Çizelge kuruldu, ilk blok henüz başlamadı.
  ///
  /// **`ScheduleResolver` bu durumu ASLA döndürmez** (KARAR 2). Yalnızca
  /// Adım 4'te "Başlat'a basıldı, çizelge yazılıyor" geçiş anında UI
  /// tarafından kullanılır.
  const factory SessionState.beforeStart({
    required String sessionId,
    required SessionSchedule schedule,
  }) = SessionBeforeStart;

  /// Çalışma bloğu sürüyor. **Bu durumdayken tam ekran reklam yasaktır.**
  const factory SessionState.inBlock({
    required String sessionId,
    required int blockIndex,
    required int blockEndsAtMs,
    required int remainingMs,
    required SessionSchedule schedule,
  }) = SessionInBlock;

  /// Mola sürüyor. Reklam gösterimi için doğal an.
  const factory SessionState.inBreak({
    required String sessionId,
    required int blockIndex,
    required int breakEndsAtMs,
    required int remainingMs,
    required int extensionsUsed,
    required SessionSchedule schedule,
  }) = SessionInBreak;

  /// Çizelge bitti, oturum sonu formu bekleniyor.
  const factory SessionState.summarizing({
    required String sessionId,
    required SessionSchedule schedule,
  }) = SessionSummarizing;

  /// Oturum kaydedildi, odak skoru hesaplandı.
  const factory SessionState.saved({
    required String sessionId,
    required int focusScore,
  }) = SessionSaved;

  /// Cihaz saati çizelgenin başlangıcından geriye alınmış.
  ///
  /// Normal akışta oturum başlatıldığı anda `now >= firstStartMs` olmalıdır.
  /// Bu durum Adım 4'te "cihaz saati değişti" kurtarma akışına bağlanacak.
  const factory SessionState.clockMovedBack({
    required String sessionId,
    required SessionSchedule schedule,
  }) = SessionClockMovedBack;

  /// Oturum fiilen çalışıyor mu (blok veya mola)?
  bool get isRunning => this is SessionInBlock || this is SessionInBreak;

  /// **Reklam katmanının mutlak kuralı:** çalışma bloğu sürerken hiçbir
  /// tam ekran reklam gösterilemez. `AdGateway` bu getter'ı okuyacak.
  bool get isInStudyBlock => this is SessionInBlock;

  /// Varsa oturum kimliği.
  String? get sessionIdOrNull => switch (this) {
        SessionIdle() => null,
        SessionConfiguring() => null,
        SessionBeforeStart(:final sessionId) => sessionId,
        SessionInBlock(:final sessionId) => sessionId,
        SessionInBreak(:final sessionId) => sessionId,
        SessionSummarizing(:final sessionId) => sessionId,
        SessionSaved(:final sessionId) => sessionId,
        SessionClockMovedBack(:final sessionId) => sessionId,
      };

  /// Varsa çizelge. [idle], [configuring] ve [saved] için `null`.
  SessionSchedule? get scheduleOrNull => switch (this) {
        SessionIdle() => null,
        SessionConfiguring() => null,
        SessionSaved() => null,
        SessionBeforeStart(:final schedule) => schedule,
        SessionInBlock(:final schedule) => schedule,
        SessionInBreak(:final schedule) => schedule,
        SessionSummarizing(:final schedule) => schedule,
        SessionClockMovedBack(:final schedule) => schedule,
      };

  /// Geri sayımda gösterilecek kalan süre (saniye). Diğer durumlarda 0.
  int get remainingSeconds => switch (this) {
        SessionInBlock(:final remainingMs) => remainingMs ~/ 1000,
        SessionInBreak(:final remainingMs) => remainingMs ~/ 1000,
        SessionIdle() => 0,
        SessionConfiguring() => 0,
        SessionBeforeStart() => 0,
        SessionSummarizing() => 0,
        SessionSaved() => 0,
        SessionClockMovedBack() => 0,
      };
}
