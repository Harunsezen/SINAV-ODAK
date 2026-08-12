# QA SWEEP + EKRAN GÖRÜNTÜSÜ PASI — RAPOR

**Tarih:** 2026-08-12 · **Sürüm:** v1.0 (kod dondurma sonrası)
**Kapsam:** tüm ekranların otomatik gezilmesi, her kontrolün basılması,
ekran görüntüsü üretimi.

---

## 0. ÖZET

| Ölçüt | Sonuç |
| --- | --- |
| **Toplam test** | **774** (önce 739 → **+35**) — hepsi yeşil |
| `flutter analyze` | **No issues found** (0 error / 0 warning / 0 info) |
| Gezinti turu | 12 tur · **69 adım** |
| Ekran görüntüsü | **22 PNG** · gerçek font (Roboto + MaterialIcons) |
| **Bulgu** | **8** → **4 A (çökme) düzeltildi** · 3 C (kozmetik) · 1 D (bilgi) |
| Emülatör | **çalıştırılamadı** (KVM yok + SDK indirilemiyor) — §1 |
| Koruma grep'leri | G3–G8 + G12 — eşleşmelerin tamamı tek tek okundu, **ihlal yok** (§6) |

Bu turda bulunan **4 çökme gerçek uygulama hatasıydı** — testlerin
uydurduğu senaryolar değil. Dördü de kullanıcının normal akışta
tetikleyebileceği türden: uzun bir ders adı yazmak, veya telefonu
430 px genişlikte kullanmak.

---

## 1. ÖN KONTROL — EMÜLATÖR NEDEN YOK

Koordinatör briefi: *"KVM ve dl.google.com kontrol et; ikisi de kapalıysa
emülatörü atla."* İkisi de kapalı:

```
$ ls -la /dev/kvm
ls: cannot access '/dev/kvm': No such file or directory

$ grep -c kvm /proc/modules
(boş)

$ curl -s -o /dev/null -w "%{http_code}" https://dl.google.com/android/repository/repository2-3.xml
000

$ which adb emulator sdkmanager
(hiçbiri yok)

$ ls /root/Android /usr/lib/android-sdk
ls: cannot access ...: No such file or directory
```

Donanım sanallaştırma cihazı yok, Android SDK yok ve indirilemiyor.
**Emülatör bu ortamda kurulamaz.** Bu FAZ 6 §7'deki S17 tespitinin aynısı;
durum değişmedi.

**Bunun yerine ne yapıldı:** `flutter test` cihaz gerektirmiyor.
Widget ağacı gerçek boyutlarla (430×932, 360×800) kuruldu, gerçek
kontrollere gerçek dokunuşlar gönderildi ve `RepaintBoundary.toImage`
ile ağaç doğrudan piksellere çevrildi. Bu, emülatörün **yerine geçmez**
(platform kanalları, gerçek Android çizimi, gerçek dokunma gecikmesi
kapsam dışı) ama arayüz mantığının ve düzeninin tamamını kapsıyor.

**Kapanmayan risk:** gerçek cihazda bildirim kanalı, wakelock, AdMob
görüntüleme ve paylaşım sayfası hâlâ **denenmedi**. FAZ 6'daki cihaz smoke
checklist'i geçerliliğini koruyor.

---

## 2. YÖNTEM

### 2.1 Yeni dosyalar

| Dosya | İçerik |
| --- | --- |
| `test/qa/qa_harness.dart` | ortak altyapı: gerçek font yükleme, tohum verisi, uygulama kurulumu |
| `test/qa/full_walk_test.dart` | 12 tur · 69 adım gezinti |
| `test/qa/screenshots_test.dart` | 23 test · 22 PNG |

### 2.2 Her adımın iddiası

`step()` yardımcısı her adımdan sonra **iki şeyi birden** doğruluyor:

```dart
await body();
await tester.pumpAndSettle();
expect(tester.takeException(), isNull, reason: '$name: istisna atıldı');
```

`takeException()` kritik: Flutter bir düzen hatasını (`RenderFlex overflow`,
`BoxConstraints forces an infinite width`, assertion) yakalayıp **kırmızı
ekran** çiziyor ve test yine de "geçmiş" görünüyor. `takeException` bunu
sessiz geçmeye kapatıyor. Ayrıca rota değişimlerinde `currentRoute(c)`
ile **doğru ekrana gidildiği** ayrıca iddia ediliyor.

### 2.3 Gerçek font

```
QA FONT: Roboto + MaterialIcons yüklendi
```

`flutter test` varsayılan olarak **Ahem** kullanıyor: her harf siyah bir
kutu olarak çiziliyor, görüntüler işe yaramıyor. Fontlar
`$FLUTTER_ROOT/bin/cache/artifacts/material_fonts` altından yüklendi.
Yüklenemeseydi test **düşmeyecek**, durum rapora yazılacaktı — yüklendi,
görüntülerdeki yazılar gerçek.

### 2.4 Harness'ta çözülen iki tuzak

**`pumpAndSettle` sonsuza kadar dönüyordu.** Ekranlar veri gelene kadar
`CircularProgressIndicator` çiziyor; bu sonsuz animasyon `pumpAndSettle`'ı
asla bitirmiyor. Çözüm: `pumpQaApp` 12 provider'ı önceden ısıtıyor, ilk
kare zaten veriyle geliyor.

**Ekran görüntüsü testi PNG'yi yazıp kilitleniyordu.** `toImage` ve
`toByteData` **gerçek** asenkron iş; testin sahte zaman bölgesinde
beklenirse dosya yazılıyor ama test bitmiyor. Flutter'ın kendi altın dosya
eşleştiricisi de aynı sebeple `runAsync` kullanıyor
(`flutter_test/lib/src/_matchers_io.dart` → `MatchesGoldenFile.matchAsync`).
`tester.runAsync(...)` ile sarıldıktan sonra 23 testin tamamı **8 saniyede**
bitiyor (öncesinde tek test 9+ dakikada bitmiyordu).

---

## 3. EKRAN × AKSİYON TABLOSU

Kısaltma: **✅** istisna yok + rota doğru.

### Tur 1 — BOŞ tur (hiç oturum yok)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ana Panel | boş "son oturumlar" durumu | ✅ |
| İstatistik | sekmeye geç | ✅ |
| İstatistik | boşken CSV dışa aktar → uyarı | ✅ |
| İstatistik | aralık: Ay | ✅ |
| Yanlışlar | sekmeye geç | ✅ |
| Takvim | sekmeye geç | ✅ |
| Takvim | önceki ay | ✅ |
| Takvim | sonraki ay | ✅ |
| Ayarlar | sekmeye geç | ✅ |
| Ana Panel | sekmeye dönüş | ✅ |

### Tur 2 — DOLU tur (oturum + yanlış + hedef verisi)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ana Panel | dolu liste + günlük kart | ✅ |
| İstatistik | grafik ve özet kartları | ✅ |
| İstatistik | Ay aralığı | ✅ |
| İstatistik | Hafta aralığı | ✅ |
| İstatistik | CSV dışa aktarma (Noop paylaşım kapısı) | ✅ |
| Takvim | dolu ay ısı haritası | ✅ |
| Yanlışlar | dolu liste | ✅ |

### Tur 3 — Kurulum akışı

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ana Panel | "Oturumu Başlat" | ✅ → `/setup/subject` |
| Ders Seç | ders seç | ✅ → `/setup/topic` |
| Konu Seç | "Konu seçmeden devam et" | ✅ → `/setup/activity` |
| Çalışma Türü | tür seç | ✅ → `/setup/plan` |
| Plan | "Özel" sekmesi | ✅ |
| Plan | "Bitiş" sekmesi | ✅ |
| Plan | "Hazır" sekmesine dönüş | ✅ |

### Tur 4 — Aktif oturum (değişmez kurallar)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Oturum | alt navigasyon **gizli** | ✅ |
| Oturum | **PAUSE düğmesi YOK** (aranıp bulunamadı) | ✅ |
| Oturum | "Molayı Atla" çalışma bloğunda **pasif** | ✅ |
| Oturum | "Bitir" → onay diyaloğu | ✅ |
| Oturum | onaydan "Vazgeç" → oturum sürüyor | ✅ |
| Oturum | "Bitir" → onayla → özet formu | ✅ → `/summary` |

### Tur 5 — Özet formu → tebrik

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Özet | +5 / +10 / +20 / Sıfırla | ✅ |
| Özet | soru sayısı + doğru/yanlış/boş dağılımı | ✅ |
| Özet | motivasyon seçimi + not girişi | ✅ |
| Özet | KAYDET | ✅ → `/done` |
| Tebrik | yeni rozet kartı ("İlk Adım") | ✅ |
| Tebrik | "Ana panel" | ✅ → `/` |

### Tur 6 — Yanlışlar

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Yanlışlar | Aktif / Tekrar edildi / Öğrenildi sekmeleri | ✅ |
| Yanlışlar | "+" → ekleme ekranı | ✅ |
| Yanlış Ekle | ders seç → KAYDET | ✅ |
| Yanlışlar | listeye dönüş, kayıt görünüyor | ✅ |

### Tur 7 — Ayarlar sekmesi (D4/K3 doğrulaması)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ayarlar sekmesi | **debug** modda `DbHealthPage` (geliştirme aracı) açılıyor | ✅ beklenen |

Bu kasıtlı: release derlemesinde gerçek Ayarlar ekranı açılıyor. Tur, bu
davranışı **iddia ediyor** ki ileride sessizce release'e sızmasın.

### Tur 8 — Ayarlar ekranı (her anahtar, her düğme)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ayarlar | tema: koyu → açık → sistem | ✅ |
| Ayarlar | "Ekran açık kalsın" kapat/aç | ✅ |
| Ayarlar | bildirim / ses / titreşim anahtarları | ✅ |
| Ayarlar | günlük hedef artır/azalt | ✅ |
| Ayarlar | net katsayısı → onay diyaloğu → **Vazgeç** | ✅ |
| Ayarlar | net katsayısı → **onayla** (geçmiş netler yeniden hesaplandı) | ✅ |
| Ayarlar | veri sıfırlama 1. onaydan **Vazgeç** | ✅ veri duruyor |
| Ayarlar | veri sıfırlama 2. adımda **yanlış kelime** → sil pasif | ✅ |
| Ayarlar | diyalogdan çık | ✅ veri duruyor |
| Ayarlar | Hedefler + Rozetler girişleri var | ✅ |

Veri sıfırlama **kasten tamamlanmadı** — yıkıcı işlem; onay kapılarının
tuttuğu doğrulandı, tetik çekilmedi.

### Tur 9 — Hedefler

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Hedefler | `/goals` açılıyor | ✅ |
| Hedefler | hedef silme → onay diyaloğu | ✅ |
| Hedefler | "Hedef ekle" → form sayfası | ✅ |

### Tur 10 — Rozetler ve katalog

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Rozetler | 11 rozet listesi, kilitli/açık | ✅ |
| Katalog | `/manage` açılıyor | ✅ |
| Katalog | **SİLME düğmesi YOK** (G8 iddiası) | ✅ |
| Katalog | arşivlenenleri göster/gizle | ✅ |
| Katalog | ders ekle → **Vazgeç** | ✅ eklenmedi |
| Katalog | ders ekle → **KAYDET** | ✅ eklendi |
| Katalog | "Türler" sekmesi | ✅ |
| Katalog | tür ekle | ✅ |

### Tur 11 — Uzun adlar + dar ekran (360 px)

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| Ana Panel | 360 px + çok uzun ders/konu adları | ✅ taşma yok |
| İstatistik | aynı | ✅ |
| Yanlışlar | aynı | ✅ |
| Kurulum akışı | aynı | ✅ |

### Tur 12 — textScale 1.5

| Ekran | Aksiyon | Sonuç |
| --- | --- | --- |
| İstatistik · Yanlışlar · Takvim · Ayarlar · Ana Panel | büyük fontla her sekme | ✅ 5/5 |

---

## 4. BULGULAR

### 4.1 A — ÇÖKME (4 bulgu, **dördü de düzeltildi**)

Dördü de gerçek uygulama hatası; gezinti turu bulmasa v1.0 ile birlikte
yayına çıkacaktı.

---

**A1 — Uzun ders/konu adı uygulamayı çökertiyor**

*Bulunduğu yer:* `lib/presentation/settings/catalog_screen.dart`
*Nasıl tetiklenir:* Katalog → "Ders ekle" → 60 karakterden uzun bir ad yaz → Kaydet.

Şemada `subjects.name` 60, `topics.name` 120, `activity_types.name` 60
karakterle sınırlı (`catalog_tables.dart`). Arayüzde **hiçbir sınır yoktu**:
uzun ad kabul ediliyor, yazma anında Drift `InvalidDataException` fırlatıyor
ve uygulama çöküyordu. Kullanıcı sadece uzun bir ders adı yazdığı için.

*Düzeltme:* `_NameDialog` artık `maxLength` alıyor ve `TextField`'a
veriyor — giriş kesiliyor **ve** sayaç sınırı önceden gösteriyor. Sınırlar
şemayla birebir aynı sabitlerde toplandı:

```dart
const int kSubjectNameMax = 60;
const int kTopicNameMax = 120;
const int kActivityNameMax = 60;
```

Beş çağrı yerinin (ders ekle/düzenle, konu ekle/düzenle, tür ekle/düzenle)
hepsi güncellendi.

---

**A2 — Ayarlar ekranı 430 px'te tema satırında çöküyor**

*Bulunduğu yer:* `lib/presentation/settings/settings_screen.dart`
*Nasıl tetiklenir:* Ayarlar ekranını 430 px genişlikte aç.

Tema seçici `ListTile(trailing: SegmentedButton(...))` olarak yazılmıştı.
Üç segmentli buton satırın **tamamını** kaplayınca Flutter
*"Trailing widget consumes entire tile width"* assertion'ı ile ekranı
çökertiyordu. 430 px sıradan bir telefon genişliği — bu, dar bir kenar
durumu değil.

*Düzeltme:* `ListTile` yerine `Column`; etiket üstte, seçici altta.

---

**A3 — Ayarlar'daki katalog satırı aynı sebeple çöküyor**

*Bulunduğu yer:* `lib/presentation/settings/settings_screen.dart`

Aynı hata, ikinci yer: `ListTile(trailing: FilledButton.tonal("Yönet"))`.

*Düzeltme:* Hedefler/Rozetler satırlarıyla aynı desene çekildi —
`trailing: Icon(Icons.chevron_right)` + satırın tamamı `onTap`.
Dokunma hedefi büyüdü, çökme kalktı.

---

**A4 — "Hedef ekle" alt sayfası açılırken çöküyor**

*Bulunduğu yer:* `lib/presentation/goals/goal_form_sheet.dart`
*Nasıl tetiklenir:* Hedefler → "Hedef ekle".

Alt sayfa `isScrollControlled` ile ölçülürken alttaki `Row`, çocuklarına
sonsuz genişlik veriyor; `FilledButton`
*"BoxConstraints forces an infinite width"* ile çöküyordu.

*Düzeltme:* `Row` → `OverflowBar`. Ölçüm güvenli hâle geldi, ayrıca dar
ekranda butonlar alt alta geçiyor.

---

### 4.2 C — KOZMETİK (3 bulgu, **düzeltilmedi** — kod dondurma)

**C1 — Koyu temada kilitli rozet ikonları fazla parlak.**
`14_achievements_dark.png`. Kilitli rozetlerin daire zeminleri koyu temada
neredeyse beyaz; açık rozetlerden daha çok dikkat çekiyor. Okunaklılık
sorunu yok, hiyerarşi ters.

**C2 — Boş takvimde yoğunluk göstergesi ("az ▁▂▃▄▅ çok") görünüyor.**
`43_calendar_empty.png`. Hiç veri yokken renk ölçeğini açıklamanın anlamı
yok; boş durum mesajıyla birlikte gösteriliyor.

**C3 — `31_home_narrow.png` uzun adları göstermiyor.**
Bu bir uygulama hatası değil, **görüntü seçimi hatası**: ana panel zaten
ders adı basmıyor, dolayısıyla bu görüntü uzun ad senaryosunu kanıtlamıyor.
Uzun adlar `32_stats_narrow.png`'de görünüyor (iki satıra sarıyor, taşma
yok) ve gezinti Tur 11'de dört ekranda ayrıca iddia ediliyor.

### 4.3 D — BİLGİ (1 bulgu)

**D1 — `app_en.arb` çeviri değil, kopya.**
339 anahtarın **339'u** Türkçe metnin birebir aynısı. Bu **bilinen ve
belgelenmiş** bir durum, yeni bir hata değil: `l10n.yaml` içinde
*"EN dosyası altyapının çalıştığını gösteren iskelet; tam çeviri v1.2'ye
ait"* yazıyor ve `app.dart:41` dili `locale: const Locale('tr')` ile
sabitliyor. Bugün kullanıcıya sızmıyor.

**Risk:** `app.dart:41`'deki sabitleme kaldırılırsa İngilizce cihazlar
Türkçe arayüz görür — sessizce, hata vermeden. v1.2'de çeviri yapılmadan
locale kilidi açılmamalı.

---

## 5. EKRAN GÖRÜNTÜLERİ (22 PNG)

Dizin: `qa_screenshots/` · üretim:
`flutter test test/qa/screenshots_test.dart`

| # | Dosya | Ekran | Koşul |
| --- | --- | --- | --- |
| 01 | `01_home_light.png` | Ana Panel | açık, 430×932 |
| 02 | `02_stats_light.png` | İstatistik | açık |
| 03 | `03_calendar_light.png` | Takvim | açık |
| 04 | `04_wrongs_light.png` | Yanlışlar | açık |
| 05 | `05_goals_light.png` | Hedefler | açık |
| 06 | `06_achievements_light.png` | Rozetler | açık |
| 07 | `07_catalog_light.png` | Katalog | açık |
| 08 | `08_run_light.png` | Aktif oturum | açık |
| 11 | `11_home_dark.png` | Ana Panel | **koyu** |
| 12 | `12_stats_dark.png` | İstatistik | koyu |
| 13 | `13_calendar_dark.png` | Takvim | koyu |
| 14 | `14_achievements_dark.png` | Rozetler | koyu |
| 15 | `15_run_dark.png` | Aktif oturum | koyu |
| 21 | `21_home_bigtext.png` | Ana Panel | **textScale 1.5** |
| 22 | `22_goals_bigtext.png` | Hedefler | textScale 1.5 |
| 23 | `23_stats_bigtext.png` | İstatistik | textScale 1.5 |
| 31 | `31_home_narrow.png` | Ana Panel | **360×800** + uzun adlar |
| 32 | `32_stats_narrow.png` | İstatistik | 360×800 + uzun adlar |
| 33 | `33_calendar_narrow.png` | Takvim | 360×800 |
| 41 | `41_stats_empty.png` | İstatistik | **boş durum** |
| 42 | `42_goals_empty.png` | Hedefler | boş durum |
| 43 | `43_calendar_empty.png` | Takvim | boş durum |

**Görüntüler iddia edilmiyor** — altın dosya karşılaştırması yok. Amaç
insan gözüyle bakılacak çıktı üretmek; test yalnızca üretim sırasında
istisna atılmadığını doğruluyor. Altın dosya karşılaştırması eklenirse
her font/tema değişikliğinde 22 dosya kırmızıya döner; v1.0'da bu maliyet
istenmedi.

**Görüntülerde göze çarpan bir artefakt:** katalog ve hedefler
görüntülerinde eylem düğmesinin (FAB) etrafında siyah bir çerçeve var.
Bu, test ortamında klavye odağının FAB'da olmasından kaynaklanan **odak
halkası**; gerçek cihazda dokunarak kullanınca çıkmıyor. Uygulama hatası
değil.

Ayrıca katalog görüntüsünde FAB son satırın üstüne biniyor gibi
görünüyor — bu da hata değil: liste `padding: EdgeInsets.only(bottom: 88)`
taşıyor, görüntü listenin ortasında alındığı için öyle görünüyor. Sona
kaydırıldığında son öğe FAB'ın üstünde kalıyor. (Kod okunarak doğrulandı:
`catalog_screen.dart:187`, `goals_screen.dart:40`.)

---

## 6. KORUMA GREP'LERİ (G3–G8, G12)

| Guard | Ham eşleşme | İhlal |
| --- | --- | --- |
| G3 testlerde `DateTime.now()` yok | 0 | ✅ 0 |
| G4a domain'de Flutter/Drift/Riverpod importu yok | 0 | ✅ 0 |
| G4b presentation → data importu yok | 0 | ✅ 0 |
| G5 run/application/domain'de `Timer` yok | 0 | ✅ 0 |
| G6 pause yok | 2 | ✅ 0 |
| G7 özet/tebrik ekranında reklam yok | 3 | ✅ 0 |
| G8 ders/konu silme yok | 2 | ✅ 0 |
| G12 `lib/` içinde production reklam kimliği yok | 5 | ✅ 0 |

**Dürüstlük notu:** bu turda grep desenlerini önceki fazlardan **daha geniş**
yazdım (G6'ya `.arb` dosyaları, G8'e tüm `delete(...)` çağrıları, G12'ye
tüm `ca-app-pub-` kimlikleri dahil). Bu yüzden dört guard'da eşleşme çıktı.
**Hepsini tek tek okudum**; dördü de yanlış alarm:

- **G6 (2)** → `app_tr.arb` + `app_en.arb`, `onboardingPromiseRules`:
  *"Sayaç duraklatılamaz: başladığın bloğu bitirirsin."* Bu, kuralın
  kullanıcıya **anlatıldığı** metin — ihlali değil, ilanı. Pause düğmesi
  gezinti Tur 4'te ayrıca arandı, **bulunamadı**.
- **G7 (3)** → `done_screen.dart` `interstitialController` çağrısı. Ara
  reklam tebrik ekranının **üzerinde** değil, **Ana panel'e geçişte**
  tetikleniyor (FAZ 4 tasarımı); `interstitial_test.dart` tebrik ekranının
  kendisinde reklam olmadığını açıkça iddia ediyor.
- **G8 (2)** → `database.dart:150-151` `delete(topics)` / `delete(subjects)`.
  Bunlar `resetAllData()` içinde, yani kullanıcının iki onaydan geçerek
  istediği **"Verileri sıfırla"** özelliği; ardından `SeedData.populate`
  ile katalog yeniden kuruluyor. Katalogdan **tek tek silme** hâlâ yok —
  gezinti Tur 10 silme düğmesini arayıp bulamadığını iddia ediyor.
- **G12 (5)** → hepsi Google'ın resmî **test** yayıncı kimliği
  (`ca-app-pub-3940256099942544`), `ad_config.dart` içinde `testAppId`,
  `testBannerUnit` gibi adlarla. Production kimlikleri `--dart-define` ile
  geliyor, kodda yok.

---

## 7. KANIT — 4 KOMUT

```
$ flutter analyze
No issues found! (ran in 6.7s)

$ flutter test
00:00 +774: All tests passed!
```

| Ölçüt | Eşik | Sonuç |
| --- | --- | --- |
| Test sayısı | ≥ 739 (düşmeyecek) | **774** ✅ |
| analyze error | 0 | **0** ✅ |
| analyze warning | 0 | **0** ✅ |
| analyze info | — | **0** ✅ |

**Test artışının kaynağı:** +12 gezinti turu, +23 ekran görüntüsü testi
= **+35**. 739 → 774.

---

## 8. DEĞİŞEN DOSYALAR

**Yeni**

```
test/qa/qa_harness.dart
test/qa/full_walk_test.dart
test/qa/screenshots_test.dart
qa_screenshots/           (22 PNG + README.txt)
QA_RAPORU.md
```

**Değişen (yalnızca A bulgularının düzeltmeleri)**

```
lib/presentation/settings/catalog_screen.dart     +30 −1   (A1)
lib/presentation/settings/settings_screen.dart    +38 −28  (A2, A3)
lib/presentation/goals/goal_form_sheet.dart       +8  −3   (A4)
```

Toplam `76 insertions(+), 32 deletions(-)`. **Davranış değişikliği yok** —
üçü de çökmeyi önleyen düzen/doğrulama düzeltmesi. Kod dondurma kapsamı
korundu: yeni özellik eklenmedi, mevcut hiçbir test gevşetilmedi.

---

## 9. KAPANMAYAN / DEVREDEN

| # | Konu | Neden kapanmadı |
| --- | --- | --- |
| S17 | APK/AAB derlemesi ve cihaz smoke testi | Android SDK yok, `dl.google.com` erişilemiyor (§1) |
| C1 | Koyu temada kilitli rozet kontrastı | kozmetik; kod dondurma |
| C2 | Boş takvimde yoğunluk göstergesi | kozmetik; kod dondurma |
| D1 | `app_en.arb` çevirisi | v1.2 kapsamı; bugün `locale` TR'ye sabit |
| — | Altın dosya (golden) karşılaştırması | v1.0'da bakım maliyeti istenmedi (§5) |

---

## 10. ZIP DOĞRULAMASI

`sinav_odak_v1.0_qa.zip` (1.4 MB · 390 dosya). Üretilmiş dosyalar
(`*.g.dart`, `app_localizations*.dart`), `build/`, `.dart_tool/` ve IDE
klasörleri **dışarıda** — ZIP'in kendi kendini kurabildiğini kanıtlamak
için.

**Boş bir dizine açılıp baştan kuruldu:**

```
$ unzip -q sinav_odak_v1.0_qa.zip -d <temiz-dizin>
$ find . -name '*.g.dart' -o -name 'app_localizations*.dart' | wc -l
0                                    ← üretilmiş dosya taşınmıyor

$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
Succeeded after 38.9s with 323 outputs (1496 actions)

$ flutter analyze
No issues found! (ran in 9.9s)

$ flutter test
00:00 +774: All tests passed!

$ ls qa_screenshots/*.png | wc -l
22
```

ZIP, kaynaktan sıfırdan derlenip **774 testin tamamını geçiriyor**.

---

## 11. NE ÖĞRENDİM

**"Test geçti" ile "ekran çizildi" aynı şey değil.** Bu turdaki dört
çökmenin hiçbiri mevcut 739 testin hiçbirini düşürmüyordu — çünkü hiçbiri
o ekranları **gerçek genişlikte** kurup **gerçek kontrollere** basmıyordu.
`takeException()` iddiası olmasaydı gezinti turu da sessizce geçerdi:
Flutter düzen hatasını yakalayıp kırmızı ekran çiziyor ve test yeşil
kalıyor.

**İkinci ders, harness'tan:** bir test "yavaş" görünüyorsa önce
kilitlenmediğinden emin olmak gerekiyor. Ekran görüntüsü testi PNG'yi
başarıyla yazıp sonra donuyordu; bu, "yavaş" değil "yanlış zaman
bölgesinde bekliyor" demekti ve çözüm `runAsync` idi — Flutter'ın kendi
altın dosya kodunun on yıldır yaptığı şey.
