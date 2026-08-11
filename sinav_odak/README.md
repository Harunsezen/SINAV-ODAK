# Sınav Odak

Sınava hazırlanan öğrenciler için %100 ücretsiz, offline-first çalışma takip
uygulaması. Gelir yalnızca reklamdan; çalışma sırasında tam ekran reklam yok.

**Bu klasör: Adım 1 (iskelet) + Adım 2 (veritabanı) tamamlandı.**

---

## Kurulum

Bu depo yalnızca `lib/`, `test/` ve yapılandırma dosyalarını içerir.
Platform klasörlerini (android/ ios/) Flutter'ın kendisi üretmeli:

```bash
cd sinav_odak

# 1) Platform klasörlerini üret (mevcut pubspec.yaml KORUNUR)
flutter create --org com.harunsezen --project-name sinav_odak \
  --platforms=android,ios .

# 2) Paketleri çek
flutter pub get

# 3) Drift/Riverpod kod üretimi  (*.g.dart dosyaları burada oluşur)
dart run build_runner build --delete-conflicting-outputs

# 4) Çalıştır
flutter run
```

> `flutter create` pubspec.yaml'ı ezmeye çalışırsa dosyayı yedekle ve geri koy.
> `*.g.dart` dosyaları `.gitignore`'da; her `git clone` sonrası 3. adım şart.

## Doğrulama

Uygulama açıldığında **Ayarlar** sekmesine git. Görmen gerekenler:

- Ayar satırı: OK · net katsayısı 4.0 · hedef 240 dk
- YKS dersleri: 15 kayıt
- Çalışma türleri: 11 kayıt

Testler:

```bash
flutter test
```

> Testler `NativeDatabase.memory()` kullanır. Linux'ta genelde sorunsuz;
> Windows'ta sistemde `sqlite3.dll` yoksa `sqlite3_flutter_libs` yerine
> host için sqlite3 kurmak gerekebilir.

---

## Mimari kararlar (kısa)

| Konu | Karar | Gerekçe |
|---|---|---|
| Zamanlayıcı | Mutlak zaman damgalı çizelge + `resolve(now)` | iOS arka planda kod çalıştırmaz; `Timer` güvenilir değil |
| WorkManager | **Kullanılmıyor** | Periyodu ≥15 dk ve "inexact"; blok bitişi kayar |
| Zaman formatı | epoch **milisaniye** INTEGER | Drift'in DateTime dönüşümü saniye çözünürlüğünde |
| Şifreleme | **Yok** (SQLCipher/AES kapsam dışı) | Çalışma süresi/soru verisi için aşırı mühendislik |
| VERBIS | **Gerekmiyor** | Tek geliştirici, eşik altı, özel nitelikli veri yok, veri cihazda |
| Hedef yaş | Play Console **13+** | Families politikası kişiselleştirilmiş reklamı kapatır, eCPM düşer |
| Ders silme | Yok, **arşivleme** var | Silinen ders geçmiş istatistikleri bozar |
| İkon | `iconKey` TEXT | Sabit olmayan `IconData`, `--tree-shake-icons` derlemesini kırar |
| Pre-start interstitial | **Kaldırıldı** | AdMob'da interstitial atlanamaz; en yüksek niyetli anı bozar |

## Veritabanı şeması (v1)

```
user_settings (tek satır, id='me')
subjects ──< topics
activity_types
study_sessions ──< session_blocks
study_sessions ──> subjects / topics / activity_types
daily_stats            (denormalize günlük özet)
wrong_items            (YANLIŞ DEFTERİ) ──> subjects / topics / study_sessions
goals · achievements · ad_events · app_state
```

`wrong_items.status`: `active` → `reviewed` → `mastered`
`wrong_items.source`: `auto` (oturum sonu wrong_count>0) | `manual`

## Sonraki adımlar

3. Domain saf servisler: `ScheduleBuilder`, `ScheduleResolver`,
   `FocusScoreCalculator`, `NetCalculator` (+ %95 test kapsamı)
4. Run akışı: session start, inBlock, inBreak, recovery, lifecycle
5. Oturum sonu formu + `wrong_items` kaydı
6. Reklam katmanı: `AdGateway`, `AdPolicyEngine`, widget'lar
7. Ana panel, istatistik, yanlışlar, takvim, ayarlar ekranları

---

## Denetim sonrası uygulanan düzeltmeler (Adım 2.1)

`sinav_odak_audit_raporu.md` içindeki 7 P0 bulgusunun tamamı ve 6 P1/P2 bulgusu koda işlendi.

| ID | Düzeltme | Dosya |
|---|---|---|
| P0-01 | `SessionRepository` eklendi; `recomputeDay` artık save/delete/interrupt akışlarında çağrılıyor | `data/repositories/session_repository.dart` (yeni) |
| P0-02 | `Topics.isArchived` eklendi, `deleteTopic` → `archiveTopic`; FK'lere `restrict`/`setNull` | `tables/*`, `daos/subject_dao.dart` |
| P0-03 | `RecoveryService` eklendi, `main()` açılışta çağırıyor | `domain/services/recovery_service.dart` (yeni) |
| P0-04 | `sqlite3` doğrudan bağımlılık olarak eklendi | `pubspec.yaml` |
| P0-05 | `google_mobile_ads` Adım 6'ya kadar yorum satırında (manifest App ID olmadan açılışta çökertiyordu) | `pubspec.yaml` |
| P0-06 | Seed `insertOrIgnore` ile idempotent; health check üç tabloyu kontrol ediyor | `seed_data.dart`, `database.dart` |
| P0-07 | `watchSingle()` → `watchSingleOrNull()` + otomatik `ensure()` | `settings_dao.dart`, `providers.dart` |
| P1-03 | `fatal_warnings: false` | `build.yaml` |
| P1-04 | `intl: any` | `pubspec.yaml` |
| P1-05 | `bumpAwayStats` SQL seviyesinde artırma (race fix) | `session_dao.dart` |
| P1-06 | `wrongCount = 0` → otomatik yanlış kaydı siliniyor | `wrong_item_dao.dart` |
| P1-07 | Oturum silinince yanlış kaydı `manual`'e dönüşüyor | `wrong_item_dao.dart` |
| P1-08 | `mastered` kayda yeni yanlış gelirse `active`'e dönüyor | `wrong_item_dao.dart` |
| P2-01/02 | `wrong_items.session_id` ve `study_sessions.topic_id` index'leri | `tables/*` |
| P2-06 | Raw SQL'de `'running'` yerine `SessionStatus.running.name` bind | `stats_dao.dart` |

**Şema stratejisi:** v1 yayında olmadığı için bunlar **clean schema change** — `schemaVersion` 1'de kaldı. Geliştirme cihazından uygulamayı silip yeniden kurman gerekiyor.

**Test sayısı:** 7 → 20.

### Hâlâ açık olan P1'ler (Adım 3–6)

`schedule_json` tipli modeli · `BlockType.breakTime` ↔ `"break"` JSON eşlemesi · onboarding redirect · run route'ları · bildirim/lifecycle katmanı · reklam katmanı · net katsayısı değişince geçmiş netlerin yeniden hesaplanması

---

## ⚠️ AG5-2 — GELİŞTİRME CİHAZINDAN UYGULAMAYI SİL

`study_sessions` üzerine **kısmi unique index** eklendi (KARAR D3):

```sql
CREATE UNIQUE INDEX idx_one_running
  ON study_sessions(status) WHERE status = 'running';
```

Aynı anda birden fazla `running` oturum artık **veritabanı seviyesinde**
imkânsız. Daha önce koruma yalnızca `StartSessionUseCase` içindeydi ve
"önce oku sonra yaz" yapısı yarış durumunda ikinci bir `running` satıra
izin veriyordu; bu durumda ilk oturumun çalışması `daily_stats`'a hiç
yansımıyor ve hata **sessiz** kalıyordu.

Index `onCreate` içinde oluşturuluyor ve **`schemaVersion` 1'de KALDI**
(clean schema change — v1 henüz yayında değil). Bu yüzden:

> **Geliştirme cihazında uygulama kuruluysa SİL ve yeniden kur.**
> Mevcut veritabanı dosyası `onCreate`'i tekrar çalıştırmaz; index
> oluşmaz ve kısıt sessizce devre dışı kalır. Ayrıca eski veritabanında
> birden fazla `running` satır varsa index zaten oluşturulamazdı.

---

## FAZ 6 — Production derleme

### 1. Reklam kimlikleri

Production AdMob kimlikleri **koda girmez**. İki yerden geçilir ve **ikisi
de** gerekir: Dart tarafı `--dart-define`, Android manifest tarafı Gradle
özelliği.

```bash
flutter build apk --release \
  --dart-define=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY \
  --dart-define=ADMOB_BANNER_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_NATIVE_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_INTERSTITIAL_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_REWARDED_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  -Padmob_app_id=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

- `--dart-define=ADMOB_APP_ID=...` → `AdConfig` (Dart; birim kimlikleri ve
  `usingTestIds` kontrolü)
- `-Padmob_app_id=...` → `manifestPlaceholders["admobAppId"]` →
  `AndroidManifest.xml`'deki `com.google.android.gms.ads.APPLICATION_ID`

**Hiçbiri verilmezse Google'ın resmî TEST kimlikleri kullanılır.**
Varsayılanın test olması bilinçli: unutulursa gelir kaybedilir, tersi
(production kimliğiyle geliştirme + kendi reklamına tıklama) AdMob hesabını
kapattırır.

`-Padmob_app_id` yerine kalıcı olarak `android/gradle.properties` içine
`admob_app_id=...` yazılabilir — **bu dosya depoya commit'lenmemelidir.**

### 2. Release imzalama (ZORUNLU)

Play Store'a yüklenecek çıktı **kendi keystore'unla** imzalanmalı. Debug
anahtarıyla imzalanmış bir AAB/APK **yüklenemez**.

> **Keystore'u KAYBETME ve ASLA paylaşma.** Play, bir uygulamanın imza
> anahtarını değiştirmene izin vermez: keystore kaybolursa o uygulamaya bir
> daha güncelleme yayımlayamazsın; sızarsa uygulamanın kimliği çalınır.
> Yedeğini kendi bilgisayarının dışında da tut.

#### 2.1 Anahtar üret (bir kez)

```bash
keytool -genkey -v \
  -keystore ~/anahtarlar/sinav-odak-upload.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Sorulan bilgileri doldur ve **parolayı not et**. `-validity 10000` (~27 yıl)
Google'ın önerdiği süredir; daha kısası anahtarın ömrü dolduğunda güncelleme
yayımlamanı engeller.

#### 2.2 `android/key.properties` oluştur

```properties
storePassword=KEYSTORE_PAROLASI
keyPassword=ANAHTAR_PAROLASI
keyAlias=upload
storeFile=/home/kullanici/anahtarlar/sinav-odak-upload.jks
```

- Dosyanın yeri: **`android/key.properties`** (proje kökü değil).
- `storeFile` **mutlak yol** olmalı; göreli yazarsan `android/` klasörüne
  göre çözülür.
- Bu dosya ve `*.jks` / `*.keystore` **`.gitignore`'da** — depoya girmezler.

#### 2.3 Nasıl çalışıyor

`android/app/build.gradle`:

- `key.properties` **varsa** → `signingConfigs.release` doldurulur ve release
  derlemesi onunla imzalanır.
- **Yoksa** → debug anahtarına düşer (geliştirme kırılmasın diye) ve Gradle
  şu uyarıyı basar:

  ```
  UYARI: android/key.properties yok — release derlemesi DEBUG anahtarıyla
  imzalanıyor. Bu çıktı Play Store'a YÜKLENEMEZ.
  ```

Yayın derlemesinde bu uyarıyı görüyorsan **dur**: çıktı Play'e yüklenemez.

#### 2.4 Play Store çıktısı: **AAB** (APK değil)

Google Play **Android App Bundle** ister. `flutter build apk` yalnızca
elden dağıtım / cihaza kurulum içindir.

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY \
  --dart-define=ADMOB_BANNER_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_NATIVE_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_INTERSTITIAL_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  --dart-define=ADMOB_REWARDED_UNIT=ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY \
  -Padmob_app_id=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

Cihazda denemek için APK (aynı define'larla):

```bash
flutter build apk --release  # ...aynı --dart-define ve -Padmob_app_id
# çıktı: build/app/outputs/flutter-apk/app-release.apk
```

Kimlikleri vermezsen **test reklamları** ile derlenir — geliştirmede doğrusu
budur, yayında gelir kaybıdır. Release derlemede Ayarlar → Hakkında'daki
"TEST reklam kimlikleri kullanılıyor" uyarısının **kaybolduğunu** doğrula.

### 3. Yayına çıkmadan önce

- [ ] `AdConfig.usingTestIds == false` (release derlemede doğrula)
- [ ] `android/key.properties` oluşturuldu ve derlemede imzalama uyarısı ÇIKMIYOR (bkz. §2)
- [ ] `PRIVACY.md` bir URL'de yayımlandı ve Play Console'a girildi
- [ ] Play Console *Data safety* formu `PRIVACY.md` §10'daki tabloya göre dolduruldu
- [ ] Hedef kitle yaşı **13+** seçildi

### 4. i18n

Arayüz metinleri `lib/l10n/app_tr.arb` içinde; `L10n` sınıfı
`flutter gen-l10n` (veya `flutter pub get`) ile üretilir. Uygulama şu an
**Türkçe'ye sabitlenmiştir** (`lib/app.dart` içinde `locale: Locale('tr')`);
`app_en.arb` iskelet olarak duruyor, İngilizce çeviri v1.2'ye bırakıldı.
