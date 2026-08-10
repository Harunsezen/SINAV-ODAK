/// Çizelge (schedule) JSON'unun okunması veya doğrulanması sırasında
/// oluşan hatalar.
///
/// Bu hata sınıfı bilinçli olarak `AppFailure`'ı GENİŞLETMEZ:
/// `AppFailure` `sealed` olduğu için tüm alt tipleri `core/errors/failures.dart`
/// içinde tanımlanmak zorunda; domain katmanının core'a bu şekilde bağlanması
/// katman sınırını bozardı. Bu yüzden bağımsız bir `Exception`'dır.
///
/// Not: Bu hatalar KULLANICI hatası değil, VERİ BOZULMASI göstergesidir.
/// UI bunları "oturum kaydı okunamadı" gibi tek bir mesajla ele almalı,
/// [reason] değerini kullanıcıya göstermemelidir.
library;

/// Çizelgenin neden geçersiz sayıldığı.
enum ScheduleCodecReason {
  /// JSON parse edilemedi veya beklenen alan tipleri tutmuyor.
  malformedJson,

  /// `version` alanı 1 değil. İleri sürüm verisi okunamaz.
  unsupportedVersion,

  /// Zorunlu bir alan eksik.
  missingField,

  /// `blocks` listesi boş. Bloksuz çizelge anlamsızdır.
  emptyBlocks,

  /// `type` alanı 'study' veya 'break' dışında bir değer.
  unknownBlockType,

  /// Blok sınırları geçersiz: `start >= end`.
  invalidBlockBounds,

  /// Zaman damgası saniyeye hizalı değil (ms kısmı sıfır değil).
  notAlignedToSecond,

  /// `s` alanı `(end - start) / 1000` ile uyuşmuyor.
  durationMismatch,

  /// Bir bloğun `end` değeri sonraki bloğun `start` değerine eşit değil.
  /// Çizelgede boşluk veya çakışma var.
  nonContiguousBlocks,

  /// `i` alanları 0'dan başlayıp ardışık artmıyor.
  badIndexSequence,

  /// `totalStudyS` bloklardan hesaplanan değerle uyuşmuyor.
  totalStudyMismatch,

  /// `totalBreakS` bloklardan hesaplanan değerle uyuşmuyor.
  totalBreakMismatch,

  /// `plannedEndAt` son bloğun `end` değerine eşit değil.
  plannedEndMismatch,

  /// Çalışma bloğunda `skipped` veya `extendedS` bulundu.
  /// Bu alanlar yalnızca mola bloklarında anlamlıdır.
  invalidStudyBlockFlags,

  /// Negatif epoch, negatif süre veya negatif `extendedS`.
  invalidNegativeValue,
}

/// Çizelge okuma/doğrulama hatası.
class SessionScheduleCodecException implements Exception {
  const SessionScheduleCodecException(
    this.reason,
    this.detail, {
    this.blockIndex,
  });

  /// Makine tarafından ayırt edilebilir hata nedeni.
  final ScheduleCodecReason reason;

  /// Geliştirici için ayrıntı. Kullanıcıya gösterilmez.
  final String detail;

  /// Hata bir bloktan kaynaklanıyorsa o bloğun sırası.
  final int? blockIndex;

  @override
  String toString() {
    final at = blockIndex == null ? '' : ' (blok #$blockIndex)';
    return 'SessionScheduleCodecException[${reason.name}]$at: $detail';
  }

  @override
  bool operator ==(Object other) =>
      other is SessionScheduleCodecException &&
      other.reason == reason &&
      other.detail == detail &&
      other.blockIndex == blockIndex;

  @override
  int get hashCode => Object.hash(reason, detail, blockIndex);
}
