# FAZ 7B — TAKVİM + HEDEFLER + ROZETLER · İŞÇİ RAPORU

**Tarih:** 10 Ağustos 2026
**Faz:** 7B (kapsam c + d + e + f) — **son kod fazı**
**Durum:** TAMAM

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **698 / 698 geçti** (eşik ≥622 — **+76**) |
| **analyze** | **No issues found!** — 0 error · 0 warning · 0 info |
| **build_runner** | hatasız |
| **G3–G8 + G12** | tamamı temiz (doğru strip deseniyle) |
| **ARB anahtarı** | 130 → **206**, TR/EN **senkron** |
| **Yeni sapma** | **YOK** |

FAZ 7A sonundaki 622 testin **hiçbiri düşmedi**.

---

## 2. YAPILAN İŞ

### (c) Takvim ✅

`daily_stats`'tan beslenen ay ızgarası.

- **7 sütunlu ızgara**, Pazartesi başlangıçlı (TR kullanımı)
- **Yoğunluk renklendirmesi**: çalışılan dakikaya göre 4 kademe
  (30 / 90 / 180 dk eşikleri) + lejant
- **Bugün** vurgusu (çerçeve), oturum olan günde nokta işareti
- Gün hücresinde **tooltip**: süre + oturum sayısı
- **Ay navigasyonu** — yıl sınırını doğru geçiyor (Ocak → Aralık)
- **Ay özeti**: toplam süre + kaç gün çalışıldı
- **Boş durum**
- `calendarBanner` yuvası **korundu** (politika kapılı)

**Karar — ileri gitmek yalnızca geçmiş aylarda açık.** İçinde bulunulan ayda
"sonraki ay" düğmesi pasif: gelecekte veri olamaz, kullanıcıyı boş ızgarada
gezdirmenin anlamı yok.

**Karar — koyu dolgu üzerinde ters renk.** 180 dk üstü hücrelerde yazı
`onPrimary`'ye geçiyor; aksi halde koyu zemin üzerinde koyu rakam
okunmuyordu.

**Saat `clockProvider`'dan** — açılış ayı ve "bugün" vurgusu sabit `t0` ile
test edilebiliyor.

### (d) Hedefler ✅

- **Aktif / Tamamlanan** ayrı bölümler (aktifler üstte)
- **İlerleme çubuğu** + `değer / hedef birim` + yüzde
- **Hedef oluşturma** alt sayfası: tür seçimi, hedef stepper'ı, ders seçimi
- **Hedef silme** (onaylı)
- **Boş durum**

İlerleme `goals.currentValue`'dan okunuyor — bu alanı FAZ 5'te eklenen
`SessionRepository.recomputeGoals()` KAYDET yolunda yazıyor.

**Birim sözleşmesi korundu.** `goal_labels.dart` birimleri
`GoalProgressCalculator`'ın sözleşmesine göre veriyor: süre hedefleri
**DAKİKA**. "Saat" yazmak 240'lık bir hedefi "240 saat" gibi göstermek
olurdu. Test bunu iki tipte kilitliyor (`120 / 240 dk`, `40 / 100 soru`).

**S8 sınırları uygulandı:**

| Hedef | Alt | Üst | Adım |
| --- | --- | --- | --- |
| Süre (günlük/haftalık/ders) | 15 | **480 dk** | 15 |
| Soru (günlük/haftalık) | 10 | **500** | 10 |

Oturum kurulumunda 480 dk tavanı varken hedefte sınırsıza izin vermek,
kullanıcıya asla ulaşamayacağı bir hedef kurdurmak olurdu.

**Tip değişince değer TAVANA kırpılıyor.** Soru hedefinde 500'e çıkıp süreye
dönen kullanıcıda değer 480'e iniyor ve adıma hizalanıyor — aksi halde
stepper 500 gibi geçersiz bir değerde takılırdı. Ayrı bir test bunu
doğruluyor.

**Ders bazlı hedefte ders seçilmeden OLUŞTUR pasif.** `subjectId` null
kalırsa hedef hiçbir dersle eşleşmez ve ilerlemesi sonsuza kadar 0 kalırdı.

**Formda sunulan 5 tip** (`dailyMinutes`, `weeklyMinutes`, `dailyQuestions`,
`weeklyQuestions`, `subjectMinutes`). `topicCompletion`, `net` ve `streak`
şemada ve `GoalProgressCalculator`'da duruyor ama form onları sunmuyor:
kullanıcının doğrudan kuracağı türler değil (konu tamamlama katalogdan, seri
kendiliğinden ilerliyor).

### (e) Rozetler ✅

**`achievements` tablosu Adım 1'den beri şemadaydı ama yazan kod yoktu** —
tablo sonsuza kadar boş kalıyordu. `daily_stats`, `streak` ve `goals` ile
aynı hikâye; çözüm de aynı desen.

**`AchievementCalculator`** — saf domain servisi (Flutter/Drift/Riverpod
import etmiyor). **11 rozet** (istenen en az 6):

| Kod | Koşul |
| --- | --- |
| `first_session` | İlk oturum |
| `streak_3` / `streak_7` / `streak_30` | 3 / 7 / 30 günlük seri |
| `hours_10` / `hours_100` | Toplam 10 / 100 saat |
| `questions_1000` | Toplam 1000 soru |
| `marathon_day` | Tek günde 6 saat |
| `focus_90` | Günün odak puanı 90+ |
| `early_bird` | 06:00–08:00 arası başlayan oturum |
| `night_owl` | 00:00–04:00 arası başlayan oturum |

**Yazma KAYDET yolunda** — `SessionRepository.save()` içinde
`recomputeStreak` → `recomputeGoals` → `recomputeAchievements` sırasıyla.
Ayrı bir tetikleyiciye bırakmak, oturum yazan ikinci bir kod yolu açıldığında
sessizce atlanması demekti.

**Karar — rozetler GERİ ALINMAZ.** `evaluate()` yalnızca *yeni açılanları*
döner; kapatma diye bir kavram yok. Seri bozulunca kazanılmış rozeti silmek
cezalandırma olurdu. Test bunu açıkça kilitliyor.

**Karar — aynı rozet iki kez yazılmıyor.** `insertOrIgnore` kullanılıyor
(`insertOnConflictUpdate` DEĞİL): aksi halde her oturum kaydında `unlockedAt`
güncellenir ve kullanıcı "ilk oturum" rozetini 300. oturumda kazanmış
görünürdü. Test hem satır sayısını hem `unlockedAt`'in sabit kaldığını
doğruluyor.

**Karar — `focus_90` için `daySessionCount > 0` şartı.** Oturum yokken
`avgFocusScore` 0 geliyor; şart olmasaydı tek bir kötü okuma bedava rozet
açabilirdi.

**Rozet listesi UI**: kilitli rozetler **de** listeleniyor (soluk + kilit
ikonu + "Kilitli"). Neyin peşinde olduğunu görmeyen kullanıcı için rozet
sistemi motive edici değil, rastgele bir sürpriz olurdu. Açık rozetlerde
başlık + açıklama + `YENİ` etiketi (görülmemişse).

**İkonlar sabit `IconData`.** `IconData(codePoint)` `--tree-shake-icons`
derlemesini kırıyor (README'deki karar); `achievementIcon()` switch ile sabit
ikonlara eşliyor. Bir test her katalog ikonunun gerçekten eşleştiğini
doğruluyor — eşleşmeyen anahtar sessizce varsayılana düşerdi.

### (f) L10n ✅

ARB **130 → 206 anahtar**. **7B ekranlarındaki metinlerin tamamı ARB'den** —
grep ile doğrulandı (§5). Eski ekranlara dokunulmadı (talimat).
`app_en.arb` **anahtar bazında TR ile senkron** (doğrulandı); çeviri hâlâ
v1.2 (S16).

`monthName` ICU `select` ile ay adlarını veriyor — `intl` yerel biçimlendirme
yerine ARB kullanıldı, çünkü uygulama locale'i `tr`'ye sabit.

---

## 3. DOĞRULAMA — 4 KOMUT

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded (hatasız)

$ flutter analyze
Analyzing sinav_odak...
No issues found! (ran in 6.8s)

$ flutter test
00:5x +698: All tests passed!        (EXIT=0)
```

Severity sayımı: **error 0 · warning 0 · info 0**.

> Ara durumda 1 info çıktı: `_BannerPlaceholder isn't referenced`. Stats ve
> Calendar gerçek ekranlara geçince yer tutucu **ölü kod** olmuştu; sınıf ve
> artık hiç kullanılmayan `placeholder_page.dart` silindi, kullanılmayan üç
> import temizlendi. Bu son kod fazı olduğu için yer tutucu bırakmanın
> gerekçesi kalmadı.

---

## 4. TEST SAYISI

| Faz sonu | Test |
| --- | --- |
| FAZ 7A | 622 |
| **FAZ 7B** | **698** (+76) |

| Yeni dosya | Test |
| --- | --- |
| `test/unit/achievement_calculator_test.dart` | 25 |
| `test/unit/achievement_persist_test.dart` | 14 |
| `test/widget/goals_screen_test.dart` | 17 |
| `test/widget/calendar_screen_test.dart` | 10 |
| `test/widget/achievements_screen_test.dart` | 10 |

**7A dersleri uygulandı:**
- Test yüzeyi baştan 1200×3000 (rozet listesi 4000) — uzun listelerde
  `ListView` tembel kurulumu `find`'ı boş döndürüyor
- Diyalog/`State` ömrü: yeni form `ConsumerStatefulWidget` içinde, controller
  sızıntısı yok
- `SegmentedButton` yerine `ChoiceChip` kullanıldı (seçili değerin
  segmentlerde olma zorunluluğu yok → assertion riski yok)

---

## 5. KORUMA GREP'LERİ

Doğru strip deseniyle (FAZ 6 §5'te belgelenen hata tekrarlanmadı):

```bash
strip() { grep -vE "^[^:]*:[0-9]+:[[:space:]]*(///|//|\*|/\*)"; }
```

| Guard | Sonuç |
| --- | --- |
| G3 testlerde `DateTime.now()` yok | ✅ 0 |
| G4a domain'de Flutter/Drift/Riverpod yok | ✅ 0 |
| G4b presentation → data yok | ✅ 0 |
| G5 run katmanında `Timer` yok | ✅ 0 |
| G6 pause yok | ✅ 0 (aşağıya bak) |
| G7 summary/done ekranında reklam yok | ✅ 0 |
| G8 ders/konu/tür silme yok | ✅ 0 |
| G12 `lib/` içinde production reklam kimliği yok | ✅ 0 |

**G6'nın tek eşleşmesi ihlal değil** — `promise_step.dart:35`:
`'Sayaç duraklatılamaz: başladığın bloğu bitirirsin.'` Kuralın kullanıcıya
anlatıldığı arayüz metni.

**G4b'ye dikkat edildi**: 7A'da bu guard'ı ihlal etmiştim. Bu turda
widget'lar baştan **skaler/kayıt** parametre alacak şekilde yazıldı —
`_DayCell`, `_GoalCard`, `_AchievementTile` hiçbiri Drift tipi almıyor.
Takvim ızgarası `Map<String, ({int studyS, int sessions})>` kullanıyor,
`List<DailyStat>` değil.

**L10n kapsamı** ayrıca grep'lendi: 7B'nin beş yeni dosyasında ARB dışı
Türkçe metin **yok**.

---

## 6. YENİ / DEĞİŞEN DOSYALAR

**Yeni**

```
lib/domain/services/achievement_calculator.dart    saf rozet hesabı (11 rozet)
lib/data/local/daos/achievement_dao.dart           rozet yazma + lifetimeTotals
lib/presentation/calendar/calendar_screen.dart     ay ızgarası
lib/presentation/goals/goals_screen.dart           hedef listesi
lib/presentation/goals/goal_form_sheet.dart        hedef oluşturma (S8)
lib/presentation/goals/goal_labels.dart            tip/birim etiketleri
lib/presentation/achievements/achievements_screen.dart  rozet listesi
test/unit/{achievement_calculator,achievement_persist}_test.dart
test/widget/{calendar_screen,goals_screen,achievements_screen}_test.dart
```

**Değişen**

```
lib/data/repositories/session_repository.dart  recomputeAchievements()
lib/data/local/database.dart                   AchievementDao kaydı
lib/data/local/daos/goal_dao.dart              watchAll()
lib/core/di/app_providers.dart                 7B provider'ları
lib/core/router/app_router.dart                /calendar gerçek ekran,
                                               /goals, /achievements,
                                               ölü _BannerPlaceholder silindi
lib/core/router/routes.dart                    Routes.achievements
lib/presentation/settings/settings_screen.dart Hedefler/Rozetler girişi
lib/l10n/app_tr.arb · app_en.arb               130 -> 206 anahtar
```

**Silinen**

```
lib/presentation/shell/placeholder_page.dart   son kullanıcısı kalmadı
```

---

## 7. SAPMALAR

**Bu turda yeni sapma YOK.** Mevcut durum:

| # | Durum |
| --- | --- |
| S1–S14 | Kapalı |
| S15 (i18n kapsamı) | 7A + 7B ekranlarında **kapalı**. Eski ekranlar (run, summary, onboarding, wrongs, home) hâlâ gömülü — talimat gereği dokunulmadı |
| S16 | Açık — `app_en.arb` anahtar bazında senkron ama değerler TR; çeviri v1.2 |
| S17 | Açık — release APK bu ortamda üretilemiyor (Android SDK yok, `dl.google.com` proxy'de 403) |

---

## 8. GİT

Koordinatör kararı **GIT YOK** idi; teslim rapor + ZIP olarak hazırlandı.

**Not:** FAZ 7A tesliminden sonra depo sahibi Claude GitHub App'i
`Harunsezen/SINAV-ODAK`'a kurdu ve push engeli (S17'nin git ayağı) kalktı —
12 commit `claude/sinav-odak-devralma-uck9dd` dalına başarıyla gönderildi
(uzak HEAD `6f6f7ec`). Bu turun commit'i de aynı dala eklendi. Teslimin
kendisi yine rapor + ZIP; git artık ek bir yedek kanal.

---

## 9. KOD DURUMU — %100 TAMAM

7B son kod fazıydı. Ürünün tüm ekranları yazıldı:

| Ekran | Durum |
| --- | --- |
| Onboarding (5 adım + KVKK rıza) | ✅ FAZ 3 |
| Ana panel | ✅ FAZ 5 |
| Oturum kurulumu (ders → konu → tür → plan) | ✅ FAZ 1 |
| Aktif oturum / mola / oturum sonu / tebrik | ✅ FAZ 1 |
| Yanlış defteri | ✅ FAZ 2 |
| Reklam katmanı (banner/native/interstitial/rewarded + UMP) | ✅ FAZ 4, 6 |
| İstatistik (grafik + CSV) | ✅ FAZ 7A |
| Ayarlar (tam) + katalog yönetimi | ✅ FAZ 7A |
| **Takvim** | ✅ FAZ 7B |
| **Hedefler** | ✅ FAZ 7B |
| **Rozetler** | ✅ FAZ 7B |

**Yayına çıkmadan kalan işler (kod değil, kurulum):**

1. **Release imzalama** — `signingConfigs.release` + keystore (şu an debug
   anahtarı kullanılıyor). **Yayın için ŞART.**
2. **Release APK derlemesi** — Android SDK'lı bir makinede; komut
   `README.md` → *FAZ 6 — Production derleme*'de
3. **Cihazda duman testi** — `FAZ_06_RAPORU.md` §7'deki liste; özellikle
   *arka plandan dönüşte sayaç kayması* ve *boot sonrası bildirim*
4. **Play Console** — `PRIVACY.md` yayımlama + *Data safety* formu + 13+
5. **İngilizce çeviri** (S16) — v1.2
