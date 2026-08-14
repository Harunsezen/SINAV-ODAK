# v1.1 — FAZ 4: MARKA VE GELİR (P2)

**Dal:** `claude/sinav-odak-v1.1` · **Test:** 845 → **860**

---

## 0. ÖZET

| Madde | Durum |
| --- | --- |
| 4.1 Nah splash animasyonu | ⏸ **BEKLEMEDE** — Balto görseli koordinatörde |
| 4.2 Marka sesi paketi (ARB tr+en) | ✅ |
| 4.3 Offline Balto metni | ✅ |
| 4.4 Rewarded "Destek Ol" + Balto'nun Dostu | ✅ |
| 4.5 Banner konum tercihi | ✅ **ve gerçekten etkisi var** |
| 4.6 Yatay odak modu | ✅ |
| 4.7 Temizlik: `printing` kaldırıldı | ✅ |
| UX incelemesi | ✅ `UX_REVIEW.md` FAZ 4 — **6 bulgu, 5'i düzeltildi** |
| `flutter test` | **860** ✅ |
| `flutter analyze` | **0 issue** ✅ |
| `dart format .` | **0 changed** ✅ |
| `flutter build apk --release --analyze-size` | ❌ Android SDK yok — §6 |

---

## 1. Marka sesi

Balto'nun sesi altı yere girdi:

| Yer | Metin |
| --- | --- |
| Boş istatistik | "Henüz veri yok — ya dahisin ya da daha başlamadın 😏" |
| Zincir uyarısı | "Zincir buzda kanka 🧊" |
| Oturum sonrası | "Beyin: 'ter attım' 💪" |
| Gece Kuşu rozeti | "Uyku efsanesi varmış, duydun mu? 🦉" |
| Reklam gelmezse | "İnternet yok, reklam yok — Balto da tatilde 🌴" |
| Ödül gelmezse | "Reklam gelmedi. Niyetin yeter, sağ ol 🤝" |

Son ikisi bilinçli ton değişikliği: reklamın gelmemesi **kullanıcının
suçu değil**. Eski metin ("Şu an gösterilecek reklam yok") kullanıcıyı
boşa kürek çekmiş gibi bırakıyordu.

Tümü `app_tr.arb` + `app_en.arb`'de (EN hâlâ TR iskeleti — v1.2 kapsamı).

---

## 2. Offline Balto metni

Reklam yüklenemediğinde yuva **boş gri kutu** olarak kalıyordu; kullanıcı
"bir şey bozuldu" diye düşünür.

```dart
final loaded = ref.watch(bannerLoadedProvider(placement)).valueOrNull;
...
loaded == false ? l.adOffline : l.adSponsored
```

**Bağlantı paketi eklemedim.** `connectivity_plus` yeni bağımlılık +
izin getirirdi; `AdGateway.loadBanner` zaten `null` dönüyor ve kullanıcı
açısından sonuç aynı: reklam yok.

**Yükseklik sabit** — ayrı bir test bunu iddia ediyor. Değişseydi çalışma
ekranında sayaç zıplardı.

**Yan fayda:** `AdGateway.loadBanner` bugüne kadar `BannerAdSlot`'tan
hiç çağrılmıyordu; yuva sabit bir yer tutucuydu. Artık kapı gerçekten
çağrılıyor.

---

## 3. Rewarded + Balto'nun Dostu 🤝

Ayarlar → "Destek ol" → 30 sn ödüllü reklam → rozet.

**Rozet yalnızca ödül GERÇEKTEN kazanılınca açılıyor.** Reklam
yüklenmezse veya kullanıcı yarıda bırakırsa `earned == false` gelir,
rozet verilmez. Bedava rozet, rozetin değerini düşürürdü.

**Ölçüm yolu kapalı:** rozet kataloğunda `test: _never`. Bir test bunu
en uç ölçümlerle doğruluyor (1000 saat, 999 999 soru, 365 gün seri) —
hiçbiri rozeti açmıyor.

Kazanılınca toast kuyruğuna giriyor; kullanıcı ödülünü hemen görüyor.

---

## 4. Banner konum tercihi — ve **ölü ayar** hikâyesi

Ayarlar → Reklam konumu: **Alt · Üst · Yatayda yan**. Varsayılan alt
(v1.0 davranışı).

### ⚠️ Bu ayarı önce ÖLÜ yazdım

Kolon, migration, controller metodu, üç segmentli seçici — hepsi hazırdı.
Kullanıcı seçebiliyordu. **Ama hiçbir yerde okunmuyordu.** Seçim
veritabanına yazılıyor, ekranda hiçbir şey değişmiyordu.

Bu, bu projenin **tekrar eden** hata sınıfı: `keepScreenOn`,
`daily_stats`, `streak`, `goals.currentValue`, `achievements` — hepsi
"şemada var, okuyan kod yok" idi.

Yatay mod ekran görüntüsünü incelerken fark ettim: banner hiç yoktu ve
"Yatayda yan" seçeneğinin ne yaptığını soramadım, çünkü hiçbir şey
yapmıyordu.

**Düzeltme + üç test.** Testler koordinat karşılaştırıyor, metin değil:

```dart
expect(bannerX, lessThan(counterX));    // yanda → banner sayacın solunda
expect(bannerY, lessThan(counterY));    // üst   → sayacın üstünde
expect(bannerY, greaterThan(counterY)); // alt   → sayacın altında
```

### Kapsam sınırı — dürüst not

Konum ayarı şu an **çalışma ekranı banner'ında** uygulanıyor. Ana panel,
İstatistik ve Takvim banner'ları hâlâ kendi sabit yerlerinde.

Konumun asıl önem taşıdığı yer çalışma ekranı (odak bozulmasın) ve
"Yatayda yan" yalnızca orada anlamlı. Diğer ekranlara yaymak v1.2'ye
ait — ama ayarın etiketi bunu vaat ediyor gibi durabilir; beta geri
bildiriminde bu netleşmezse etiket daraltılmalı.

---

## 5. Yatay odak modu

`OrientationBuilder` ile iki düzen:

- **Dikey:** v1.0 düzeni (çipler → sayaç → banner → kontroller)
- **Yatay:** sol banner (seçiliyse) · orta sayaç · sağ kontroller

Yatayda dikey düzen kullanılsaydı sayaç kontrollerin üstüne sıkışıp
okunmaz hâle gelirdi.

> **Brief'ten sapma:** brief yatayda "sol %25 **native**" diyordu; ben
> **banner** koydum. Native kart 120 px sütuna sığmıyor ve
> `AdPolicyEngine` native'i yalnızca **mola** ekranına izin veriyor —
> çalışma ekranında yalnızca ince banner (G7). Kuralı bozmamak için
> banner seçtim.

---

## 6. Kalite kapıları

```
$ flutter analyze
No issues found! (ran in 6.7s)

$ flutter test
01:55 +860: All tests passed!

$ dart format .
Formatted 207 files (0 changed) in 2.57s

$ flutter build apk --release --analyze-size
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 845 | **860** ✅ |
| `flutter analyze` | 0 | **0** ✅ |
| `dart format .` | 0 changed | **0** ✅ |
| `--analyze-size` | çıktı rapora | ❌ **üretilemedi** |

### `--analyze-size` çıktısı neden yok

Komutu çalıştırdım; Android SDK olmadığı için derleme başlamadan durdu:

```
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

**Boyut analizi derlemenin çıktısı** — derleme olmadan üretilemiyor.
Uydurma bir tablo yazmak yerine boş bırakıyorum.

**Sizin makinenizde bakılacaklar:**

```
flutter build apk --release --analyze-size
```

| İzlenecek | Beklenti |
| --- | --- |
| `assets/fonts/` | ~340 KB (Roboto Regular + Bold) |
| `pdf` paketi | ~1 MB civarı |
| `fl_chart` | ~300–500 KB |
| **Toplam artış (v1.0 → v1.1)** | **~2 MB'ı geçmemeli** |

`printing` bu fazda kaldırıldı (§7) — FAZ 3 raporundaki öneri uygulandı.

---

## 7. Temizlik: `printing` kaldırıldı

FAZ 3'te uyarmıştım: `printing` eklenmişti ama **hiç kullanılmıyordu**
(PDF üretimi için `pdf` yetiyor; `printing` yazdırma/önizleme için).

Kaldırmadan önce **kanıtladım**:

```
$ grep -rn "package:printing" lib/ test/
(eşleşme yok)   → 0 import
```

`flutter pub remove printing` → `- printing 5.14.3`. Analyze ve 860 test
sonrasında da temiz.

---

## 8. 4.1 — Nah splash (BEKLEMEDE)

`assets/brand/balto_sticker.png` ve `balto_net.png` repoda **yok**.
Balto sizin marka karakteriniz; yerine kendi çizdiğim bir karikatürü
koymam doğru olmazdı. Görseller eklendiğinde yapılabilir.

Hazırlık gerektiren noktalar (görsel gelince):
- İlk açılış 2–3 sn, sonrakiler 1 sn → "ilk açılış mı" bilgisi
  `user_settings`'te tutulabilir (yeni kolon → schemaVersion 4).
- Lottie/Rive **ek paket** demek; iki PNG + `AnimatedOpacity` ile de
  yapılabilir ve APK'ya hiçbir şey eklemez. Önerim bu.
- "Nah" yazısı yok — jesti karikatür taşıyacak.

---

## 9. Şema göçü v2 → v3

`user_settings.banner_position` eklendi; `schemaVersion` **3**.

```dart
if (from < 2) { ...achievementToastEnabled... }
if (from < 3) { await m.addColumn(userSettings, userSettings.bannerPosition); }
```

Adım adım, atlamadan: iki sürüm geriden gelen cihaz da doğru yükseliyor.
`migration_v1_to_v2_test.dart` artık **iki** göçü de test ediyor; v3
testinde varsayılanın `bottom` (v1.0 davranışı) geldiği doğrulanıyor.

---

## 10. Değişen dosyalar

**Yeni**
```
FAZ_4.md
test/widget/faz4_test.dart
qa_screenshots/91..94 (4 PNG)
```

**Değişen**
```
pubspec.yaml                                   printing KALDIRILDI
lib/domain/entities/enums.dart                 BannerPosition
lib/data/local/tables/settings_table.dart      banner_position
lib/data/local/database.dart                   schemaVersion 3 + onUpgrade
lib/core/di/ad_providers.dart                  bannerLoaded + bannerPosition
lib/presentation/ads/banner_ad_slot.dart       offline Balto metni
lib/presentation/run/run_screen.dart           yatay mod + banner konumu
lib/presentation/settings/settings_screen.dart konum seçici + rozet açma
lib/application/settings_controller.dart       setBannerPosition
lib/domain/services/achievement_calculator.dart  balto_friend (test: _never)
lib/presentation/achievements/*.dart           metin + ikon eşlemesi
lib/l10n/*.arb                                 14 anahtar (4'ü güncellendi)
test/qa/qa_harness.dart                        pumpQaSettings RepaintBoundary
test/widget/{ad_slots,home_screen,settings_support}_test.dart  etiket iddiaları
test/unit/{sanayi_badges,migration_v1_to_v2}_test.dart  16 rozet + v3 göçü
```
