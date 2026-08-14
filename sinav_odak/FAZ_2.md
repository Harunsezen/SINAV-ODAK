# v1.1 — FAZ 2: GAMIFICATION (P1)

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 803 → **828**

> **Güncelleme:** rozet eşiği kararı sonrası `industry_escape` 100 → **150 saat**
> (merdiven: önce teknik kademe, sonra hikâye). §2'ye bakın.

---

## 0. ÖZET

| Madde | Durum |
| --- | --- |
| 2.1 Rozet toast sistemi | ✅ kuyruklu, animasyonlu, ayardan kapatılır |
| 2.2 Sanayi Evreni (4 rozet) | ✅ 11 → **15 rozet** |
| 2.3 Mola atlama butonu | ✅ **zaten vardı** — doğrulandı + test eklendi |
| 2.4 Kademe çipleri | ✅ |
| UX incelemesi | ✅ `UX_REVIEW.md` FAZ 2 — **6 bulgu, 5'i düzeltildi** |
| `flutter test` | **828** ✅ |
| `flutter analyze` | **0 issue** ✅ |
| `dart format .` | **0 changed** ✅ |
| `flutter build apk --release` | ❌ Android SDK yok (§7) |

---

## 1. 2.1 — Rozet toast sistemi

`lib/presentation/achievements/achievement_toast.dart`

Sağ üstten değil **üstten** kayarak giren koyu kart; 4 saniye durur,
dokununca hemen kapanır.

### Kuyruk neden gerekli

Tek bir oturum kaydı **birden fazla** rozet açabiliyor — uzun bir aradan
sonra dönen kullanıcı aynı kayıtta hem `master_waits` hem bir seri rozeti
alabilir. Hepsi aynı anda gösterilseydi üst üste binerdi. `AchievementToastQueue` bunları sıraya alıyor; test
bunu açıkça iddia ediyor (*"aynı anda YALNIZCA bir kart"*).

### `Overlay` değil, ağaç içinde katman

`AchievementToastLayer`, `MaterialApp.builder` içinde gezinme yığınının
üstünde duruyor. `Overlay` kullanmak `BuildContext`'i router'ın dışına
taşır ve rota değişiminde kart asılı kalabilirdi. Bu konumda kart rota
değişse de yaşıyor — kullanıcı tebrik ekranından çıksa bile rozetini
görüyor.

Kart kullanıcının işini **engellemiyor**: altındaki ekran tıklanabilir
kalıyor (testle iddia edildi).

### Ayar

`Ayarlar → Rozet bildirimleri`. **Bildirim ayarından bağımsız** —
uygulama içi bir kart, sistem bildirimi değil. `notificationEnabled`a
kapasaydım, sistem bildirimlerini kapatan kullanıcı rozet kutlamalarını
da sessizce kaybederdi.

Titreşim `hapticGatewayProvider` üzerinden ve kullanıcının titreşim
ayarına kapılı. **Ses eklenmedi:** brief "opsiyonel" diyordu ve ses
dosyası APK'yı büyütür; ayrıca sessize alınmış telefonda anlamsız.

---

## 2. 2.2 — Sanayi Evreni (4 rozet)

| Rozet | Kod | Koşul | Balto metni |
| --- | --- | --- | --- |
| 🏭 Sanayiden Kurtuldun | `industry_escape` | toplam **≥150 sa** | "150 saat. Artık elin yağlı değil, kalemin keskin." |
| 🔧 Şanzımanı İndir | `downshift` | haftalık sert düşüş | "Bu hafta devir düştü. Vites küçült, ama durma." |
| 🔩 Mehmet Usta Seni Bekliyor | `master_waits` | 5+ gün ara → dönüş | "5 gün tezgâhı bıraktın. Döndün ya, gerisi kolay." |
| 🏆 15.000 Soru | `questions_15000` | toplam ≥15000 soru | "On beş bin. Bu artık şans değil, alışkanlık." |

### "Şanzımanı İndir" — iki koruma

Bu bir ödül değil, dostça bir dürtme. Naif bir "bu hafta geçen haftadan
az" kuralı işe yaramazdı:

- **Önceki hafta anlamlı olmalı (≥5 saat).** Yoksa bir saatlik haftadan
  yarım saate düşen herkes rozet alırdı.
- **Düşüş sert olmalı (yarıdan aşağı).** Küçük dalgalanma düşüş değil.

### "Mehmet Usta" — ne zaman tetikleniyor

Rozetler yalnızca **oturum kaydedilirken** değerlendiriliyor. Yani bu
rozet "ara verdiğin an" değil, **döndüğün an** açılıyor. Metnin anlamı
da bu: tezgâh seni bekliyordu, geldin.

**Teknik ayrıntı:** "kaç gün ara verdin" için `settings.lastStudyDate`
**kullanılamıyor** — `save()` içinde `recomputeStreak` rozetlerden ÖNCE
çalışıp o alanı bugüne çekiyor. Okunsaydı fark daima 0 çıkardı. Bunun
için `SessionDao.previousSessionDateKey()` eklendi.

### ✅ Çakışma KAPANDI — merdiven (koordinatör kararı)

İlk uygulamada `industry_escape` ve `hours_100` **ikisi de 100 saatteydi**
(brief bu eşiği veriyordu) ve aynı anda patlıyorlardı. Çakışmayı
belgeleyip koordinatöre taşıdım; karar geldi:

| Rozet | Eşik |
| --- | --- |
| 🏆 `hours_100` (teknik kademe) | 100 saat — **değişmedi** |
| 🏭 `industry_escape` (hikâye) | **150 saat** (100 → 150) |

Mantık: **önce teknik başarı, sonra hikâye.** Aradaki 50 saat, iki
rozetin de kendi anını yaşaması için.

Çakışmayı belgeleyen test artık **merdiveni kilitleyen** teste dönüştü:
100 saatte yalnızca `hours_100`, 150 saatte ikisi de. Eşiklerden biri
diğerine kayarsa test düşer.

ARB metni de güncellendi — "100 saat" artık yanlış olurdu.

---

## 3. 2.3 — Mola atlama butonu (zaten vardı)

Mola ekranında **"Molayı Bitir"** butonu v1.0'dan beri var
(`break_screen.dart`, `Key('break-skip')` → `runController.skipBreak()`).

"Ekledim" demek yanlış olurdu. Yaptığım: davranışın gerçekten
çalıştığını doğrulamak ve **kaydı test altına almak** — mola atlanınca
çizelgenin kaydığı ve sonraki bloğa geçildiği zaten
`skip_break` use-case testlerinde iddia ediliyor.

---

## 4. 2.4 — Kademe çipleri

Sayaç üstünde: metin + çipler. Aktif blok geniş ve dolu, geçmişler soluk
dolu, gelecekler boş.

`Wrap` kullanıldı: 10+ bloklu uzun planlarda çipler alt satıra geçiyor;
`Row` olsaydı taşardı.

**Metin KALDI.** İlk denemede yalnızca çipler bırakılmıştı — UX
incelemesinde görüldü ki gören kullanıcı "kaçıncı blok" bilgisini
tamamen kaybediyor (bkz. UX_REVIEW FAZ 2 §2).

---

## 5. Şema göçü v1 → v2

Rozet bildirimi ayarı yeni bir kolon gerektirdi:
`user_settings.achievement_toast_enabled`.

**Projenin ilk gerçek migration'ı.** v1.0 kapalı betaya çıkıyor ve v1.1
onun üstüne kurulacak; `onUpgrade` yanlışsa kullanıcı açılışta çöken bir
uygulama ve erişilemeyen bir geçmiş bulur.

```dart
onUpgrade: (m, from, to) async {
  // Adım adım, ATLAMADAN. Tek bir `if (to == N)` yazmak iki sürüm
  // geriden gelen cihazı bozar.
  if (from < 2) {
    await m.addColumn(userSettings, userSettings.achievementToastEnabled);
  }
}
```

`migration_v1_to_v2_test.dart` bunu **gerçekten çalıştırıyor**: gerçek
tablodan kolonu düşürüp v1 hâlini üretiyor, veri yazıyor, yükseltiyor ve
verinin sağ kaldığını + yeni kolonun **açık** geldiğini doğruluyor.

> İlk denememde v1 şemasını elle yazmıştım ve `created_at`'i unutmuştum;
> test hemen düştü. Elle yazılan taklit, gerçek şema değişince sessizce
> yanlışlaşır — bu yüzden şema artık SQLite'ın kendisinden türetiliyor.

---

## 6. UX incelemesi — 6 bulgu

Ayrıntı: `UX_REVIEW.md` → FAZ 2.

| # | Bulgu | Kim buldu |
| --- | --- | --- |
| 2.1 | Ana panelde "50/100" **iki satıra bölünüyordu** | **ben** (ekran görüntüsü) |
| 2.2 | Çipler eklenince "1. blok / 2" metni kayboldu | **ben** (ekran görüntüsü) |
| 2.3 | `questions_15000` ikonu fallback ile çakışıyordu | **mevcut guard test** |
| 2.4 | QA harness üretimden sapmıştı (toast katmanı yok) | **ben** (test düşünce) |
| 2.5 | İki rozet aynı eşikteydi | **ben** — koordinatöre taşındı, **kapandı** |
| 2.6 | Kart AppBar'ı örtüyor | **ben** — kabul edildi |

**2.1 FAZ 2'nin konusu bile değildi:** rozet şeridinin arkasındaki ana
panele bakarken görüldü. 360 px + textScale 1.5'te soru değeri
`50/10` + `0` diye bölünüyordu. `FittedBox` ile düzeltildi.

**2.3'ü kendi yazdığım eski guard test yakaladı.** `questions_15000`
rozetine `emoji_events` ikonunu vermiştim; o ikon eşleşmeyen anahtarların
düştüğü **varsayılan**. Gerçek bir rozet onu kullanınca bekçi anlamını
yitiriyordu. `workspace_premium`'a taşındı.

**2.4 onboarding hatasıyla aynı sınıftan:** QA harness gerçek uygulamayı
değil, ona benzeyen başka bir ağacı test ediyordu. Testi gevşetmek
yerine harness üretimle hizalandı.

---

## 7. Kalite kapıları

```
$ flutter analyze
No issues found! (ran in 10.8s)

$ flutter test
01:41 +828: All tests passed!

$ dart format .
Formatted 199 files (0 changed) in 2.17s

$ flutter build apk --release
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 803 | **828** ✅ |
| `flutter analyze` | 0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |
| `flutter build apk --release` | yeşil | ❌ SDK yok — sizin makinenizde |

---

## 8. Ekran görüntüleri

| Dosya | İçerik |
| --- | --- |
| `71_achievement_toast.png` | Rozet şeridi, açık tema |
| `72_achievement_toast_dark.png` | Koyu tema |
| `73_achievement_toast_narrow.png` | 360 px + textScale 1.5 |
| `74_block_chips.png` | Kademe çipleri + metin |
| `75_sanayi_badges.png` | Rozet listesi (15 rozet) |

Toplam 36 kare.

---

## 9. Değişen dosyalar

**Yeni**
```
FAZ_2.md
lib/presentation/achievements/achievement_toast.dart
test/unit/sanayi_badges_test.dart
test/unit/migration_v1_to_v2_test.dart
test/widget/achievement_toast_test.dart
qa_screenshots/71..75 (5 PNG)
```

**Değişen**
```
lib/domain/services/achievement_calculator.dart  4 rozet + 3 metrik
lib/data/local/tables/settings_table.dart        yeni kolon
lib/data/local/database.dart                     schemaVersion 2 + onUpgrade
lib/data/local/daos/session_dao.dart             previousSessionDateKey
lib/data/repositories/session_repository.dart    yeni metrikler
lib/application/settings_controller.dart         setAchievementToastEnabled
lib/presentation/achievements/achievements_screen.dart  metin + ikon eşlemesi
lib/presentation/run/run_screen.dart             kademe çipleri
lib/presentation/run/done_screen.dart            toast kuyruğuna ekleme
lib/presentation/home/home_screen.dart           FittedBox (UX 2.1)
lib/presentation/settings/settings_screen.dart   rozet anahtarı
lib/app.dart                                     toast katmanı
lib/l10n/*.arb                                   11 yeni anahtar
test/qa/qa_harness.dart                          harness üretimle hizalandı
test/widget/achievements_screen_test.dart        yeni kodlar guard listesine
```
