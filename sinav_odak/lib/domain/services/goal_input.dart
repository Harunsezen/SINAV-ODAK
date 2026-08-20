// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

/// Manuel hedef girişinin sınırları ve **serbest metin** ayrıştırıcısı.
///
/// **Neden domain katmanında:** "geçerli giriş nedir" bir ürün kuralı,
/// arayüz ayrıntısı değil. Burada durunca hem diyalogdan hem onboarding
/// adımından aynı kural okunuyor ve Flutter kurmadan test edilebiliyor.
///
/// ## Neden serbest metin
///
/// Kullanıcı "2sa 8dk" de yazabilir "148dk" da, sadece "148" de. Ayrı
/// saat/dakika alanları belirsizliği kaldırıyordu ama iki alan arasında
/// gezinmeye zorluyordu. Tek alan + esnek ayrıştırma daha az sürtünme.
///
/// Türkçe ve İngilizce birimler birlikte tanınıyor: uygulama iki dilde
/// çalışıyor ve klavye dili arayüz dilinden bağımsız olabiliyor.
///
/// ## Geçersizde ne olur
///
/// Ayrıştırıcılar geçersiz girişte **`null`** döndürüyor; çağıran taraf
/// eski değeri koruyor. Sessizce 0'a veya sınıra kırpmak daha kötü
/// olurdu: kullanıcı yanlış yazdığını fark etmeden hedefini kaybederdi.
abstract final class GoalInput {
  /// Süre hedefi alt sınırı (dakika). Koordinatör kararı: "süre 0-12sa".
  static const minDurationMinutes = 0;

  /// Süre hedefi üst sınırı: 12 saat.
  static const maxDurationMinutes = 12 * 60;

  /// Soru hedefi sınırları.
  static const minCount = 1;
  static const maxCount = 2000;

  /// Süreyi serbest metinden okur. Geçersizse `null`.
  ///
  /// Tanınan biçimler:
  /// ```
  /// "148"        → 148 dk   (birimsiz sayı = DAKİKA)
  /// "148dk"      → 148 dk
  /// "2sa"        → 120 dk
  /// "2sa 8dk"    → 128 dk
  /// "2 saat 8 dakika" → 128 dk
  /// "2h 8m"      → 128 dk   (İngilizce arayüz / klavye)
  /// "2:08"       → 128 dk   (saat:dakika)
  /// ```
  ///
  /// **Birimsiz sayı neden dakika:** hedefler dakika cinsinden saklanıyor
  /// ve "90" yazan biri 90 saat değil 90 dakika kastediyor.
  static int? parseDuration(String raw) {
    final s = _normalize(raw);
    if (s.isEmpty) return null;

    // "2:08" biçimi.
    final clock = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(s);
    if (clock != null) {
      return _clamp(
        int.parse(clock.group(1)!) * 60 + int.parse(clock.group(2)!),
        minDurationMinutes,
        maxDurationMinutes,
      );
    }

    // Birimsiz sayı = dakika.
    if (RegExp(r'^\d+$').hasMatch(s)) {
      return _clamp(int.parse(s), minDurationMinutes, maxDurationMinutes);
    }

    // Birimli: saat ve/veya dakika.
    //
    // Sıra ÖNEMLİ: "dakika" içinde "d" var, "saat" içinde "sa" var.
    // Uzun birim adları önce denenmezse "dakika" yanlış eşleşirdi.
    final hour = RegExp(r'(\d+)\s*(saat|hours|hour|sa|hr|h)\b');
    final minute = RegExp(r'(\d+)\s*(dakika|minutes|minute|min|dk|dak|m)\b');

    final hm = hour.firstMatch(s);
    final mm = minute.firstMatch(s);
    if (hm == null && mm == null) return null;

    // Ayrıştırılamayan artık kalmamalı: "2sa abc" geçersiz sayılmalı.
    var rest = s;
    if (hm != null) rest = rest.replaceFirst(hm.group(0)!, ' ');
    if (mm != null) rest = rest.replaceFirst(mm.group(0)!, ' ');
    if (rest.trim().isNotEmpty) return null;

    final h = hm == null ? 0 : int.parse(hm.group(1)!);
    final m = mm == null ? 0 : int.parse(mm.group(1)!);
    return _clamp(h * 60 + m, minDurationMinutes, maxDurationMinutes);
  }

  /// Soru sayısını serbest metinden okur. Geçersizse `null`.
  ///
  /// ```
  /// "75"        → 75
  /// "75 soru"   → 75
  /// "75 questions" → 75
  /// ```
  static int? parseCount(String raw) {
    final s = _normalize(raw);
    if (s.isEmpty) return null;

    final m = RegExp(r'^(\d+)\s*(soru|questions|question|q)?$').firstMatch(s);
    if (m == null) return null;
    return _clamp(int.parse(m.group(1)!), minCount, maxCount);
  }

  /// Küçük harfe indirir, Türkçe'ye özgü İ/I sorununu elle çözer ve
  /// fazla boşlukları teke indirir.
  ///
  /// `toLowerCase()` yerel bağımsız: "İ" → "i̇" (birleşik nokta) üretiyor
  /// ve `dakika` eşleşmesini bozabiliyor. Birim adlarında geçen harfleri
  /// önceden sabitliyoruz.
  static String _normalize(String raw) => raw
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Sınır DIŞINDA ise `null` — kırpmıyor.
  ///
  /// Kırpmak sessiz bir yalan olurdu: "20 saat" yazan kullanıcı 12 saat
  /// kaydedildiğini fark etmeden ekrandan çıkardı.
  static int? _clamp(int value, int min, int max) =>
      (value < min || value > max) ? null : value;
}
