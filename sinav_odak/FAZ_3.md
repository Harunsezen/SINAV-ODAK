# v1.1 — FAZ 3: VERİ VE DIŞA AKTARIM (P1)

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 828 → **845**

---

## 0. ÖZET

| Madde | Durum |
| --- | --- |
| 3.1 Çift hedefli PDF rapor (Veli / Eğitimci) | ✅ |
| 3.2 Grafik çeşitliliği (çizgi · pasta · ısı haritası) | ✅ |
| UX incelemesi | ✅ `UX_REVIEW.md` FAZ 3 — **6 bulgu, 6'sı çözüldü** |
| `flutter test` | **845** ✅ |
| `flutter analyze` | **0 issue** ✅ |
| `dart format .` | **0 changed** ✅ |
| `flutter build apk --release` | ❌ Android SDK yok (§6) |

**Gizlilik sözü korundu:** hesap yok, sunucu yok, ağ çağrısı yok. PDF
cihazda üretiliyor.

---

## 1. 3.1 — Çift hedefli PDF rapor

**Akış:** İstatistik → 📄 **Rapor Al** → *Veli* / *Eğitimci* → PDF üret →
sistem paylaşım sayfası.

### Katman ayrımı

| Katman | Dosya | Sorumluluk |
| --- | --- | --- |
| Domain (saf Dart) | `report_data.dart` | Rapor **verisi** + türetilmiş hesaplar |
| Application | `build_report.dart` | Hangi sayı nereden gelir, **kime ne gösterilir** |
| Services | `pdf_report_builder.dart` | Yalnızca **çizim** |
| Presentation | `report_button.dart` | Seçim, ilerleme, hata mesajı |

Bu ayrım sayesinde rapor içeriği PDF paketine dokunmadan test edilebiliyor.

### Veli raporu — tek sayfa

Büyük ve az sayıda rakam: toplam çalışma, oturum, soru, net, başarı oranı,
seri. Ders dağılımı tablosu. **Zayıf konu listesi YOK.**

Veliye "çocuğunuzun en kötü olduğu 10 konu" göndermek uygulamanın
amacının tersi olurdu. Bu bir **içerik** kararı, biçim değil — bu yüzden
`BuildReportUseCase` içinde alınıyor ve ayrı bir testle iddia ediliyor.

### Eğitimci raporu — çok sayfa

Sayfa 1: analitik özet tablosu (10 satır) + ders dağılımı.
Sayfa 2+: gelişim gereken konular + günlük döküm, sayfa numaralı.

### İki hesap kararı

**Başarı oranı boşları paydaya katmıyor** (`doğru / (doğru + yanlış)`).
Katsaydı, temkinli davranıp boş bırakan öğrenci cezalandırılırdı.

**Günlük ortalama çalışılan güne bölünüyor**, takvim gününe değil. Takvim
gününe bölmek hafta sonu dinlenen öğrencinin raporunu haksızca kötü
gösterirdi.

### Gizlilik kaşesi

Her raporun altında, istisnasız:

> 🔒 Veriler yalnızca cihazda işlendi. Satılmadı, paylaşılmadı.
> — Balto, Sınav Odak

Bu cümle **doğru**: `BuildReportUseCase` yalnızca yerel SQLite'tan
okuyor, `PdfReportBuilder` ağ kullanmıyor, paylaşım geçici dosya
üzerinden sistem sayfasına gidiyor.

### ⚠️ Türkçe font — sessiz bir hata yakalandı

`pdf` paketinin yerleşik Helvetica'sı **ş, ğ, ı, İ harflerini
desteklemiyor**. Ölçtüm:

```
PROBE ş U+15f -> false     PROBE Ç U+c7 -> true
PROBE ğ U+11f -> false     PROBE ç U+e7 -> true
PROBE ı U+131 -> false
PROBE İ U+130 -> false
```

PDF **hata vermeden** üretiliyordu; yani Türkçe rapor sessizce bozuk
çıkacaktı — üstelik veliye giden belgede.

**Çözüm:** Roboto Regular + Bold gömüldü (`assets/fonts/`, ~340 KB).
İki test bunu kilitliyor.

`printing` paketinin `PdfGoogleFonts`'u fontu **çalışma zamanında
indiriyor**; ağ gerektirdiği ve "sunucu yok" sözüyle çeliştiği için
seçilmedi.

---

## 2. 3.2 — Grafik çeşitliliği

| Grafik | Ne gösteriyor | Not |
| --- | --- | --- |
| Çizgi | **Haftalık** toplam eğilimi | ≥2 hafta yoksa gizleniyor |
| Pasta | Ders dağılımı (%) | Efsane ayrı sütunda |
| Isı haritası | Gün × saat yoğunluğu | fl_chart'ta hazırı yok — elle |

**Isı haritası neden elle yazıldı:** `fl_chart` heatmap sunmuyor. Ek bir
paket getirmek APK'yı büyütürdü; takvim ekranındaki yoğunluk deseni
saat ekseniyle yeniden kullanıldı.

**Isı haritası oturumun BAŞLAMA saatini sayıyor**, süreyi saatlere
bölmüyor. Bölmek daha "doğru" olurdu ama bir oturum nadiren saat sınırını
aşıyor ve bölme, *"hangi saatte çalışmayı seviyorum"* sorusunu
bulanıklaştırırdı.

---

## 3. UX incelemesi — 6 bulgu

Ayrıntı: `UX_REVIEW.md` → FAZ 3.

| # | Bulgu | Kim buldu |
| --- | --- | --- |
| 3.1 | Çizgi grafik, çubuk grafikle **aynı veriyi** çiziyordu | **ben** (ekran görüntüsü) |
| 3.2 | "Ders dağılımı" başlığı ekranda **iki kez** | **ben** (ekran görüntüsü) |
| 3.3 | Yerleşik PDF fontu Türkçe harfleri desteklemiyor | **ben** (ölçüm) |
| 3.4 | `fl_chart 0.71` Flutter 3.24 ile derlenmiyor | **derleyici** |
| 3.5 | Grafikler eklenince QA turu listeyi bulamıyordu | **mevcut QA turu** |
| 3.6 | Veliye zayıf konu listesi gitmemeli | **ben** (tasarım) |

**3.1 ve 3.2 kendi eklediğim gürültüydü.** Üç grafik ekleyince ekranda
aynı veri iki kez çizilir hâle geldi ve aynı başlık iki kez yazıldı.
İkisi de ancak **tam sayfa görüntüsüne** bakınca göründü; kodda ayrı
widget'lar oldukları için gözden kaçıyorlardı.

**3.4 önemli bir uyarı:** `flutter analyze` **temiz geçti**, derleme
düştü. "Analyze temiz" tek başına yeterli bir kapı değil — bu yüzden
`flutter test` her turda koşuyor.

---

## 4. Testler (+17)

| Dosya | Test | İçerik |
| --- | --- | --- |
| `pdf_report_test.dart` | 9 | Türkçe glif bekçisi (iki yönlü), PDF imzası, veli<eğitimci boyutu, hesap kenar durumları |
| `build_report_test.dart` | 5 | veli≠eğitimci içeriği, boş günler 0 ile, paylar toplamı 1, boş rapor |
| `screenshots_test.dart` | +3 | grafikler, hedef kitle seçimi, dar ekran |

Güncellenen: `full_walk_test.dart` (grafikler eklenince listeye kaydırma),
`stats_screen_test.dart` (sahte `ShareGateway`'e `shareBytes`).

---

## 5. Ekran görüntüleri

| Dosya | İçerik |
| --- | --- |
| `81_stats_charts.png` | Üç grafik, 430 px |
| `82_report_audience.png` | Veli / Eğitimci seçimi |
| `83_stats_charts_narrow.png` | 360 px + uzun ders adı |

Toplam 39 kare.

---

## 6. Kalite kapıları

```
$ flutter analyze
No issues found! (ran in 6.6s)

$ flutter test
01:51 +845: All tests passed!

$ dart format .
Formatted 206 files (0 changed) in 2.37s

$ flutter build apk --release
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 828 | **845** ✅ |
| `flutter analyze` | 0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |
| `flutter build apk --release` | yeşil | ❌ SDK yok — sizin makinenizde |

### ⚠️ Bu fazda APK doğrulaması daha önemli

FAZ 3, v1.1'in **APK'ya en çok dokunan** fazı:

- **3 yeni paket:** `pdf`, `printing`, `fl_chart`
- **~340 KB gömülü font**
- `printing` paketi Android tarafında kendi kaynaklarını getiriyor

Derlemeyi kendi makinenizde çalıştırırken **APK boyutuna bakmanızı**
öneririm (`flutter build apk --release --analyze-size`). Beklenen artış
1–2 MB; bundan fazlaysa `printing` paketi gözden geçirilmeli — PDF
üretimi için `pdf` yetiyor, `printing` yalnızca yazdırma/önizleme için
gerekiyor ve **şu an kullanılmıyor**.

> Not: `printing`'i şimdi çıkarmadım çünkü paylaşım akışının gerçek
> cihazda nasıl davrandığını göremiyorum; çıkarmanın etkisini
> doğrulayamadan bağımlılık silmek riskli. Cihazda paylaşım çalışıyorsa
> `printing` güvenle kaldırılabilir.

---

## 7. Değişen dosyalar

**Yeni**
```
FAZ_3.md
lib/domain/entities/report_data.dart
lib/application/usecases/build_report.dart
lib/services/report/pdf_report_builder.dart
lib/presentation/stats/report_button.dart
lib/presentation/stats/stats_charts.dart
assets/fonts/Roboto-Regular.ttf · Roboto-Bold.ttf
test/unit/pdf_report_test.dart · build_report_test.dart
qa_screenshots/81..83 (3 PNG)
```

**Değişen**
```
pubspec.yaml                              pdf, printing, fl_chart ^0.69, assets/fonts
lib/domain/ports/share_gateway.dart       shareBytes
lib/services/export/file_share_gateway.dart  gerçek + Noop shareBytes
lib/core/di/app_providers.dart            rapor + ısı haritası provider'ları
lib/presentation/stats/stats_screen.dart  Rapor Al + üç grafik bölümü
lib/l10n/*.arb                            26 yeni anahtar
test/qa/full_walk_test.dart               grafik sonrası kaydırma
test/widget/stats_screen_test.dart        sahte kapıya shareBytes
```
