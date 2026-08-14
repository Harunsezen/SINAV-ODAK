# PDF TASARIM NOTU — Veli Karnesi + Eğitimci Raporu

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 865 → **866**
**Çıktı:** `qa_pdf/rapor_veli.pdf` (1 sayfa) · `qa_pdf/rapor_egitimci.pdf` (1 sayfa)

---

## KIRMIZI ÇİZGİLER — durum

| # | Çizgi | Durum |
| --- | --- | --- |
| 1 | Veliye zayıf konu listesi YOK | ✅ bölüm hiç çizilmiyor; karar `BuildReportUseCase`'te, iki test kilitli |
| 2 | Kaşe her sayfada, birebir metin | ✅ `MultiPage.footer` + veli sayfasında sabit alt blok |
| 3 | EMOJİ YOK → çizilmiş şekil | ✅ 7 simge + halka + çubuk + sütun + kilit, hepsi `CustomPaint` |
| 4 | TR virgül · "Dönem:" | ✅ `221,5` · `133,3` · `65,3` · `23,0` · "Dönem: 01.08.2025 — 07.08.2025" |
| 5 | Boş veri bölümü çizilmez | ✅ her bölüm `if` ile korunuyor + **yapısal test** |
| 6 | Test ≥ 860 | ✅ **866** |
| 7 | 5 maddelik tasarım notu | ✅ aşağıda |

---

# 5 TASARIM KARARI

## 1. Palet: tek aile, iki sıcaklık

İki belge **akraba görünmeli** ama karıştırılmamalı. Aynı beş aksan
rengini (indigo · teal · amber · violet · rose) ikisinde de kullandım;
ayrımı **zemin sıcaklığına** yükledim:

- **Veli — krem `#FCF9F2`.** Sıcak, kâğıt hissi, diploma/karne çağrışımı.
  Buzdolabına asılacak şey beyaz ofis kâğıdı gibi durmamalı.
- **Eğitimci — lavanta beyazı `#F7F6FC`.** Soğuk, nötr, uzun süre
  taranacak bir belge.

Başlık bandı da ayrışıyor: veli **indigo**, eğitimci **violet**. Aynı
ailenin iki üyesi.

Mürekkep saf siyah değil `#232636`. Kâğıtta saf siyah sert görünüyor ve
renkli kartların yanında ağırlık yapıyor.

## 2. Veli: az sayı, büyük sayı — eğitimci: çok sayı, sıkı ızgara

Aynı veriden iki farklı **yoğunluk**:

**Veli** üç kahraman kartla açılıyor (süre · soru · net), her biri kendi
yumuşak renk zemininde ve çizilmiş madalyonuyla. Altında başarı halkası,
seri ve oturum. Bir veli belgeyi 10 saniye okur; o 10 saniyede gurur
duyacağı üç sayı görmeli.

**Eğitimci** on ölçümü beşerli iki sıralık kart ızgarasında veriyor.
Tablo yerine ızgara, çünkü eğitimci aradığı sayıyı **tarayarak** değil
konumundan buluyor.

> **Ölçülen hata:** ızgara hücrelerine önce `CrossAxisAlignment.stretch`
> verdim. `MultiPage` çocuklarını dikeyde sınırsız kısıtla ölçüyor;
> stretch sonsuza uzayıp `TooManyPagesException` fırlattı — eğitimci
> raporu hiç üretilemedi. Aynı hatanın veli sayfasındaki kardeşi daha
> sinsiydi: sayfa üretildi ama **başlık bandı dışında hiçbir şey
> çizilmedi**. İkisi de sabit yükseklikle çözüldü.

## 3. Tablo değil çubuk

Ders dağılımı ve zayıf konular artık tablo değil **oranlı çubuk**:

```
Matematik   ████████████░░░░░░░░   4 sa 55 dk   195   133,3
Türkçe      █████░░░░░░░░░░░░░░░   1 sa 50 dk    90    65,3
Coğrafya    ██░░░░░░░░░░░░░░░░░░       40 dk     30    23,0
```

Payı anlamak için sayıları karşılaştırmak gerekmiyor, uzunluklara bakmak
yetiyor. Sayılar yine orada — çubuk onları **değiştirmiyor, önceliyor**.

Sütun anahtarı (Süre · Soru · Net) en altta ve soluk. Üstte olsa
çubukların önüne geçerdi; ihtiyaç duyulduğunda bakılacak bir dipnot.

Başarı oranı için **halka**: `%80` hem yazı hem şekil. Tepeden başlayıp
saat yönünde doluyor — dolan gösterge sezgisi.

## 4. Emoji yok: her simge vektör

`🔒` Roboto'da yok; `pdf` paketi eksik glifi sessizce `.notdef` kutusu
(▯) çiziyordu ve bu **veliye giden belgede** görünüyordu. Emoji fontu
(~1 MB) APK bütçesine sığmıyor.

Yedi simgenin hepsi `CustomPaint` ile çizildi: kilit · saat · soru
listesi · hedef · alev · oturum kartları · madalya. Toplam maliyet
birkaç yüz bayt, her okuyucuda aynı.

Simgeler **küçük boyutta okunana kadar** yeniden çizildi:

| Simge | İlk deneme | Sorun | Son hâl |
| --- | --- | --- | --- |
| Madalya | disk + göbek deliği | rakam **"8"** gibi okunuyordu | disk + **yıldız** |
| Oturum | takvim | **çanta** gibi | kaydırılmış iki kart |
| Oturum (2. deneme) | iki düz çubuk | **eşittir işareti** gibi | ↑ |
| Alev | simetrik damla | yuvarlak **leke** | sivri uçlu alev |

22–26 pt'de okunmayan bir simge süs değil gürültü.

## 5. Boşluk ve köşe: tek değer, her yerde

- **Köşe yarıçapı 12 pt**, istisnasız (bant 14, kaşe 8 — kasıtlı iki
  aykırı). Tutarlılık en ucuz tasarım aracı.
- **Kenar boşluğu 34 pt.** Geniş; karne havası sıkışıklığı kaldırmıyor.
- Bölümler arası **16 pt**, kart içi **12–14 pt**. İki kademe yeter.

Eğitimci raporunun altında **çizgili koç notu** var: el yazısıyla
doldurulacak üç satır. Rapor bir *belge*; üstüne not düşülebilmesi onu
kullanışlı kılıyor.

> **Ölçülen hata:** çizgileri önce kart kenarlığıyla aynı renkte
> (0.7 pt `#E4E1F0`) çizdim — beyaz üzerinde **görünmüyordu**. Çıktıya
> bakmasam "yaptım" derdim. 0.9 pt `#D5D0E6` ile hem belirgin hem silik.

---

## Ek: gözle bulunan üç kusur daha

Bu pas boyunca test yeşilken çıktıya bakarak bulunan, kodun kendi
raporlamadığı hatalar:

1. **"En iyi gün" hücresi BOŞ çiziliyordu.** Değer `03.08 · 1 sa 30 dk`
   idi; 12 pt kalın metin ~100 pt'lik hücreye sığmayınca `pdf` paketi
   hücreyi sessizce boş bıraktı. Tarih etikete taşındı:
   `1 sa 30 dk` / `En iyi gün · 03.08`.
2. **Koç notu neredeyse boş bir 2. sayfaya taşıyordu.** Bölüm araları
   kısaltıldı; 7 günlük rapor artık **tek sayfa**.
3. **Bir haftalık grafikte sütunlar sayfa genişliğine yayılıp** grafik
   değil renkli blok yığını gibi görünüyordu. Sütun genişliği 26 pt ile
   sınırlandı, bütün ortalandı.

---

## Uzun rapor güvenliği

Kartlar `Container`; `MultiPage` onları **bölemiyor**. Günlük listeyi tek
karta koysaydım 8 aylık bir rapor sayfadan uzun tek bir kart üretip
`TooManyPagesException` fırlatırdı.

Liste **24 satırlık kartlara bölünüyor** (`_daysPerCard`); kartlar
sayfalar arasında doğal akıyor. Regresyon testi 250 günlük tohumla hem
bunu hem kaşenin her sayfada olduğunu doğruluyor.

---

## Kalite kapıları

```
$ flutter test
01:02 +866: All tests passed!

$ flutter analyze
No issues found! (ran in 9.8s)

$ dart format .
Formatted 209 files (0 changed) in 1.91s
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 860 | **866** ✅ |
| `flutter analyze` | 0/0/0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |

APK derlemesi bu ortamda yok (Android SDK yok) — sizin makinenizde.
Bu pasta APK'ya **hiçbir varlık eklenmedi**: tüm görseller kod içinde
çizilen vektörler, yeni paket yok, yeni font yok.

---

## Değişen dosyalar

**Yeni**
```
PDF_TASARIM.md
lib/services/report/report_theme.dart    palet · TR biçim · çizim ilkelleri
```

**Değişen**
```
lib/services/report/pdf_report_builder.dart   tam yeniden tasarım
lib/l10n/app_tr.arb, app_en.arb               "Dönem" · Balto notu · koç notu
lib/presentation/stats/report_button.dart     iki yeni string
test/qa/pdf_export_test.dart                  boş-veri testi + 250 günlük spill
test/unit/pdf_report_test.dart                ReportStrings güncellendi
qa_pdf/*.pdf                                  yeniden üretildi
```

---

# EK — FONT KAYNAĞI SERTLEŞTİRME (mikro hotfix)

## Bildirilen belirti üretilemedi

Veli PDF'inde Türkçe karakter düşmesi bildirildi
(`Çalışma→Calisma`, `hiçbir→hibir`, `üretildi→retildi`). Teslim edilen
dosyada bu **ölçülemedi** — dört ayrı yoldan bakıldı:

| Kontrol | Veli | Eğitimci |
| --- | --- | --- |
| Sayfa görüntüsü (`pdftoppm`) | Türkçe doğru | Türkçe doğru |
| Metin katmanı (`pdftotext`) | `Çalışma Karnesi` · `Başarı oranı` | doğru |
| Gömülü font (`pdffonts`) | Roboto-Regular + Bold, Identity-H, `uni yes` | aynı |
| ToUnicode CMap | ş ğ ı ç ö ü | ş ğ ı **İ** ç ö ü |

İki belge **font açısından birebir aynı**. Veli CMap'inde İ yok çünkü
veli raporu hiç İ **basmıyor** (İntegral zayıf konular listesinde, o da
eğitimciye ait) — eksik font değil, eksik harf.

**Bakılabilecek yerler:** (a) elde eski bir kopya olması — bu pasta
dosya üç kez yeniden üretildi; (b) PDF okuyucunun kendi yazı tipi
değiştirme/erişilebilirlik ayarı; (c) metnin okuyucudan kopyalanıp
başka bir yere yapıştırılmış olması. Sizde hâlâ görünüyorsa hangi
okuyucu olduğunu yazın, o okuyucuya göre bakayım.

## Ama işaret edilen delik GERÇEKTİ

`ThemeData.withFont` yalnızca `base` + `bold` ile çağrılıyordu. Italik
girişleri boş kalınca `TextStyle.defaultStyle()` devreye giriyor:

```dart
// pdf-3.11.3/lib/src/widgets/text_style.dart:165
fontNormal: Font.helvetica(),
fontItalic: Font.helveticaOblique(),
```

Helvetica WinAnsi ve **ş/ğ/ı/İ taşımıyor**. Bugün italik kullanılmadığı
için patlamıyordu; **tek bir `fontStyle: italic` eklemek** tam olarak
bildirilen belirtiyi üretirdi — üstelik *hata vermeden*.

## Yapılan

1. **Tek font kaynağı:** `ReportFonts` (`report_theme.dart`). İki şablon
   da bundan besleniyor; `pdf_report_builder.dart` içinde başka hiçbir
   yerde font kurulmuyor.
2. **Dört girişin dördü de Roboto:** `base` · `bold` · `italic` ·
   `boldItalic`. Yerleşik font hiçbir yoldan giremiyor.
3. **Tasarım ve Balto cümlesi aynen korundu.**

## Bekçi testi — ve yalancı olmadığının kanıtı

`FONT BEKÇİSİ: veli PDF byte'ında ş/ğ/ı/İ + yerleşik font YOK` üç şeyi
iddia ediyor: yerleşik font geçmiyor · gömülü font yalnızca Roboto ·
yedi Türkçe harf ToUnicode CMap'inde.

Yedi harfin hepsini bastırmak için ölçümde Balto notu yerine prova
dizesi veriliyor (üretim metni değişmiyor) — böylece "şablon İ'yi
basabiliyor mu" sorusu da yanıtlanıyor.

**Negatif kontrol** (bekçinin gerçekten ısırdığı ölçüldü):

| `ReportFonts.theme` | italik metin | Bekçi |
| --- | --- | --- |
| italik boş (düzeltme öncesi) | var | ❌ *"yerleşik font Helvetica sızmış"* |
| italik = Roboto (düzeltme) | var | ✅ geçiyor |
| italik = Roboto (düzeltme) | yok (üretim hâli) | ✅ geçiyor |

Ortadaki satır önemli: düzeltme, italik **kullanılsa bile** belgeyi
güvende tutuyor.

```
$ flutter test    → +867: All tests passed!
$ flutter analyze → No issues found!
$ dart format .   → 209 files (0 changed)
```
