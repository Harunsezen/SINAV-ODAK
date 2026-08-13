# v1.1 — FAZ 1: TEMEL UX (P0)

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 786 → **803**

---

## 0. ÖZET

| Madde | Durum |
| --- | --- |
| 1.1 Oturumda geri dönüş (ana ekrana) | ✅ |
| 1.2 Plan ekranına geri tuşu | ✅ **dört kurulum ekranının hepsine** |
| 1.3 Erken bitirme diyaloğu (Kaydet/Sil/Devam) | ✅ |
| 1.4 `cupertino_icons` temizliği | ✅ zaten yoktu — **doğrulandı + bekçi test** |
| UX incelemesi | ✅ `UX_REVIEW.md` — **8 bulgu, 7'si düzeltildi** |
| `flutter test` | **803** ✅ (eşik 786) |
| `flutter analyze` | **0 issue** ✅ |
| `dart format .` | **0 changed** ✅ |
| `flutter build apk --release` | ❌ **YAPILAMADI** — §6 |

**Kendi bulduğum bulgular:** 4 tanesi (1.3, 1.4, 1.5, 1.6 — `UX_REVIEW.md`).
Biri kendi eklediğim özelliğin açtığı gedikti.

---

## 1. Yapılan değişiklikler

### 1.1 — Oturumdan onaylı çıkış

v1.0'da router aktif oturumda **her** yolu `/run`'a çeviriyordu; geri tuşu
"çıkamazsın" snackbar'ı gösteriyordu. Kullanıcı uygulamada kilitliydi.

Yeni akış:

```
[Aktif oturum] --geri tuşu / AppBar oku--> [Onay diyaloğu]
                                              |
                        Vazgeç <--------------+--------------> Ana panele dön
                          |                                          |
                    oturumda kal                          sessionMinimized = true
                                                          router /home'a izin verir
                                                                     |
                                                   [Ana panel: "24:00 kaldı" şeridi]
                                                                     |
                                                              dokun -> /run
```

**Korunan değişmezler** (üçü de ayrı testlerle iddia ediliyor):
- **Sayaç durmuyor.** Küçültme oturumu bitirmez; duvar saati işlemeye
  devam eder. "Pause yok" kuralı etkilenmedi.
- **`canPop` hâlâ false.** Kazara çıkış imkânsız; her iki kapı da onaydan
  geçiyor.
- **Onaysız kaçış hâlâ yasak.** `router.go(/home)` doğrudan denenirse
  `/run`'a geri çevriliyor.

Dosyalar: `minimize_session.dart` (yeni), `app_providers.dart`
(`sessionMinimizedProvider`, `showActiveSessionBannerProvider`),
`app_router.dart` (redirect), `run_screen.dart`, `break_screen.dart`,
`home_screen.dart`, `app.dart` (oturum bitince bayrak düşer).

### 1.2 — Kurulum akışında geri

Koordinatör Plan ekranını bildirmişti; kök neden **dört ekranı birden**
etkiliyordu: akış baştan sona `context.go()` kullanıyor, `go` yığını
değiştirdiği için `Navigator.canPop()` daima false ve AppBar'ın otomatik
geri tuşu hiç çizilmiyor.

Dördüne de açık `leading` geri tuşu eklendi, her biri bir önceki adıma
bağlı.

### 1.3 — Erken bitirme: üç yol

`Bitir` → **Sil · Devam et · Kaydet**

- **Kaydet** — eski davranış: bitiş bağlamı yazılır, özet formuna gidilir.
- **Devam et** — eski "Vazgeç": hiçbir şey değişmez.
- **Sil** — YENİ. `DiscardSessionUseCase`: bildirimleri iptal eder,
  izleyiciyi bırakır, satırları siler. **İkinci onaydan geçer.**

`DiscardSessionUseCase` neden üç işi birlikte yapıyor: yalnızca
`deleteSession` çağrılsaydı oturum giderdi ama bildirimleri OS'ta asılı
kalır ve yaşam döngüsü izleyicisi olmayan bir oturuma yazmaya devam
ederdi. Sıra da önemli — önce dış dünya, sonra veritabanı.

Şema doğrulandı: `session_blocks` CASCADE (`session_tables.dart:79`),
`wrong_items.session_id` SET NULL (`tracking_tables.dart:62`).

### 1.4 — `cupertino_icons`

**Zaten yoktu.** `pubspec.yaml`, `pubspec.lock` ve `lib/` ağacının
tamamında tek eşleşme yok. "Temizledim" demek yanlış olurdu; onun yerine
**geri gelmesini engelleyen bir bekçi test** eklendi
(`setup_back_navigation_test.dart`): pubspec'te `cupertino_icons`,
kodda `CupertinoIcons` veya `package:flutter/cupertino.dart` ararsa düşer.

---

## 2. UX incelemesi

Ayrıntı: **`UX_REVIEW.md`** (sayfa bazında, ekran görüntüsü referanslı).

| # | Bulgu | Kim buldu |
| --- | --- | --- |
| 1.1 | Oturumda geri tuşu yok | koordinatör |
| 1.2 | Kurulum geri tuşu — **4 ekranda birden** | koordinatör (kapsam ben) |
| 1.3 | Küçültülmüşken "Oturumu Başlat" hâlâ etkin | **ben** |
| 1.4 | "Sil" birincil butonun bitişiğinde | **ben** |
| 1.5 | "Sil" dokunma alanı ~30 px | **ben** |
| 1.6 | Şeritte kalan süre yok | **ben** |
| 1.7 | Mola ekranında da geri tuşu yok | **ben** |
| 1.8 | Geri ikonu çıplak (kabul edildi) | **ben** |

**1.3 en önemlisi:** kendi eklediğim küçültme özelliği ana paneli
erişilebilir yaptı ve "Oturumu Başlat" butonu orada duruyordu. Kullanıcı
dört kurulum ekranını geçip BAŞLAT'a bastığında `SessionFailure`
alıyordu. Veri bozulmuyor (`start_session.dart:38` kendini koruyor) ama
dört ekranlık bir çıkmaz. Buton artık **"Oturuma dön"** oluyor.

**1.4 yalnızca dar ekran görüntüsünde görüldü:** geniş ekranda "Sil"
sadece "Kaydet"in solundaydı; 360 px + textScale 1.3'te eylemler alt alta
geçince **"Sil" doğrudan "Kaydet"in üstüne** düşüyordu.

---

## 3. Ekran görüntüleri

`qa_screenshots/` — FAZ 1 için 7 yeni kare:

| Dosya | İçerik |
| --- | --- |
| `61_run_backbutton.png` | Aktif oturum, geri tuşu görünür |
| `62_minimize_dialog.png` | Küçültme onay diyaloğu |
| `63_home_active_banner.png` | Ana panel: "24:00 kaldı" şeridi + "Oturuma dön" |
| `64_early_finish_dialog.png` | Üç yollu Bitir diyaloğu (430 px) |
| `65_early_finish_bigtext.png` | Aynı diyalog, 360 px + textScale 1.3 |
| `66_setup_subject_back.png` | Ders Seç, geri tuşuyla |
| `67_setup_plan_back.png` | Plan, geri tuşuyla |

Toplam 31 kare (24 önceki + 7 yeni). Gerçek fontlarla
(`Roboto + MaterialIcons`), açık/koyu/büyük font/dar ekran.

---

## 4. Testler

**786 → 803 (+17)**

| Dosya | Test | İçerik |
| --- | --- | --- |
| `session_minimize_test.dart` | 7 | küçültme gidiş-dönüş, vazgeçme, onaysız kaçış YASAK, bayrak sıfırlama, "Oturumu Başlat" gediği, Sil + ikinci onay, Sil→vazgeç |
| `setup_back_navigation_test.dart` | 2 | dört adımda geri tuşu, cupertino bekçisi |
| `run_screen_test.dart` | +1 | AppBar geri tuşu aynı onaydan geçiyor |
| `screenshots_test.dart` | +7 | FAZ 1 görüntüleri |

### Güncellenen testler (gevşetme DEĞİL)

Beş test **eski ürün kuralını** kodluyordu ve koordinatör o kuralı
değiştirdi. Hepsi yeni davranışa **en az eskisi kadar sıkı** güncellendi:

| Test | Eski iddia | Yeni iddia |
| --- | --- | --- |
| `geri tuşu yakalanıyor` | snackbar çıkıyor | onay diyaloğu çıkıyor **+ Vazgeç ekranda tutuyor** |
| `Bitir tek tıkla kapatmıyor` | Vazgeç/Evet var | üç eylem var + "Devam et" oturumu açık tutuyor |
| `onay oturumu KAPATMIYOR` | "Evet, bitir" | "Kaydet" — iddianın kendisi aynı |
| QA walk: `geri tuşu KORUYOR` | — | küçültme diyaloğu + vazgeçince `/run`'da kalma |
| QA walk: `özet formu` | "Evet, bitir" | "Kaydet" |

**Hiçbir iddia kaldırılmadı**; `canPop == false` ve "onaysız çıkış yasak"
kontrolleri korundu, üstüne yenileri eklendi.

---

## 5. Değişen dosyalar

**Yeni**
```
FAZ_1.md · UX_REVIEW.md
lib/presentation/run/minimize_session.dart
lib/application/usecases/discard_session.dart
test/widget/session_minimize_test.dart
test/widget/setup_back_navigation_test.dart
qa_screenshots/61..67 (7 PNG)
```

**Değişen**
```
lib/core/di/app_providers.dart          sessionMinimized + showBanner + discard
lib/core/router/app_router.dart         redirect küçültmeyi tanıyor
lib/presentation/run/run_screen.dart    AppBar geri + üç yollu Bitir + Sil
lib/presentation/run/break_screen.dart  AppBar geri
lib/presentation/home/home_screen.dart  şerit + "Oturuma dön"
lib/app.dart                            oturum bitince bayrak düşer
lib/presentation/session_setup/*.dart   dört ekrana geri tuşu
lib/l10n/app_tr.arb · app_en.arb        16 yeni anahtar
test/... (5 test güncellendi)
```

---

## 6. Kalite kapıları — 4 komut çıktısı

```
$ flutter analyze
Analyzing sinav_odak...
No issues found! (ran in 5.1s)

$ flutter test
01:17 +803: All tests passed!

$ dart format .
Formatted 195 files (0 changed) in 1.81 seconds.

$ flutter build apk --release
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 786 | **803** ✅ |
| `flutter analyze` | 0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |
| `flutter build apk --release` | yeşil | ❌ **yapılamadı** |

### APK kapısı — dördüncü kez aynı engel

```
$ curl -s -o /dev/null -w '%{http_code}' https://dl.google.com/android/repository/repository2-3.xml
000
```

Android SDK bu ortamda yok ve indirilemiyor (S17, FAZ 6'dan beri). Bu kapı
**bu ortamda geçilemez**; sahte "yeşil" yazmıyorum. Derlemeyi sizin
makinenizde doğrulamanız gerekiyor. Bu turda hiçbir Android/Gradle
dosyasına dokunulmadı.

---

## 7. Dikkat edilmesi gereken ürün kararı

Küçültme, v1.0'ın **bilinçli** bir kısıtını gevşetiyor: "aktif oturum
varken kullanıcı ana panele kaçamaz". Gerekçesi çift oturum riskiydi.

Bu risk **kapalı kalıyor**: `StartSessionUseCase` zaten
`findActiveSession()` ile kendini koruyor, ve UX tarafında "Oturumu
Başlat" butonu artık aktif oturum varken "Oturuma dön"e dönüşüyor. Yani
kullanıcı ikinci oturuma giden yolu **hiç göremiyor**.

Yine de bu bir davranış değişikliği: kullanıcı artık oturum sürerken
istatistiklere, ayarlara, katalog yönetimine girebiliyor. Beta'da
izlenmesi gereken şey, öğrencilerin bu özgürlüğü "oyalanma" için kullanıp
kullanmadığı. Odak skoru zaten uygulamadan çıkışları ölçüyor
(`LifecycleTracker`) ama **uygulama içi** dolaşma o metriğe girmiyor.
