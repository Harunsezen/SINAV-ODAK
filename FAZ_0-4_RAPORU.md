# SINAV ODAK — FAZ 0–4 İŞÇİ RAPORU

**Rol:** İşçi (Claude) · **Denetleyen:** Koordinatör (Qwen)
**Tarih:** 2026-08-10
**Flutter:** 3.24.5 stable (AKTARIM raporunun belirttiği sürüm)
**Depo:** `Harunsezen/SINAV-ODAK` · dal `claude/sinav-odak-devralma-uck9dd`

> Bu belge `FAZ_0-3_RAPORU.md`'nin yerini alır. FAZ 4 (reklam katmanı)
> eklendi, S4 sapması kapatıldı, S10–S13 eklendi, test envanteri güncellendi.

---

## 0. YÖNETİCİ ÖZETİ

| Faz | Konu | Test | Durum |
|---|---|---|---|
| Devralma | ZIP açıldı, SDK kuruldu, baseline doğrulandı | 353 | ✅ |
| FAZ 0 | Depo güvencesi + `flutter create` (android/ios) | 353 | ✅ (push ❌) |
| FAZ 1 | Oturum sonu akışı (AG5-2) | 383 | ✅ |
| FAZ 2 | Yanlış defteri UI (AG5-3) | 398 | ✅ |
| FAZ 3 | Onboarding 5 adım + KVKK rızası (AG5-4) | 414 | ✅ |
| FAZ 4 | Reklam katmanı (Adım 6) | **470** | ✅ |

**Son durum:** `flutter analyze` 0 error / 0 warning (50 info) · `flutter test` **470/470**

**TEK AÇIK ENGEL: `git push` 403.** Sekiz commit yerelde hazır, uzağa gidemiyor. Detay §2.

**KOORDİNATÖR KARARI BEKLEYEN 12 MADDE var → §10.**

---

## 1. DEVRALMA DOĞRULAMASI + KRİTİK TEŞHİS

### 1.1 Ortam

Çalışma dizini `/home/user/SINAV-ODAK` devralındığında **boştu** (yalnızca
`README.md`). Yapılanlar:

- ZIP `sinav_odak/` alt dizinine açıldı (AKTARIM'daki `cd sinav_odak` ile uyumlu)
- Flutter 3.24.5 stable indirildi ve kuruldu (sistemde Flutter yoktu)
- `libsqlite3.so` zaten mevcuttu → symlink/`libsqlite3-dev` gerekmedi
- `.flutter-plugins*` üretilen dosya oldukları için `.gitignore`'a eklendi

### 1.2 ⚠️ TEŞHİS: Görev tanımındaki "335 test" yanlış — doğru sayı **353**

Görev tanımı, G11 ve kabul kriterleri boyunca "335 test" geçiyor. Devralınan
kodda çalıştırılan `flutter test` **353/353** verdi. Bu bir eksiklik değil,
**rakam yer değiştirmesi** (353 → 335):

**Kanıt 1 — AKTARIM raporu satır 5:**
> `flutter analyze` 0 error / 0 warning · `flutter test` **353/353 geçti**

**Kanıt 2 — AKTARIM raporu satır 350:**
> `flutter test        # beklenen: 353/353`

**Kanıt 3 — AKTARIM §1'deki dosya bazlı test tablosunun toplamı:**

```
7+30+13+35+17+36+21+27+16+10+6+11+8+7+10+13+12+10+11+9+11+5+13+9+6 = 353
```

Düşen test yok, eksik dosya yok. Baseline sağlam olduğu için göreve geçildi.

**→ Görev tanımındaki 335 ve buna dayalı eşikler düzeltilmeli.**
Güncel gerçek: baseline 353, FAZ 4 sonu **470**. Bu yüzden FAZ 4 (≥440) ve
FAZ 5 (≥410) eşikleri **zaten aşılmış** durumda; oldukları gibi bırakılırsa
anlamsız kriter olarak kalırlar.

---

## 2. PUSH ENGELİ — KOORDİNATÖR AKSİYONU GEREKİYOR

`git push` **on bir kez**, farklı yollarla denendi. **Hepsi 403.**

| Deneme | Sonuç |
|---|---|
| `git push` (büyük harfli URL `Harunsezen/SINAV-ODAK`) | `403 Forbidden` |
| `git push` (küçük harfli `harunsezen/sinav-odak`) | `403 Forbidden` |
| 4 kez üstel geri çekilmeli retry (2s/4s/8s/16s) | hepsi `403` |
| `add_repo(access: "push")` ×3 | `already_present` — push kimliği üretmiyor |
| `mcp__github__create_branch` ×2 | `403 Resource not accessible by integration` |

### Teşhis kanıtları

```
=> Send header: GET /Harunsezen/SINAV-ODAK/info/refs?service=git-receive-pack HTTP/1.1
<= Recv header: HTTP/1.1 403 Forbidden
```

- 403, `git-receive-pack` isteğinin **ilk adımında** ve **GitHub'dan** dönüyor
- Egress proxy'de kayıtlı hata **yok** (`recentRelayFailures: []`) → engel ağ
  veya kurumsal egress politikası **değil**
- **Okuma çalışıyor:** `git ls-remote --heads origin` uzaktaki `main`'i listeliyor

**Sonuç:** Bu oturumun GitHub kimliği bu depo için **salt okunur**.

### GitHub'ın şu anki gerçek durumu

| | Yerel (konteyner) | GitHub |
|---|---|---|
| Dallar | `main` + `claude/sinav-odak-devralma-uck9dd` | sadece `main` |
| Son commit | `532868b` (FAZ 4) | `d66ce3b` (Initial commit) |
| Dosyalar | `.gitignore`, raporlar, `sinav_odak/` (tüm kod) | **sadece `README.md`** |

Yani **hiçbir kod GitHub'da değil**.

### Çözüm (ikisinden biri)

1. Yazma yetkisi açılsın: https://claude.ai/admin-settings/claude-in-slack
   Açıldığı anda tek komut yeterli.
2. Teslim edilen **git bundle** kullanıcı tarafından push edilsin:
   ```bash
   mkdir sinav-odak-restore && cd sinav-odak-restore
   git init
   git bundle verify ../sinav-odak-faz4.bundle
   git fetch ../sinav-odak-faz4.bundle HEAD:refs/heads/restore
   git checkout restore
   git remote add origin https://github.com/Harunsezen/SINAV-ODAK.git
   git branch -m restore claude/sinav-odak-devralma-uck9dd
   git push -u origin claude/sinav-odak-devralma-uck9dd
   ```
   Bundle **kendi kendine yeter** ("records a complete history") ve bu akış
   burada uçtan uca test edildi.

### Commit zinciri (yerel)

```
532868b  FAZ 4: reklam katmani                                  <- HEAD
f848e72  Teslim ciktilarini gitignore'a ekle
c58fb85  Rapor: FAZ 0-3 denetim belgesi
6289cc3  FAZ 3: onboarding 5 adim + KVKK/GDPR rizasi
5f04c03  FAZ 2: yanlis defteri UI
27433a1  FAZ 0 + FAZ 1: platform klasorleri ve hizalama
c8bca57  Adim 5 AG5-2: oturum sonu formu, tebrik, kurtarma
ab542e3  Adim 5 AG1: 353 test dogrulandi
d66ce3b  Initial commit                                          <- remote/main
```

> **NOT:** Konteyner geçicidir. Bundle dosyaları dışında yerel commit'ler
> kalıcı değildir; push veya bundle uygulaması **acildir**.

---

## 3. FAZ 0 — DEPO GÜVENCESİ + BASELINE

- Devralınan hal `ab542e3` ile commit'lendi
- `flutter create --org com.harunsezen --project-name sinav_odak --platforms=android,ios .`
- **58 dosya** üretildi (`android/` 22, `ios/` 36)
- **Takipli hiçbir dosya ezilmedi** (`git status` ile doğrulandı)
- `flutter create`'in ürettiği `test/widget_test.dart` **SİLİNDİ**: var olmayan
  `MyApp`'i referans ediyor, süiti kırardı
- `*.iml` `.gitignore`'a eklendi

**Manifest izinleri ve desugaring FAZ 6.2'ye aittir** (AD_ID ve APPLICATION_ID
FAZ 4'te eklendi, gerisi FAZ 6).

| Kriter | Durum |
|---|---|
| 4 komut temiz | ✅ |
| `android/` `ios/` var | ✅ 58 dosya |
| push başarılı | ❌ §2 |

---

## 4. FAZ 1 — OTURUM SONU AKIŞI (AG5-2)

### Dört komut

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 23.2s with 41 outputs (140 actions)

$ flutter analyze
error=0  warning=0  info=50

$ flutter test
00:33 +383: All tests passed!
```

### Uygulanan kararlar

**D1 — TEK KAYIT YOLU.** RunScreen "Bitir" onayı artık `finishSession`
**çağırmıyor**; yalnızca `pendingFinishProvider`'a `{early, endMs}` yazıp
`/run/summary`'ye gidiyor. Kayıt tek yerden, formun KAYDET butonundan geçiyor.
Soru sayıları ilk ve tek yazımda kaydediliyor, `daily_stats` bir kez
hesaplanıyor. `endMs` sayesinde formu doldurma süresi çalışma süresine
eklenmiyor.

**D2 — Kurtarma diyaloğu.** `pendingRecoveryProvider` hesaplanıyor ama
hiçbir yerde tüketilmiyordu. `RecoveryGate` ana paneli sarıyor, sonucu **tek
kez** tüketiyor: `needsDecision` → [Koru]/[Sil] · `clockMovedBack` →
[Devam et]/[Oturumu kes] (`interruptNow`) · `resume`/`none` → diyalog yok.

**D3/K2 — Tek `running` şema kısıtı.**
```sql
CREATE UNIQUE INDEX idx_one_running
  ON study_sessions(status) WHERE status = 'running';
```
`onCreate` içinde, `schemaVersion` 1'de kaldı, README'ye "uygulamayı sil" notu.
Kod seviyesindeki koruma yetersizdi: `StartSession` "önce oku sonra yaz"
yapısı, yarış durumunda ikinci `running` satıra izin veriyordu; o durumda ilk
oturumun çalışması `daily_stats`'a hiç yansımıyor ve hata sessiz kalıyordu.

**D4/K3 — `db_health` yalnız debug.** Karar `settingsPageFor(debug:)`
fonksiyonuna alındı. `kDebugMode` doğrudan gövdeye yazılsaydı release dalı
**test edilemezdi** (testler debug modda koşar, o dal derleme zamanında
elenir). Şimdi iki dal da doğrulanıyor.

### Değişen dosyalar

| Dosya | Durum |
|---|---|
| `presentation/run/pending_finish_controller.dart` | YENİ |
| `presentation/run/summary_form.dart` (S10) | YENİ |
| `presentation/run/done_screen.dart` (S11) | YENİ |
| `presentation/home/recovery_gate.dart` (S18) | YENİ |
| `presentation/summary/summary_screen.dart` | **SİLİNDİ** (iskelet) |
| `presentation/home/home_screen.dart` | RecoveryGate montajı |
| `presentation/run/run_screen.dart` | Bitir akışı D1 |
| `presentation/run/run_controller.dart` | `finish(nowMs:)` |
| `application/recovery_service.dart` | `interruptNow()` |
| `core/router/app_router.dart` | Gerçek ekranlar · K3 · `/run/done` muafiyeti |
| `core/di/app_providers.dart` | 4 yeni provider |
| `data/local/database.dart` | K2 index |
| `data/local/daos/subject_dao.dart` | `findTopic()` |
| `README.md` | K2 notu |

### Kabul

| Kriter | Durum | Kanıt |
|---|---|---|
| test ≥ 350 | ✅ | 383 |
| canlı net 41.0 (44/12/4) | ✅ | `summary-net` = "41" |
| invariant hatası + KAYDET pasif | ✅ | mesaj `NetCalculator`'un kendisinden |
| KAYDET → completed + wrong_items + daily_stats + done | ✅ | |
| early modda `actualDurationS` = `endMs`'ten | ✅ | 600 sn |
| recovery 3 dal | ✅ | 9 test |
| G6/G7 regresyonları | ✅ | |

---

## 5. FAZ 2 — YANLIŞ DEFTERİ UI (AG5-3)

### Dört komut

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 23.8s with 37 outputs (140 actions)

$ flutter analyze
error=0  warning=0  info=50

$ flutter test
00:29 +398: All tests passed!
```

### Değişen dosyalar

| Dosya | Durum | Ne |
|---|---|---|
| `presentation/wrongs/wrong_list_screen.dart` | YENİ | `SegmentedButton` 3 sekme + `watchByStatus` + FAB |
| `presentation/wrongs/wrong_card.dart` | YENİ | Renk şeridi, ders·konu, "N yanlış", not önizleme, kaynak rozeti, durum ilerlet |
| `presentation/wrongs/wrong_detail_sheet.dart` | YENİ | Not düzenle, sil (onaylı), "Bu konuyu çalış" |
| `presentation/wrongs/add_wrong_screen.dart` | YENİ | Elle kayıt — **route**, dialog değil |
| `core/utils/color_hex.dart` | YENİ | `colorHex → Color` tek yerde |
| `core/di/app_providers.dart` | DEĞİŞTİ | `wrongItemsProvider` |
| `core/router/routes.dart` + `app_router.dart` | DEĞİŞTİ | `/wrongs` gerçek, `/wrongs/add` shell dışında |
| `presentation/session_setup/subject_picker.dart` | DEĞİŞTİ | Renk çözümleme kopyası kaldırıldı |

**Kart Drift tipi almıyor** — alanlar tek tek parametre; `WrongItemView`
yalnızca listede tip çıkarımıyla tüketiliyor (G4 korunuyor).

### Kabul

| Kriter | Durum |
|---|---|
| test ≥ 360 | ✅ **398** |
| 3 sekme + `watchByStatus` | ✅ |
| Kart alanları + kaynak rozeti | ✅ |
| Durum ilerlet / not / sil (onaylı) / "Bu konuyu çalış" | ✅ |
| "Bu konuyu çalış" → `act_analiz` + `/session/plan` | ✅ `isReadyForPlan` assert'li |
| add_wrong route, ders zorunlu | ✅ |
| Boş durum mesajları | ✅ sekmeye özel 3 mesaj |

---

## 6. FAZ 3 — ONBOARDING 5 ADIM + KVKK/GDPR RIZASI

### Dört komut

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 27.7s with 38 outputs (146 actions)

$ flutter analyze
error=0  warning=0  info=50

$ flutter test
00:38 +414: All tests passed!
```

### Değişen dosyalar

| Dosya | Durum | Ne |
|---|---|---|
| `onboarding/onboarding_screen.dart` | **YENİDEN YAZILDI** | PageView + ilerleme + alt bar |
| `onboarding/steps/promise_step.dart` | YENİ | 1/5 Vaat |
| `onboarding/steps/exam_step.dart` | YENİ | 2/5 `ExamType` kartları (6 tür) |
| `onboarding/steps/goal_step.dart` | YENİ | 3/5 60–480 dk /30 · 20–500 soru /10 |
| `onboarding/steps/consent_step.dart` | YENİ | 4/5 KVKK metni + rıza toggle + izin/Atla |
| `onboarding/steps/summary_step.dart` | YENİ | 5/5 Özet + [Başla] |
| `application/usecases/complete_onboarding.dart` | DEĞİŞTİ | `personalizedAdsConsent` |

**Tasarım kararı:** seçimler tek yerde (`OnboardingScreen` State) toplanır ve
**yalnızca son adımda** yazılır. Yarıda bırakılan onboarding yarım ayar
bırakmaz — bir test bunu kilitliyor.

### Kabul

| # | Kriter | Durum | Kanıt |
|---|---|---|---|
| K2 | test ≥ 410 | ✅ | **414** |
| K3 | PageView + ilerleme | ✅ | `1/5`→`2/5`, progress 0.2→0.4 |
| K4 | Sınav türü kartları | ✅ | seçilmeden Devam **pasif** |
| K5 | consent varsayılan false | ✅ | dokunulmazsa DB'ye `false` |
| K6 | Bildirim izni akışı durdurmaz | ✅ | reddedilse de Devam; Atla hiç istemiyor |
| K7 | [Başla] → settings patch + redirect | ✅ | `270 dk`, `onboardingCompleted=true`, `/home` |
| K8 | Router redirect | ✅ | mevcut `router_redirect_test` ile kilitli |

---

## 7. FAZ 4 — REKLAM KATMANI (Adım 6)

### Dört komut

```
$ flutter pub get
Got dependencies!
102 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 19.1s with 312 outputs (627 actions)

$ flutter analyze
error=0  warning=0  info=50
50 issues found. (ran in 8.8s)

$ flutter test
00:36 +470: All tests passed!
```

### Değişen dosyalar

| Dosya | Durum | Sorumluluk |
|---|---|---|
| `domain/entities/ad_placement.dart` | YENİ | `AdPlacement` + `kind`/`isFullScreen`/`screenName` |
| `domain/ports/ad_gateway.dart` | YENİ | Saf port; reklam nesnesi `Object?` |
| `domain/services/ad_policy_engine.dart` | YENİ | **Saf Dart kural motoru** |
| `data/local/daos/ad_event_dao.dart` | YENİ | log/markClicked/markCompleted/pruneOlderThan/lastShownAt |
| `services/ads/noop_ad_gateway.dart` | YENİ | Varsayılan, reklamsız |
| `services/ads/admob_gateway.dart` | YENİ | Gerçek adaptör; politika **içeride** |
| `presentation/ads/banner_ad_slot.dart` | YENİ | RED → `SizedBox.shrink` |
| `presentation/ads/native_ad_slot.dart` | YENİ | 1200 ms · "Sponsorlu" · ≥48dp |
| `presentation/ads/interstitial_controller.dart` | YENİ | Ara reklamın TEK çağrı yolu |
| `core/di/ad_providers.dart` | YENİ | Reklam DI (ayrı dosya) |
| `data/local/database.dart` | DEĞİŞTİ | `pruneAdEvents` çıkarıldı, `AdEventDao` kaydedildi |
| `main.dart` | DEĞİŞTİ | `adEventDao.pruneOlderThan(nowMs())` |
| `presentation/run/break_screen.dart` | DEĞİŞTİ | `break-ad-slot` → `NativeAdSlot` |
| `presentation/run/run_screen.dart` | DEĞİŞTİ | Kontrol çubuğu üstü ince banner |
| `presentation/run/done_screen.dart` | DEĞİŞTİ | [Ana panel] → `maybeShow` + `go(home)` |
| `presentation/home/recovery_gate.dart` | DEĞİŞTİ | **S4 kapatıldı:** "Kaydet" → "Koru" |
| `pubspec.yaml` | DEĞİŞTİ | `google_mobile_ads` yorumdan çıkarıldı |
| `android/.../AndroidManifest.xml` | DEĞİŞTİ | `APPLICATION_ID` (TEST) + `AD_ID` izni |

### Politika kuralları (`AdPolicyEngine`, saf Dart)

1. **Rıza yoksa HİÇBİR reklam yok** — kişiselleştirilmiş olsun olmasın.
   KVKK/GDPR'ın gerektirdiğinden katı, bilinçli ürün kararı.
2. **`isInStudyBlock` → tam ekran ASLA.** Ürünün tek vaadi "odaklanmanı
   kolaylaştırırım"; onu en yüksek niyetli anda bozmak ürünü yalanlar.
3. Çalışma ekranında yalnızca **ince banner**, o da kullanıcı ayarı açıksa.
4. Native mola kartı: kalan > 180 sn.
5. Interstitial: 90 sn frekans kapısı, **tek tetik** Done→Home geçişi.
   Cihaz saati geriye alınırsa kapı kapalı kalır (sömürü engeli).
6. Rewarded: frekans kapısı yok (kullanıcı başlatır), diğer kurallar geçerli.

### Neden politika `AdGateway` implementasyonunun İÇİNDE

Çağıran katmana bırakılsaydı, yeni bir çağrı yolu açan kişi kuralı sessizce
delerdi. `AdMobGateway`'in **dört giriş noktasının dördü de** `_allowed()`'dan
geçiyor; `InterstitialController` ayrıca `AdPolicyEngine.allows` çağırıyor.
Ekranlar politikayı ayrıca soruyor (boş yer ayırmamak için), ama son söz
gateway'de.

### Kabul

| Kriter | Durum | Kanıt |
|---|---|---|
| 4 komut temiz | ✅ | 0 error / 0 warning / 50 info (baseline ile aynı) |
| test ≥ 440 | ✅ | **470** |
| `isInStudyBlock`'ta fullscreen çağrısı yok | ✅ | grep: `showInterstitial`/`showRewarded` yalnız 2 yerde, ikisi de politika kapılı |
| consent false'ta slotlar boş | ✅ | banner/native testleri: `findsNothing` + yükseklik 0 |
| Domain temiz | ✅ | `flutter/drift/riverpod/google_mobile_ads` yok |
| commit + bundle | ✅ | `532868b` |
| push | ❌ | §2 |

---

## 8. TEST ENVANTERİ (353 → 470)

```
353  devralınan baseline
  -5  summary_screen_test.dart      (iskelet ekranla birlikte silindi, §10-S9)
 +11  summary_form_test.dart
  +6  done_screen_test.dart
  +9  recovery_gate_test.dart
  +4  single_running_index_test.dart
  +4  router_redirect_test.dart     (mevcut dosyaya eklendi)
  +1  run_screen_test.dart
 -----
 383  FAZ 1 sonu
 +15  wrongs_test.dart
 -----
 398  FAZ 2 sonu
 +16  onboarding_test.dart          (yeniden yazıldı, eskisi yoktu)
 -----
 414  FAZ 3 sonu
 +32  ad_policy_test.dart
  +7  ad_event_dao_test.dart
  +9  ad_slots_test.dart
  +6  interstitial_test.dart
  +2  run_screen_test.dart          (reklam regresyonu)
 -----
 470  FAZ 4 sonu
```

Sayılar her dosyanın **tek tek çalıştırılmasıyla** doğrulandı.

### Politika testinin kapsamı (32 test)

Rıza kapısı 5 · çalışma bloğu yasağı 5 · banner 4 · native sınırları
(179/180/181 sn) 4 · interstitial (89/90/91 sn + saat geri alma) 6 ·
rewarded 2 · `AdPlacement` sözleşmesi 4 · `allows()` 2.

---

## 9. MİMARİ KURAL DOĞRULAMALARI (her fazda tekrarlandı)

| Kural | Komut | Sonuç |
|---|---|---|
| G4a domain'de Flutter/Drift/Riverpod/AdMob yok | `grep -rE "import 'package:(flutter\|drift\|flutter_riverpod\|google_mobile_ads)" lib/domain/` | **TEMİZ** |
| G4b presentation → data yok | `grep -rn "import '.*data/" lib/presentation/` | **TEMİZ** |
| G3 testlerde `DateTime.now()` yok | `grep -rn "DateTime.now()" test/` | **TEMİZ** (eşleşmeler yorum) |
| G6 pause butonu yok | `grep -rniE "'Duraklat'\|Icons\.pause\|'Durdur'" lib/presentation/` | **TEMİZ** (eşleşme dartdoc) |
| G7 summary/done reklamsız | grep reklam anahtarları | **TEMİZ** |
| G8 ders/konu silme yok | `grep -rn "deleteSubject\|deleteTopic" lib/presentation/` | **TEMİZ** |

> AKTARIM §6'daki tuzak doğrulandı: yorum satırları ayıklanmadığında
> `DateTime.now()` ve `Icons.pause` **yanlış alarm** veriyor.

---

## 10. ⚠️ KOORDİNATÖR KARARI BEKLEYEN SAPMALAR (G12)

Hiçbiri FAZ 5'e engel değil; hepsi geri alınabilir.

### S1 — `SavedResult` üçüncü alan taşıyor: `dateKey` — **AÇIK**
- **Spec:** `{sessionId, focusScore}`, DoneScreen `watchDay(todayKey)`
- **Yapılan:** `{sessionId, focusScore, dateKey}`; oturumun `dateKey`'i kullanılıyor
- **Neden:** `todayKey()` içeride `DateTime.now()` çağırıyor. (a) Widget testi
  günlük ilerlemeyi doğrulayamaz. (b) **G9 ile çelişir**: gece 23:50'de başlayıp
  00:40'ta biten oturum bittiğinde kullanıcıya BAŞKA günün özeti gösterilir
- **Test edildi mi:** Evet · **Geri alma:** tek satır

### S2 — `savedResultProvider` `pending_finish_controller.dart` içinde — **AÇIK**
İkisi de aynı akışın state'i. Ayrılmasını isterseniz taşınır.

### S3 — G11'deki "335 test" yanlış — **AÇIK**
Gerçek baseline 353 (üç kanıt, §1.2). Şu an 470. Kabul eşikleri güncellenmeli.

### S4 — Recovery diyaloğunda "Kaydet" etiketi — ✅ **KAPATILDI (FAZ 4)**
`needsDecision` geldiğinde kayıt zaten `interrupted` olarak yazılı; "Kaydet"
pasif bir butonu adlandırıyordu. **"Koru" olarak değiştirildi**, test güncellendi.

### S5 — Yanlış kartındaki dört butonun üçü detay sayfasında — **AÇIK**
- **Spec:** Dördü de kartta
- **Yapılan:** **Durum ilerlet** kartta; not düzenle / sil / "Bu konuyu çalış"
  `wrong_detail_sheet.dart`'ta (spec'in ayrı dosya olarak istediği yer)
- **Neden:** Dört buton kartı okunmaz hale getiriyordu
- **Test edildi mi:** Evet, dördü de · Her aksiyon karttan **tek dokunuş** uzakta

### S6 — `/wrongs/add` shell dışında — **AÇIK**
Spec shell içi/dışı belirtmiyor. Yarım kalmış formda alt navigasyon kullanıcıyı
başka sekmeye götürmesin diye kurulum akışıyla aynı desende.

### S7 — Rıza adımında üç ileri yolu var — **AÇIK**
İzin butonu **istekte bulunur ve sonucu gösterir, ilerletmez**; kullanıcı
[Devam] ile geçer. [Atla] doğrudan ilerletir. Test 8/9/10 ancak böyle ayrı ayrı
doğrulanabiliyor. Üçü de test edildi.

### S8 — Hedef stepper'larına üst sınır kondu (480 dk / 500 soru) — **AÇIK**
Spec aralığı veriyor ama yalnızca alt sınır testi istiyor. Sürdürülemez hedef
kullanıcıyı ilk haftada başarısız hissettirir.

### S9 — `summary_screen_test.dart` (5 test) silindi — **AÇIK (bilgi)**
İki testi ("yer tutucular mevcut", "KAYDET henüz bağlı değil") tam olarak
FAZ 1'in bitirdiği durumu doğruluyordu; taşınamazdı. Kalan üç koruma — boş
durum, özet başlığı ve **REKLAM YOK regresyon kalkanı** — `summary_form_test`'e
aynen taşındı. **Test zayıflatılmadı.**

### S10 — `RecordingAdGateway` test klasöründe — **AÇIK** *(FAZ 4)*
Görev tanımı `noop_ad_gateway.dart` içinde ima ediyordu. Test ikizini `lib/`
altında tutmak onu uygulamayla birlikte sevk etmek demekti;
`test/unit/ad_helpers.dart`'a taşındı. 15 test onu kullanıyor.

### S11 — `AdPlacement` enum, serbest metin (`screen: 'run'`) değil — **AÇIK** *(FAZ 4)*
Spec `banner(screen, ...)` diyordu. Enum ile yazım hatası "reklam gösterme"
diye sessizce geçmek yerine **derleme hatası** veriyor — reklam politikasında
sessiz hata para veya politika ihlali demek. `screenName` getter'ı `ad_events`
için metni yine üretiyor.

### S12 — Native yuva gecikme boyunca da yer ayırmıyor — **AÇIK** *(FAZ 4)*
Spec "1200 ms gecikmeli" diyor ama bu sürede ne görüneceğini söylemiyor. Boş
kutu yerine `SizedBox.shrink`; kart belirince düzen kayıyor ama öncesinde
anlamsız boşluk durmuyor. Test edildi.

### S13 — `rewarded` için frekans kapısı yok — **AÇIK** *(FAZ 4)*
Spec "rewarded: consent" diyor. Kullanıcının kendi başlattığı akış olduğu için
90 sn kapısı uygulanmadı; rıza ve çalışma bloğu kuralları geçerli. Test edildi.

---

## 11. TEKNİK NOTLAR (gelecek fazları ilgilendirir)

### 11.1 `testWidgets` içinde Drift akışı beklemek KİLİTLENİYOR

```dart
// YAPMA — süreç sessizce takılır, hata bile vermez:
final stat = await db.statsDao.watchDay(key).first;

// YAP — Future tabanlı sorgu:
final stat = await db.statsDao.summaryFor(day, day);
final rows = await db.select(db.wrongItems).get();
```

`testWidgets` sahte zaman bölgesinde çalışıyor; akışın ilk değerini beklemek
deadlock üretiyor. **İki kez bu yüzden test süreci dondu.** Provider akışlarını
`pumpWidget` ÖNCESİNDE ısıtmak sorunsuz:

```dart
await container.read(wrongItemsProvider(status).future);
await container.read(subjectsProvider.future);
```

### 11.2 `DbHealthPage` widget testinde render edilemiyor

Açtığı Drift akışları widget ağacı yıkıldıktan sonra da askıda timer bırakıyor
(`A Timer is still pending...`). K3/D4 testi ekranı **render etmeden** hangi
ekranın seçildiğini doğruluyor.

### 11.3 Uzun form ekranlarında test yüzeyi

Varsayılan 800×600 yüzeyde KAYDET/Devam butonları görünür alanın dışında kalıp
dokunuşlar hedefe ulaşmıyor. Etkilenen testlerde `tester.view.physicalSize`
yükseltildi; böylece `ListView` sanallaştırma tuzağına da düşülmüyor.

### 11.4 Sayaç artırma testlerinde ara `pump` zorunlu

`onPressed` kapanışı son çizilen değeri yakalar; ara `pump` olmadan N dokunuş
değeri 1 yapar.

### 11.5 `analyze` sayımında tuzak

`grep -cE '^\s+warning •'` gerçek bir warning'i **kaçırdı** (girinti farkı).
Doğru sayım: `grep -cE '(^|[[:space:]])warning •'`. Bir tur "0 warning" diye
rapor edilen çıktıda aslında bir warning vardı; düzeltildi.

---

## 12. AÇIK KALANLAR

### Acil (koordinatör)
1. **Push yetkisi** — §2. Tek gerçek engel; GitHub'da hâlâ hiç kod yok
2. **335 → 353 düzeltmesi** ve FAZ 5 eşiğinin (≥410) güncellenmesi
3. **S1–S3, S5–S13 kararları** — §10

### FAZ 5'e kalanlar (reklam tarafı)
- **Home / Stats / Calendar banner** — ekranlar FAZ 5'te yeniden yazılacak,
  `BannerAdSlot` oraya takılacak
- **Rewarded UI** — Ayarlar "Destek ol" (politika ve gateway hazır, ekran yok)

### FAZ 6'ya kalanlar
- **Gerçek UMP SDK** (Google Consent) — şu an yalnızca toggle var
- **`manifestPlaceholders`** ile production AdMob ID'sinin `--dart-define`'dan
  geçirilmesi
- i18n altyapısı, kalan manifest izinleri + desugaring, boot receiver,
  launcher ikon, PRIVACY.md, release APK smoke

### AKTARIM'dan devralınan teknik borç
- `user_settings.currentStreak/longestStreak/lastStudyDate` — kolonlar var,
  yazan kod yok (FAZ 5 `StreakCalculator`)
- `achievements` tablosu — yazan kod yok
- `goals.currentValue` otomatik güncellenmiyor
- 50 adet `info` lint — devralınan 52'nin altında; **yeni lint eklenmedi**
- **Uygulama gerçek cihazda hiç çalıştırılmadı** — tüm doğrulama host
  testleriyle. `AdMobGateway` de dahil hiç çalıştırılmadı (testlerde
  `NoopAdGateway`). FAZ 6.5 cihaz kontrolü bunu kapatacak

---

## 13. ÖZET TABLO — KOORDİNATÖRE

| Konu | Durum |
|---|---|
| FAZ 0 / 1 / 2 / 3 / 4 | ✅ (push hariç) |
| `flutter analyze` | ✅ 0 error / 0 warning / 50 info |
| `flutter test` | ✅ **470/470** |
| Mimari kurallar (G3/G4/G6/G7/G8) | ✅ grep'le doğrulandı |
| Reklam politikası | ✅ 32 birim testle kilitli |
| `git push` | ❌ **403 — yetki gerekiyor** |
| Karar bekleyen sapma | ⚠️ **12 açık, 1 kapandı (S4)** |
