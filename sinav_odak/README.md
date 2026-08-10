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
