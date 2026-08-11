# SINAV ODAK — FAZ 5 RAPORU

**Rol:** İşçi (Claude) · **Denetleyen:** Koordinatör (Qwen)
**Flutter:** 3.24.5 stable
**Git:** koordinatör kararıyla **tamamen kapalı** — push yok, bundle yok.
Teslim: `FAZ_05_RAPORU.md` + projenin tam ZIP'i.

---

## 1. DÖRT KOMUT TAM ÇIKTISI

```
$ flutter pub get
Got dependencies!
102 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 23.2s with 156 outputs (419 actions)

$ flutter analyze
error=0  warning=0  info=50
50 issues found. (ran in 12.7s)

$ flutter test
00:41 +524: All tests passed!
```

**Test: 470 → 524 (+54).** Eşik ≥470 karşılandı, altına düşülmedi.
**info 50** — devralınan 52'nin altında, FAZ 5'te yeni lint eklenmedi.

---

## 2. DEĞİŞEN DOSYA TABLOSU

| Dosya | Durum | Ne |
|---|---|---|
| `domain/services/streak_calculator.dart` | **YENİ** | Saf Dart streak hesabı + `displayStreak` |
| `domain/services/goal_progress_calculator.dart` | **YENİ** | Saf Dart hedef ilerlemesi (`GoalMetrics`, birim sözleşmesi) |
| `data/repositories/session_repository.dart` | DEĞİŞTİ | `recomputeStreak` + `recomputeGoals`, **KAYDET yoluna bağlandı** |
| `presentation/home/home_screen.dart` | **YENİDEN YAZILDI** | Streak rozeti, bugün kartı, 3 metrik, son oturumlar, banner |
| `presentation/settings/settings_screen.dart` | **YENİ** | "Destek ol" (ödüllü reklam) |
| `presentation/ads/rewarded_controller.dart` | **YENİ** | Ödüllü reklamın TEK çağrı yolu |
| `core/di/app_providers.dart` | DEĞİŞTİ | `todayKeyProvider`, `displayStreakProvider`, `recentSessionsProvider`, `activeGoalsProvider` |
| `core/router/app_router.dart` | DEĞİŞTİ | K3 temizliği: release dalı `SettingsScreen`; stats/calendar'a banner yuvası |
| `test/unit/streak_calculator_test.dart` | **YENİ** | 22 test |
| `test/unit/goal_progress_test.dart` | **YENİ** | 12 test |
| `test/unit/streak_persistence_test.dart` | **YENİ** | 5 test |
| `test/widget/home_screen_test.dart` | **YENİ** | 9 test |
| `test/widget/settings_support_test.dart` | **YENİ** | 6 test |
| `test/integration/router_redirect_test.dart` | DEĞİŞTİ | D4/K3 testleri yeni davranışa güncellendi |

---

## 3. KAPSAM MADDELERİ

### (a) StreakCalculator ✅

Şemadaki `currentStreak` / `longestStreak` / `lastStudyDate` kolonları Adım
1'den beri duruyordu, **yazan kod yoktu** — üçü de hep 0/null kalıyordu.

**Hesap saf Dart.** Girdi zaman damgası değil **gün anahtarı** (`YYYY-MM-DD`):
streak "kaç GÜN üst üste" sorusudur, saat/dakikayla uğraşmak yaz saati
geçişinde bir günü 23 veya 25 saat yapıp hesabı bozardı. Gün farkı
`DateTime.utc` üzerinden alınıyor, aynı sebeple.

**Kurallar:** ilk kayıt → 1 · aynı gün ikinci oturum → değişmez · dün
çalışılmış → +1 · arada boş gün → 1'e döner · **rekor asla silinmez**.

**Saat geri alma / geçmişe dönük kayıt:** zinciri ne uzatır ne kırar,
`lastStudyDate` en ileri tarihte kalır. Aksi halde saat geri alındığında
ertesi gün zincir yanlışlıkla kopardı.

**Gösterim ≠ depolama.** Ana panelde `displayStreak` kullanılıyor: zincir
koptuysa kullanıcıya 0 görünür ama **DB'ye dokunulmaz**. Uygulamayı açmak
veriyi değiştirmemeli; yazma yolu yalnızca kayıt anıdır. Bir widget testi
bunu kilitliyor.

**Kurtarılan (`interrupted`) oturum streak yazmaz** — `markInterrupted`
`save` yolundan geçmez. Bilinçli: kurtarma, kullanıcının o gün gerçekten
çalıştığını değil, uygulamanın yarıda kaldığını gösterir.

### (b) Home ekranı ✅

Streak alevi (yalnız canlıysa) · bugün kartı (ilerleme halkası + süre/hedef)
· 3 metrik (soru/hedef, net, odak) · [Oturumu Başlat] · son oturumlar ·
`BannerAdSlot(homeBanner)`.

**Stats ve Calendar** sekmelerine de banner yuvası eklendi
(`statsBanner` / `calendarBanner`). Ekranların kendisi bu turun kapsamında
değil; yer tutucu + politika kapılı banner olarak duruyorlar.

### (c) Ayarlar → "Destek ol" ✅

`RewardedController` — ödüllü reklamın **tek** çağrı yolu. Ara reklamla aynı
gerekçe: her ekranın kendi `showRewarded` çağrısını açması kuralın sessizce
delindiği yol olurdu.

**Frekans kapısı YOK** (S13 onaylı): kullanıcı kendisi başlatıyor.
Rıza ve çalışma bloğu kuralları geçerli — ikisi de testle kilitli.

Rıza yoksa buton **pasif** ve sebebi altında yazıyor. "Bir şey vardı ama
sana kapalı" demekten dürüst.

**K3 temizliği tamamlandı:** release dalı artık `PlaceholderPage` değil,
`SettingsScreen`. `settingsPageFor(debug:)` sözleşmesi korundu.

### (d) goals.currentValue ✅

Kolon şemada vardı, **hiçbir kod yazmıyordu**: kullanıcı hedef oluşturuyor,
ilerleme sonsuza kadar 0 kalıyordu.

`recomputeGoals` KAYDET yolunda çalışıyor. **Birim sözleşmesi:** süre
hedefleri DAKİKA (`dailyMinutes`, `weeklyMinutes`, `subjectMinutes`);
ölçümler saniye gelir ve dakikaya çevrilir — saniye yazılsaydı 240 dakikalık
hedef 4 saniyede dolmuş görünürdü.

Ders bazlı hedefte yalnızca o dersin süresi sayılır. Hedefe ulaşıldığında
durum `completed`'a çekilir (`>=`, sınır dahil).

**Neden `SessionRepository` içinde, ayrı serviste değil:** oturumu yazan
ikinci bir kod yolu açıldığında sessizce atlanmasın diye. `daily_stats`'ın
başına gelen tam olarak buydu.

---

## 4. TEST ENVANTERİ (470 → 524)

```
470  FAZ 4 sonu
 +22  streak_calculator_test.dart     (saf hesap)
 +12  goal_progress_test.dart         (saf hesap + kayıt yolu)
  +5  streak_persistence_test.dart    (üç kolonun yazılması)
  +9  home_screen_test.dart
  +6  settings_support_test.dart
 -----
 524  FAZ 5 sonu
```

**Streak testleri:** gece yarısı (ay/yıl sınırı, artık yıl, yaz saati
haftası) · boş gün · uzun ara · saat geri alma · bozuk gün anahtarı ·
`displayStreak` beş senaryo · rekorun korunması.

`router_redirect_test` iki testi güncellendi (17 test, sayı değişmedi):
release dalı artık `SettingsScreen` döndürüyor — K3'ün öngördüğü değişiklik.

---

## 5. KABUL KRİTERLERİ

| Kriter | Durum | Kanıt |
|---|---|---|
| 4 komut temiz | ✅ | 0 error / 0 warning / 50 info |
| test ≥ 470 | ✅ | **524** |
| (a) StreakCalculator + kolonlar yazılıyor | ✅ | 27 test |
| (a) gece yarısı / boş gün / saat geri alma | ✅ | üçü de ayrı testlerde |
| (b) Home yeniden + banner | ✅ | 9 test |
| (b) Stats/Calendar banner | ✅ | politika kapılı yuvalar |
| (c) "Destek ol" tek çağrı yolu | ✅ | `RewardedController` |
| (c) rıza + çalışma bloğu kuralı | ✅ | 2 test |
| (c) frekans kapısı YOK (S13) | ✅ | ardışık iki gösterim testi |
| (d) goals.currentValue otomatik | ✅ | 7 test |
| G3 testlerde `DateTime.now()` yok | ✅ | grep temiz |
| G4 domain temiz / presentation→data yok | ✅ | grep temiz |
| G5 run katmanında `Timer` yok | ✅ | grep temiz |
| G6 pause yok | ✅ | grep temiz |
| G7 summary/done reklamsız | ✅ | grep temiz |
| G8 ders/konu silme yok | ✅ | grep temiz |

---

## 6. §11 TEKNİK NOTLARINA UYUM

- **Drift akışı `testWidgets` içinde beklenmedi** — assert'lerde Future
  tabanlı sorgular (`db.select(...).get()`, `settingsDao.read()`), provider
  akışları `pumpWidget` öncesinde ısıtıldı
- **Test yüzeyi yükseltildi** (1200×2400) — Home ve Ayarlar uzun listeler
- **`analyze` sayımı** `(^|[[:space:]])` deseniyle yapıldı (girinti tuzağı)
- **`idx_one_running`** yüzünden çok günlü streak testlerinde her gün ayrı
  oturum kimliği kullanıldı

---

## 7. AÇIK KALANLAR (FAZ 6 ve sonrası)

**Ayarlar ekranı kısmi.** Bu turda yalnızca "Destek ol" var. Tema, net
katsayısı (+ `RecomputeNetsUseCase`), hedefler, `keepScreenOn`,
ses/titreşim, rıza tercihi değiştirme, ders/konu/tür yönetimi, veri
sıfırlama ve "hakkında" **yok**.

**Stats / Calendar / Goals ekranları yok** — yer tutucu + banner yuvası
olarak duruyorlar. `fl_chart`, CSV dışa aktarma, `subjectBreakdown` grafiği
yazılmadı.

**Devralınan teknik borç:** `achievements` tablosuna yazan kod hâlâ yok.

**FAZ 6'ya ait:** i18n altyapısı, kalan manifest izinleri + desugaring,
boot receiver, launcher ikon, PRIVACY.md, release APK smoke, gerçek UMP SDK,
production AdMob ID'sinin `--dart-define` ile geçirilmesi.

**Doğrulanmamış:** uygulama gerçek cihazda hiç çalıştırılmadı. `AdMobGateway`
dahil tüm reklam yolu host testlerinde `NoopAdGateway`/`RecordingAdGateway`
ile doğrulandı. FAZ 6.5 cihaz kontrol listesi bunu kapatacak.

---

## 8. G12 SAPMA NOTU

**S14 (yeni) — `goal_progress_calculator.dart` ayrı dosya.** Görev tanımı
(d) maddesini dosya belirtmeden veriyordu. Hesabı `SessionRepository` içine
gömmek yerine saf domain servisine aldım: "dakika mı saniye mi" gibi birim
hataları ancak böyle birim testle yakalanabiliyor. 12 test bu dosyaya
bağlı.

Bunun dışında sapma yok. S1–S3, S5–S13 koordinatör kararıyla kapalı;
dokunulmadı.
