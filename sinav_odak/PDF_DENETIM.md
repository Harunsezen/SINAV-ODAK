# PDF GÖRSEL DENETİMİ — Veli + Eğitimci

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 860 → **865**
**Çıktı:** `qa_pdf/rapor_veli.pdf` · `qa_pdf/rapor_egitimci.pdf` · `qa_pdf.zip`

---

## 0. ÖZET

| Brief maddesi | Durum |
| --- | --- |
| 1. Tohum verisiyle iki gerçekçi PDF | ✅ 7 oturum · 3 ders · 2 konu · 3 yanlış · 1 rozet · seri 6/11 |
| 2. `test/qa/pdf_export_test.dart` — kalıcı test | ✅ 5 test |
| 3. Türkçe provası ş/ğ/ı/İ/ç/ö/ü | ⚠️ **İ eksikti — bulundu ve düzeltildi** |
| 4. Veli PDF'inde zayıf konu YOK | ✅ gözle doğrulandı |
| 5. Her sayfanın altında gizlilik kaşesi | 🔴 **BOZUKTU — düzeltildi** |
| 6. Sohbete ek | ✅ `qa_pdf.zip` |
| 7. Kapılar | test **865** ✅ · analyze **0** ✅ · format **0 changed** ✅ |

**Gözle bakmasaydım bulunamayacak 6 kusur çıktı.** Beşi düzeltildi, biri
raporlandı (§6). En ağırı doğrudan 5. maddeyi ihlal ediyordu.

---

## 1. 🔴 P0 — Gizlilik kaşesi sayfaların çoğunda YOKTU

Brief'in 5. maddesi: *"Her sayfanın altında gizlilik kaşesi görünür
olsun."* İlk üretimde 2 sayfalık raporda kaşe iki sayfada da vardı —
**geçmiş gibi görünüyordu.** Geçmemişti.

Kaşe `MultiPage.build` listesinin **son elemanıydı**. `MultiPage`
çocukları sayfalara akıtır; dolayısıyla kaşe akışın bittiği yere, yani
**yalnızca son sayfaya** düşüyordu. 7 oturumluk tohum bunu gizledi:
her şey 2 sayfaya sığdığı için kaşe zaten son sayfadaydı.

### Ölçüm — 80 günlük gerçekçi aralık

```
Toplam sayfa: 5
  sayfa 1 -> gizlilik kaşesi: 1
  sayfa 2 -> gizlilik kaşesi: 0     ← söz verilmiş, yazılmamış
  sayfa 3 -> gizlilik kaşesi: 0
  sayfa 4 -> gizlilik kaşesi: 0
  sayfa 5 -> gizlilik kaşesi: 1
```

3 aylık çalışan bir öğrencinin eğitimci raporunda **5 sayfanın 3'ünde**
kaşe yok. Bu yalnızca kozmetik değil: ürünün "veri cihazda kalıyor"
sözünün belgedeki tek yazılı kanıtı o kaşe.

### Düzeltme

Kaşe akış çocuğu olmaktan çıkıp `MultiPage.footer` içine taşındı —
`footer` her sayfa için ayrı çağrılıyor. Sayfa numarası da aynı alt
bloğa alındı.

### Regresyon testi

`gizlilik kaşesi SPILL eden raporda da her sayfada` — 80 günlük tohumla
üretip **sayfa içerik akışlarını zlib'den çözerek** kaşeyi sayfa sayfa
sayıyor:

```dart
final pages   = streams.where((s) => s.contains('BT')).toList();
final stamped = pages.where((s) => s.contains(marker)).length;
expect(pages.length, greaterThanOrEqualTo(3));  // tohum kısa olursa test boş kalır
expect(stamped, pages.length);
```

Gömülü fontta metin subset glif indeksine dönüştüğü için aranamıyor;
bu yüzden test **yerleşik Helvetica + ASCII işaret** kullanıyor. Düzenin
kendisi ölçülüyor, metin değil.

---

## 2. 🔴 P0 — Kilit emojisi veliye giden belgede kutu (▯) olarak çıkıyordu

`app_tr.arb` + `app_en.arb` içindeki kaşe metni `🔒` ile başlıyordu.
Roboto'da U+1F512 **yok**. `pdf` paketi uyarıyor ve `.notdef` kutusu
çiziyor:

```
Unable to find a font to draw "🔒" (U+1f512) try to provide a TextStyle.fontFallback
```

Görsel kanıt ilk çıktıda netti: kaşe metninin başında boş kare.
**Üretim ARB'sinde olduğu için gerçek kullanıcı PDF'lerini de
etkiliyordu** — yalnızca testi değil.

**Emoji fontu eklemedim.** NotoEmoji ~1 MB+; FAZ 4'teki bütçe "v1.0 →
v1.1 toplam artış ~2 MB'ı geçmemeli" ve görsel başına 200 KB üst sınırı
var. Bir kilit ikonu için o bedel ödenmez. Emoji metinden kaldırıldı;
kaşenin gri zemini zaten görsel ayrımı sağlıyor.

> **Not:** Uygulama içi Balto metinlerindeki emojiler (🌴 🤝 🧊 …)
> etkilenmedi — onlar Flutter tarafında, cihaz emoji fontuyla çiziliyor.
> Sorun yalnızca PDF'e giren tek metinde.

---

## 3. 🟠 P1 — "En iyi gün" gün göstermiyordu

Eğitimci raporu:

```
En iyi gün        1 sa 30 dk      ← hangi gün?
```

Etiket bir **gün** vaat ediyor, değer bir **süre**. Eğitimci o günü
takvimle eşleştiremiyor; sayı tek başına işe yaramaz.

`ReportData.bestDayKey` eklendi (saf Dart, eşitlikte ilk gün kazanır):

```
En iyi gün        2025-08-03 · 1 sa 30 dk
```

---

## 4. 🟠 P1 — Tablolar kendi bölüm başlığını sütun başlığı olarak tekrarlıyordu

```
Ders dağılımı                         ← bölüm başlığı
┌───────────────┬────────┬──────┬─────┐
│ Ders dağılımı │  Süre  │ Soru │ Net │  ← aynı metin, sütun başlığı
```

Aynısı "Gelişim gereken konular" tablosunda da vardı. Sütun başlığı
sütunu adlandırmalı, bölümü değil. `ReportStrings`'e `subjectColumn`
("Ders") ve `topicColumn` ("Konu") eklendi; ARB'ye iki yeni anahtar.

---

## 5. 🟠 P1 — Özet ızgarasının ilk VERİ satırı başlık gibi çiziliyordu

Eğitimci sayfa 1'inde "Toplam çalışma | 6 sa 30 dk" satırı ortalanmış ve
vurgulu çiziliyordu; altındaki satırlar sola dayalıydı. Sebep:

```dart
pw.TableHelper.fromTextArray(headers: null, data: [...])
```

`headerCount` varsayılanı **1**. `headers: null` verilince paket ilk
**veri** satırını başlık sanıyor. `headerCount: 0` eklendi.

---

## 6. 🟡 RAPORLANDI (düzeltilmedi) — Yanlış defteri rapora hiç yansımıyor

`statsDao.weakestTopics` şunu yapıyor:

```sql
SELECT ... SUM(ss.wrong_count) FROM study_sessions ss JOIN topics t ...
```

Yani **oturumlardaki** yanlış sayısını konuya göre topluyor.
`wrong_items` tablosuna — öğrencinin *yanlış defterine elle yazdığı*
kayıtlara — **hiç bakmıyor**.

Tohumda Türev'e 12 + 7 = 19 yanlış elle eklendim; raporda görünen sayı
**30** (oturumlardan gelen 8+12+10). Defterdeki 19 kayıt hiçbir yere
gitmiyor.

Bu, bu projenin **tekrar eden hata sınıfının** yeni bir örneği:
*"veri yazılıyor, okuyan kod yok"* (`keepScreenOn`, `daily_stats`,
`streak`, `goals.currentValue`, `achievements`, `banner_position`).

**Düzeltmedim** çünkü bu bir **ürün kararı**: "gelişim gereken konular"
oturum istatistiğinden mi, defterden mi, ikisinin toplamından mı
beslenmeli? Öğrencinin bilerek deftere yazdığı konu bence daha güçlü bir
sinyal — ama bunu tek başıma değiştirmek raporun anlamını sessizce
kaydırırdı. Karar sizin.

Testteki yanlış yorum düzeltildi (eskiden "buradan besleniyor" diyordu).

---

## 7. ⚠️ Türkçe provası: İ harfi hiç basılmıyordu

Brief 7 harf istedi: **ş ğ ı İ ç ö ü**. İlk çıktıda altısı vardı, **büyük
İ (U+0130) raporun hiçbir yerinde geçmiyordu** — yani font kilidinin
kanıtlaması gereken en kritik harflerden biri *görsel olarak
doğrulanmamıştı*. (`pdf_report_test.dart` yerleşik fontun İ'yi
desteklemediğini zaten ölçüyor; eksik olan gömülü fontla **basılmış**
kanıttı.)

Tohuma `İntegral` konulu bir oturum eklendi (7. oturum). Artık zayıf
konular tablosunda "Matematik · İntegral" basılıyor.

### Son durum — gözle doğrulanan harfler

| Harf | Nerede görünüyor |
| --- | --- |
| ş | Çalı**ş**ma Karnesi · Ba**ş**arı oranı · payla**ş**ılmadı |
| ğ | Co**ğ**rafya · Ders da**ğ**ılımı · Geli**ş**im |
| ı | Aral**ı**k · Sat**ı**lmad**ı** · yaln**ı**zca · S**ı**nav Odak |
| İ | **İ**ntegral |
| ç | Türk**ç**e · **ç**alışma |
| ö | Günlük d**ö**küm |
| ü | T**ü**rkçe · S**ü**re · G**ü**n · d**ö**k**ü**m |

Hepsi Roboto'dan doğru glifle çıkıyor; hiçbirinde kutu/tofu yok.

---

## 8. ✅ Veli raporunda zayıf konu listesi YOK — gözle doğrulandı

Brief 4. maddesi. `rapor_veli.pdf` **tek sayfa**; içinde yalnızca:

1. Başlık + aralık
2. Altı büyük sayı (süre · oturum · soru · net · başarı · seri)
3. Ders dağılımı tablosu (3 satır)
4. Gizlilik kaşesi

**"Gelişim gereken konular" bölümü hiç yok** — ne başlık, ne tablo, ne
boş bir "—". Sayfada aşağı doğru geniş bir boşluk var; oraya
eklenmediği gözle görülüyor.

Karar PDF katmanında değil, `BuildReportUseCase` içinde:

```dart
final weak = audience == ReportAudience.teacher
    ? await _db.statsDao.weakestTopics(from, to)
    : const <...>[];
```

Veli raporu için liste daha veri katmanında boş geliyor; PDF'in gizleyip
gizlememesine kalmıyor. İki test bunu kilitliyor (biri use-case
seviyesinde, biri bu QA testinde).

---

## 9. Üretilen çıktı

| Dosya | Boyut | Sayfa |
| --- | --- | --- |
| `qa_pdf/rapor_veli.pdf` | 13.8 KB | 1 |
| `qa_pdf/rapor_egitimci.pdf` | 15.8 KB | 2 |
| `qa_pdf.zip` | 27.6 KB | — |

### Tohum verisi

7 oturum · 2025-08-01 → 08-07 · 3 ders (Matematik, Türkçe, Coğrafya) ·
2 konu (Türev, İntegral) · 315 soru · net 221.5 · başarı %80 ·
seri 6/11 · 1 rozet (`streak_3`) · 3 yanlış defteri kaydı.

Sayılar elle doğrulandı:

| Değer | Hesap | Raporda |
| --- | --- | --- |
| Toplam süre | 26 700 sn | 7 sa 25 dk ✓ |
| Soru | 236 doğru + 58 yanlış + 21 boş | 315 ✓ |
| Net | 236 − 58/4 | 221.5 ✓ |
| Başarı | 236 / (236+58) = 236/294 | %80 ✓ (boşlar paydada yok) |
| Günlük ortalama | 26 700 / **7 çalışılan gün** | 1 sa 3 dk ✓ |
| En iyi gün | 5400 sn → 08-03 | 2025-08-03 · 1 sa 30 dk ✓ |

---

## 10. Kalite kapıları

```
$ flutter test
00:59 +865: All tests passed!

$ flutter analyze
No issues found! (ran in 20.1s)

$ dart format .
Formatted 208 files (0 changed) in 2.14s
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 860 | **865** ✅ |
| `flutter analyze` | 0/0/0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |

APK derlemesi bu ortamda yok (Android SDK yok) — sizin makinenizde.
Bu pasta APK'ya **hiçbir varlık eklenmedi**; iki ARB anahtarı ve bir
emoji kaldırıldı, boyut etkisi bayt mertebesinde.

---

## 11. Değişen dosyalar

**Yeni**
```
PDF_DENETIM.md
test/qa/pdf_export_test.dart      5 test
qa_pdf/rapor_veli.pdf
qa_pdf/rapor_egitimci.pdf
qa_pdf.zip
```

**Değişen**
```
lib/services/report/pdf_report_builder.dart   kaşe footer'a · headerCount:0
                                              · sütun başlıkları · en iyi gün
lib/domain/entities/report_data.dart          bestDayKey
lib/presentation/stats/report_button.dart     iki yeni string
lib/l10n/app_tr.arb, app_en.arb               🔒 kaldırıldı · 2 yeni anahtar
test/unit/pdf_report_test.dart                ReportStrings güncellendi
```

---

## 12. Ders

**"Test geçti" ile "doğru çıktı" aynı şey değil.** İlk koşuda 4 testin
dördü de yeşildi ve PDF'ler üretilmişti. Kaşe hatası da, emoji kutusu
da, İ eksiği de **yeşil testin altında** duruyordu. Üçü de ancak dosyayı
açıp sayfaya bakınca ortaya çıktı.

İkinci ders: **tohum verisi hatayı gizleyebilir.** 7 oturumluk "gerçekçi"
tohum tam olarak kaşe hatasının görünmediği boyuttaydı. Uzun aralığı
ayrıca denemeseydim rapor "5. madde ✅" diye kapanacaktı.
