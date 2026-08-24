// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import 'goal_input.dart';

/// Kitap okuma oturumunun giriş kuralları (v1.3).
///
/// **Neden domain katmanında:** "kaç dakika okunabilir", "sayfa sayısı
/// nereye kadar makul", "boş kitap adı ne demek" — üçü de ürün kuralı,
/// arayüz ayrıntısı değil. Burada durunca kurulum ekranı, oturum sonu
/// formu ve PDF aynı kuralı okuyor ve hepsi Flutter kurmadan test
/// edilebiliyor.
///
/// ## Sınırlar neden var
///
/// Sınırsız giriş istatistiği saçmalaştırır: "9999 sayfa" bir günün
/// toplamını, "40 saat" haftalık grafiği okunmaz hale getirir. Sınırlar
/// gerçek üst ucun **çok üzerinde** — meşru kullanımı engellemiyor,
/// yalnızca hatalı girişi kesiyor.
abstract final class BookInput {
  /// Okuma süresi alt sınırı (dakika).
  ///
  /// 0 değil: süresi olmayan bir okuma oturumu ölçmediği bir şeyi
  /// kaydeder. 5 dakika, "kısa bir mola okuması"nın alt ucu.
  static const minDurationMinutes = 5;

  /// Üst sınır 12 saat — `GoalInput.maxDurationMinutes` ile AYNI.
  ///
  /// İki ayrı tavan koymak, aynı uygulamada "12 saat çok" ile "20 saat
  /// olur" demek olurdu.
  static const maxDurationMinutes = GoalInput.maxDurationMinutes;

  /// Sayfa hedefi ve okunan sayfa sınırları.
  ///
  /// Üst sınır oturum sonu formundaki soru tavanıyla (2000) aynı: iki
  /// alan da "bir oturumda girilebilecek en fazla adet" sorusunu
  /// cevaplıyor.
  static const minPages = 1;
  static const maxPages = 2000;

  /// Kitap adının en fazla uzunluğu.
  ///
  /// Şemadaki sütun sınırıyla aynı. Uzun ad istatistik kartında ve PDF
  /// satırında kırpılıyor; veriyi de kırpmak, kaydedilenle görünenin
  /// aynı olmasını sağlıyor.
  static const maxTitleLength = 80;

  /// Kaydedilebilecek en uzun okuma süresi (saniye).
  ///
  /// Sayfa hedefi modunda sayaç İLERİ sayıyor ve doğal bir sonu yok.
  /// Kullanıcı sayacı açık unutup ertesi gün dönerse "23 saat okudum"
  /// kaydı oluşurdu. [capReadingS] bunu tavana çekiyor ve arayüz
  /// kırpıldığını **söylüyor** — sessiz kırpma, kullanıcının fark
  /// etmeden yanlış veri kaydetmesi demekti.
  static const maxReadingS = maxDurationMinutes * 60;

  /// Süreyi serbest metinden okur ("45", "45dk", "1sa 30dk", "1:30").
  ///
  /// Biçim ayrıştırması [GoalInput.parseDuration] ile ORTAK; burada
  /// yalnızca okuma oturumuna özgü aralık uygulanıyor. Ayrı bir
  /// ayrıştırıcı yazmak, aynı kullanıcının aynı yazımının bir ekranda
  /// kabul edilip diğerinde reddedilmesi demekti.
  ///
  /// Geçersizde `null` döner — çağıran eski değeri korur.
  static int? parseMinutes(String raw) {
    final value = GoalInput.parseDuration(raw);
    if (value == null) return null;
    return (value < minDurationMinutes || value > maxDurationMinutes)
        ? null
        : value;
  }

  /// Sayfa sayısını serbest metinden okur ("120", "120 sayfa", "120 pages").
  ///
  /// Geçersizde `null`.
  static int? parsePages(String raw) {
    final s = _normalize(raw);
    if (s.isEmpty) return null;

    final m = RegExp(r'^(\d+)\s*(sayfa|pages|page|sf|s|p)?$').firstMatch(s);
    if (m == null) return null;

    final value = int.parse(m.group(1)!);
    return (value < minPages || value > maxPages) ? null : value;
  }

  /// Okunan sayfa sayısını sınıra çeker. **Negatif ve tavan üstü kesilir.**
  ///
  /// Oturum sonu formu sayaçla da giriş alıyor; orada 0 geçerli bir değer
  /// ("açtım ama okuyamadım"), bu yüzden alt sınır [minPages] değil 0.
  static int clampPagesRead(int value) =>
      value < 0 ? 0 : (value > maxPages ? maxPages : value);

  /// Ölçülen okuma süresini kaydedilebilir tavana çeker.
  static int capReadingS(int seconds) =>
      seconds < 0 ? 0 : (seconds > maxReadingS ? maxReadingS : seconds);

  /// Süre tavana dayandı mı? Arayüz bunu kullanıcıya söylemek için sorar.
  static bool isReadingCapped(int seconds) => seconds > maxReadingS;

  /// Kitap adını kaydedilebilir hale getirir.
  ///
  /// **Boş bırakılabilir (koordinatör kuralı).** Boş, yalnızca boşluk ya
  /// da sınırın ötesi:
  /// ```
  /// ""            → null
  /// "   "         → null
  /// "  Sefiller " → "Sefiller"
  /// "a" * 200     → ilk 80 karakter
  /// ```
  ///
  /// `null` dönmesi "kitap adı yok" demek; istatistik ve PDF orada
  /// yerine geçen bir etiket ("Kitap") gösteriyor. Boş string
  /// saklanmıyor: veritabanında `''` ile `NULL` iki ayrı "yok" hali
  /// üretir ve okuyan her yer ikisini de kontrol etmek zorunda kalırdı.
  static String? normalizeTitle(String? raw) {
    if (raw == null) return null;
    final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return null;
    return collapsed.length <= maxTitleLength
        ? collapsed
        : collapsed.substring(0, maxTitleLength);
  }

  static String _normalize(String raw) => raw
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
