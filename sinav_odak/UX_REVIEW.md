# UX_REVIEW — sayfa bazında ekran incelemesi

**Yöntem:** her değişen sayfa `qa_screenshots/` altına PNG olarak
çizildi ve **gözle** satır satır incelendi. Emülatör bu ortamda
kurulamıyor (KVM yok, `dl.google.com` kapalı — S17), bu yüzden görüntüler
`RepaintBoundary.toImage` ile gerçek fontlarla üretiliyor.

Kontrol listesi her sayfa için aynı: **geri tuşu · dokunma alanı (≥48 px) ·
metin taşması (uzun metin + textScale) · kontrast (koyu tema) · loading ·
error · empty · erişilebilirlik.**

---

## FAZ 1 — bulgu özeti

| # | Sayfa | Bulgu | Durum |
| --- | --- | --- | --- |
| 1.1 | Aktif oturum | Geri tuşu yoktu — kullanıcı oturumda kilitliydi | ✅ düzeltildi |
| 1.2 | Kurulum (4 ekran) | Geri tuşu **hiçbirinde** yoktu (bildirilenden geniş) | ✅ düzeltildi |
| 1.3 | Ana panel | **Küçültülmüşken "Oturumu Başlat" hâlâ etkin** — 4 ekran sonra hata | ✅ düzeltildi |
| 1.4 | Bitir diyaloğu | **"Sil" birincil butonun bitişiğinde** — dar ekranda tam üstüne düşüyor | ✅ düzeltildi |
| 1.5 | Bitir diyaloğu | "Sil" dokunma alanı ~30 px (<48) | ✅ düzeltildi |
| 1.6 | Ana panel şeridi | "Sayaç işliyor" — kalan süre yok, belirsiz | ✅ düzeltildi |
| 1.7 | Mola ekranı | Geri tuşu yoktu (oturum ekranıyla aynı kusur) | ✅ düzeltildi |
| 1.8 | Aktif oturum | Geri ikonu çıplak ok, etiket yok | ⚠️ kabul edildi |

**8 bulgu · 7'si düzeltildi · 1'i gerekçeyle bırakıldı.**

Bunlardan **1.3, 1.4, 1.5, 1.6 koordinatörün istemediği, ekran
görüntüsüne bakarken bulunan** bulgular. 1.3 kendi eklediğim özelliğin
açtığı bir gedikti.

---

## 1. Aktif oturum ekranı (`/run`)

**Görüntü:** `61_run_backbutton.png` (açık) · `08_run_light.png` ·
`15_run_dark.png`

| Kontrol | Sonuç |
| --- | --- |
| Geri tuşu | ✗ **YOKTU** → ✅ AppBar'a eklendi + sistem geri tuşu |
| Dokunma alanı | ✅ `IconButton` 48×48; alt butonlar `Expanded` |
| Metin taşması | ✅ textScale 1.5'te taşma yok (`23_*`, `65_*`) |
| Kontrast (koyu) | ✅ `15_run_dark.png` — sayaç ve butonlar okunur |
| Loading | ✅ oturum gelene kadar `CircularProgressIndicator` |
| Error | ✅ cihaz saati geri alınırsa `_ClockMovedBackBody` |
| Empty | — (aktif oturum tanımı gereği dolu) |
| Erişilebilirlik | ✅ sayaç `Semantics(liveRegion)` + dakika/saniye sözle |

### ✗ BULUNDU 1.1 — çıkış kapısı yok (koordinatör bildirdi)

Aktif oturumda geri tuşu yalnızca *"Oturumu bitirmek için Bitir'e bas."*
snackbar'ı gösteriyordu ve router **her** yolu `/run`'a çeviriyordu.
Kullanıcı ana panele, istatistiklere, ayarlara gidemiyordu. Uygulama
kullanıcıyı kendi ekranında hapsediyordu.

**DÜZELTME:** AppBar'a geri ikonu + sistem geri tuşu, ikisi de onay
diyaloğundan geçiyor. Onaylanırsa `sessionMinimizedProvider` yazılıyor ve
router `/home`'a izin veriyor.

**Korunan değişmezler:** sayaç DURMUYOR (pause yok), `canPop` hâlâ false
(kazara çıkış yok), onaysız `/home` denemesi hâlâ `/run`'a geri çevriliyor —
üçü de ayrı testlerle iddia ediliyor.

### ⚠️ 1.8 — geri ikonu çıplak (kabul edildi)

Odak ekranında AppBar başlığı yok; geri oku tek başına duruyor ve
"oturumu bitirir mi?" belirsizliği taşıyor. `tooltip` var ama dokunmatikte
görünmüyor.

**Neden düzeltilmedi:** etiket eklemek odak ekranının sadeliğini bozuyor
ve asıl belirsizliği zaten **onay diyaloğu** çözüyor — kullanıcı okuyup
karar veriyor, yanlışlıkla bir şey olmuyor. Metinli bir "Küçült" butonu
v1.2'de değerlendirilebilir.

---

## 2. Mola ekranı (`/run/break`)

**Görüntü:** `03_calendar_light.png` yok — mola için `08/15` serisi + kod
incelemesi.

| Kontrol | Sonuç |
| --- | --- |
| Geri tuşu | ✗ **YOKTU** → ✅ eklendi (bulgu 1.7) |
| Dokunma alanı | ✅ iki buton `Expanded`, 48 px yükseklik |
| Reklam ayrımı | ✅ native kart butonlardan ≥48 dp uzakta (FAZ 4 kuralı) |
| Loading | ✅ `CircularProgressIndicator` |

### ✗ BULUNDU 1.7 — mola ekranında da çıkış yok

Oturum ekranı düzeltilirken mola ekranı unutulsaydı, kullanıcı **molaya
girdiği anda** yine kilitlenecekti. Aynı `confirmMinimizeSession` bu
ekrana da bağlandı.

---

## 3. Ana panel (`/home`)

**Görüntü:** `63_home_active_banner.png` · `01_home_light.png` ·
`11_home_dark.png` · `21_home_bigtext.png` · `31_home_narrow.png`

| Kontrol | Sonuç |
| --- | --- |
| Geri tuşu | — (kök ekran) |
| Dokunma alanı | ✅ şerit `ListTile` (≥56 px), buton 56 px |
| Metin taşması | ✅ 360 px + textScale 1.5'te taşma yok |
| Kontrast (koyu) | ✅ şerit `primaryContainer`/`onPrimaryContainer` çifti |
| Empty | ✅ "Henüz kayıtlı oturum yok." |

### ✗ BULUNDU 1.3 — küçültülmüşken "Oturumu Başlat" hâlâ etkindi

**Kendi eklediğim özelliğin açtığı gedik.** v1.0'da router aktif oturumda
her yolu `/run`'a çevirdiği için ana panele hiç gidilemiyordu; küçültmeyi
ekleyince ana panel erişilebilir oldu ve **"Oturumu Başlat" butonu orada
duruyordu.**

Kullanıcı dört kurulum ekranını geçip BAŞLAT'a bastığında
`StartSessionUseCase` `SessionFailure` fırlatıyor. **Veri bozulmuyor** —
use-case `findActiveSession()` ile kendini koruyor (kontrol edildi,
`start_session.dart:38`) — ama kullanıcı dört ekran sonunda duvara
çarpıyor.

**DÜZELTME:** aktif oturum varken buton etiketi **"Oturuma dön"** oluyor
ve doğrudan `/run`'a götürüyor. Regresyon testi:
*"küçültülmüşken 'Oturumu Başlat' YENİ oturum başlatmıyor"*.

### ✗ BULUNDU 1.6 — şerit belirsizdi

İlk hâli *"Sayaç işliyor. Dokun, kaldığın yerden devam et."* diyordu.
20 dakika önce küçülten kullanıcı **ne kadar kaldığını bilmeden** geri
dönmek zorundaydı — oysa süre zaten `runStateProvider`'da hesaplanıyor.

**DÜZELTME:** şerit artık **"24:00 kaldı — dokun, devam et"** yazıyor.
Kalan süre yoksa (durum henüz çözülmediyse) eski metne düşüyor.

---

## 4. "Bitir" diyaloğu (FAZ 1.3)

**Görüntü:** `64_early_finish_dialog.png` (430 px) ·
`65_early_finish_bigtext.png` (360 px, textScale 1.3)

| Kontrol | Sonuç |
| --- | --- |
| Dokunma alanı | ✗ "Sil" ~30 px → ✅ hepsi 88×48 |
| Metin taşması | ✅ dar ekranda eylemler alt alta geçiyor, kesilme yok |
| Kontrast | ✅ "Sil" `colorScheme.error`, koyu temada da okunur |
| Yıkıcı eylem ayrımı | ✗ birincilin bitişiğindeydi → ✅ en uzağa alındı |

### ✗ BULUNDU 1.4 — "Sil", "Kaydet"in bitişiğindeydi

İlk sıralama **Devam et · Sil · Kaydet** idi. Geniş ekranda "Sil" birincil
butonun hemen solunda; **dar ekranda eylemler alt alta geçince "Sil"
doğrudan "Kaydet"in üstüne düşüyordu.** Geri alınamaz bir işlem için
yanlış dokunuş riski kabul edilemez.

Bu, ancak `65_early_finish_bigtext.png`'e bakınca görüldü — geniş ekran
görüntüsünde sorun bu kadar bariz değildi.

**DÜZELTME:** sıra **Sil · Devam et · Kaydet**. Yıkıcı eylem birincilden
en uzakta; aralarında güvenli bir eylem var.

### ✗ BULUNDU 1.5 — dokunma alanı

"Sil" çıplak `TextButton` olarak ~30 px genişlikteydi (Material asgarisi
48 px). Üçüne de `minimumSize: Size(88, 48)` verildi.

---

## 5. Kurulum akışı — 4 ekran (FAZ 1.2)

**Görüntü:** `66_setup_subject_back.png` · `67_setup_plan_back.png`

| Kontrol | Sonuç |
| --- | --- |
| Geri tuşu | ✗ **dördünde de yoktu** → ✅ dördüne de eklendi |
| Dokunma alanı | ✅ `IconButton` 48×48 |
| Loading | ✅ `CircularProgressIndicator` |
| Error | ✅ "Dersler yüklenemedi: {error}" |
| Empty | ✅ "Bu sınav türü için ders yok." / "Bu derste henüz konu yok." |

### ✗ BULUNDU 1.2 — kusur bildirilenden GENİŞ

Koordinatör yalnızca Plan ekranını bildirmişti. Kod incelemesinde kök
neden çıktı: kurulum akışı baştan sona `context.go()` kullanıyor.
**`go` gezinme yığınını DEĞİŞTİRİR, üstüne eklemez** → `Navigator.canPop()`
daima false → `AppBar`'ın otomatik geri tuşu **hiçbir adımda** çizilmiyor.

Yani kusur dört ekranda birden vardı: Ders Seç, Konu Seç, Çalışma Türü,
Plan.

**DÜZELTME:** her ekrana **açık** `leading` geri tuşu, bir önceki adıma
bağlı (`Ders Seç → ana panel`, `Konu Seç → Ders Seç`, `Tür → Konu`,
`Plan → Tür`).

**Neden `push`'a geçmedim:** akışı `context.push`'a çevirmek geri tuşunu
kendiliğinden getirirdi ama tüm uygulamanın gezinme semantiğini
değiştirirdi — `plan_setup`'taki `go(Routes.run)` gibi "yığını değiştir"
niyetli çağrılar da etkilenirdi. Açık `leading` daha dar ve öngörülebilir.

---

## 6. Erişilebilirlik ve gizlilik

| Konu | Durum |
| --- | --- |
| TalkBack — sayaç | ✅ `Semantics(liveRegion)`, "24 dakika 0 saniye kaldı" |
| TalkBack — geri tuşu | ✅ `tooltip` semantik etiket olarak okunuyor |
| Kontrast | ✅ tüm yeni yüzeyler tema renk çiftlerinden (`primaryContainer`/`on*`) |
| Hesap / sunucu | ✅ yok — eklenen hiçbir şey ağ kullanmıyor |
| Veri | ✅ küçültme bayrağı yalnızca bellekte; DB'ye yazılmıyor |

---

## 7. Kapsanamayan

- **Gerçek cihaz dokunuşu.** Görüntüler widget ağacından üretiliyor;
  gerçek parmak, gerçek Android çizimi ve OEM kabukları kapsam dışı.
- **`flutter build apk --release`.** Android SDK yok, `dl.google.com`
  kapalı. Bu kapı bu ortamda geçilemiyor (S17).
