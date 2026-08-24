# v1.3 — KİTAP OKUMA MODU

**Dal:** `claude/sinav-odak-v1.3` (`c734b93`'ten açıldı)
**Test:** 1274 → **1358**
**Şema:** 6 → **7**

> `claude/sinav-odak-v1.1` ve `claude/sinav-odak-v1.2` **donduruldu**,
> ikisine de dokunulmadı.

---

## Şema kararı: AYRI tablo

Çalışma oturumunun üç zorunlu alanı var: **ders**, **çalışma türü**,
**çizelge**. Kitap okumanın üçü de yok.

| | `study_sessions`'a sığdır | `book_sessions` ekle |
| --- | --- | --- |
| Sahte "Kitap Okuma" dersi | **gerekir** | yok |
| O sahte dersin göründüğü yerler | ders seçici · pasta grafik · CSV · gelişim gereken konular | — |
| Sayfa hedefi modunda `schedule_json` | uydurulur | gerekmiyor |
| `daily_stats`, seri, PDF'in ayrıca okuması | gerekmez | **gerekir** |

İkincisi seçildi. Bedeli görünür ve testle kilitli; sahte ders satırının
bedeli görünmez olurdu — roman okuyan öğrenci ders dağılımında
"Kitap Okuma %40" satırı bulurdu.

```
book_sessions(id, date_key, mode, started_at, ended_at,
              planned_duration_s, page_target,
              actual_duration_s, pages_read, book_title, status)
```

Karşı modun alanı `null` KALIYOR: sayfa modunda planlanmış süre yok,
uydurulmuyor. Çalışma oturumundaki `idx_one_running` koruması kitap için
de var (`idx_one_running_book`) — üstelik iki tür oturum **aynı anda**
açılamıyor.

**Migration v6 → v7:** tablo + `daily_stats`'a iki kolon (`reading_s`,
`pages_read`). Mevcut hiçbir satır değişmiyor; v1.2'de kaydedilmiş günler
"0 saniye okuma" olarak devam ediyor — doğru cevap, çünkü o günlerde
kitap modu gerçekten yoktu.

---

## SERİ KURALI — kuralın kodda durduğu yer

> *"kitap oturumu da seriye sayılır — o gün sadece kitap okuyan
> öğrencinin serisi KIRILMAZ."*

Seri hesabı çalışma oturumuyla **tek yerden** geçiyor:

```dart
// SessionRepository.saveBookSession
await _db.statsDao.recomputeDay(dateKey);
await recomputeStreak(dateKey);      // ← kural burada
await recomputeGoals(dateKey);
await recomputeAchievements(dateKey);
```

`book_streak_test.dart` sekiz testle zorluyor: üç gün üst üste yalnızca
kitap → seri 3 · çalışma ile okuma **aynı** seriyi paylaşıyor · okumanın
araya girdiği gün zinciri kurtarıyor · aynı gün ikinci okuma seriyi iki
kez artırmıyor · kitapsız geçen gün zinciri **kırıyor** (kural simetrik,
"kitap okuyunca seri hiç kırılmaz" gibi bir kaçak yok) · silinen okuma
seriye sayılmıyor · seri rozeti okuma günüyle de açılıyor.

**Rozet ve hedefler de aynı yoldan geçiyor.** Geçmeseydi öğrenci seriyi
uzatır, "7 gün üst üste" rozetini bir sonraki ÇALIŞMA oturumuna kadar
göremezdi.

---

## Okuma süresi ÇALIŞMA süresine EKLENMİYOR

`daily_stats.total_study_s` yalnızca çalışma oturumlarını sayıyor; okuma
`reading_s` içinde ayrı duruyor.

**Neden:** ikisi toplansaydı bir saat roman okuyan öğrencinin **günlük
çalışma hedefi** kendiliğinden dolardı. Hedef "ne kadar çalıştım"
sorusunu cevaplıyor.

Grafik yine de ikisini birlikte gösteriyor — **yığılmış çubuk**, ayrı
renk, altında efsane. Tek renge katılsaydı grafiğe bakan öğrenci "iki
saat çalışmışım" sanırdı; hiç gösterilmeseydi o gün kitap okuyan öğrenci
boş bir sütun görürdü.

Grafiğin başlığı da değişti: **"Günlük çalışma" → "Günlük süre"**.
Çubuklara okuma girdikten sonra "çalışma" demek küçük bir yalandı.

---

## "Emin misin?" — brifteki iki cümlenin okunuşu

Brif iki şey söylüyordu:

```
MOD A/B  ... "Bitti" · "Emin misin?" → Evet → kitap adı + sayfa
ORTAK    "Emin misin?" → Hayır: form açık kalır, veri kaybolmaz
```

Onay **"Bitti"ye basınca** çıkıyor, sonra form açılıyor (birinci cümle).
"Hayır" hiçbir şey kaybettirmiyor: diyalog kapanıyor, **oturum açık
kalıyor, biriken süre duruyor**, sayaç kaldığı yerden görünüyor (ikinci
cümle). `book_flow_test` bunu ayrı bir testle kilitliyor.

**Süre modunda sayaç kendiliğinden dolarsa onay SORULMUYOR** — okuma
zaten bitti, onaylanacak bir karar yok; sormak boş bir dokunuş olurdu.
Doğrudan forma geçiliyor. *Farklı isteniyorsa tek satır.*

Diyaloğa **"Sil"** de kondu (brifte yoktu): yanlışlıkla başlatılan bir
okuma istatistiğe ve **seriye** karışmamalı. v1.1'de çalışma oturumu için
alınan kararın (FAZ 1.3) aynısı, ikinci onaydan geçiyor ve yıkıcı eylem
en solda duruyor.

---

## Süre girmenin ÜÇ yolu

```
sayıya dokun    → klavye açılır          (uzak değer: 30 → 90)
[+] tek dokunuş → +5 dk / +5 sayfa       (yakın değer)
[+] basılı tut  → akan sayaç, hızlanır   (arada kalan değer)
```

Akan sayaç `HoldRepeatButton` — hedef ekranı için yazılmış ve test
edilmiş bileşen; yeniden yazılmadı. Klavye alanı `GoalInput.parseDuration`
ile **aynı** ayrıştırıcıyı kullanıyor ("1sa 30dk", "90", "1:30"), yalnızca
aralık farklı (5 dk – 12 saat). İki ayrı ayrıştırıcı, aynı kullanıcının
aynı yazımının bir ekranda kabul edilip diğerinde reddedilmesi demekti.

---

## Nereye eklendi — kurulum akışına DEĞİL

Kitap, ana panelde **ikinci bir kapı** (`Kitap Oku`). Ders/konu/tür
seçiminin önüne "ne tür oturum?" ekranı koymak, yaygın durumu (çalışma
oturumu) her seferinde bir dokunuş yavaşlatırdı. Okuma zaten ders ve konu
seçmiyor; kendi kapısından giriyor.

---

## Gözle bulunan BEŞ hata

Testler yeşildi; beşi de ekran görüntüsüne ve üretilen PDF'e bakınca
çıktı.

**1. Sayaç ekranın soluna yapışmış, ilk hane KIRPILMIŞTI.** `Scaffold`
gövdeye **gevşek** genişlik veriyor (`0 <= w <= 411`); `Column` en geniş
çocuğu kadar daralıyor ve içerik sola kayıyordu. Çalışma ekranında sorun
görünmüyor çünkü orada tam genişlik kaplayan bir çocuk (banner) var —
yani orada da kural yazılı değil, **tesadüf**. `SizedBox(width: infinity)`
+ sayaca `FittedBox` eklendi.

**2. Oturum sonu formunda "Okuma Bitti" İKİ KEZ yazıyordu** — başlık
çubuğunda ve kartın içinde. Kartın söyleyecek daha iyi bir şeyi vardı:
okunan süre.

**3. "20 sayfa" düğmesi "+20" gibi okunuyordu.** Hedefi tek dokunuşla
yazan düğme, yanındaki "+20" artırma düğmesiyle aynı sıradaydı ve ikisi
aynı şeymiş gibi görünüyordu. **"Hedefe ulaştım"** oldu.

**4. Okuma sürerken "Oturumu Başlat" hâlâ ETKİNDİ.** Dokununca router
kullanıcıyı sayaca geri atıyordu — düğme hiçbir şey yapmamış gibi
görünüyordu. v1.1'de çalışma oturumu için düzeltilen hatanın
(UX_REVIEW §1.3, "dört ekran sonunda duvara çarpmak") kitap sürümü.
İki giriş de pasifleşti; dönüş yolu şeritte duruyor.

**5. PDF'te KİTAP bölümü ÖNCE yanlış rapora düştü, sonra başlığı
YALNIZ kaldı.** Bölüm eğitimci raporuna yazıldı sanılıyordu; üretilen
dosyaya bakınca **veli** raporunda çıktığı görüldü (aynı desen iki
şablonda da vardı, ilk eşleşme değiştirilmişti). Düzeltildikten sonra
"Kitap okuma" başlığı birinci sayfanın dibinde yalnız kaldı, içeriği
ikinci sayfaya geçti: `pw.Column` dikey `Flex` ve `MultiPage` onu sayfa
sınırından ikiye ayırabiliyor. `pw.Inseparable` ile başlık ve toplamlar
tek blok yapıldı. Ayrıca bölüm günlük dökümün **arkasına** alındı — kitap
listesi 14'erlik kartlara bölünebiliyor, günlük ritim grafiği
bölünemiyor; taşması gereken bölünebilen olmalı.

---

## Testler — KİTAP için 84

| Dosya | Adet | Ne koruyor |
| --- | ---: | --- |
| `test/unit/book_input_test.dart` | 22 | sınırlar, **boş kitap adı**, tavan kırpma — saf Dart |
| `test/unit/book_run_calculator_test.dart` | 12 | sayaç: geri/ileri, süre dolması, 12 saat tavanı, saatin geri alınması |
| `test/unit/book_session_test.dart` | 23 | iki modun kaydettiği veri, tek açık oturum, `daily_stats` ayrımı |
| `test/unit/book_streak_test.dart` | 8 | **SERİ KURALI** |
| `test/widget/book_flow_test.dart` | 11 | iki mod akışının tamamı + "Hayır" + boş ad + sil |
| `test/qa/book_shots_test.dart` | 11 | görsel üretim (12 PNG) |
| `test/qa/pdf_export_test.dart` (+3) | 3 | **PDF kitap satırı**, yalnızca-okuma raporu, kitaplı dosyalar |
| `test/unit/migration_v1_to_v2_test.dart` (+1) | 1 | v6 → v7, `daily_stats` bozulmuyor |

Brifin istediği dördü de var: iki mod akışı · seri kuralı · PDF kitap
satırı · ARB tr/en (60 yeni anahtar, iki dilde tam).

---

## Görülecek çıktılar

```
qa_book/                       12 PNG — kurulum, sayaç, onay, form, istatistik,
                               İngilizce, 320 px, küçültülmüş şerit
qa_pdf/rapor_veli_kitap.pdf    veli karnesi + KİTAP sayfası (2. sayfa)
qa_pdf/rapor_egitimci_kitap.pdf eğitimci raporu + KİTAP bölümü
```

Veli raporu **tek sayfa kalıyor**; KİTAP sayfası yalnızca okuma varsa
ekleniyor. Hiç okuma yoksa ne kart, ne bölüm, ne efsane çiziliyor —
öğrencinin yapmadığı bir şeyi eksik gibi göstermemek için.

---

## Bilerek yapılmayanlar

- **Ana paneldeki "Son oturumlar" okumaları göstermiyor.** Brif okumanın
  görüneceği üç yeri saymıştı: istatistik kartı, hafta/ay grafiği, PDF.
  Ana panel listesi kapsam dışıydı; karıştırmak "hangi sıra, ne gösterilir"
  sorusunu açıyor. **Not defterine yazıldı.**
- **Okuma bildirimi yok.** Çalışma oturumu blok/mola bildirimi kuruyor;
  okuma kurmuyor. Süre dolduğunda uygulama kapalıysa kullanıcı haber
  almıyor — açtığında forma düşüyor ve süre doğru yazılıyor.
- **Odak skoru yok.** "Uygulamadan kaç kez çıktın" ölçüsü, telefonu
  bırakıp kâğıt kitap okuyan öğrenci için anlamsız — ve onu
  cezalandırırdı.
- **CSV'ye okuma girmiyor.** Dışa aktarma sütunları çalışma oturumuna
  ait (soru, doğru, yanlış, net); okuma satırı o tabloya sığmıyor.
- **Kitap adı hatırlanmıyor.** Her oturumda yeniden yazılıyor; "aynı
  kitaba devam" kısayolu yok.

---

## APK/AAB YOK — sahte yeşil yazmıyorum

Bu ortamda Android SDK kurulu değil (`dl.google.com` proxy tarafından
kapalı). **Derlenmedi, cihazda çalıştırılmadı.** Aşağıdakiler bir insan
tarafından gerçek cihazda kontrol edilmeli:

```
flutter build apk --release
flutter build appbundle --release
```

1. v1.2 kurulu bir cihaza v1.3 kurulduğunda uygulama **açılıyor mu**
   (şema 6 → 7) ve eski istatistikler yerinde mi?
2. Okuma sürerken uygulama kapatılıp açıldığında sayaç **doğru süreyi**
   gösteriyor mu?
3. Sayfa hedefi modunda sayaç gece boyunca açık bırakılırsa süre 12
   saate kırpılıyor ve uyarı görünüyor mu?
