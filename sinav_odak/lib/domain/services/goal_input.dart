// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

/// Manuel hedef girişinin sınırları ve ayrıştırıcısı.
///
/// **Neden domain katmanında:** "geçerli giriş nedir" bir ürün kuralı,
/// bir arayüz ayrıntısı değil. Burada durunca hem diyalogdan hem
/// onboarding adımından aynı kural okunuyor, hem de kural Flutter
/// kurmadan test edilebiliyor.
///
/// ## Geçersizde ne olur
///
/// Ayrıştırıcılar geçersiz girişte **`null`** döndürüyor; çağıran taraf
/// eski değeri koruyor. Sessizce 0'a veya sınıra kırpmak daha kötü
/// olurdu: kullanıcı yanlış yazdığını fark etmeden hedefini kaybederdi.
abstract final class GoalInput {
  /// Süre hedefi alt sınırı (dakika).
  ///
  /// Sıfıra izin veriliyor (koordinatör kararı: "süre 0-12sa"). Sıfır
  /// dakikalık bir günlük hedef pratikte anlamsız — ürün tarafında bir
  /// alt sınır (ör. 15 dk) istenirse tek sabit değişimi yeter.
  static const minDurationMinutes = 0;

  /// Süre hedefi üst sınırı: 12 saat.
  static const maxDurationMinutes = 12 * 60;

  /// Soru hedefi sınırları.
  static const minCount = 1;
  static const maxCount = 2000;

  /// "2" + "10" → 130 dakika. Geçersizse `null`.
  ///
  /// - İki alan da boşsa geçersiz (kullanıcı hiçbir şey yazmamış).
  /// - **Tek alan boşsa 0 sayılıyor:** yalnızca "2" yazıp saat alanında
  ///   bırakmak "2 saat" demek; kullanıcıyı ikinci alanı doldurmaya
  ///   zorlamak gereksiz sürtünme.
  /// - Dakika alanına 59'dan büyük yazmak serbest: "0 sa 90 dk" = 90 dk.
  ///   Sınırı toplam belirliyor, tek tek alanlar değil.
  static int? parseDuration({required String hours, required String minutes}) {
    final h = hours.trim();
    final m = minutes.trim();
    if (h.isEmpty && m.isEmpty) return null;

    final hv = h.isEmpty ? 0 : _digits(h);
    final mv = m.isEmpty ? 0 : _digits(m);
    if (hv == null || mv == null) return null;

    final total = hv * 60 + mv;
    if (total < minDurationMinutes || total > maxDurationMinutes) return null;
    return total;
  }

  /// "75" → 75. Geçersizse `null`.
  static int? parseCount(String raw) {
    final v = _digits(raw.trim());
    if (v == null) return null;
    if (v < minCount || v > maxCount) return null;
    return v;
  }

  /// Yalnızca rakamlardan oluşan pozitif tam sayı; değilse `null`.
  ///
  /// `int.tryParse` "+5", " 5" ve "-5"i de kabul ediyor. Hedef alanında
  /// eksi veya işaret anlamsız; katı davranıp geçersiz saymak, sessizce
  /// tuhaf bir değer üretmekten iyi.
  static int? _digits(String s) {
    if (s.isEmpty) return null;
    for (final c in s.codeUnits) {
      if (c < 0x30 || c > 0x39) return null;
    }
    return int.tryParse(s);
  }
}
