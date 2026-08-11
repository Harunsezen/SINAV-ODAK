# SINAV ODAK — AKTARIM RAPORU

**Devreden:** Claude (Adım 1 → Adım 5 / AG1)
**Devralan:** yeni Claude
**Son doğrulanmış durum:** `flutter analyze` 0 error / 0 warning · `flutter test` **353/353 geçti**
**Flutter sürümü:** 3.24.5 stable (bu sürümle derlendi ve test edildi)

---

## 0. PROJE NEDİR

YKS/LGS/KPSS öğrencileri için **%100 ücretsiz, offline-first, duraklatılamayan** çalışma zamanlayıcısı ve istatistik uygulaması. Gelir yalnızca reklamdan; çalışma sırasında tam ekran reklam **asla** gösterilmez.

**Ürünün tek cümlelik vaadi:** "Ders çalışırken telefonunu açtırmayan, kapattığında ne yaptığını sana rakamla gösteren ücretsiz çalışma sayacı."

### Şu an ne çalışıyor

Kullanıcı uygulamayı açar → onboarding → ana panel → ders/konu/tür/plan seçer → oturum başlar → çalışma bloğu sayar → mola gelir (uzatılabilir, atlanabilir) → çizelge biter → oturum sonu ekranı **iskelet halinde** görünür.

### Şu an ne çalışmıyor

Oturum sonu formunda **soru girişi yapılamıyor**, KAYDET butonu bağlı değil. Yani bir oturum başlatılabiliyor ve yaşatılabiliyor ama **düzgün kapatılamıyor**. Sıradaki işin birincisi bu.

---

## 1. SON DOSYA LİSTESİ

Tüm dosyalar bu oturumlarda sıfırdan üretildi; "DEĞİŞTİ" işareti, bir sonraki adımda üzerine dönülüp güncellenen dosyaları gösteriyor.

### Kök

```
pubspec.yaml            — [YENİ]    Flutter/Drift/Riverpod/GoRouter/Freezed bağımlılıkları; google_mobile_ads bilinçli olarak YORUMDA
analysis_options.yaml   — [YENİ]    flutter_lints + custom_lint; *.g.dart hariç tutuluyor (bu bir tuzak, bkz. §3)
build.yaml              — [YENİ]    Drift codegen ayarları; fatal_warnings kapalı
.gitignore              — [YENİ]    *.g.dart ve *.freezed.dart hariç — clone sonrası build_runner ZORUNLU
README.md               — [YENİ]    Kurulum, mimari kararlar, şema özeti
```

### core/ — çapraz kesen altyapı

```
lib/core/constants/app_colors.dart   — [YENİ]    Tema tohumu + ders renk paleti
lib/core/theme/app_theme.dart        — [YENİ]    Light/dark tema; sayaç için tabular figures
lib/core/errors/failures.dart        — [YENİ/DEĞİŞTİ] sealed AppFailure: Plan/Validation/Storage/Session
lib/core/utils/time.dart             — [YENİ]    nowMs() — tek zaman kaynağı
lib/core/utils/date_key.dart         — [YENİ/DEĞİŞTİ] 'YYYY-MM-DD' gün anahtarı; gece yarısı kuralı burada
lib/core/utils/formatters.dart       — [YENİ]    Süre/net biçimlendirme
lib/core/router/routes.dart          — [YENİ]    Tüm route yolları tek yerde
lib/core/router/app_router.dart      — [YENİ/DEĞİŞTİ] Provider tabanlı GoRouter; onboarding + aktif oturum redirect'leri
lib/core/di/app_providers.dart       — [YENİ/DEĞİŞTİ] DI konteyneri; TÜM provider'lar burada (bkz. §2.6)
```

### domain/ — saf Dart, hiçbir şeye bağımlı değil

```
lib/domain/entities/enums.dart                   — [YENİ]    BlockType, SessionStatus, GoalType, WrongItemStatus...
lib/domain/entities/block_type_codec.dart        — [YENİ/DEĞİŞTİ] study<->"study", breakTime<->"break" sözleşmesi
lib/domain/entities/schedule_codec_exception.dart— [YENİ/DEĞİŞTİ] 15 nedenli codec hatası
lib/domain/entities/schedule_block.dart          — [YENİ/DEĞİŞTİ] Immutable blok + alignToSecond + validate
lib/domain/entities/session_schedule.dart        — [YENİ/DEĞİŞTİ] Immutable çizelge; private constructor, 11 kurallı validate
lib/domain/entities/session_state.dart           — [YENİ/DEĞİŞTİ] Freezed sealed union, 8 state, joker dal YOK
lib/domain/ports/session_notifier.dart           — [YENİ]    Bildirim portu (arayüz)
lib/domain/ports/session_activity_tracker.dart   — [YENİ]    Lifecycle izleme portu (arayüz)
lib/domain/services/schedule_builder.dart        — [YENİ/DEĞİŞTİ] fromPreset/fromSpecial/fromEndTime + _splitStudyMinutes
lib/domain/services/schedule_resolver.dart       — [YENİ/DEĞİŞTİ] resolve(schedule, nowMs) → SessionState. MİMARİNİN KALBİ
lib/domain/services/schedule_modifier.dart       — [YENİ/DEĞİŞTİ] extendBreak / skipBreak
lib/domain/services/net_calculator.dart          — [YENİ]    Net, başarı oranı, hız, soru başına süre
lib/domain/services/focus_score_calculator.dart  — [YENİ]    0–100 odak skoru (formül SABİT, bkz. §5)
lib/domain/services/notification_planner.dart    — [YENİ]    Hangi bildirim ne zaman — saf, test edilebilir
```

### application/ — orkestrasyon (domain + data birlikte)

```
lib/application/schedule_writer.dart              — [YENİ]    ÇİFT KAYIT KÖPRÜSÜ (bkz. §2.3)
lib/application/recovery_service.dart             — [YENİ/DEĞİŞTİ] Açılışta yarıda kalan oturumu değerlendirir
lib/application/usecases/start_session.dart       — [YENİ/DEĞİŞTİ] Tek running koruması + transaction + bildirim + izleme
lib/application/usecases/finish_session.dart      — [YENİ/DEĞİŞTİ] Normal/erken mod, net + odak skoru + foregroundS hesabı
lib/application/usecases/extend_break.dart        — [YENİ]    +5 dk, limit domain'de
lib/application/usecases/skip_break.dart          — [YENİ]    Molayı erken bitir
lib/application/usecases/complete_onboarding.dart — [YENİ]    Onboarding'in Drift bağımlılığını buraya taşır
```

### data/ — Drift veritabanı

```
lib/data/local/database.dart                       — [YENİ/DEĞİŞTİ] 12 tablo, 6 DAO, migration, seed health check
lib/data/local/connection/connection.dart          — [YENİ]    SQLite bağlantısı; şifreleme YOK (bilinçli)
lib/data/local/converters/block_type_converter.dart— [YENİ]    Domain codec'ini Drift'e bağlar
lib/data/local/seed_data.dart                      — [YENİ/DEĞİŞTİ] 5 sınav türü, 51 ders, 152 konu, 11 çalışma türü; idempotent
lib/data/local/tables/settings_table.dart          — [YENİ]    Tek satırlık ayar tablosu
lib/data/local/tables/catalog_tables.dart          — [YENİ/DEĞİŞTİ] subjects, topics, activity_types (ikisi de arşivlenir, silinmez)
lib/data/local/tables/session_tables.dart          — [YENİ/DEĞİŞTİ] study_sessions, session_blocks
lib/data/local/tables/tracking_tables.dart         — [YENİ/DEĞİŞTİ] goals, daily_stats, wrong_items, achievements, ad_events, app_state
lib/data/local/daos/settings_dao.dart              — [YENİ/DEĞİŞTİ] Ayar satırı garantisi (ensure)
lib/data/local/daos/subject_dao.dart               — [YENİ/DEĞİŞTİ] Ders/konu/tür CRUD + arşivleme
lib/data/local/daos/session_dao.dart               — [YENİ/DEĞİŞTİ] Oturum + blok yazma, kurtarma sorguları, bumpAwayStats
lib/data/local/daos/stats_dao.dart                 — [YENİ/DEĞİŞTİ] recomputeDay, aralık özeti, ders kırılımı, zayıf konular
lib/data/local/daos/goal_dao.dart                  — [YENİ]    Hedef CRUD
lib/data/local/daos/wrong_item_dao.dart            — [YENİ/DEĞİŞTİ] Yanlış defteri; auto/manual ayrımı
lib/data/repositories/session_repository.dart      — [YENİ/DEĞİŞTİ] save/delete/markInterrupted + recomputeDay orkestrasyonu
```

### services/ — altyapı

```
lib/services/notifications/notification_service.dart    — [YENİ]  Eklenti kurulumu, izin, timezone
lib/services/notifications/local_session_notifier.dart  — [YENİ]  Gerçek SessionNotifier; planı uygular
lib/services/notifications/noop_session_notifier.dart   — [YENİ]  Test/geliştirme için boş implementasyon
lib/services/background/lifecycle_tracker.dart          — [YENİ/DEĞİŞTİ] awayS + exitCount ölçümü
```

### presentation/ — UI

```
lib/main.dart                                        — [YENİ/DEĞİŞTİ] DB init, bildirim init, kurtarma kontrolü
lib/app.dart                                         — [YENİ/DEĞİŞTİ] MaterialApp.router, tema
lib/presentation/shell/app_shell.dart                — [YENİ]  5 sekmeli alt navigasyon
lib/presentation/shell/placeholder_page.dart         — [YENİ]  Yazılmamış ekranlar için
lib/presentation/shell/db_health_page.dart           — [YENİ]  GEÇİCİ debug ekranı — Adım 7'de SİLİNECEK
lib/presentation/onboarding/onboarding_screen.dart   — [YENİ/DEĞİŞTİ] MİNİMAL; 5 adım + UMP rızası eksik
lib/presentation/home/home_screen.dart               — [YENİ]  MİNİMAL giriş noktası; Adım 7'de dolacak
lib/presentation/session_setup/setup_controller.dart — [YENİ]  Seçim modeli + NotifierProvider (autoDispose DEĞİL)
lib/presentation/session_setup/subject_picker.dart   — [YENİ]  S04 ders seçimi
lib/presentation/session_setup/topic_picker.dart     — [YENİ]  S05 konu seçimi (atlanabilir)
lib/presentation/session_setup/activity_picker.dart  — [YENİ]  S06 çalışma türü
lib/presentation/session_setup/plan_setup.dart       — [YENİ]  S07 üç plan modu + canlı önizleme
lib/presentation/run/run_controller.dart             — [YENİ/DEĞİŞTİ] RunController aksiyonları (provider'lar DI'da)
lib/presentation/run/run_screen.dart                 — [YENİ]  S08 aktif çalışma; PAUSE YOK, geri tuşu yakalı
lib/presentation/run/break_screen.dart               — [YENİ/DEĞİŞTİ] S09 mola; +5 dk / Molayı Bitir
lib/presentation/summary/summary_screen.dart         — [YENİ]  S10 İSKELET — soru girişi ve KAYDET bağlı DEĞİL
```

### test/ — 353 test

```
test/unit/usecase_helpers.dart              — [YENİ]  Paylaşılan koşum: sabit t0, FakeNotifier, FakeTracker, seed
test/unit/database_seed_test.dart           — 7    Seed, ayar satırı, FK, arşivleme
test/unit/session_schedule_codec_test.dart  — 30   JSON round-trip, 11 doğrulama kuralı
test/unit/session_state_test.dart           — 13   8 state + getter'lar
test/unit/schedule_builder_test.dart        — 35   3 plan modu + edge girdiler
test/unit/schedule_resolver_test.dart       — 17   Blok sınırları, 3000 ms tolerans
test/unit/schedule_modifier_test.dart       — 36   extendBreak/skipBreak + KARAR B senaryoları
test/unit/net_calculator_test.dart          — 21   Net, hız, tüm doğrulama hataları
test/unit/focus_score_test.dart             — 27   Kritik 62 senaryosu, bileşenler, negatifler
test/unit/notification_planner_test.dart    — 16   Bildirim planı, kimlik determinizmi
test/unit/lifecycle_tracker_test.dart       — 10   awayS/exitCount, inactive çıkış sayılmaz
test/unit/start_session_test.dart           — 6    Tek running, çift kayıt senkronu, gece yarısı
test/unit/finish_session_test.dart          — 11   Normal/erken, foregroundS hesabı, recomputeDay
test/unit/extend_break_test.dart            — 8    Uzatma, limit, geçersiz girdiler
test/unit/skip_break_test.dart              — 7    Atlama, extendedS düşürme
test/unit/recover_session_test.dart         — 10   4 kurtarma sonucu + bozuk JSON fallback
test/unit/session_repository_test.dart      — 13   daily_stats orkestrasyonu, yanlış defteri
test/unit/run_controller_test.dart          — 12   resolve entegrasyonu, ticker state ilerletmiyor
test/unit/setup_controller_test.dart        — 10   Seçim, atlama, reset
test/widget/run_screen_test.dart            — 11   PAUSE YOK, geri tuşu, ticker
test/widget/break_screen_test.dart          — 9    +5 dk, limit, otomatik geçiş
test/widget/plan_setup_test.dart            — 11   3 mod, uyarılar, hatalar, BAŞLAT
test/widget/summary_screen_test.dart        — 5    İskelet + REKLAM YOK kalkanı
test/integration/router_redirect_test.dart  — 13   Onboarding + aktif oturum redirect'leri
test/integration/session_lifecycle_test.dart— 9    Uçtan uca oturum akışı
test/integration/session_setup_flow_test.dart—6    Uçtan uca kurulum akışı
```

---

## 2. MİMARİ KARARLAR

### 2.1 Sayaç `Timer` tabanlı DEĞİL — en önemli karar

**Neden:** iOS'ta uygulama arka plana geçtikten ~30 sn sonra kod çalıştıramazsınız; `Timer` ölür. Android'de de agresif OEM pil optimizasyonları (Xiaomi, Oppo, Huawei) foreground service'i öldürebilir.

**Çözüm:** Oturum başlarken **tüm blok/mola bitiş anları mutlak `DateTime` olarak DB'ye yazılır**. Durum her sorulduğunda `ScheduleResolver.resolve(schedule, nowMs)` ile **baştan hesaplanır**.

**Doğruluk zinciri:** `nowMs()` → DB'deki çizelge → `resolve()`. UI ticker bu zincirin parçası değildir; yalnızca yeniden boyamayı tetikler.

Bu kural `test/unit/run_controller_test.dart` içindeki *"state YALNIZCA saate bağlı; ticker onu ilerletmiyor"* testiyle ve `run_screen_test.dart` içindeki widget testiyle **davranış seviyesinde** kilitlidir. Biri `runStateProvider` içine sayaç mantığı koyarsa testler kırılır.

### 2.2 Katman yapısı

```
domain/        SAF DART — hiçbir şeye bağımlı değil, DateTime.now() çağırmaz
application/   ORKESTRASYON — domain + data'yı birlikte kullanır
data/          Drift; yalnızca domain/entities kullanır
services/      Altyapı (bildirim, lifecycle) — port'ları implemente eder
presentation/  UI — application + domain + core/di; data'ya DOĞRUDAN erişmez
core/di/       DI konteyneri — tüm provider'lar burada
```

**Neden `application/` var:** `RecoveryService` ilk başta `domain/services/` altındaydı ve `data/local/database.dart` import ediyordu — katman ihlali. Use-case'ler de aynı sorunu yaşayacaktı (DB'ye yazacaklar). Bunlar saf domain servisi değil, **orkestrasyon** servisi. `application/` bu tür sınıfların doğru yeri.

**Neden `ports/` var:** Bildirim ve lifecycle izleme Flutter gerektirir. Use-case'ler bu ayrıntıyı bilmemeli. `SessionNotifier` ve `SessionActivityTracker` arayüzleri sayesinde use-case'ler Flutter'ı hiç tanımadan bildirim kurup izleme başlatabiliyor; testlerde sahte implementasyon veriliyor.

### 2.3 `schedule_json` ve `session_blocks` neden ikili

Aynı çizelge iki yerde tutuluyor:

| Temsil | Rolü |
|---|---|
| `study_sessions.scheduleJson` | **Kurtarmanın tek doğruluk kaynağı.** Uygulama öldürülse bile buradan tam çizelge geri okunur |
| `session_blocks` satırları | **SQL sorgulanabilirlik.** İstatistik, mola analizi, "kaç blok atlandı" gibi sorgular |

**Risk:** biri güncellenip diğeri güncellenmezse kurtarma **yanlış bloktan** devam eder ve hata **sessiz** kalır.

**Koruma:** `lib/application/schedule_writer.dart` tek giriş noktası. `StartSession`, `ExtendBreak`, `SkipBreak` — üçü de buradan geçer, ikisini tek transaction'da yazar. **İkisini ayrı ayrı yazan yeni bir kod yolu ASLA açılmamalı.** `extend_break_test` ve `skip_break_test` içinde "scheduleJson VE session_blocks birlikte güncelleniyor" testleri bunu kilitliyor.

**Fayda:** `RecoveryService`, JSON bozuksa `session_blocks`'tan kurtarma yapabiliyor (fallback). İkiliğin tek gerçek getirisi bu.

### 2.4 `BlockType.breakTime` ↔ `"break"`

Dart'ta `break` ayrılmış kelime olduğu için enum adı `breakTime` kaldı, ama JSON ve DB'de **`"break"`** yazılır. Dönüşüm `domain/entities/block_type_codec.dart` içinde; `BlockTypeConverter` (data) bu saf fonksiyonları kullanır — tersi değil.

Başlangıçta kolon `textEnum<BlockType>()` idi ve DB'ye `"breakTime"` yazıyordu; JSON ise `"break"` diyordu. Bu ikilik kurtarmanın tam merkezindeydi. **Temiz şema değişikliğiyle** düzeltildi (`schemaVersion` 1'de kaldı) — bu yüzden eski bir cihaz veritabanı varsa **uygulama silinmelidir**.

### 2.5 `foregroundS` ölçülmüyor, HESAPLANIYOR

`LifecycleTracker` yalnızca `awayS` ve `exitCount` yazar. Oturum kapanırken `foregroundS = actualDurationS - awayS`.

**Neden:** doğrudan önplan ölçümü, uygulama öldürüldüğünde son dilimi kaybeder. Hesaplama zarif bozulur.

Bu değişiklik bir testi düşürdü ve **bilinçli olarak** güncellendi: kurtarılan oturumun skoru 41 → 55'e çıktı, çünkü artık `awayS` kaydı olmayan oturum tam presence sayılıyor.

### 2.6 Tüm provider'lar `core/di/app_providers.dart` içinde

`run_controller.dart` başta kendi provider'larını içeriyordu ama `activeSessionProvider` Drift'in `StudySession` tipini döndürüyor — presentation'da durduğu sürece data importu kaçınılmazdı. Hepsi DI konteynerine taşındı.

**Ekranlar Drift tiplerini TİP ÇIKARIMI ile tüketir:**

```dart
final subjects = ref.watch(subjectsProvider);   // AsyncValue<List<Subject>>
data: (list) => ... list[i].name ...            // import GEREKMEZ
```

Dart'ta bir tipin üyelerine erişmek için import gerekmez; yalnızca tip **adını yazmak** için gerekir.

### 2.7 Diğer kritik kararlar

| Karar | Gerekçe |
|---|---|
| **WorkManager kullanılmıyor** | Minimum periyot 15 dk ve "inexact"; blok bitişi kayar |
| **SQLCipher/AES yok** | Çalışma süresi ve soru sayısı için aşırı mühendislik; anahtar yönetimi karmaşıklığı getirir, karşılığı yok |
| **Ders ve konu SİLİNMEZ, arşivlenir** | Silinen ders geçmiş istatistikleri bozar. `isArchived` alanı ikisinde de var |
| **`SessionSchedule` private constructor** | Doğrulanmamış çizelge üretmek dil seviyesinde imkânsız. Dışa açık tek giriş: `fromBlocks` ve `fromJson`, ikisi de `validate()` eder |
| **`SessionState` `sealed` + joker dal yok** | Yeni bir state eklendiğinde eksik `switch`'ler derleme hatası verir |
| **Pre-start interstitial kaldırıldı** | AdMob'da interstitial atlanamaz; kullanıcının en yüksek niyetli anını bozar ve politika riski taşır |
| **Bildirim planı eklentiden ayrı** | `flutter_local_notifications` platform kanalı kullanır, host testinde `MissingPluginException` atar. `NotificationPlanner` saf Dart olduğu için 16 testle kapsandı |
| **Bildirim kimlikleri FNV-1a ile** | `String.hashCode` süreçler arası kararlı değil; uygulama yeniden başlayınca eski bildirimler iptal edilemezdi |
| **Setup state `autoDispose` DEĞİL** | Kurulum ekranları arası geçişte seçimler kaybolmamalı; temizlik açıkça `reset()` ile |

---

## 3. AÇIK KALAN MADDELER

### 3.1 Ürün kararı bekleyenler

| # | Konu | Mevcut durum | Seçenekler |
|---|---|---|---|
| Ü1 | **`clockMovedBack` davranışı** | Sadece bilgilendirme ekranı gösteriliyor | (a) oturumu kes (b) uyarıyla devam (c) kullanıcıya sor |
| Ü2 | **Tek `running` DB kısıtı** | Kod koruması var (`StartSessionUseCase`), şema kısıtı YOK | `CREATE UNIQUE INDEX ... WHERE status='running'` eklensin mi? |
| Ü3 | **`db_health_page` production koruması** | Ayarlar sekmesinin tamamını kaplıyor, `kDebugMode` koruması yok | Adım 7'de silinecek ama unutulursa production'a sızar |
| Ü4 | **Net katsayısı değişince geçmiş netler** | Değişmiyor; eski oturumlar eski katsayıyla kalıyor | (a) hepsini yeniden hesapla (b) dondur (c) oturuma katsayı yaz |
| Ü5 | **`equalDistribution` benzeri manuel blok düzenleme** | Kaldırıldı | Adım 4+'ta yeni modelle mi gelecek? |

### 3.2 Kodda açık kalanlar

**Yüksek öncelik**
- **Oturum sonu formu (S10)** — iskelet var, soru/doğru/yanlış/boş girişi ve KAYDET bağlı değil. **Oturum düzgün kapatılamıyor.**
- **Tebrik ekranı (S11)** — hâlâ `PlaceholderPage`
- **Kurtarma diyaloğu (S18)** — `pendingRecoveryProvider` `main.dart`'ta hesaplanıyor ama **hiçbir yerde tüketilmiyor**. Yarıda kalan oturum sessizce `interrupted` yazılıyor, kullanıcıya sorulmuyor

**Orta öncelik**
- **Onboarding 5 adımı** — şu an tek ekran + "Başla" butonu. Sınav türü seçimi, hedef girişi, **UMP rıza formu** (KVKK — reklamdan ÖNCE zorunlu), bildirim izni yok
- **Ana panel** — minimal; özet, streak, hızlı başlat, son oturumlar yok
- **Yanlış defteri UI** — tablo ve DAO hazır, ekran yok
- **İstatistik / takvim / ayarlar ekranları** — hiçbiri yok
- **Ders/konu/tür yönetim ekranları** — DAO'lar hazır, ekran yok
- **Foreground service** — `flutter_foreground_task` pubspec'te, kod yok
- **Reklam katmanı** — `AdGateway`, `AdPolicyEngine`, widget'lar, UMP; hiçbiri yok. `ad_events` tablosu var ama yazan yok

**Düşük öncelik / teknik borç**
- **R5 — kurulum akışı iptal edilirse reset yok.** Kullanıcı geri tuşuyla çıkarsa setup state doluyor kalıyor. Pratikte sorun çıkmıyor çünkü ana paneldeki "Oturumu Başlat" her seferinde `reset()` çağırıyor. **Ama Adım 7'de "hızlı başlat" gibi ikinci bir giriş noktası eklenirse bu açık ortaya çıkar**
- `user_settings.currentStreak / longestStreak / lastStudyDate` — üç kolon var, **yazan kod yok** (`StreakService` yazılmadı)
- `achievements` tablosu — **yazan kod yok** (`AchievementService` yazılmadı)
- `goals.currentValue` otomatik güncellenmiyor (`GoalProgressService` yok)
- `resolve()` içindeki boş çizelge guard'ı **erişilemez** (private constructor boş çizelge üretilmesini engelliyor); `// coverage:ignore-line` eklendi
- 52 adet `info` seviyesi lint (`require_trailing_commas`, `prefer_const_*`) — `dart fix --apply` ile çoğu düzelir

### 3.3 Doğrulanmamış varsayımlar

| # | Varsayım | Durum |
|---|---|---|
| D1 | **Uygulama gerçek cihazda hiç çalıştırılmadı** | `android/` ve `ios/` klasörleri **YOK**; `flutter create` çalıştırılmadı. Tüm doğrulama host testleriyle yapıldı |
| D2 | **Bildirimler gerçek cihazda test edilmedi** | `NotificationPlanner` (plan) 16 testle kapsandı, ama `LocalSessionNotifier` (uygulama) hiç çalıştırılmadı |
| D3 | **`LifecycleTracker` gerçek lifecycle olaylarıyla test edilmedi** | Testler `didChangeAppLifecycleState`'i elle çağırıyor; gerçek cihazda `hidden`/`inactive` sıralaması farklı olabilir |
| D4 | **Android desugaring yapılandırması** | `flutter_local_notifications` `coreLibraryDesugaringEnabled true` **zorunlu kılıyor**; eklenmezse derleme kırılır. Henüz eklenmedi |
| D5 | **`USE_EXACT_ALARM` Play politikası** | Timer uygulamaları için izinli ama Console'da gerekçe yazılması gerekiyor |
| D6 | **Converter geçişi eski veriyi kırar** | `session_blocks.type` kolonunda `'breakTime'` yazılı satır varsa okunamaz. `schemaVersion` 1'de kaldığı için migration yok — **cihazdan uygulama silinmeli** |

---

## 4. SIRADAKİ İŞLER

Sırayla:

### 1. Oturum sonu formunu tamamla (EN KRİTİK)

`lib/presentation/summary/summary_screen.dart` iskeletini doldur:
- Soru sayacı: hızlı butonlar (+5 / +10 / +20 / Sıfırla) + elle giriş
- Doğru / yanlış / boş sayaçları
- **Canlı net önizlemesi** — `NetCalculator` + ayardan `netPenaltyCoefficient`
- Duygu seçici (5 emoji) + opsiyonel not alanı
- KAYDET → `finishSessionProvider` → tebrik ekranına yönlendirme

**Bu ekranda reklam YOK ve olmayacak.** `summary_screen_test.dart` içinde bunu koruyan bir regresyon testi var.

### 2. Tebrik ekranı (S11)

Odak skoru animasyonu, günlük ilerleme özeti, "Yeni oturum" / "Ana panel" butonları. `/run/done` route'u hazır, `PlaceholderPage` gösteriyor.

### 3. Kurtarma diyaloğunu bağla

`pendingRecoveryProvider` hesaplanıyor ama tüketilmiyor. `RecoveryOutcome.needsDecision` geldiğinde "Oturum yarıda kesildi, kaydedelim mi?" diyaloğu gösterilmeli. Şu an kullanıcıya hiç sorulmadan `interrupted` yazılıyor.

### 4. Yanlış defteri UI

`wrong_items` tablosu ve `WrongItemDao` hazır. Ekran: 3 sekme (Aktif / Tekrar Edildi / Öğrenildi), kartta "Bu konuyu çalış" butonu → kurulum akışına konu önceden dolu gider.

### 5. Onboarding'i tamamla

5 adım + **UMP rıza formu**. Reklam katmanından (Adım 6) **önce** yapılmalı — KVKK gereği rıza alınmadan kişiselleştirilmiş reklam gösterilemez.

### 6. Adım 6 — reklam katmanı, 7 — kalan ekranlar

---

### İlk turda çalıştırılacak komutlar

```bash
cd sinav_odak

# Platform klasörleri YOK — önce üret
flutter create --org com.harunsezen --project-name sinav_odak \
  --platforms=android,ios .
# pubspec.yaml ezilirse yedekten geri koy

flutter pub get
dart run build_runner build --delete-conflicting-outputs   # *.g.dart burada oluşur
flutter analyze     # beklenen: 0 error, 0 warning
flutter test        # beklenen: 353/353
```

### `flutter create` sonrası ZORUNLU eklemeler

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

`android/app/build.gradle` — **bu olmadan derleme kırılır**:
```gradle
compileOptions { coreLibraryDesugaringEnabled true }
dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.2' }
```

Linux'ta test hatası alırsan: `sudo apt install libsqlite3-dev`

---

## 5. KURALLAR — DEĞİŞMEZ

### Mimari

1. **Sayaç `Timer` tabanlı olamaz.** Doğruluk kaynağı mutlak zaman damgalı çizelge + `resolve(now)`. UI ticker yalnızca görseldir, state'i **ilerletmez**.
2. **`domain/` altında Flutter, Drift, Riverpod import edilemez.** Doğrulama: `grep -rE "import 'package:(flutter|drift|flutter_riverpod)" lib/domain/` → boş olmalı.
3. **Domain servisler `DateTime.now()` çağırmaz.** Tüm zamanlar parametre olarak gelir.
4. **`presentation/` katmanı `data/`'ya doğrudan erişemez.** Drift tipleri tip çıkarımıyla tüketilir. Doğrulama: `grep -rn "import '.*data/" lib/presentation/` → boş olmalı.
5. **`data/` katmanı `domain/services/` import edemez.**
6. **`schedule_json` ve `session_blocks` DAİMA birlikte güncellenir** — yalnızca `ScheduleWriter` üzerinden.
7. **WorkManager kullanılmaz.**

### Ürün

8. **Pause butonu YOKTUR ve eklenmeyecektir.** Yalnızca "Oturumu Bitir" var ve onay ister. `run_screen_test.dart` bunu koruyor: `Durdur`, `Duraklat`, `Icons.pause*` hepsi `findsNothing`.
9. **Aktif çalışma bloğu sırasında tam ekran reklam ASLA gösterilmez.** Bu kontrol `AdGateway` implementasyonunun **içinde** olmalı, çağıran katmanda değil.
10. **Oturum sonu formunda reklam YOKTUR.** Kullanıcı veri girerken bölünmez.
11. **Tüm reklamlar sessiz başlar.** `setAppMuted(true)`.
12. **Uygulama %100 ücretsiz.** Hiçbir temel özellik kilitlenmez, abonelik yok.
13. **Ders ve konu silinmez, arşivlenir.**
14. **Geri tuşu run katmanında yakalanır**; kullanıcı kazara çıkamaz.
15. **Alt navigasyon run ve setup katmanlarında gizlidir** (route'lar shell dışında).
16. **Hedef yaş 13+** (Play Console). KVKK/GDPR rıza akışı zorunlu.

### Sözleşmeler (bozulamaz)

17. `BlockType.study` ↔ `"study"`, `BlockType.breakTime` ↔ `"break"`
18. `sk` / `ex` yalnızca varsayılan değilse JSON'a yazılır
19. **Focus formülü SABİTTİR.** `earlyFinished` %60 senaryosu **62** üretir. Değiştirmek isterseniz önce ürün kararı alın
20. Net formülü: `net = doğru - (yanlış / katsayı)`, katsayı ayardan gelir
21. Mola uzatma limiti toplam **+600 sn**, oturum geneli (tek mola için değil)
22. `dateKey` oturumun **başladığı** yerel güne yazılır (gece yarısı kuralı)
23. Kurtarılan oturum **düşük ama dürüst** skor alır; sahte veri üretilmez

### Test

24. **Testlerde `DateTime.now()` YASAK.** Sabit epoch: `const int t0 = 1754467200000;`
25. **Widget/entegrasyon testlerinde `clockProvider` override edilir.**
26. Her test kendi DB'sini kurar (`NativeDatabase.memory()`); paylaşılan mutable state yok.
27. Widget testlerinde gerçek `GoRouter` kullanılır (`context.go` çağrıldığı için).
28. Test adları Türkçe ve açıklayıcı.
29. **Testler davranışı test eder, implementasyonu değil.**

### Süreç — ALTIN KURAL

30. **Kod yazılan her turda şu dördü çalıştırılır ve TAM çıktı rapora eklenir:**
    ```
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
    flutter analyze
    flutter test
    ```
31. **`flutter test` çalıştırılmadan "bitti" denmez.** `analyze` temiz olsa bile derleme hatası ancak testte ortaya çıkar — bu bizzat yaşandı (bkz. aşağıdaki tuzak).
32. Mevcut testler bozulmaz. Bir test bilinçli olarak değiştirilecekse **gerekçesi koda yorum olarak yazılır**.
33. Emin olunmayan yerde **"doğrulanmalı"** denir; varsayım kanıt gibi sunulmaz.

---

## 6. ÖNCEDEN YAŞANMIŞ TUZAKLAR

Bu hatalar bir kez yapıldı; tekrarlanmasın:

**`flutter analyze` üretilen kodu İNCELEMEZ.** `analysis_options.yaml` içindeki `exclude: **/*.g.dart` yüzünden `database.g.dart` içindeki `'SessionStatus' isn't a type` hatası analizden temiz geçti ama derleme patladı. **`analyze` tek başına yeterli değildir.**

**`database.dart` part dosyasının ihtiyaç duyduğu importları yapmak zorunda.** Part dosyaları kendi import'unu yapamaz, kütüphane kapsamını kullanır. `enums.dart` ve `block_type_converter.dart` importları kaldırılırsa üretilen kod derlenmez ve `analyze` bunu yakalamaz.

**`library;` direktifi tüm direktiflerden ÖNCE gelmek zorunda.** Doc yorumuyla birlikte import'ların altına yazılırsa `build_runner` tamamen durur.

**`find.byType` alt sınıfları yakalamaz.** `OutlinedButton.icon` `_OutlinedButtonWithIcon` üretir; `find.byType(OutlinedButton)` onu bulmaz. `find.text(...)` veya `find.byWidgetPredicate(...)` kullanın.

**`PopScope` jeneriktir ve GoRouter kendi `PopScope`'unu ekler.** `find.byWidgetPredicate((w) => w is PopScope && !w.canPop)` kullanın.

**`ListView.builder` uzun listelerde alt öğeleri render etmez.** Matematik'in 24 konusu var; 23. sıradaki "Türev" widget testinde bulunamaz. Görünür öğe kullanın veya `scrollUntilVisible`.

**`main()` içinde getter tanımlanamaz.** `SetupNotifier get n => ...` derlenmez; fonksiyona çevirin.

**grep kontrollerinde yorum satırlarını ayıklayın.** `DateTime.now()` ve `finishSession` "ihlalleri" üç kez yanlış alarm verdi; hepsi dartdoc'ta geçiyordu. `| grep -v "///"` ekleyin.

**Drift `isNull`/`isNotNull` matcher'larla çakışır.** Test dosyalarında `import 'package:drift/drift.dart' hide isNotNull, isNull;`


---

# EK A — VERİTABANI ŞEMASI (referans)

`schemaVersion = 1`. Tüm zaman damgaları **epoch milisaniye INTEGER**
(Drift'in `DateTime` dönüşümü saniye çözünürlüğünde olduğu için kullanılmadı).

## FK davranış matrisi

| İlişki | onDelete | Gerekçe |
|---|---|---|
| `topics.subject_id → subjects.id` | `cascade` | Ders zaten silinmiyor, arşivleniyor |
| `study_sessions.subject_id → subjects.id` | `restrict` | Geçmiş istatistik korunmalı |
| `study_sessions.topic_id → topics.id` | `setNull` | Konu kaybolsa oturum kalsın |
| `study_sessions.activity_type_id → activity_types.id` | `restrict` | |
| `session_blocks.session_id → study_sessions.id` | `cascade` | Bloklar oturuma ait |
| `wrong_items.session_id → study_sessions.id` | `setNull` | + repository `source`'u `manual`'e çevirir |
| `wrong_items.subject_id → subjects.id` | `restrict` | |
| `wrong_items.topic_id → topics.id` | `setNull` | |

> `PRAGMA foreign_keys = ON` `beforeOpen`'da açılıyor — SQLite'ta varsayılan
> KAPALI. Bunu kaldıran biri tüm CASCADE davranışını sessizce iptal eder.

## Tablolar

**`user_settings`** (tek satır, `id = 'me'`)
`createdAt` · `examType` (yks) · `dailyGoalMinutes` (240) · `dailyGoalQuestions` (100) ·
**`netPenaltyCoefficient` (4.0)** · `notificationEnabled` · `soundEnabled` ·
`vibrationEnabled` · `keepScreenOn` · `themeMode` (system) ·
`showAdsInFocusScreen` (true) · **`personalizedAdsConsent` (false — KVKK)** ·
`onboardingCompleted` (false) · `currentStreak` · `longestStreak` · `lastStudyDate`

**`subjects`** — `id` · `name` · `colorHex` · `examType` · `sortOrder` ·
`isArchived` · `isDefault` · `createdAt`

**`topics`** — `id` · `subjectId` · `name` · `isCompleted` · `completedAt` ·
`targetQuestionCount` · `sortOrder` · `isArchived` · `createdAt`
*index:* `idx_topics_subject`

**`activity_types`** — `id` · `name` · **`iconKey` (TEXT)** · `isDefault` ·
`isArchived` · `sortOrder`

> `iconKey` TEXT çünkü sabit olmayan `IconData` kullanımı Flutter'ın
> `--tree-shake-icons` derlemesini kırıyor.

**`study_sessions`** — `id` · **`dateKey`** · `startedAt` · `endedAt` ·
`plannedDurationS` · `actualDurationS` · `totalBreakS` · `subjectId` ·
`topicId?` · `activityTypeId` · `status` · `focusScore?` ·
**`foregroundS` · `awayS` · `exitCount`** (dürüst odak ölçümü) ·
`questionCount` · `correctCount` · `wrongCount` · `emptyCount` · `net` ·
`mood?` · `note?` · **`scheduleJson`**
*index:* date, status, subject, topic

**`session_blocks`** — `id` · `sessionId` · `indexNo` ·
**`type` (BlockTypeConverter → "study"/"break")** · `plannedStartAt` ·
`plannedEndAt` · `actualEndAt?` · `plannedS` · `actualS` · `wasSkipped` ·
`extendedS`
*index:* `idx_blocks_session`

**`daily_stats`** (PK `dateKey`) — `totalStudyS` · `totalBreakS` ·
`sessionCount` · `questionCount` · `correctCount` · `wrongCount` ·
`emptyCount` · `net` · `avgFocusScore` · `subjectBreakdownJson`

> Denormalize. `StatsDao.recomputeDay()` ile yeniden hesaplanır; çağrı
> **yalnızca** `SessionRepository` içinden yapılır (save/delete/markInterrupted).

**`wrong_items`** — `id` · `createdAt` · `sessionId?` · `subjectId` ·
`topicId?` · `wrongCount` · `note?` · `status` (active/reviewed/mastered) ·
`reviewedAt?` · `source` (auto/manual)
*index:* status, subject, session

**`goals`** — `id` · `type` · `targetValue` · `currentValue` · `subjectId?` ·
`startDate` · `endDate?` · `status` · `createdAt`

**`achievements`** — `id` · `code` (unique) · `unlockedAt` · `isSeen`

**`ad_events`** — `id` · `adKind` · `placement` · `screenName` · `shownAt` ·
`wasCompleted` · `wasClicked` — *30 günden eskiler açılışta silinir*

**`app_state`** — `key` / `value`

## Seed verisi

5 sınav türü · 51 ders · 152 konu · 11 çalışma türü.
ID'ler sabit ve okunabilir: `sub_yks_1` (Matematik), `top_sub_yks_1_22`
(Türev), `act_soru`. **Idempotent** (`insertOrIgnore`) — `beforeOpen`
kurtarma yolundan yeniden çağrılabilir.

---

# EK B — FORMÜLLER (kod ile birebir)

## Odak skoru — DEĞİŞTİRİLEMEZ

```
1) completion = (actualDurationS / plannedDurationS).clamp(0,1)   -> 55 puan
   plannedDurationS == 0 ise completion 0 (hata değil)
2) presence   = (foregroundS / actualDurationS).clamp(0,1)        -> 25 puan
   actualDurationS == 0 ise presence 0
3) exit       = 10 * (1 - (exitCount / 6).clamp(0,1))             -> 10 puan
4) compliance = 1 - (extendedBreakS / totalPlannedBreakS).clamp(0,1) -> 10 puan
   totalPlannedBreakS == 0 ise compliance 1.0
5) çarpan: completed 1.00 | earlyFinished 0.80 | interrupted 0.55
   running -> null (skor hesaplanmaz)

sonuç = (toplam * çarpan).round().clamp(0, 100)
```

**Kilit senaryo:** `earlyFinished`, actual 2160 / planned 3600, fg 2160,
exit 0, ext 0, totalBreak 600 → `33 + 25 + 10 + 10 = 78`, `× 0.80 = 62.4` →
**62**. Bu değer `focus_score_test.dart` içinde sabitlenmiştir.

**Streak bonusu skora DAHİL DEĞİLDİR** — skor tek bir oturumun dürüst
ölçümüdür, streak ayrıca gösterilir.

## Net

```
net                = correct - (wrong / coefficient)     // katsayı ayardan, varsayılan 4.0
successRate        = correct / (correct + wrong + empty)
solutionSpeed      = questionCount / (actualDurationS / 3600)
secondsPerQuestion = actualDurationS / questionCount
questionCount == 0 -> NetResult.empty
```

## Blok bölme — DAKİKA bazında

```
base = totalStudyMinutes ~/ studyBlocks
rem  = totalStudyMinutes %  studyBlocks
base < 10 -> PlanFailure
İlk `rem` blok (base + 1) dakika, diğerleri base dakika. Sonra saniyeye çevrilir.

120 dk / 5 blok -> [24,24,24,24,24]
100 dk / 4 blok -> [25,25,25,25]
101 dk / 4 blok -> [26,25,25,25]   <- saniye bazlı bölme 25dk15sn x4 üretirdi
```

`fromEndTime`'da artık saniyeler (`studyS % 60`) **son çalışma bloğuna**
eklenir; `plannedEndAtMs == alignToSecond(endAtMs)` garanti.

## Mola atlama — `extendedS` düşürme

```
originalS   = target.seconds - target.extendedS
newSeconds  = (alignedNow - target.startMs) ~/ 1000
newExtendedS = max(0, newSeconds - originalS)
```

Kullanıcı +5 dk uzatıp hemen bitirirse kullanmadığı uzatma odak skorunda
ceza olarak yazılmaz.

## Sabitler

| Sabit | Değer | Yer |
|---|---|---|
| `clockSkewToleranceMs` | 3000 | `ScheduleResolver` |
| `minStudyBlockMinutes` | 10 | `ScheduleBuilder` |
| `maxStudyBlockS` | 7200 (uyarı eşiği, **>** ile) | `ScheduleBuilder` |
| `maxTotalExtensionS` | 600 (oturum geneli) | `ScheduleModifier` |
| `maxBlocksPerSession` | 64 | `NotificationPlanner` |
| `currentVersion` | 1 | `SessionSchedule` |

## Çizelge JSON sözleşmesi

```json
{
  "version": 1,
  "createdAt": 1754467200000,
  "blocks": [
    {"i": 0, "type": "study", "start": 1754467200000, "end": 1754468640000, "s": 1440},
    {"i": 1, "type": "break",  "start": 1754468640000, "end": 1754468940000, "s": 300}
  ],
  "totalStudyS": 4320,
  "totalBreakS": 600,
  "plannedEndAt": 1754472120000
}
```

`sk` (skipped) ve `ex` (extendedS) **yalnızca varsayılan değilse** yazılır.

`validate()` 11 kural: version · boş blok · `start >= end` ·
`s != (end-start)/1000` · saniyeye hizalı değil · ardışık değil · `i` sırası ·
`totalStudyS` · `totalBreakS` · `plannedEndAt` · negatif değer · çalışma
bloğunda `sk`/`ex`.

---

# EK C — YAZILMAMIŞ EKRANLARIN TASARIMI

Adım 5–7'de yapılacak ekranların ürün tasarımı. Bu kararlar alınmış durumda.

## S10 — Oturum Sonu Formu (iskelet var, doldurulacak)

Üst: "Oturum tamamlandı ✓" + ders·konu + süre
Soru sayacı: `[+5] [+10] [+20] [Sıfırla]` + elle giriş
Doğru (yeşil) / Yanlış (kırmızı) / Boş (gri) — `[−] sayı [+]`
**Canlı net** (28sp) · Duygu seçici 5 emoji · Not alanı (opsiyonel)
**REKLAM YOK.**

## S11 — Tebrik

Odak skoru animasyonu · günlük ilerleme · `[Yeni oturum] [Ana panel]`
Reklam **yalnızca kayıt TAMAMLANDIKTAN sonra** gösterilebilir.

## S18 — Kurtarma diyaloğu

"Oturum yarıda kesildi" / "Son kayıtlı süre: 34 dakika" → `[Sil] [Kaydet]`
Modal; altta ana panel görünür.

## S03 — Ana Panel (tam hali)

İlerleme halkası (bugünkü süre / hedef) · 3'lü mini kart (soru, net, odak) ·
streak rozeti · hızlı başlat (son kombinasyon) · son 5 oturum ·
büyük CTA · üst banner + orta native kart.

## Yanlış Defteri

3 sekme: **Aktif** · Tekrar Edildi · Öğrenildi
Kart: ders renk şeridi · ders · konu · "12 yanlış" · not
Aksiyonlar: **[Bu konuyu çalış]** (kurulum akışına konu dolu gider) ·
**[Öğrendim]** → `mastered`
Sekme rozeti: `WrongItemDao.activeCount()`

## İstatistik

Dönem sekmeleri (Günlük/Haftalık/Aylık) · özet kartları · 7 grafik
(çizgi: günlük süre, bar: ders, pasta: dağılım, çizgi: net gelişimi,
ısı haritası, sütun: D/Y/B, radar: ders bazlı güç-zayıflık) ·
kırılım tabloları · filtre FAB.
`fl_chart` pubspec'te hazır. **Radar MVP'de opsiyonel.**

## Takvim

Ay grid'i (yoğunluk renkli) · gün detay sheet'i · oturum listesi.

## Onboarding (5 adım)

1. Vaat · 2. Sınav türü · 3. Günlük hedef · 4. **UMP rıza formu (KVKK)** ·
5. Bildirim izni (reddedilirse akış DURMAZ)

---

# EK D — REKLAM KATMANI TASARIMI (Adım 6)

Kararlar alınmış; kod yazılmadı. `ad_events` tablosu hazır, yazan yok.

## Yerleşim matrisi

| Ekran | Format | Tetikleyici | Gösterilmez |
|---|---|---|---|
| Ana Panel | Adaptive banner (üst) + native kart (orta) | ekran açılışı | aktif oturum varken native |
| Kurulum (S04–S07) | Alt banner | ekran açılışı | — |
| **Başlat anı** | — | — | **HİÇ** (bkz. aşağıda) |
| Aktif çalışma (S08) | İnce banner, kontrol çubuğunun **16dp üstünde** | oturum başlangıcı | ayarda kapalıysa; blok < 15 dk |
| Mola (S09) | **Büyük native**, 1200 ms gecikmeli | mola başlangıcı | mola < 3 dk |
| Mola (S09) | Interstitial | mola ≥ 10 dk **ve** cooldown | günlük limit dolu |
| **Oturum sonu (S10)** | — | — | **HİÇ** |
| Tebrik (S11) | Interstitial veya native | **kayıt TAMAMLANDIKTAN sonra** | rozet kazanıldıysa native'e düş |
| İstatistik | Alt banner + liste arası native | scroll | grafiği kapatacaksa |

## Frekans motoru

```
interstitialCooldown   = 10 dakika
maxInterstitialsPerDay = 5
firstLaunchGrace       = 24 saat (yeni kullanıcıya interstitial yok)
```

## Mutlak kurallar (kod seviyesinde)

1. `SessionState.isInStudyBlock` iken tam ekran reklam **HER ZAMAN** engellenir.
   Bu kontrol **`AdGateway` implementasyonunun İÇİNDE** olmalı — çağıran
   katmanda değil. `SessionState.isInStudyBlock` getter'ı bunun için var.
2. Oturum sonu formunda hiçbir reklam yok.
3. Tüm video reklamlar `setAppMuted(true)` ile başlar.
4. Reklam yüklenemezse akış **beklemez**; 2 sn timeout, `SizedBox.shrink()`.
5. Reklam ile en yakın buton arası **minimum 48dp**.
6. Her reklam alanının üstünde "Sponsorlu" etiketi.

## Neden pre-start interstitial YOK

AdMob'da interstitial **atlanamaz** (atlanabilir olan tek format rewarded
interstitial, 5 sn). Kullanıcının bir eylemi başlatmak için butona bastığı
anda çıkan interstitial, Google'ın "beklenmeyen reklam" kategorisine girer
ve hesap askıya alınma riski taşır. Ayrıca ürünün tek vaadi olan
"odaklanmanı kolaylaştırırım" sözünü en yüksek niyetli anda bozar.

## Rewarded ödülleri (hiçbiri temel özellik değil)

24 saat reklamsız mola · 7 gün özel tema · 1 PDF rapor · özel sayaç
görünümü · destek rozeti. Dil: **"İzle ve destekle"**, asla
"izlemezsen X yapamazsın".

## Gerçekçi gelir (TR)

banner eCPM 0.30–1.00 USD · native/interstitial 1.50–4.00 USD ·
ARPDAU 0.004–0.012 USD. **10.000 DAU ≈ günlük 40–120 USD.**
Bunu bilmek agresif reklam koyma dürtüsünü engeller.

---

# EK E — YASAL VE MAĞAZA GEREKSİNİMLERİ

| Konu | Karar | Gerekçe |
|---|---|---|
| **Play hedef yaş** | **13+** | "Karma yaş" seçilirse Families politikası kişiselleştirilmiş reklamı kapatır, eCPM ciddi düşer |
| **UMP rıza akışı** | **Zorunlu**, reklamdan önce | KVKK/GDPR |
| `personalizedAdsConsent` | Varsayılan **false** | Rıza alınmadan kişiselleştirme yok |
| Ayarlarda "rıza tercihimi değiştir" | Zorunlu | KVKK/GDPR |
| **VERBIS kaydı** | **Gerekmiyor** | Tek geliştirici, eşik altı, özel nitelikli veri yok, veri cihazda |
| Gizlilik politikası URL | **Zorunlu** (Play) | GitHub Pages yeterli |
| `com.google.android.gms.permission.AD_ID` | Manifest + Data Safety beyanı | Play zorunlu |
| `USE_EXACT_ALARM` | Timer uygulaması olarak izinli | Console'da gerekçe yazılmalı |
| Veri silme + dışa aktarma | Zorunlu | KVKK madde 11 |

**Geliştirme boyunca yalnızca test ad unit ID'leri:**
`ca-app-pub-3940256099942544/...` · **Kendi reklamına asla tıklama** —
hesap kapanır. Production ID'leri `--dart-define` ile geçilir, koda girmez.

> AdMob hesabı ebeveyn adına açıldığı için politika ihlali riski normalden
> pahalı.

---

# EK F — ALINMIŞ ÜRÜN KARARLARI (kayıt)

Tartışmaya kapalı; değiştirilecekse önce ürün kararı alınmalı.

| # | Karar |
|---|---|
| 1 | Pause yok; yalnızca "Oturumu Bitir" ve onay ister |
| 2 | Pre-start interstitial **kaldırıldı** |
| 3 | Aktif çalışma bloğunda tam ekran reklam **asla** |
| 4 | Oturum sonu formunda reklam **yok** |
| 5 | `foregroundS` ölçülmez, `actualDurationS - awayS` olarak hesaplanır |
| 6 | `inactive` lifecycle durumu **çıkış sayılmaz** (bildirim paneli, gelen arama) |
| 7 | Kurtarılan oturum **düşük ama dürüst** skor alır; sahte veri üretilmez |
| 8 | `interrupted` oturum istatistiklere **sayılır** |
| 9 | `earlyFinished` oturum streak ve hedefe **sayılır** |
| 10 | Mola uzatma limiti **oturum geneli** +600 sn (tek mola için değil) |
| 11 | `skipBreak` sonrası `extendedS` gerçekten kullanılana düşürülür |
| 12 | `skipBreak` tam bitiş anında da hata verir (`>=`) |
| 13 | Focus formülü **sabit**; `earlyFinished` %60 → 62 |
| 14 | Net katsayısı **parametre** (varsayılan 4.0, alternatif 3.0) |
| 15 | `mastered` yanlış kaydı yeni yanlış gelince `active` olur |
| 16 | `wrongCount = 0` → otomatik yanlış kaydı **silinir** |
| 17 | Oturum silinince yanlış kaydı `manual`'e dönüşür, silinmez |
| 18 | Ders ve konu **silinmez, arşivlenir** |
| 19 | `dateKey` oturumun **başladığı** güne yazılır |
| 20 | Bitiş saati geçmişteyse **otomatik yarına taşınmaz**, hata gösterilir |
| 21 | Setup state `autoDispose` değil; `reset()` açıkça çağrılır |
| 22 | `SessionState.beforeStart` resolver'dan **asla** dönmez |
| 23 | Saat toleransı 3000 ms (NTP sıçraması `clockMovedBack` sanılmasın) |
| 24 | SQLCipher/AES **yok** |
| 25 | WorkManager **yok** |
| 26 | Uygulama %100 ücretsiz; hiçbir temel özellik kilitlenmez |

---

# EK G — GELİŞTİRME ORTAMI NOTLARI

- **Flutter 3.24.5 stable** ile derlendi ve test edildi. Daha yeni sürümde
  `Color.withValues` gibi API'ler açılır; `break_screen.dart` şu an
  `withOpacity` kullanıyor (3.24'te `withValues` yok).
- `pubspec.yaml`'da `google_mobile_ads` **yorumda**. Açılırsa
  `AndroidManifest.xml`'e `com.google.android.gms.ads.APPLICATION_ID`
  meta-data'sı **aynı commit'te** eklenmeli — yoksa uygulama **açılışta çöker**
  (SDK ContentProvider kontrolü yapıyor).
- Linux'ta test için `libsqlite3.so` bağı gerekebilir:
  `sudo apt install libsqlite3-dev`
- 52 adet `info` seviyesi lint var (`require_trailing_commas`,
  `prefer_const_*`). `dart fix --apply` ile çoğu düzelir; henüz
  çalıştırılmadı çünkü diff'i büyütüp incelemeyi zorlaştırıyor.
- `git` deposu **private** planlanıyor. Depoyu sonradan private yapmak,
  o ana kadar açıkta kalmış commit'leri geri almaz — reklam ID'leri ve
  `google-services.json` **hiçbir zaman** commit edilmemeli.
