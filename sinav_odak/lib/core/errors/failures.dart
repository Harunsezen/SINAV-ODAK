/// Kullanıcıya gösterilebilir, beklenen hata durumları.
///
/// `sealed` olduğu için tüm alt tipleri BU dosyada tanımlanmak zorundadır.
/// Domain'deki [SessionScheduleCodecException] bu yüzden [AppFailure]'ı
/// genişletmez; ayrı bir `Exception` olarak tanımlanmıştır.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Kullanıcıya gösterilebilecek Türkçe açıklama.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Plan doğrulama hataları (blok < 10 dk, bitiş saati geçmiş,
/// mola uzatma limiti aşıldı...).
class PlanFailure extends AppFailure {
  const PlanFailure(super.message);
}

/// Girdi doğrulama hataları (negatif soru sayısı, geçersiz katsayı,
/// yanlış blok tipi, tutarsız zaman değeri...).
///
/// [PlanFailure]'dan farkı: plan kurulabilir ama verilen değer geçersiz.
class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, {this.field});

  /// Hatanın hangi alandan kaynaklandığı (örn. 'correctCount').
  /// UI bu alanı vurgulamak için kullanabilir.
  final String? field;

  @override
  String toString() =>
      field == null ? 'ValidationFailure: $message' : 'ValidationFailure($field): $message';
}

/// Veritabanı katmanı hataları.
class StorageFailure extends AppFailure {
  const StorageFailure(super.message);
}

/// Oturum akışında geçersiz durum geçişi.
class SessionFailure extends AppFailure {
  const SessionFailure(super.message);
}
