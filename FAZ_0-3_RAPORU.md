# SINAV ODAK — FAZ 0–3 İŞÇİ RAPORU

**Rol:** İşçi (Claude) · **Denetleyen:** Koordinatör (Qwen)
**Tarih:** 2026-08-10
**Flutter:** 3.24.5 stable (AKTARIM raporunun belirttiği sürüm)
**Depo:** `Harunsezen/SINAV-ODAK` · dal `claude/sinav-odak-devralma-uck9dd`

---

## 0. YÖNETİCİ ÖZETİ

| Faz | Konu | Test | Durum |
|---|---|---|---|
| Devralma | ZIP açıldı, SDK kuruldu, baseline doğrulandı | 353 | ✅ |
| FAZ 0 | Depo güvencesi + `flutter create` (android/ios) | 353 | ✅ (push ❌) |
| FAZ 1 | Oturum sonu akışı (AG5-2) | 383 | ✅ |
| FAZ 2 | Yanlış defteri UI (AG5-3) | 398 | ✅ |
| FAZ 3 | Onboarding 5 adım + KVKK rızası (AG5-4) | 414 | ✅ |

**Son durum:** `flutter analyze` 0 error / 0 warning (50 info) · `flutter test` **414/414**

**TEK AÇIK ENGEL: `git push` 403.** Beş commit yerelde hazır, uzağa gidemiyor. Detay §2.

**KOORDİNATÖR KARARI BEKLEYEN 8 MADDE var → §9.**

---

## 1. DEVRALMA DOĞRULAMASI + KRİTİK TEŞHİS

### 1.1 Ortam

Çalışma dizini `/home/user/SINAV-ODAK` devralındığında **boştu** (yalnızca `README.md`).
Yapılanlar:

- ZIP `sinav_odak/` alt dizinine açıldı (AKTARIM'daki `cd sinav_odak` komutuyla uyumlu)
- Flutter 3.24.5 stable indirildi ve kuruldu (sistemde Flutter yoktu)
- `libsqlite3.so` zaten mevcuttu → symlink/`libsqlite3-dev` gerekmedi
- `.flutter-plugins` / `.flutter-plugins-dependencies` üretilen dosya oldukları için `.gitignore`'a eklendi

### 1.2 ⚠️ TEŞHİS: Görev tanımındaki "335 test" yanlış — doğru sayı **353**

Görev tanımı, G11 ve K7/K2 kriterleri boyunca "335 test" geçiyor. Devralınan kodda
çalıştırılan `flutter test` **353/353** verdi. Bu bir eksiklik değil, **rakam yer
değiştirmesi** (353 → 335):

**Kanıt 1 — AKTARIM raporu satır 5:**
> `flutter analyze` 0 error / 0 warning · `flutter test` **353/353 geçti**

**Kanıt 2 — AKTARIM raporu satır 350:**
> `flutter test        # beklenen: 353/353`

**Kanıt 3 — AKTARIM §1'deki dosya bazlı test tablosunun toplamı:**

```
7+30+13+35+17+36+21+27+16+10+6+11+8+7+10+13+12+10+11+9+11+5+13+9+6 = 353
```

Düşen test yok, eksik dosya yok. Baseline sağlam olduğu için göreve geçildi.

**→ Görev tanımındaki 335 rakamı ve buna dayalı kabul eşikleri düzeltilmeli.**
Güncel gerçek: baseline 353, FAZ 3 sonu **414**.

---

## 2. PUSH ENGELİ — KOORDİNATÖR AKSİYONU GEREKİYOR

`git push` altı kez, farklı yollarla denendi. **Hepsi 403.**

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
- Egress proxy'de kayıtlı hata **yok** (`recentRelayFailures: []`) → engel ağ veya
  kurumsal egress politikası **değil**
- **Okuma çalışıyor:** `git ls-remote --heads origin` uzaktaki `main`'i listeliyor

**Sonuç:** Bu oturumun GitHub kimliği bu depo için **salt okunur**. Tekrar denemek
sonucu değiştirmez.

### Çözüm (ikisinden biri)

1. Yazma yetkisi açılsın: https://claude.ai/admin-settings/claude-in-slack
   Açıldığı anda tek komut yeterli:
   `git push -u origin claude/sinav-odak-devralma-uck9dd`
2. Teslim edilen **git bundle** kullanıcı tarafından push edilsin:
   ```bash
   git fetch /yol/sinav-odak-faz3.bundle \
     claude/sinav-odak-devralma-uck9dd:claude/sinav-odak-devralma-uck9dd
   git push -u origin claude/sinav-odak-devralma-uck9dd
   ```
   Bundle her fazda güncellenip teslim edildi; sonuncusu beş commit'in tamamını
   içeriyor ve `git bundle verify` ile doğrulandı.

### Commit zinciri (yerel)

```
6289cc3  FAZ 3: onboarding 5 adim + KVKK/GDPR rizasi        <- HEAD
5f04c03  FAZ 2: yanlis defteri UI
27433a1  FAZ 0 + FAZ 1: platform klasorleri ve hizalama
c8bca57  Adim 5 AG5-2: oturum sonu formu, tebrik, kurtarma
ab542e3  Adim 5 AG1: 353 test dogrulandi
d66ce3b  Initial commit                                      <- remote/main BURADA
```

> **NOT:** Konteyner geçicidir. Bundle dosyaları dışında yerel commit'ler kalıcı
> değildir; push veya bundle uygulaması **acildir**.

---

## 3. FAZ 0 — DEPO GÜVENCESİ + BASELINE

### Yapılanlar

- Devralınan hal `ab542e3` ile commit'lendi
- `flutter create --org com.harunsezen --project-name sinav_odak --platforms=android,ios .`
- **58 dosya** üretildi (`android/` 22, `ios/` 36)
- **Takipli hiçbir dosya ezilmedi** — `pubspec.yaml`, `README.md`,
  `analysis_options.yaml` dokunulmadan kaldı (`git status` ile doğrulandı)
- `flutter create`'in ürettiği `test/widget_test.dart` **SİLİNDİ**: var olmayan
  `MyApp`'i referans ediyor, süiti kırardı
- `*.iml` `.gitignore`'a eklendi

**Manifest izinleri ve desugaring FAZ 6.2'ye aittir; bu fazda YAPILMADI.**

### Kabul

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
97 packages have newer versions incompatible with dependency constraints.

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 23.2s with 41 outputs (140 actions)

$ flutter analyze
error=0  warning=0  info=50
50 issues found. (ran in 8.7s)

$ flutter test
00:33 +383: All tests passed!
```

### Değişen dosyalar

| Dosya | Durum | Ne |
|---|---|---|
| `presentation/run/pending_finish_controller.dart` | YENİ | `PendingFinish` + `SavedResult` |
| `presentation/run/summary_form.dart` | YENİ | S10 oturum sonu formu |
| `presentation/run/done_screen.dart` | YENİ | S11 tebrik ekranı |
| `presentation/home/recovery_gate.dart` | YENİ | S18 kurtarma diyaloğu kapısı |
| `presentation/summary/summary_screen.dart` | **SİLİNDİ** | İskelet; yerini `summary_form` aldı |
| `presentation/home/home_screen.dart` | DEĞİŞTİ | RecoveryGate montajı |
| `presentation/run/run_screen.dart` | DEĞİŞTİ | Bitir akışı: `finish` ÇAĞRILMIYOR |
| `presentation/run/run_controller.dart` | DEĞİŞTİ | `finish(nowMs:)` opsiyonel parametresi |
| `application/recovery_service.dart` | DEĞİŞTİ | `interruptNow()` |
| `core/router/app_router.dart` | DEĞİŞTİ | Gerçek ekranlar · K3 · `/run/done` muafiyeti |
| `core/di/app_providers.dart` | DEĞİŞTİ | `recoveryServiceProvider`, `dayStatsProvider`, `activeSessionLabelsProvider`, `recoveryConsumedProvider` |
| `data/local/database.dart` | DEĞİŞTİ | K2 `idx_one_running` kısmi unique index |
| `data/local/daos/subject_dao.dart` | DEĞİŞTİ | `findTopic()` (arşivlenmiş konu adı da dönsün) |
| `README.md` | DEĞİŞTİ | K2 "uygulamayı sil" notu |
| `test/widget/summary_form_test.dart` | YENİ | 11 test |
| `test/widget/done_screen_test.dart` | YENİ | 6 test |
| `test/widget/recovery_gate_test.dart` | YENİ | 9 test |
| `test/unit/single_running_index_test.dart` | YENİ | 4 test |
| `test/widget/run_screen_test.dart` | DEĞİŞTİ | +1, 2 test yeni akışa güncellendi |
| `test/integration/router_redirect_test.dart` | DEĞİŞTİ | +4 test |
| `test/widget/summary_screen_test.dart` | **SİLİNDİ** | §9-S9 |

### Uygulanan kararlar

**KARAR D1 — TEK KAYIT YOLU.** RunScreen "Bitir" onayı artık `finishSession`
**çağırmıyor**; yalnızca `pendingFinishProvider`'a `{early, endMs}` yazıp
`/run/summary`'ye gidiyor. Kayıt tek yerden, formun KAYDET butonundan geçiyor.
Böylece soru sayıları ilk ve tek yazımda kaydediliyor, `daily_stats` bir kez
hesaplanıyor. `endMs` sayesinde formu doldurma süresi çalışma süresine eklenmiyor.

**KARAR D2 — Kurtarma diyaloğu.** `pendingRecoveryProvider` hesaplanıyor ama
hiçbir yerde tüketilmiyordu. `RecoveryGate` ana paneli sarıyor ve sonucu **tek kez**
tüketiyor:
- `needsDecision` → [Kaydet] kapatır (kayıt zaten `interrupted`), [Sil] siler
- `clockMovedBack` → [Devam et] kapatır, [Oturumu kes] `interruptNow` çağırır
- `resume` / `none` → diyalog yok

**KARAR D3/K2 — Tek `running` şema kısıtı.**
```sql
CREATE UNIQUE INDEX idx_one_running
  ON study_sessions(status) WHERE status = 'running';
```
`onCreate` içinde, `schemaVersion` 1'de kaldı. README'ye "geliştirme cihazından
uygulamayı sil" notu eklendi. **Kod seviyesindeki koruma yetersizdi**: `StartSession`
"önce oku sonra yaz" yapısı, yarış durumunda ikinci `running` satıra izin veriyordu;
o durumda ilk oturumun çalışması `daily_stats`'a hiç yansımıyor ve hata sessiz kalıyordu.

**KARAR D4/K3 — `db_health` yalnız debug.** Karar `settingsPageFor(debug:)`
fonksiyonuna alındı. `kDebugMode` doğrudan gövdeye yazılsaydı release dalı
**test edilemezdi** (testler debug modda koşar, o dal derleme zamanında elenir).
Şimdi iki dal da doğrulanıyor.

### Kabul

| Kriter | Durum | Kanıt |
|---|---|---|
| 4 komut temiz | ✅ | |
| test ≥ 350 | ✅ | 383 |
| canlı net 41.0 (44/12/4) | ✅ | `summary-net` = "41" |
| invariant hatası + KAYDET pasif | ✅ | mesaj `NetCalculator`'un kendisinden |
| KAYDET → completed + wrong_items + daily_stats + done | ✅ | |
| early modda `actualDurationS` = `endMs`'ten | ✅ | 600 sn |
| recovery 3 dal | ✅ | 9 test |
| G6 pause yok | ✅ | |
| G7 summary/done reklamsız | ✅ | |

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
| `core/di/app_providers.dart` | DEĞİŞTİ | `wrongItemsProvider` (status family) |
| `core/router/routes.dart` | DEĞİŞTİ | `wrongsAdd = '/wrongs/add'` |
| `core/router/app_router.dart` | DEĞİŞTİ | `/wrongs` gerçek ekran, `/wrongs/add` shell dışında |
| `presentation/session_setup/subject_picker.dart` | DEĞİŞTİ | Kendi renk çözümleme kopyası kaldırıldı |
| `test/widget/wrongs_test.dart` | YENİ | 15 test |

**Kart Drift tipi almıyor** — alanlar tek tek parametre; `WrongItemView` yalnızca
listede tip çıkarımıyla tüketiliyor (G4 korunuyor).

### Kabul

| Kriter | Durum |
|---|---|
| 4 komut temiz | ✅ |
| test ≥ 360 | ✅ **398** |
| SegmentedButton 3 sekme + `watchByStatus` | ✅ |
| Kart: renk şeridi, ders·konu, sayı, not, kaynak rozeti | ✅ |
| Durum ilerlet / not düzenle / sil (onaylı) / "Bu konuyu çalış" | ✅ |
| "Bu konuyu çalış" → `act_analiz` + `/session/plan` | ✅ `isReadyForPlan` assert'li |
| add_wrong route, ders zorunlu, konu opsiyonel | ✅ |
| Boş durum mesajları | ✅ sekmeye özel 3 mesaj |
| Manuel kayıt silinince tamamen gider | ✅ |

---

## 6. FAZ 3 — ONBOARDING 5 ADIM + KVKK/GDPR RIZASI

### Dört komut

```
$ flutter pub get
Got dependencies!
97 packages have newer versions incompatible with dependency constraints.

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 27.7s with 38 outputs (146 actions)

$ flutter analyze
error=0  warning=0  info=50
50 issues found. (ran in 10.9s)

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
| `application/usecases/complete_onboarding.dart` | DEĞİŞTİ | `personalizedAdsConsent` parametresi |
| `test/widget/onboarding_test.dart` | **YENİDEN YAZILDI** | 16 test |

### Tasarım kararı (raporlanmalı)

**Seçimler tek yerde (`OnboardingScreen` State) toplanır ve YALNIZCA son adımda,
[Başla] ile yazılır.** Yarıda bırakılan onboarding yarım ayar bırakmaz. Bunu
`12b) yarıda bırakılan onboarding ayar YAZMIYOR` testi kilitliyor.

`personalizedAdsConsent` presentation katmanından `UserSettingsCompanion`
kullanılmadan yazılabilsin diye `CompleteOnboardingUseCase`'e parametre eklendi (G4).

### Kabul

| # | Kriter | Durum | Kanıt |
|---|---|---|---|
| K1 | 4 komut temiz | ✅ | 0 error / 0 warning |
| K2 | test ≥ 410 | ✅ | **414** |
| K3 | PageView + ilerleme | ✅ | `1/5`→`2/5`, progress 0.2→0.4 |
| K4 | Sınav türü kartları | ✅ | 6 tür, seçilmeden Devam **pasif** |
| K5 | consent varsayılan false | ✅ | toggle `false`; dokunulmazsa DB'ye `false` |
| K6 | Bildirim izni akışı durdurmaz | ✅ | reddedilse de Devam; Atla hiç istemiyor |
| K7 | [Başla] → settings patch + redirect | ✅ | `examType`, `270 dk`, consent, `onboardingCompleted=true`, `/home` |
| K8 | Router redirect | ✅ | mevcut `router_redirect_test` ile kilitli |
| K9 | git push BAŞARILI | ❌ | §2 |

---

## 7. TEST ENVANTERİ (353 → 414)

```
353  devralınan baseline
  -5  summary_screen_test.dart      (iskelet ekranla birlikte silindi, §9-S9)
 +11  summary_form_test.dart
  +6  done_screen_test.dart
  +9  recovery_gate_test.dart
  +4  single_running_index_test.dart
  +4  router_redirect_test.dart     (mevcut dosyaya eklendi)
  +1  run_screen_test.dart          (mevcut dosyaya eklendi)
 -----
 383  FAZ 1 sonu
 +15  wrongs_test.dart
 -----
 398  FAZ 2 sonu
 +16  onboarding_test.dart          (yeniden yazıldı, eskisi yoktu)
 -----
 414  FAZ 3 sonu
```

---

## 8. MİMARİ KURAL DOĞRULAMALARI (her fazda tekrarlandı)

| Kural | Komut | Sonuç |
|---|---|---|
| G4a domain'de Flutter/Drift/Riverpod yok | `grep -rE "import 'package:(flutter\|drift\|flutter_riverpod)" lib/domain/` | **TEMİZ** |
| G4b presentation → data yok | `grep -rn "import '.*data/" lib/presentation/` | **TEMİZ** |
| G3 testlerde `DateTime.now()` yok | `grep -rn "DateTime.now()" test/` | **TEMİZ** (eşleşmeler yorum satırı) |
| G6 pause butonu yok | `grep -rniE "'Duraklat'\|Icons\.pause\|'Durdur'" lib/presentation/` | **TEMİZ** (eşleşme dartdoc) |
| G7 summary/done reklamsız | `grep` reklam anahtarları | **TEMİZ** |
| G8 ders/konu silme yok | `grep -rn "deleteSubject\|deleteTopic" lib/presentation/` | **TEMİZ** |

> AKTARIM §6'daki tuzak doğrulandı: yorum satırları ayıklanmadığında `DateTime.now()`
> ve `Icons.pause` **yanlış alarm** veriyor. Tüm grep'lerde yorumlar ayıklandı.

---

## 9. ⚠️ KOORDİNATÖR KARARI BEKLEYEN SAPMALAR (G12)

Hiçbiri FAZ 4'e engel değil; hepsi geri alınabilir.

### S1 — `SavedResult` üçüncü alan taşıyor: `dateKey`
- **Spec:** `savedResult (NotifierProvider {sessionId, focusScore})`, DoneScreen
  `watchDay(todayKey)` kullanacak
- **Yapılan:** `SavedResult {sessionId, focusScore, dateKey}`; DoneScreen oturumun
  `dateKey`'ini kullanıyor
- **Neden:** `todayKey()` içeride `DateTime.now()` çağırıyor. (a) Widget testi günlük
  ilerlemeyi doğrulayamaz — gerçek bugünü okur, seed edilen gün tutmaz. (b) **G9 ile
  çelişir**: gece 23:50'de başlayıp 00:40'ta biten oturum bittiğinde kullanıcıya
  BAŞKA günün özeti gösterilir
- **Test edildi mi:** Evet (`done_screen_test`, `summary_form_test`)
- **Geri alma maliyeti:** Tek satır

### S2 — `savedResultProvider` `pending_finish_controller.dart` içinde
- **Spec:** Ayrı dosya olarak saymamış
- **Yapılan:** İkisi de aynı akışın state'i olduğu için tek dosyada
- **Test edildi mi:** Evet (dolaylı)

### S3 — G11'deki "335 test" rakamı yanlış
- **Gerçek baseline:** 353 (üç bağımsız kanıt, §1.2)
- **Aksiyon:** Görev tanımı ve kabul eşikleri düzeltilmeli

### S4 — Recovery diyaloğunda **[Kaydet]** pasif bir butonu adlandırıyor
- **Spec:** `needsDecision → [Sil] / [Kaydet]`
- **Sorun:** `needsDecision` geldiğinde kayıt **zaten** `interrupted` olarak yazılmış
  durumda. [Kaydet] yalnızca diyaloğu kapatıyor, hiçbir şey kaydetmiyor
- **Yapılan:** Spec birebir uygulandı (etiket "Kaydet")
- **Öneri:** "Tamam" veya "Koru" daha dürüst olurdu
- **Test edildi mi:** Evet

### S5 — Yanlış kartındaki dört butonun üçü detay sayfasında
- **Spec:** Dördü de kartta (durum ilerlet, not düzenle, sil, "Bu konuyu çalış")
- **Yapılan:** **Durum ilerlet** kartta; not düzenle / sil / "Bu konuyu çalış"
  karta dokununca açılan `wrong_detail_sheet.dart`'ta
- **Neden:** Renk şeridi + iki satır metin + not önizlemesi + dört buton kartı
  okunmaz hale getiriyordu. Ayrıca spec `wrong_detail_sheet.dart`'ı ayrı dosya
  olarak istiyor; içeriği bu
- **Test edildi mi:** Evet, dördü de
- **Not:** Her aksiyon karttan **tek dokunuş** uzakta

### S6 — `/wrongs/add` shell dışında
- **Spec:** "route" diyor, shell içi/dışı belirtmiyor
- **Yapılan:** Kurulum akışıyla aynı desende shell dışında
- **Neden:** Yarım kalmış formda alt navigasyon kullanıcıyı başka sekmeye götürmesin
- **Test edildi mi:** Evet (dolaylı — route açılıyor ve kayıt yapılıyor)

### S7 — Rıza adımında üç ileri yolu var
- **Spec:** [Bildirim izni ver] ve [Atla] tanımlı; izin verildikten sonra ne olacağı
  yazılmamış
- **Yapılan:** İzin butonu **istekte bulunur ve sonucu ekranda gösterir, ilerletmez**;
  kullanıcı sonucu görüp alt bardaki [Devam] ile geçer. [Atla] doğrudan ilerletir
- **Neden:** Test 8 (istek yapıldı), 9 (reddedilse de geçilir) ve 10 (Atla istemez)
  ancak böyle ayrı ayrı doğrulanabiliyor
- **Test edildi mi:** Evet, üçü de

### S8 — Hedef stepper'larına üst sınır da kondu
- **Spec:** Aralık veriyor (60–480, 20–500) ama yalnızca alt sınır testi istiyor
- **Yapılan:** Üst sınır da uygulandı
- **Neden:** Sürdürülemez hedef kullanıcıyı ilk haftada başarısız hissettirir
- **Test edildi mi:** Alt sınır test edildi

### S9 — `summary_screen_test.dart` (5 test) silindi
- **Neden:** İki testi ("yer tutucular mevcut", "KAYDET henüz bağlı değil (iskelet)")
  tam olarak FAZ 1'in bitirdiği durumu doğruluyordu; taşınamazdı
- **Korunanlar:** Kalan üç koruma — boş durum, özet başlığı ve **REKLAM YOK
  regresyon kalkanı** — `summary_form_test.dart`'a aynen taşındı
- **Test zayıflatılmadı**

---

## 10. TEKNİK NOTLAR (gelecek fazları ilgilendirir)

### 10.1 `testWidgets` içinde Drift akışı beklemek KİLİTLENİYOR

```dart
// YAPMA — süreç sessizce takılır, hata bile vermez:
final stat = await db.statsDao.watchDay(key).first;

// YAP — Future tabanlı sorgu:
final stat = await db.statsDao.summaryFor(day, day);
final rows = await db.select(db.wrongItems).get();
```

`testWidgets` sahte zaman bölgesinde çalışıyor; akışın ilk değerini beklemek
deadlock üretiyor. **İki kez bu yüzden test süreci dondu** (summary_form,
recovery_gate). Provider akışlarını `pumpWidget` ÖNCESİNDE ısıtmak sorunsuz:

```dart
await container.read(wrongItemsProvider(status).future);
await container.read(subjectsProvider.future);
```

### 10.2 `DbHealthPage` widget testinde render edilemiyor

Açtığı Drift akışları widget ağacı yıkıldıktan sonra da askıda timer bırakıyor;
test çerçevesi bunu hata sayıyor (`A Timer is still pending...`). K3/D4 testi bu
yüzden ekranı **render etmeden** hangi ekranın seçildiğini doğruluyor.

### 10.3 Uzun form ekranlarında test yüzeyi

Varsayılan 800×600 yüzeyde KAYDET/Devam butonları görünür alanın dışında kalıp
dokunuşlar hedefe ulaşmıyor. Etkilenen testlerde yüzey yükseltildi
(`tester.view.physicalSize`), böylece `ListView` sanallaştırma tuzağına da
düşülmüyor.

### 10.4 Sayaç artırma testlerinde ara `pump` zorunlu

`onPressed` kapanışı son çizilen değeri yakalar; ara `pump` olmadan N dokunuş
değeri 1 yapar. Tüm stepper testlerinde her dokunuştan sonra `pump` var.

---

## 11. AÇIK KALANLAR

### Acil (koordinatör)
1. **Push yetkisi** — §2. Tek gerçek engel
2. **335 → 353 düzeltmesi** — görev tanımı ve kabul eşikleri
3. **S1–S9 kararları** — §9

### Sonraki fazlar (plana göre)
- **FAZ 4** — Reklam katmanı: `AdGateway`, `AdPolicyEngine` (saf), `AdMobGateway`,
  `ad_event_dao`, slot widget'ları, gerçek UMP. Hedef test ≥ 385 (şu an zaten 414)
- **FAZ 5** — Ana panel, istatistik, takvim, ayarlar, hedefler, `StreakCalculator`,
  `RecomputeNetsUseCase`, CSV dışa aktarma. Hedef test ≥ 410 (şu an zaten 414 —
  **eşik güncellenmeli**)
- **FAZ 6** — i18n altyapısı, AndroidManifest izinleri + desugaring, boot receiver,
  launcher ikon, PRIVACY.md, release APK smoke

### AKTARIM'dan devralınan, hâlâ açık teknik borç
- `user_settings.currentStreak / longestStreak / lastStudyDate` — üç kolon var,
  yazan kod yok (FAZ 5'te `StreakCalculator` ile gelecek)
- `achievements` tablosu — yazan kod yok
- `goals.currentValue` otomatik güncellenmiyor
- 50 adet `info` seviyesi lint (`require_trailing_commas`, `prefer_const_*`) —
  devralınan 52'nin altında; **yeni lint eklenmedi**. `dart fix --apply` ile
  çoğu düzelir, diff'i büyütmemek için çalıştırılmadı
- **Uygulama gerçek cihazda hiç çalıştırılmadı** — tüm doğrulama host testleriyle.
  FAZ 6.5 cihaz kontrol listesi bunu kapatacak

---

## 12. ÖZET TABLO — KOORDİNATÖRE

| Konu | Durum |
|---|---|
| FAZ 0 | ✅ (push hariç) |
| FAZ 1 | ✅ |
| FAZ 2 | ✅ |
| FAZ 3 | ✅ |
| `flutter analyze` | ✅ 0 error / 0 warning / 50 info |
| `flutter test` | ✅ **414/414** |
| Mimari kurallar (G3/G4/G6/G7/G8) | ✅ grep'le doğrulandı |
| `git push` | ❌ **403 — yetki gerekiyor** |
| Karar bekleyen sapma | ⚠️ **9 madde (§9)** |
