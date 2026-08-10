# FAZ 6 — PRODUCTION HAZIRLIK · İŞÇİ RAPORU

**Tarih:** 10 Ağustos 2026
**Faz:** 6 (production hazırlık)
**Durum:** a–f TAMAM · **g (release APK) YAPILAMADI** — gerekçe §7

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **541 / 541 geçti** (eşik ≥524 — **+17**) |
| **analyze** | **0 error · 0 warning · 37 info** |
| **build_runner** | 262 çıktı, 1188 aksiyon, hatasız |
| **G3–G8 + G12 koruma grep'leri** | tamamı temiz |
| **Release APK** | ❌ **N/A** — Android SDK yok ve kurulamıyor (§7) |

FAZ 5 sonundaki 524 testin **hiçbiri düşmedi**; 17 test eklendi.

---

## 2. YAPILAN İŞ (kapsam a–g)

### (a) Gerçek UMP SDK'sı ✅

Rıza artık uygulama içi bir toggle'dan ibaret değil; Google'ın resmî
**UMP (User Messaging Platform)** akışı devrede.

**Yeni dosyalar**

| Dosya | Rol |
| --- | --- |
| `lib/domain/entities/consent_state.dart` | `ConsentState` + `ConsentResult` — UMP durumunun **saf Dart** karşılığı |
| `lib/domain/ports/consent_gateway.dart` | `ConsentGateway` port'u (`gather` / `current` / `showPrivacyOptions` / `reset`) |
| `lib/services/ads/ump_consent_gateway.dart` | Gerçek UMP adaptörü |
| `lib/services/ads/noop_consent_gateway.dart` | Varsayılan (UMP'siz) adaptör |

**Neden domain'de ayrı bir enum var:** `domain/` katmanı `google_mobile_ads`
paketini **import edemez** (G4). UMP durumu karar mekanizmasına giriyorsa
domain'de kendi tipi olmak zorundaydı; adaptör çeviriyi yapıyor.

**Karar — rıza İKİ KAPILI (`adConsentProvider`)**

```dart
final adConsentProvider = Provider<bool>((ref) {
  final stored = ref.watch(settingsStreamProvider)
      .valueOrNull?.personalizedAdsConsent ?? false;
  return stored && ref.watch(consentResultProvider).canRequestAds;
});
```

- **UMP yalnızca KISITLAYABİLİR.** "Hayır" derse kullanıcı tercihi ne olursa
  olsun reklam yok.
- **Tersi geçerli değil.** UMP "evet" dese bile uygulama içi tercih kapalıysa
  reklam yok — UMP'nin onayı kullanıcı adına rıza vermek değildir.
- Bu tasarım sayesinde FAZ 4'ün **524 reklam testinin hiçbiri değişmedi**:
  UMP bir kısıt ekliyor, mevcut davranışı yeniden yazmıyor.

**Karar — hata hâlinde KAPALI (fail-closed).** Ağ yoksa, form yüklenemezse,
SDK hata verirse veya **8 sn** zaman aşımı olursa sonuç
`ConsentResult.unavailable` → `canRequestAds: false` → reklamsız devam.
Hata durumunda "izin var" saymak rızasız reklam göstermek olurdu.

**`main.dart` bağlantısı** — UMP, **ilk reklam isteğinden ÖNCE** çalışır
(Google'ın kuralı; sonradan sorup arada reklam istemek ihlal):

```dart
final consentGateway = UmpConsentGateway();
final consent = await consentGateway.gather();   // en fazla 8 sn
runApp(ProviderScope(overrides: [
  consentGatewayProvider.overrideWithValue(consentGateway),
  consentBootResultProvider.overrideWithValue(consent),
  adGatewayProvider.overrideWith(_buildAdGateway),   // ← gerçek AdMob
  ...
]));
```

> **Not:** `adGatewayProvider`'ın gerçek `AdMobGateway` ile bağlanması bu
> fazda yapıldı. FAZ 4'te sınıf yazılmıştı ama `main()` hâlâ `NoopAdGateway`
> kullanıyordu — yani **uygulama aslında hiç reklam göstermiyordu.** Bu
> rapor edilmesi gereken bir eksikti, kapatıldı.

**Rıza geri alınabilir (KVKK/GDPR zorunluluğu).** Ayarlar → *Gizlilik
tercihleri* UMP formunu yeniden açar. Sonuç `consentResultOverrideProvider`
üzerinden anında geçerli olur; kullanıcı reddederse reklam **o an** durur.
Kart yalnızca `privacyOptionsRequired == true` bölgelerde görünür — aksi
halde hiçbir şey açmayan ölü bir düğme olurdu.

**Test:** `test/unit/consent_gate_test.dart` — **17 test**.
`UmpConsentGateway`'in kendisi test edilmiyor (platform kanalı gerekiyor,
`flutter test` içinde çağrı hiç tamamlanmıyor); test edilen, ürünün asıl
kuralı: **UMP sonucu reklam kararına nasıl giriyor.** Sahte gateway
(`FakeConsentGateway`) ile 4 kombinasyonun tamamı + hata hâli + geri alma +
yer politikasıyla etkileşim kapsandı.

### (b) Production AdMob kimlikleri ✅

`lib/core/config/ad_config.dart` — tüm kimlikler `String.fromEnvironment`,
**varsayılan Google TEST kimlikleri**.

İki yerden geçilir, **ikisi de gerekir**:

| Kanal | Nereye gider |
| --- | --- |
| `--dart-define=ADMOB_*` | `AdConfig` (Dart; birim kimlikleri) |
| `-Padmob_app_id=...` | `manifestPlaceholders["admobAppId"]` → `AndroidManifest.xml` |

Tam komut `README.md` → *FAZ 6 — Production derleme* bölümünde.

**Karar — varsayılan neden TEST:** unutulursa gelir kaybedilir; tersi
(production kimliğiyle geliştirme + kendi reklamına tıklama) **AdMob
hesabını kapattırır**. Güvenli taraf açıktır.
`AdConfig.usingTestIds` ile release'te doğrulanabilir.

### (c) Android izinleri / desugaring / boot receiver ✅

`AndroidManifest.xml`:
`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`,
`RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`
\+ `ScheduledNotificationBootReceiver` (`BOOT_COMPLETED`,
`MY_PACKAGE_REPLACED`, `QUICKBOOT_POWERON`) ve `ScheduledNotificationReceiver`.

`android/app/build.gradle`:
`coreLibraryDesugaringEnabled = true`, `desugar_jdk_libs:2.1.2`,
`minSdk = 21`, `manifestPlaceholders["admobAppId"]`.

Boot receiver olmadan cihaz yeniden başladığında **planlanmış mola/oturum
bildirimleri sessizce kayboluyordu.**

### (d) Uygulama ikonu + adı ✅

- `android:label="Sınav Odak"`
- Yeni ikon: marka indigosu (`#4F5BD5`) üzerinde beyaz **kronometre**
  (kapalı kadran + kurma düğmesi + akrep).
- **Android:** 5 yoğunlukta `ic_launcher.png` (48→192) + 5 yoğunlukta
  `ic_launcher_foreground.png` (108→432) + `mipmap-anydpi-v26/ic_launcher.xml`
  (uyarlanabilir ikon) + `values/ic_launcher_background.xml`.
- **iOS:** `AppIcon.appiconset` içindeki 15 boyutun tamamı yenilendi
  (saydamlık yok — App Store kuralı).
- **Mağaza:** `assets/icon/icon.png` (512×512).

> İkon, ortamda görüntü kütüphanesi (PIL vb.) olmadığı için **saf stdlib
> PNG kodlayıcıyla** üretildi (4× supersampling ile kenar yumuşatma).
> İlk deneme kapalı olmayan halka yüzünden **güç düğmesi** gibi okunuyordu;
> kadran kapatılıp akrep eğildi ve kurma düğmesi eklendi.

### (e) i18n (gen_l10n) ✅

`l10n.yaml` + `lib/l10n/app_tr.arb` (**39 anahtar**) + `app_en.arb` (iskelet).
`L10n` sınıfı üretiliyor; `app.dart` delegeleri bağlıyor.

**Uygulama Türkçe'ye SABİT** (`locale: Locale('tr')`). `app_en.arb` şu an
Türkçe değerleri taşıyor — **İngilizce çeviri v1.2'ye bırakıldı** (K8).
Altyapı hazır, çeviri işi ayrı.

Metinler `L10n.of(context)`'ten okunan ekranlar: `app_shell.dart`,
`banner_ad_slot.dart`, `native_ad_slot.dart`. Geri kalan ekranların
metinleri hâlâ gömülü — **ARB'ye taşınmaları v1.2 işi** (sapma S15, §8).

### (f) PRIVACY.md ✅

`PRIVACY.md` — 10 bölüm:
özet · cihazda işlenen veriler · **AdMob'un işlediği veriler** · rıza
mekanizması (UMP + iki kapı + geri alma) · izin gerekçeleri tablosu ·
çocukların gizliliği · analitik YOK beyanı · saklama süreleri · KVKK m.11 /
GDPR m.15–22 hakları · **Play Console *Data safety* formu için doldurulmuş
cevap tablosu**.

### (g) Release APK ❌ — **YAPILAMADI**, bkz. §7

---

## 3. DOĞRULAMA — 4 KOMUT

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 30.1s with 262 outputs (1188 actions)

$ flutter analyze
77 issues found.        ← dart fix + dart format ÖNCESİ
37 issues found.        ← SONRASI
error: 0 · warning: 0 · info: 37

$ flutter test
00:40 +541: All tests passed!
```

**Severity sayımı** (yorum satırı tuzağına düşmeyen desen, §11.5):

```
$ for s in error warning info; do
    printf "%s: %s\n" "$s" "$(grep -cE "(^|[[:space:]])$s •" analyze.txt)"
  done
error: 0
warning: 0
info: 37
```

Kalan 37 info'nun tamamı stil (`require_trailing_commas`,
`prefer_const_constructors`, DAO'lardaki `unnecessary_import`); **hiçbiri
davranış değiştirmiyor.** `dart fix --apply` 35 dosyada 70 düzeltme yaptı,
`dart format` 148 dosyanın 75'ini biçimlendirdi — bunlar FAZ 6'da eklenen
L10n delege satırlarının bıraktığı biçim borcunu da kapattı.

---

## 4. TEST SAYISI

| Faz sonu | Test |
| --- | --- |
| FAZ 5 | 524 |
| **FAZ 6** | **541** (+17) |

Eklenen 17 test: `test/unit/consent_gate_test.dart`.

**Ara olay — 17 test kırıldı ve düzeltildi.** `L10n` delegeleri `app.dart`'a
bağlandığında test koşumu `507 +17 -17`'ye düştü: test harness'ları
`MaterialApp`'i delegesiz kuruyordu (`router_redirect_test` 7,
`session_setup_flow_test` 5, `ad_slots_test` 4, `home_screen_test` 1).
14 test dosyasına `localizationsDelegates: L10n.localizationsDelegates` +
`supportedLocales: L10n.supportedLocales` eklendi. **Test zayıflatılmadı**,
eksik olan kurulum tamamlandı.

---

## 5. KORUMA GREP'LERİ (G3–G8, G12)

| Guard | Sonuç |
| --- | --- |
| G3 testlerde `DateTime.now()` yok | ✅ 0 |
| G4a domain'de Flutter/Drift/Riverpod importu yok | ✅ 0 |
| G4b presentation → data importu yok | ✅ 0 |
| G5 run katmanında `Timer` yok | ✅ 0 |
| G6 pause yok | ✅ 0 (aşağıya bak) |
| G7 summary/done ekranında reklam yok | ✅ 0 |
| G8 ders/konu silme yok | ✅ 0 |
| G12 `lib/` içinde production reklam kimliği yok | ✅ 0 |

**Bu turda bulunan grep hatası (dürüstlük notu).** İlk koşumda G3=12, G5=1,
G6=5, G7=3, G12=5 çıktı. Sebep bendeydi: yorum satırlarını eleyen filtre
`^\s*//` deseniyle yazılmıştı, oysa `grep -rn` çıktısı **`dosya:satır:`
önekiyle** başlıyor — desen hiçbir zaman eşleşmiyordu ve **hiçbir yorum
elenmiyordu**. Doğru desen:

```bash
strip() { grep -vE "^[^:]*:[0-9]+:[[:space:]]*(///|//|\*|/\*)"; }
```

Düzeltilince tüm sayımlar sıfırlandı. **"Grep temiz" demeden önce eşleşen
satırları tek tek okumak şart** — bu, §11.5'teki yorum tuzağının ikinci
kez farklı kılıkta karşıma çıkmasıydı.

**İki kalan eşleşme, ihlal DEĞİL:**

1. **G6** → `promise_step.dart:35`:
   `'Sayaç duraklatılamaz: başladığın bloğu bitirirsin.'`
   Bu, kuralın **kullanıcıya anlatıldığı arayüz metni** — tam tersi.
2. **G7** → `done_screen.dart` `interstitialController` çağrısı.
   Ara reklam tebrik ekranının **ÜZERİNDE** değil, **Ana panel'e GEÇİŞTE**
   tetikleniyor (FAZ 4 tasarımı). `interstitial_test.dart` bunu açıkça
   doğruluyor: *"tebrik ekranının KENDİSİNDE reklam yok (G7)"* testi ekran
   açılışında `loadedBanners`, `loadedNatives` ve `shownInterstitials`
   listelerinin **boş** olduğunu iddia ediyor.

---

## 6. YENİ / DEĞİŞEN DOSYALAR

**Yeni**

```
PRIVACY.md
l10n.yaml
assets/icon/icon.png
lib/core/config/ad_config.dart
lib/domain/entities/consent_state.dart
lib/domain/ports/consent_gateway.dart
lib/services/ads/ump_consent_gateway.dart
lib/services/ads/noop_consent_gateway.dart
lib/l10n/app_tr.arb · lib/l10n/app_en.arb
test/unit/consent_gate_test.dart
android/.../mipmap-anydpi-v26/ic_launcher.xml
android/.../values/ic_launcher_background.xml
android/.../mipmap-*/ic_launcher_foreground.png   (5 yoğunluk)
```

**Değişen (öne çıkanlar)**

```
lib/main.dart                       UMP + gerçek AdMob bağlandı
lib/core/di/ad_providers.dart       consentBoot/Override/Result + iki kapılı rıza
lib/app.dart                        L10n delegeleri, locale tr
lib/presentation/settings/settings_screen.dart   Gizlilik tercihleri kartı
android/app/build.gradle            desugaring, minSdk 21, admobAppId
android/app/src/main/AndroidManifest.xml         izinler, label, receiver'lar
README.md                           production derleme bölümü
android/.../mipmap-*/ic_launcher.png  · ios/.../AppIcon.appiconset/*.png
```

Toplam 124 yol değişti (çoğu `dart format` ve üretilmiş `*.g.dart`).

---

## 7. RELEASE APK — YAPILAMADI (kanıtlı)

**APK üretilmedi. Bu bir eksiklik olarak raporlanıyor, "bitti" denmiyor.**

Kanıt zinciri:

```
$ echo "$ANDROID_HOME / $ANDROID_SDK_ROOT"
 /                                     ← ikisi de boş

$ flutter doctor
[✗] Android toolchain - develop for Android devices
    ✗ Unable to locate Android SDK.

$ flutter build apk --release
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
EXIT=1

$ curl -r 0-1000 https://dl.google.com/android/repository/commandlinetools-linux-*.zip
curl: (56) CONNECT tunnel failed, response 403
```

**Kök neden:** bu ortamda Android SDK kurulu değil ve `dl.google.com`
çıkış proxy'si tarafından **403** ile engellendiği için **kurulamıyor da**.

**Disk sorunu DEĞİL:** 28 GB boş (`df`: 252G toplam, 11G kullanılmış).
Engel tamamen ağ politikası.

**Yan bulgu:** ortamda Java **21** var; `android/app/build.gradle` mevcut
Gradle sürümüyle Java 17 bekliyor. SDK gelse bile bu ayrıca çözülecekti.

### APK'yı SEN nasıl alırsın

Android Studio kurulu bir makinede, ZIP'i açtıktan sonra:

```bash
cd sinav_odak
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release \
  --dart-define=ADMOB_APP_ID=... --dart-define=ADMOB_BANNER_UNIT=... \
  --dart-define=ADMOB_NATIVE_UNIT=... --dart-define=ADMOB_INTERSTITIAL_UNIT=... \
  --dart-define=ADMOB_REWARDED_UNIT=... \
  -Padmob_app_id=...
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

Kimlikleri vermezsen **test reklamları** ile derlenir — geliştirme için
doğrusu budur.

### CİHAZ DUMAN TESTİ (smoke checklist)

APK'yı kurduktan sonra sırayla:

**Açılış ve onboarding**
- [ ] Uygulama ikonu **kronometre** olarak görünüyor, adı **Sınav Odak**
- [ ] 5 adımlık onboarding açılıyor; reklam rızası **varsayılan KAPALI**
- [ ] Onboarding bitince ana panele düşüyor, tekrar açılışta **görünmüyor**

**Oturum akışı (asıl ürün)**
- [ ] Ders → konu → tür → plan → **BAŞLAT** akışı sonuna kadar gidiyor
- [ ] Sayaç **doğru** ilerliyor; **pause butonu YOK**
- [ ] Uygulamayı arka plana alıp 2 dk sonra dön: **sayaç kaymamış**
  (mutlak çizelge doğrulaması — en kritik madde)
- [ ] Uçak modunda oturum sorunsuz başlıyor/bitiyor
- [ ] Mola ekranı açılıyor, mola atlanabiliyor
- [ ] Oturum sonu formu: net/yanlış girilebiliyor, **KAYDET** çalışıyor
- [ ] Tebrik ekranında odak puanı ve günlük ilerleme doğru
- [ ] Oturum ortasında uygulamayı **öldür** ve yeniden aç:
      kurtarma diyaloğu çıkıyor, **Kaydet** ve **Sil** ikisi de doğru davranıyor
- [ ] Cihaz saatini geri al → "saat değişmiş" uyarısı çıkıyor

**Bildirimler**
- [ ] Android 13+ ilk açılışta bildirim izni soruluyor
- [ ] Mola bitiş bildirimi **tam zamanında** düşüyor (ekran kapalıyken de)
- [ ] **Cihazı yeniden başlat** → planlı bildirim hâlâ düşüyor (boot receiver)

**Reklamlar**
- [ ] Rıza KAPALIYKEN: **hiçbir yerde** reklam yok, Ayarlar'daki
      "İzle ve destekle" **pasif**
- [ ] Rıza AÇIKKEN: ana panel/istatistik banner'ı görünüyor
- [ ] **Çalışma bloğu sırasında tam ekran reklam ASLA çıkmıyor** (G7)
- [ ] Tebrik → Ana panel geçişinde ara reklam çıkıyor; **90 sn** içinde
      ikinci kez çıkmıyor
- [ ] Reklam yüklenemezken (uçak modu) **akış hiç beklemiyor**
- [ ] AEA/UK SIM veya VPN ile: **UMP formu ilk açılışta** çıkıyor
- [ ] UMP'de "reddet" → reklam **tamamen** duruyor
- [ ] Ayarlar → **Gizlilik tercihleri** formu yeniden açıyor, karar anında geçerli

**Yayın öncesi**
- [ ] `AdConfig.usingTestIds == false`
- [ ] `signingConfigs.release` tanımlı (şu an **debug anahtarı** kullanılıyor)
- [ ] `PRIVACY.md` bir URL'de yayımlandı ve Play Console'a girildi
- [ ] *Data safety* formu `PRIVACY.md` §10 tablosuna göre dolduruldu
- [ ] Hedef kitle **13+**

---

## 8. SAPMALAR

S1–S14 koordinatör tarafından **onaylandı ve kapatıldı**. Bu turda **3 yeni**:

| # | Sapma | Neden | Etki |
| --- | --- | --- | --- |
| **S15** | i18n yalnızca 3 ekranda uygulandı; kalan metinler gömülü | Altyapı (l10n.yaml + ARB + delegeler) kuruldu, 39 anahtar tanımlandı; tüm ekranların ARB'ye taşınması FAZ 6 bütçesini aşıyordu | Yok — uygulama Türkçe'ye sabit, kullanıcı fark etmez. v1.2 işi |
| **S16** | `app_en.arb` Türkçe değerler taşıyor | İngilizce çeviri ayrı bir iş; iskeletin boş olması `flutter gen-l10n`'u kırardı | Yok — `supportedLocales`'e `en` girse de locale `tr`'ye sabit |
| **S17** | **Release APK üretilemedi** | Android SDK yok + `dl.google.com` proxy'de 403 | **Var** — teslimin bir kalemi eksik. §7'de tam kanıt ve senin tarafında çalıştırma yolu |

**Ayrıca düzeltilen, daha önce raporlanmamış bir eksik:** `main.dart`
`adGatewayProvider`'ı override etmiyordu; FAZ 4'ün `AdMobGateway`'i yazılmış
ama **hiç bağlanmamıştı** — uygulama gerçekte reklamsız çalışıyordu. Bu
fazda bağlandı.

---

## 9. GİT

Koordinatör kararı gereği **git kullanılmadı** (push denenmedi, bundle
üretilmedi, GitHub'a bağlanılmadı). Teslim bu rapor + ZIP.

---

## 10. SONRAKİ TUR İÇİN AÇIK MADDELER

1. **Release imzalama** — `signingConfigs.release` + keystore (yayın için ŞART)
2. **Kalan ekranların i18n'i** ve gerçek İngilizce çeviri (S15/S16)
3. **Ayarlar ekranının tamamı** — tema, net katsayısı, hedefler, ders/konu
   yönetimi, veri sıfırlama (şu an `settings-placeholder` kartı duruyor)
4. **Java 17 / Gradle uyumu** — APK derleyecek makinede kontrol edilmeli
5. **Cihazda duman testi** — §7'deki liste; özellikle **arka plandan dönüşte
   sayaç kayması** ve **boot sonrası bildirim** maddeleri
