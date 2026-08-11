# FAZ 8 — FİNAL DENETİM + İYİLEŞTİRME PASI · İŞÇİ RAPORU

**Tarih:** 11 Ağustos 2026
**Kapsam:** tüm `lib/` + `test/` ağacının denetimi, A+B bulgularının
uygulanması
**Durum:** TAMAM

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **737 / 737 geçti** (eşik ≥698 — **+39**) |
| **analyze** | **No issues found!** — 0 error · 0 warning · 0 info |
| **Bulgu** | **24 bulgu** — 20 uygulandı · 4 ertelendi (D) |
| **G3–G8 + G12** | **hepsi 0** — G6 dahil ilk kez tamamen temiz |
| **S15** | **KAPANDI** — 338 ARB anahtarı, **0 ölü anahtar**, TR/EN senkron |

---

## 2. BULGU TABLOSU

### A) Bug / risk — **hepsi düzeltildi**

| # | Bulgu | Etki | Yapılan |
| --- | --- | --- | --- |
| **A1** | **`keepScreenOn` ayarı hiçbir yerde okunmuyordu.** `wakelock_plus` pubspec'te duruyor, kod hiç çağırmıyordu | Kullanıcı "ekran açık kalsın" diyor, çalışma sırasında ekran yine kapanıyordu — **ayar yalan söylüyordu** | `ScreenWakeGateway` portu + `WakelockScreenGateway`; `shouldKeepScreenOnProvider` (ayar **ve** aktif oturum); `app.dart`'ta tek noktadan dinleniyor |
| **A2** | **`notificationEnabled` okunmuyordu** | Kullanıcı bildirimleri kapatsa bile **kurulmaya devam ediyordu** | `LocalSessionNotifier` artık tercihleri okuyor; kapalıysa hiç kurmuyor |
| **A3** | **`soundEnabled` / `vibrationEnabled` okunmuyordu** | Aynı sınıf hata; üç ayar birden etkisizdi | `NotificationPrefs` + **kombinasyon başına ayrı kanal kimliği** (§3.1) |
| **A4** | **43 ölü ARB anahtarı.** FAZ 6'da run/break/summary anahtarları eklenmiş ama ekranlar gömülü metin kullanmaya devam ediyordu | i18n altyapısı çalışıyor görünüyordu, gerçekte devrede değildi | Tüm ekranlar ARB'ye bağlandı; kalan 12 gerçekten ölü anahtar **silindi** |
| **A5** | **Tebrik ekranındaki rozet kartı tek karede kayboluyordu** (FAZ 8'de eklendikten sonra testin yakaladığı hata): `markSeen` akışı güncelliyor, liste anında boşalıyordu | Kullanıcı kazandığı rozeti göremezdi | Gösterilen liste `State` içinde sabitlendi |
| **A6** | **Haptik çağrısı kayıt akışını bloke ediyordu** (`await`) | KAYDET sonrası yönlendirme titreşim motorunu bekliyordu; testte `pumpAndSettle` zaman aşımına düştü | `unawaited(...)` — kaydın doğruluğu titreşime bağlı değil |

### B) Güvenli yüksek değer iyileştirme — **hepsi uygulandı**

| # | Bulgu | Yapılan |
| --- | --- | --- |
| **B1** | **Erişilebilirlik SIFIRDI** — `Semantics` kullanımı 0 | Sayaç ve mola sayacı `liveRegion` + sözel etiket ("24 dakika 0 saniye kaldı"); odak skoru, hedef ilerlemesi (yüzdeyle), rozet kilitli/açık durumu, takvim günü (gün + süre + oturum) etiketlendi |
| **B2** | **Rozetler sessizce açılıyordu** — kullanıcı Ayarlar > Rozetler'e girmedikçe haberi olmuyordu | Tebrik ekranına "Yeni rozet kazandın!" kartı + rozetlere kısayol |
| **B3** | **Haptik yoktu** | `HapticGateway` portu; KAYDET'te `success()`, rozet açılışında `celebrate()` — **titreşim ayarına kapılı** |
| **B4** | Bildirim kanalı adı/açıklaması koda gömülüydü | ARB'den besleniyor (`L10n.delegate.load` ile `runApp` öncesi) |
| **B5** | Uzun ders/konu adları taşabiliyordu | `maxLines` + `ellipsis`: oturum özeti başlığı, ana panel son oturum satırı, hedef başlığı, rozet başlığı |
| **B6** | `break_screen.dart` başında **"DOĞRULANMADI — flutter test bekliyor"** uyarısı duruyordu | Yanıltıcıydı (dosya fazlardır test ediliyor); kaldırıldı |
| **B7** | Kenar durumlar test edilmemişti | 18 test: yılbaşı, artık yıl (28→29 Şubat, 29 Şubat→1 Mart), hafta sınırı, boş katalog, **tümü arşivli**, 0 oturum, saat geri alma |

### C) Küçük eklenebilir özellik — **uygulandı**

| # | Bulgu | Yapılan |
| --- | --- | --- |
| **C1** | Mağaza görseli yoktu | `assets/store/feature_graphic.png` **1024×500** — marka indigosu degrade + kronometre + yükselen çubuk grafiği, saf stdlib PNG kodlayıcıyla üretildi |

### D) v1.2'ye bırakıldı — **DOKUNULMADI**

| # | Konu | Gerekçe |
| --- | --- | --- |
| **D1** | **İngilizce çeviri** (S16) | `app_en.arb` anahtar bazında senkron ama değerler TR. Gerçek çeviri dil işi, kod işi değil |
| **D2** | **Geçmiş oturum düzenleme/silme ekranı** | Şema (`previousDateKey`) hazır ama yeni ekran + akış demek; kapsam dışı |
| **D3** | **`db_health_page` i18n'i** | Yalnızca `kDebugMode` dalında; release'e girmiyor. Geliştirme aracını çevirmek ölü emek |
| **D4** | **Soru sayısına üst sınır** | Formda 999999 girilebiliyor. Bir ürün kararı gerektiriyor (S8 tavanları hedefler içindi); **koordinatör kararı bekliyor** |

---

## 3. ÖNE ÇIKAN KARARLAR

### 3.1 Bildirim ses/titreşim → kombinasyon başına AYRI kanal

Android'de bir bildirim kanalı **bir kez oluşturulduktan sonra ses ve
titreşim ayarları koddan değiştirilemez** — sistem kullanıcının kanal
üzerindeki tercihini korur. Tek kanal kullanıp `playSound` değerini
değiştirmek hiçbir işe yaramaz, ayar **sessizce yok sayılırdı**.

Bu yüzden `NotificationPrefs.channelId` her kombinasyona ayrı kimlik
veriyor (`session_s1_v0` gibi). Test dört kombinasyonun dört ayrı kanal
ürettiğini doğruluyor.

### 3.2 Ekran kilidi: ayar **ve** aktif oturum

`shouldKeepScreenOnProvider` iki koşulu birden arıyor. Ayarın tek başına
ekranı sürekli açık tutması pili boşuna tüketirdi. Dinleme `app.dart`'ta
tek noktada — `RunScreen`/`BreakScreen`'e ayrı ayrı konsaydı ekranlar arası
geçişte kilit bırakılıp yeniden alınırdı.

### 3.3 Haptik ayara kapılı ve **bloke etmiyor**

`SystemHapticGateway` `vibrationEnabled` false ise hiçbir şey yapmıyor —
"titreşim kapalı" diyen kullanıcıya yine titreşim vermek yalan olurdu.
Çağrılar `unawaited`: titreşim motorunu beklemek yönlendirmeyi geciktirirdi.

Kapı varsayılanı **Noop**, `main()` gerçek adaptörü bağlıyor — projenin
diğer platform kapılarıyla (reklam, paylaşım, ekran kilidi) aynı desen.

### 3.4 Ölü ARB anahtarları silindi

12 anahtar hiçbir yerde kullanılmıyordu (`commonAdd`, `statsCorrect`,
`calendarToday`…). Çeviri dosyasında ölü satır bırakmak, v1.2'de çevirmene
gereksiz iş çıkarır. Kalan **338 anahtarın tamamı kullanılıyor** (§4).

---

## 4. DOĞRULAMA

### 4.1 Dört komut

```
$ flutter pub get                → Got dependencies!
$ dart run build_runner build …  → Succeeded
$ flutter analyze                → No issues found!   (0 / 0 / 0)
$ flutter test                   → +737: All tests passed!   (EXIT=0)
```

### 4.2 S15 kapanış kanıtı

```
ARB anahtar: 338 | ölü anahtar: 0 | TR/EN senkron: EVET
Release ekranlarında gömülü arayüz metni: 0
```

Tarama `db_health_page` (debug aracı, D3) hariç tüm `lib/presentation`
ağacını kapsıyor. Kalan string literal'ler çevrilecek metin değil:
`'+10'`, `'+20'`, `'$value'`, `' : '` gibi biçim parçaları.

> **Tarama hatası notu:** ilk tarama yalnızca Türkçe özel karakter (`çğıöşü`)
> arıyordu ve **"Gizlilik tercihleri"** gibi özel karakter içermeyen metinleri
> kaçırıyordu. Desen genişletilince 8 kalıntı daha çıktı ve kapatıldı.
> "Temiz" demeden önce tarama desenini de sınamak gerekiyor.

### 4.3 Koruma grep'leri

```
G3 0 · G4a 0 · G4b 0 · G5 0 · G6 0 · G7 0 · G8 0 · G12 0
```

**G6 ilk kez 0.** Önceki fazlarda tek eşleşme `promise_step.dart`'taki
"Sayaç duraklatılamaz" arayüz metniydi; artık ARB'den geldiği için grep'e
takılmıyor. Kural aynen yürürlükte: **pause yok.**

### 4.4 Test dağılımı (yeni)

| Dosya | Test |
| --- | --- |
| `test/unit/edge_cases_test.dart` | 18 |
| `test/unit/settings_effects_test.dart` | 13 |
| `test/widget/done_achievements_test.dart` | 8 |

Mevcut 698 testin **hiçbiri düşmedi**. İki test **düzeltildi**,
zayıflatılmadı: `done_screen_test` ve `router_redirect_test` yüzeyleri
büyütüldü (rozet kartı ekranı uzattı, butonlar 800×600 dışında kalıyordu) —
iddialar aynı kaldı.

---

## 5. ÜRÜN FELSEFESİNE AYKIRI BULUNAN — DEĞİŞTİRİLMEDİ

Koordinatör kararı bekleyen tek madde:

**D4 — Oturum sonu formunda soru sayısına üst sınır yok.** Kullanıcı
`999999` girebiliyor; `NetCalculator` yalnızca negatifleri ve
"doğru+yanlış+boş ≤ soru" kuralını doğruluyor. Bir tavan (örn. 2000)
istatistikleri saçma değerlerden korur, **ama**:

- S8 tavanları (480 dk / 500 soru) **hedefler** için konmuştu, oturum
  girişi için değil
- Deneme sınavı çözen bir öğrenci tek oturumda 120+ soru girebilir;
  yanlış konan bir tavan gerçek kullanımı engeller

Bu bir **ürün kararı**, teknik düzeltme değil. Değiştirmedim; tavan
istenirse değeriyle birlikte söylenmeli.

---

## 6. YENİ / DEĞİŞEN DOSYALAR

**Yeni**

```
lib/domain/entities/notification_prefs.dart      bildirim tercihleri + kanal kimliği
lib/domain/ports/screen_wake_gateway.dart        ekran kilidi portu
lib/domain/ports/haptic_gateway.dart             dokunsal geri bildirim portu
lib/services/background/wakelock_screen_gateway.dart
lib/services/background/system_haptic_gateway.dart
assets/store/feature_graphic.png                 1024×500 mağaza görseli
test/unit/edge_cases_test.dart
test/unit/settings_effects_test.dart
test/widget/done_achievements_test.dart
```

**Değişen (öne çıkanlar)**

```
lib/services/notifications/notification_service.dart   detailsFor(prefs), ARB kanal metni
lib/services/notifications/local_session_notifier.dart tercihlere uyuyor
lib/core/di/app_providers.dart      notificationPrefs / shouldKeepScreenOn /
                                    haptic / screenWake / unseenAchievements
lib/app.dart                        ekran kilidi dinleyicisi
lib/main.dart                       gerçek kapılar + ARB kanal metni
lib/presentation/run/*              S15 + semantics + haptik + rozet kartı
lib/presentation/home/*             S15 + taşma koruması
lib/presentation/onboarding/**      S15 (5 dosya)
lib/presentation/wrongs/**          S15 (4 dosya)
lib/presentation/session_setup/**   S15 (4 dosya)
lib/presentation/settings/*         S15 (destek + gizlilik kartları)
lib/presentation/{goals,achievements,calendar}/*   semantics + taşma
lib/l10n/app_tr.arb · app_en.arb    216 → 338 anahtar, ölüler silindi
```

---

## 7. SAPMALAR

| # | Durum |
| --- | --- |
| S1–S14 | Kapalı |
| **S15** | **KAPANDI** — release ekranlarında gömülü metin 0, ölü ARB anahtarı 0 |
| S16 | Açık — `app_en.arb` değerleri TR; çeviri v1.2 (D1) |
| S17 | Açık — Android SDK yok; AAB/APK derlemesi bu ortamda yapılamıyor |

**Yeni sapma yok.**

---

## 8. KONTROL LİSTESİ DURUMU

| Madde | Durum |
| --- | --- |
| S15 — eski ekranların metinleri ARB'ye | ✅ kapandı |
| Release imzalama (`signingConfigs.release` + `key.properties` + .gitignore + README) | ✅ **bir önceki turda tamamlandı** (`RELEASE_IMZALAMA_RAPORU.md`) |
| Koyu tema tutarlılığı | ✅ tüm ekranlar `Theme.of(context).colorScheme` kullanıyor; sabit renk yalnızca ders paletinde (kullanıcı verisi) ve marka tohumunda |
| Erişilebilirlik — semantics | ✅ B1 |
| Erişilebilirlik — 48dp dokunma alanı | ✅ tüm dokunma hedefleri `IconButton` / `ListTile` / `*Button` (Material varsayılanı ≥48dp); ham `GestureDetector` yok |
| Metin taşması | ✅ B5 |
| Kenar durumlar | ✅ B7 (18 test) |
| Haptik (titreşim ayarına kapılı) | ✅ B3 |
| Performans / gereksiz rebuild | ✅ §9 |
| Bildirim kanalı adı ARB'den | ✅ B4 |
| Mağaza feature graphic 1024×500 | ✅ C1 |
| G3–G8 + G12 grep | ✅ hepsi 0 |
| Consent fail-closed | ✅ `consent_gate_test.dart` 17 testiyle yeniden koştu; UMP `unavailable` → reklam yok |

---

## 9. PERFORMANS NOTU

Provider `watch` kapsamları gözden geçirildi; **yapısal sorun bulunmadı**:

- Sayaç yalnızca `runStateProvider`'ı izliyor ve saniyede bir değişiyor;
  `uiTickerProvider` `autoDispose` — ekran kapanınca tik duruyor
- İstatistik/takvim ağır sorguları `daily_stats` üzerinden (denormalize
  özet), ham oturum taraması yok
- `unseenAchievementsProvider` yalnızca tebrik ekranında okunuyor
- Takvim ızgarası hücre başına sözlük araması yapıyor (42 hücre × O(1)),
  listeyi 42 kez taramıyor

Ölçülmüş bir darboğaz yok; profilleme gerçek cihazda yapılmalı (S17).

---

## 10. YAYINA KALAN (kod değil)

1. **Keystore üret** + `android/key.properties` (README §2)
2. **AAB derle**: `flutter build appbundle --release` + AdMob define'ları
3. **Cihaz duman testi** — `FAZ_06_RAPORU.md` §7; FAZ 8 sonrası ek maddeler:
   - "Ekran açık kalsın" AÇIK + oturum → ekran kapanmıyor; oturum bitince
     normale dönüyor
   - Bildirimler KAPALI → mola bitişinde bildirim **gelmiyor**
   - Ses/titreşim kapalı → kanal sessiz (Android bildirim ayarlarında
     kanalın ayrı göründüğünü doğrula)
   - KAYDET'te ince titreşim; titreşim ayarı kapalıyken **yok**
   - İlk oturum sonrası tebrik ekranında "Yeni rozet kazandın!" kartı
   - TalkBack ile sayaç okunuyor mu ("24 dakika 0 saniye kaldı")
4. **Play Console** — `PRIVACY.md`, *Data safety*, 13+, `feature_graphic.png`
5. **İngilizce çeviri** (D1)
