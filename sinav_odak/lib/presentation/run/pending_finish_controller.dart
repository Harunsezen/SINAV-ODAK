import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Oturum sonu akışının state'i.
///
/// **Neden `core/di` değil de burada?** Bu iki provider veri katmanına hiç
/// dokunmaz; yalnızca "Bitir" onayı ile oturum sonu formu, form ile tebrik
/// ekranı arasında bilgi taşır. `setup_controller.dart` ile aynı desen.

// ---------------------------------------------------------------------------
// Bitiş bağlamı — TEK KAYIT YOLU
//
// `finishSession` YALNIZCA oturum sonu formunun KAYDET butonundan çağrılır.
// RunScreen'deki "Bitir" onayı oturumu KAPATMAZ; yalnızca bitiş bağlamını
// buraya yazıp formu açar.
//
// Neden: eskiden "Bitir" hem finish çağırıyor hem forma yönlendiriyordu.
// Kullanıcı formu doldurmadan önce oturum kapanıyordu; form KAYDET'e
// bastığında ikinci bir finish çağrısı gerekiyor ve soru sayıları ilk
// kayıttan sonra yazıldığı için `daily_stats` iki kez hesaplanıyordu.
// ---------------------------------------------------------------------------

/// [early] `true` ise kullanıcı çizelge bitmeden "Bitir" dedi.
///
/// [endMs] süre hesabının dayanacağı **an**: erken bitirmede onayın verildiği
/// an, normal tamamlanmada çizelgenin planlanan bitişi. Form ekranda ne kadar
/// beklerse beklesin kayıtlı süre değişmez — bu alan olmasaydı kullanıcının
/// formu doldurma süresi çalışma süresine eklenirdi.
typedef PendingFinish = ({bool early, int endMs});

class PendingFinishNotifier extends Notifier<PendingFinish?> {
  @override
  PendingFinish? build() => null;

  void set({required bool early, required int endMs}) =>
      state = (early: early, endMs: endMs);

  void clear() => state = null;
}

/// **autoDispose DEĞİL:** /run -> /run/summary geçişinde RunScreen yıkılır.
/// autoDispose olsaydı bitiş bağlamı tam da forma varıldığı anda silinirdi.
final pendingFinishProvider =
    NotifierProvider<PendingFinishNotifier, PendingFinish?>(
  PendingFinishNotifier.new,
);

// ---------------------------------------------------------------------------
// Kayıt sonucu — tebrik ekranının (S11) girdisi
// ---------------------------------------------------------------------------

/// [dateKey] oturumun BAŞLADIĞI gün (G9). Tebrik ekranındaki günlük ilerleme
/// bu anahtardan okunur; `todayKey()` kullanılsaydı gece yarısını aşan bir
/// oturum bittiğinde kullanıcıya BAŞKA günün özeti gösterilirdi.
typedef SavedResult = ({String sessionId, int? focusScore, String dateKey});

class SavedResultNotifier extends Notifier<SavedResult?> {
  @override
  SavedResult? build() => null;

  void set({
    required String sessionId,
    required int? focusScore,
    required String dateKey,
  }) =>
      state = (
        sessionId: sessionId,
        focusScore: focusScore,
        dateKey: dateKey,
      );

  void clear() => state = null;
}

/// Kayıt tamamlandığında `running` oturum kalmaz; router'ın aktif oturum
/// koruması bu yüzden /run/done'ı ana panele geri yollardı. Tebrik ekranının
/// var olma hakkı bu provider'dan gelir (bkz. `app_router.dart` redirect).
final savedResultProvider = NotifierProvider<SavedResultNotifier, SavedResult?>(
  SavedResultNotifier.new,
);
