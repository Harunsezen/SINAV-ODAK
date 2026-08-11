# RELEASE İMZALAMA — EK RAPOR

**Tarih:** 11 Ağustos 2026
**Kapsam:** son kod dokunuşu (imzalama yapılandırması + belge)
**Durum:** TAMAM

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **698 / 698** (eşik ≥698 — değişmedi) |
| **analyze** | **No issues found!** — 0 / 0 / 0 |
| **pub get** | Got dependencies! |
| **build_runner** | `Succeeded` (0 aksiyon — Dart tarafı değişmedi) |

Dart kodu bu turda **hiç değişmedi**; dokunulan yerler `build.gradle`,
`.gitignore` ve `README.md`.

---

## 2. YAPILAN İŞ

### (1) `signingConfigs.release` — key.properties'den okuma

`android/app/build.gradle`:

```groovy
def keystorePropertiesFile = rootProject.file("key.properties")
def keystoreProperties = new Properties()
def hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.withInputStream { keystoreProperties.load(it) }
}
```

```groovy
signingConfigs {
    release {
        if (hasReleaseKeystore) {
            storeFile = file(keystoreProperties["storeFile"])
            storePassword = keystoreProperties["storePassword"]
            keyAlias = keystoreProperties["keyAlias"]
            keyPassword = keystoreProperties["keyPassword"]
        }
    }
}

buildTypes {
    release {
        signingConfig = hasReleaseKeystore
            ? signingConfigs.release
            : signingConfigs.debug
        ...
    }
}
```

**Karar — alanlar yalnızca dosya varsa dolduruluyor.** Koşulsuz atama
yapılsaydı `storeFile = file(null)` Gradle'ı yapılandırma aşamasında
düşürürdü; keystore'u olmayan geliştirici projeyi hiç derleyemezdi.

**Karar — düşüş SESSİZ değil.** `key.properties` yokken Gradle şu uyarıyı
basıyor:

```
UYARI: android/key.properties yok — release derlemesi DEBUG anahtarıyla
imzalanıyor. Bu çıktı Play Store'a YÜKLENEMEZ.
```

Uyarı olmasaydı hata ancak Play Console'a yükleme anında görülürdü — yani
tam derleme + yükleme turu boşa giderdi.

### (2) Sırlar `.gitignore`'da

`android/.gitignore` bunları zaten dışlıyordu (Flutter şablonundan):
`key.properties`, `**/*.keystore`, `**/*.jks`.

Buna ek olarak **kök `.gitignore`'a güvenlik ağı** eklendi: keystore proje
kökünde veya başka bir klasörde tutulursa da yakalansın.

Doğrulama (`git check-ignore`):

```
key.properties                   YOK SAYILIYOR ✓
android/key.properties           YOK SAYILIYOR ✓
test.keystore                    YOK SAYILIYOR ✓
android/app/upload.jks           YOK SAYILIYOR ✓
```

### (3) README > "Release imzalama"

`README.md` → *FAZ 6 — Production derleme* altına **§2 Release imzalama**
bölümü eklendi:

- `keytool -genkey` komutu (`-validity 10000`, alias `upload`)
- `key.properties` örneği + dosyanın yeri (`android/`) ve `storeFile`'ın
  **mutlak yol** olması gerektiği
- Düşüş davranışının açıklaması ve uyarı metni
- **`flutter build appbundle --release`** — Play **AAB** ister, APK değil;
  APK yalnızca elden dağıtım/cihaz denemesi için
- Production AdMob `--dart-define` + `-Padmob_app_id` komutu (her iki kanal
  da gerekli)
- Keystore'u kaybetme/paylaşma uyarısı: Play imza anahtarının
  değiştirilmesine izin vermiyor

Ayrıca yayın öncesi kontrol listesindeki "imzalama yapılandırması tanımlı"
maddesi, artık **çözülmüş** olduğu için "key.properties oluşturuldu ve
derlemede uyarı çıkmıyor" ile değiştirildi.

---

## 3. DOĞRULAMA

### 3.1 Dört komut

```
$ flutter pub get                → Got dependencies!
$ dart run build_runner build …  → Succeeded (0 outputs — Dart değişmedi)
$ flutter analyze                → No issues found!   (0 error/warning/info)
$ flutter test                   → +698: All tests passed!   (EXIT=0)
```

### 3.2 Gradle mantığı GERÇEKTEN çalıştırıldı

Bu ortamda Android SDK yok (S17), yani `flutter build appbundle`
**denenemiyor**. Bunun yerine imzalama mantığı ortamdaki gerçek Groovy ile
(`/opt/gradle/lib/groovy-3.0.24.jar`) iki senaryoda çalıştırıldı:

```
OK  key.properties yok  -> imza: debug
OK  key.properties var  -> imza: release, alias: upload
TUM KONTROLLER GECTI
```

İkinci senaryoda dört alanın (`storeFile`, `storePassword`, `keyAlias`,
`keyPassword`) da doğru okunduğu tek tek doğrulandı.

Ayrıca `build.gradle`'ın kendisi Groovy derleyicisiyle **AST aşamasına kadar
parse edildi**:

```
PARSE OK: build.gradle (110 satir)
```

**Bunun kanıtlamadığı şey — dürüstlük notu:** parse + mantık testi, sözdizimi
ve dallanmanın doğruluğunu gösterir; **Android Gradle Plugin'in bu
yapılandırmayı kabul ettiğini ve gerçekten imzalı bir AAB ürettiğini
GÖSTERMEZ.** Bu, ancak SDK'lı bir makinede `flutter build appbundle
--release` çalıştırılarak doğrulanabilir. S17 açık kaldığı sürece bu adım
sende.

**Senin tarafında ilk derlemede bakılacaklar:**
1. `key.properties` yokken derle → uyarı **çıkmalı**
2. `key.properties` varken derle → uyarı **çıkmamalı**
3. `keytool -printcert -jarfile app-release.aab` ile imzanın kendi
   anahtarın olduğunu doğrula (alias `upload`, debug değil)

---

## 4. KORUMA GREP'LERİ

Dart kodu değişmediği için G3–G8 + G12 sonuçları FAZ 7B ile **aynı**
(hepsi 0; G6'nın tek eşleşmesi `promise_step.dart`'taki arayüz metni).

G12 açısından ek not: imzalama sırları koda **girmedi**, `key.properties`
üzerinden okunuyor ve dosya `.gitignore`'da.

---

## 5. SAPMALAR

Yeni sapma **yok**.

| # | Durum |
| --- | --- |
| S15 | Kısmen açık — eski ekranların i18n'i (talimat gereği dokunulmadı) |
| S16 | Açık — `app_en.arb` değerleri TR; çeviri v1.2 |
| S17 | **Açık** — Android SDK yok; AAB/APK derlemesi ve imzanın uçtan uca doğrulanması bu ortamda yapılamıyor |

---

## 6. YAYINA KALAN (kod değil, kurulum)

1. ~~Release imzalama yapılandırması~~ ✅ **bu turda tamamlandı**
2. **Keystore üret** + `android/key.properties` yaz (§2.1–2.2)
3. **AAB derle**: `flutter build appbundle --release` + AdMob define'ları
4. **Cihaz duman testi** — `FAZ_06_RAPORU.md` §7 listesi
5. **Play Console** — `PRIVACY.md` yayımla, *Data safety* formu, hedef kitle 13+
6. **İngilizce çeviri** (S16) — v1.2
