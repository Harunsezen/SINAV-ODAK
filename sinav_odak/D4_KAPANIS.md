# D4 KAPANIŞ — soru sayısı üst sınırı

**Tarih:** 11 Ağustos 2026
**Kapsam:** v1.0'ın son kod değişikliği
**Durum:** TAMAM — **code freeze**

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **739 / 739 geçti** (eşik ≥737 — **+2**) |
| **analyze** | **No issues found!** — 0 / 0 / 0 |
| **pub get / build_runner** | temiz |
| **ARB** | 339 anahtar, TR/EN **senkron** |

---

## 2. YAPILAN

`lib/presentation/run/summary_form.dart` — **tek dosya değişti** (+ ARB + test).

```dart
/// Tek oturumda girilebilecek en fazla soru sayısı.
static const int maxQuestions = 2000;

void _setQuestions(int value) {
  final clamped =
      value < 0 ? 0 : (value > maxQuestions ? maxQuestions : value);
  setState(() {
    _questionCount = clamped;
    _questionsCapped = value > maxQuestions;
  });
  ...
}
```

**Davranış:**

- 2000 üstü giriş **2000'e kırpılır**; metin alanı da kırpılmış değeri
  gösterir — kullanıcı 5000 yazdığını sanıp 2000 kaydedildiğini sonradan
  öğrenmez.
- Alanın altında satır içi mesaj: **"Tek oturum için en fazla 2000 soru."**
  (hata rengiyle, `Key('summary-q-capped')`).
- Sınır içi bir değere dönülünce mesaj **kalkar**.
- **KAYDET kırpılmış değerle çalışır**; akış bölünmez, **diyalog açılmaz**.
- Alt sınır (`< 0 → 0`) davranışı aynen korundu.

**Dokunulmayanlar (talimat gereği):**

- `NetCalculator`'ın **"doğru + yanlış + boş ≤ soru"** invariant'ı aynen
  duruyor; kırpma bu kuralın önüne geçmiyor, önce çalışıyor.
- Hızlı butonlar (+5/+10/+20) aynı yoldan geçtiği için otomatik olarak
  tavana uyuyor — ayrı bir kod yolu açılmadı.
- Başka hiçbir dosya, ekran veya kural değişmedi.

**ARB:** `summaryQuestionCapped` eklendi, TR + EN senkron (EN değeri hâlâ
TR — S16 gereği, çeviri v1.2).

---

## 3. NEDEN 2000

Koordinatörün verdiği değer uygulandı. Gerekçe kodda da yazılı: bir TYT+AYT
günü ~240 soru; 2000 gerçek üst ucun çok üzerinde, yani **meşru kullanımı
engellemiyor, yalnızca hatalı girişi kesiyor** (`999999` gibi).

---

## 4. TESTLER (2 adet, istendiği gibi)

`test/widget/summary_form_test.dart`:

1. **`2000 ÜSTÜ giriş 2000e kırpılıyor ve KAYDET kırpılmış değerle çalışıyor`**
   — `5000` girilir; metin alanı `2000` gösterir; KAYDET sonrası
   veritabanındaki `questionCount` **2000**.
2. **`kırpma satır içi mesajla bildiriliyor, DİYALOG açılmıyor`**
   — başlangıçta mesaj yok; `2001` girilince mesaj çıkar;
   `find.byType(AlertDialog)` **findsNothing**; `40` girilince mesaj kalkar.

---

## 5. DOĞRULAMA

```
$ flutter pub get                → Got dependencies!
$ dart run build_runner build …  → Succeeded
$ flutter analyze                → No issues found!
$ flutter test                   → +739: All tests passed!   (EXIT=0)
```

Mevcut 737 testin hiçbiri düşmedi.

---

## 6. v1.0 CODE FREEZE

Kod tarafı bitti. Sapma durumu:

| # | Durum |
| --- | --- |
| S1–S15 | **Kapalı** |
| S16 | Açık — `app_en.arb` değerleri TR; İngilizce çeviri v1.2 |
| S17 | Açık — Android SDK bu ortamda yok; AAB derlemesi ve cihaz testi sende |

**Yayına kalanlar (kod değil):**

1. Keystore üret + `android/key.properties` (README §2)
2. `flutter build appbundle --release` + AdMob `--dart-define`'ları
3. Cihaz duman testi — `FAZ_06_RAPORU.md` §7 + `FAZ_08_RAPORU.md` §10
4. Play Console — `PRIVACY.md`, *Data safety*, 13+,
   `assets/store/feature_graphic.png`
