# FAZ 7A — AYARLAR + İSTATİSTİK · İŞÇİ RAPORU

**Tarih:** 10 Ağustos 2026
**Faz:** 7A (kapsam a + b)
**Durum:** TAMAM

> **Bölme kararı.** Koordinatör "kapsam büyük gelirse 7A (Ayarlar+Stats) /
> 7B (Calendar+Goals+achievements) diye ikiye böl" dedi. Kapsam büyüktü:
> yalnızca 7A **6 yeni ekran/bileşen, 5 yeni application/domain sınıfı ve
> 81 test** getirdi. Bu teslim **7A**'dır; 7B ayrı teslim edilecek.

---

## 1. TEK BAKIŞTA

| Ölçüt | Sonuç |
| --- | --- |
| **Test** | **622 / 622 geçti** (eşik ≥541 — **+81**) |
| **analyze** | **No issues found!** — 0 error · 0 warning · **0 info** |
| **build_runner** | 1044 çıktı, 2350 aksiyon, hatasız |
| **G3–G8 + G12** | tamamı temiz (G4b bu turda ihlal edildi ve **düzeltildi**, §6) |
| **ARB anahtarı** | 39 → **130** |

---

## 2. YAPILAN İŞ

### (a) Ayarlar — tamamı ✅

`SettingsScreen` baştan yazıldı. FAZ 5'in "Destek ol" ve FAZ 6'nın
"Gizlilik tercihleri" kartlarına **dokunulmadı** (talimat gereği).

| Bölüm | İçerik |
| --- | --- |
| **Görünüm** | Tema (sistem/açık/koyu) · ekran açık kalsın |
| **Çalışma** | Net katsayısı (3/4/5) · günlük hedef (30 dk adımlarla, 30–720) |
| **Bildirim ve ses** | Bildirim · ses · titreşim |
| **Ders ve konular** | Katalog yönetim ekranına geçiş |
| **Destek ol** | *(FAZ 5 — değişmedi)* |
| **Gizlilik tercihleri** | *(FAZ 6 — değişmedi)* |
| **Veri** | Çift onaylı sıfırlama |
| **Hakkında** | Sürüm · gizlilik metni · **test reklam kimliği uyarısı** |

**Karar — ayar gelmeden ekran çizilmiyor.** `settings == null` iken
yükleniyor göstergesi var. Anahtarları varsayılan değerle çizmek,
kullanıcının kapattığı bir ayarı bir an açık göstermek demekti.

**Karar — bildirim kapalıysa ses/titreşim PASİF.** Kapalı bir bildirimin
sesi olmaz; açık bırakmak çalışmayan bir düğme sunmaktı.

#### Net katsayısı + `RecomputeNetsUseCase`

En kritik parça. `study_sessions.net` **denormalize**: oturum kaydedilirken
o anki katsayıyla hesaplanıp yazılıyor. Katsayı değişince geçmiş satırlar
eski değerde kalıyordu — istatistik ekranı **iki farklı katsayının
karışımını** tek bir "toplam net" gibi gösteriyordu ve hata **sessizdi**.

Akış:
1. Kullanıcı 4 → 3 seçer
2. **Onay diyaloğu**: "geçmiş oturumların netleri de bu katsayıyla yeniden
   hesaplanır"
3. Onaylanırsa: ayar yazılır → tüm tamamlanmış oturumların neti yeniden
   hesaplanır → **etkilenen günlerin `daily_stats` özeti yeniden üretilir**
4. "142 oturumun neti güncellendi" bildirimi

İkinci adım (günlük özet) olmadan oturum satırları düzelir ama **grafikleri
besleyen özet eski değerde kalırdı**.

Sıra bilinçli — ayar ÖNCE yazılıyor: yeniden hesaplama yarıda kalsa bile
kullanıcının seçtiği katsayı kayıtlı kalır ve bundan sonraki oturumlar doğru
hesaplanır. Hepsi tek transaction: yarıda kalırsa toplam net hiçbir
katsayıya karşılık gelmezdi.

Katsayı **serbest metin değil** (3/4/5 seçenekleri): 0 veya negatif katsayı
`NetCalculator`'ı `ValidationFailure` ile patlatıyor.

#### Çift onaylı veri sıfırlama

1. Ne silineceğini anlatan uyarı → *Devam et*
2. **`SIFIRLA` kelimesini elle yazma** → *Kalıcı olarak sil*

İkinci adım bilinçli olarak yazma gerektiriyor: arka arkaya iki kez
"onayla"ya basmak refleks hâline gelebiliyor, kelime yazmak gelmiyor.
(Büyük/küçük harf duyarsız — niyet aynı, klavyeyle savaştırmanın anlamı yok.)

`AppDatabase.resetAllData()` foreign key zincirini izleyerek siliyor (çocuk
tablolar önce), sonra **seed'i ve ayar satırını yeniden kuruyor**.
`onboardingCompleted` sıfırlandığı için router kendi kuralıyla
`/onboarding`'e götürüyor — ekrandan ayrıca `go` çağırmak iki yönlendirmenin
yarışması olurdu.

#### Katalog yönetimi (`CatalogScreen`)

Ders / konu / çalışma türü **ekleme ve düzenleme**. İki sekme (Dersler,
Türler) + arşivlenmişleri gösterme anahtarı.

**SİLME YOK — G8.** Arşivleme var. Silinen ders geçmiş oturumların bağlı
olduğu satırı yok eder; şemada `onDelete: restrict` zaten izin vermiyor.
Arşivlenen kayıt oturum kurulumunda görünmez, geçmiş istatistikler sağlam
kalır. Test bunu iki yönden doğruluyor: ekranda silme ikonu **yok**, ve
arşivlenen ders `subjectsProvider`'da **görünmüyor** ama veritabanında
**duruyor**.

`SubjectDao.watchSubjects/watchTopics/watchActivityTypes` metotlarına
`includeArchived` parametresi eklendi — yalnızca yönetim ekranı `true`
geçiyor.

### (b) İstatistik ✅

- **Hafta / Ay** aralık seçimi
- **Özet kartları**: toplam çalışma, oturum sayısı, net, ortalama odak,
  başarı oranı
- **fl_chart günlük çubuk grafiği** (ay görünümünde etiketler seyreltiliyor)
- **Ders dağılımı**: süreye göre oransal çubuklar, ders renkleriyle
- **Gelişim gereken konular**: en çok yanlış yapılan 5 konu
- **Boş durum**: kayıt yoksa grafik yerine açıklayıcı ekran
- **CSV dışa aktarma** (paylaşım sayfası)

Kaynak `daily_stats` — oturum kaydedildikçe `recomputeDay` ile güncellenen
denormalize özet. Grafik için ham oturumları taramaya gerek yok.

**Saat `clockProvider`'dan.** `DateTime.now()` doğrudan çağrılsaydı
istatistik ekranı test edilemezdi; aralık testleri sabit `t0`'a dayanıyor.

#### CSV — kararlar

`CsvBuilder` **saf domain**: dosya sistemi ve paylaşım yok, yalnızca metin
üretimi. Kaçış kuralları platformdan bağımsız test ediliyor.

| Karar | Gerekçe |
| --- | --- |
| Ayraç `;` | Excel TR yerelinde `,` ayraçlı dosyayı tek sütuna yapıştırıyor |
| Ondalık `28,50` | TR yerelinde ondalık ayracı virgül |
| **BOM** ile başlıyor | Olmadan Excel `ğ ş İ` karakterlerini bozuyor |
| RFC 4180 kaçışı | Kullanıcının serbest "not" alanı ayraç/tırnak/satır sonu içerebiliyor |
| Kayıt yoksa yalnızca başlık | Boş dosya "dışa aktarma bozuk" hissi veriyor — ayrıca ekran zaten uyarı gösteriyor |
| Ders/konu **adı**, kimliği değil | Dışa aktarılan dosya kullanıcı için okunabilir olmalı |

`ShareGateway` port'u var çünkü `share_plus` + `path_provider` platform
kanalı istiyor; testte çağrılırsa akış hiç tamamlanmıyor. Varsayılan
`NoopShareGateway`, `main()` gerçek cihazda `FileShareGateway` ile override
ediyor.

### (f) L10n ✅

ARB **39 → 130 anahtar**. **7A'nın yeni ekranlarındaki metinlerin tamamı
ARB'den** — grep ile doğrulandı (§7). Eski gömülü metinlere dokunulmadı
(talimat). `app_en.arb` iskelet olarak senkron tutuldu (S16 hâlâ geçerli).

---

## 3. DOĞRULAMA — 4 KOMUT

```
$ flutter pub get
Got dependencies!

$ dart run build_runner build --delete-conflicting-outputs
[INFO] Succeeded after 39.3s with 1044 outputs (2350 actions)

$ flutter analyze
Analyzing sinav_odak...
No issues found! (ran in 7.5s)

$ flutter test
00:50 +622: All tests passed!        (EXIT=0)
```

**Severity sayımı** (yorum tuzağına düşmeyen desen):

```
error: 0
warning: 0
info: 0
```

> FAZ 6 sonunda 37 info kalmıştı; bu turda `dart fix --apply` + `dart format`
> ile ağaç **tamamen temizlendi**.

---

## 4. TEST SAYISI

| Faz sonu | Test |
| --- | --- |
| FAZ 6 | 541 |
| **FAZ 7A** | **622** (+81) |

| Yeni dosya | Test |
| --- | --- |
| `test/unit/csv_builder_test.dart` | 17 |
| `test/unit/recompute_nets_test.dart` | 10 |
| `test/unit/reset_data_test.dart` | 9 |
| `test/widget/settings_screen_test.dart` | 18 |
| `test/widget/stats_screen_test.dart` | 12 |
| `test/widget/catalog_screen_test.dart` | 15 |

**Mevcut 541 testin hiçbiri düşmedi.** Bir test **düzeltildi**, zayıflatılmadı:
`router_redirect_test` içindeki "release dalı Ayarlar ekranını gösteriyor"
testi, Ayarlar ekranı uzadığı için `settings-support` kartını bulamıyordu —
`ListView` tembel kurduğundan kart varsayılan 800×600 yüzeyin altında hiç
oluşturulmuyordu. İddia aynı kaldı, test yüzeyi 1200×3000'e çıkarıldı.

---

## 5. KODDA BULUNAN VE DÜZELTİLEN GERÇEK HATALAR

**1. `TextEditingController` kapanma animasyonu sırasında dispose ediliyordu.**
`showDialog(...).whenComplete(controller.dispose)` deseni katalog ekranındaki
ad diyaloğunda çöküyordu:

```
A TextEditingController was used after being disposed.
```

`whenComplete`, diyaloğun **kapanma animasyonu bitmeden** çalışıyor; TextField
hâlâ build edilirken controller ölüyor. 12 test bu yüzden düştü. Controller
`State` içine taşındı (`_NameDialog`), ömrü widget'a bağlandı.

**2. `SegmentedButton` seçili değer segmentlerde yoksa assertion atıyor.**
Veritabanında 3/4/5 dışında bir katsayı olsaydı (eski sürüm, elle düzenleme)
**Ayarlar ekranının tamamı çökerdi**. `_nearestOption` ile en yakın seçeneğe
düşülüyor.

**3. `RecomputeNetsUseCase` yanlış sayı döndürüyordu** — "güncellenen oturum
sayısı" yerine toplam oturum sayısını veriyordu. Kullanıcıya gösterilen
bildirim yanlış olurdu; sayaç eklendi.

---

## 6. G4 İHLALİ — BULUNDU VE DÜZELTİLDİ (dürüstlük notu)

İlk grep turunda **G4b = 5** çıktı. Bu bir yanlış alarm DEĞİLDİ; ihlal
bendeydi. Yeni ekranlarım `data/local` katmanına uzanıyordu:

```
lib/presentation/stats/stats_screen.dart          -> daos/stats_dao.dart, database.dart
lib/presentation/settings/catalog_screen.dart     -> database.dart
lib/presentation/settings/settings_screen.dart    -> database.dart
lib/presentation/settings/widgets/net_coefficient_tile.dart -> database.dart
```

Sebepleri ve düzeltmeleri:

| Sızıntı | Düzeltme |
| --- | --- |
| Ekranlar `UserSettingsCompanion` (Drift üretilmiş tip) kuruyordu | **`SettingsController`** (application) — `setThemeMode`, `setKeepScreenOn`, `setNetCoefficient`… |
| `stats_screen` doğrudan `statsDao.exportRows` çağırıyordu | **`ExportSessionsUseCase`** — ekran aralığı verir, `ExportOutcome` alır |
| Widget'lar `Subject` / `DailyStat` / `SubjectBreakdownRow` tiplerini alan olarak yazıyordu | Widget'lar artık **skaler / kayıt** parametreler alıyor |

Düzeltme sonrası **G4b = 0** ve 622 testin tamamı hâlâ yeşil.

> Bu, tasarımı da iyileştirdi: net katsayısı değişiminin "önce ayar, sonra
> yeniden hesaplama" sırası artık arayüzde değil `SettingsController` içinde
> ve tek yerde.

---

## 7. KORUMA GREP'LERİ

Yorum satırlarını eleyen **doğru** desen kullanıldı (FAZ 6 §5'te belgelenen
hata: `grep -rn` çıktısı `dosya:satır:` önekiyle başladığı için `^\s*//`
deseni hiçbir yorumu elemiyordu):

```bash
strip() { grep -vE "^[^:]*:[0-9]+:[[:space:]]*(///|//|\*|/\*)"; }
```

| Guard | Sonuç |
| --- | --- |
| G3 testlerde `DateTime.now()` yok | ✅ 0 |
| G4a domain'de Flutter/Drift/Riverpod yok | ✅ 0 |
| G4b presentation → data yok | ✅ 0 *(§6'da düzeltildi)* |
| G5 run katmanında `Timer` yok | ✅ 0 |
| G6 pause yok | ✅ 0 (aşağıya bak) |
| G7 summary/done ekranında reklam yok | ✅ 0 |
| G8 ders/konu/tür **silme** yok | ✅ 0 |
| G12 `lib/` içinde production reklam kimliği yok | ✅ 0 |

**G6'nın tek eşleşmesi ihlal değil** — `promise_step.dart:35`:
`'Sayaç duraklatılamaz: başladığın bloğu bitirirsin.'` Bu, kuralın
**kullanıcıya anlatıldığı arayüz metni**.

**L10n kapsamı** ayrıca grep'lendi: 7A'nın dört yeni dosyasında ARB dışı
Türkçe metin **yok**. `settings_screen`'de kalan tek gömülü metin
(`'İzle ve destekle'`) FAZ 5'in Destek ol kartına ait — talimat gereği
dokunulmadı.

---

## 8. YENİ / DEĞİŞEN DOSYALAR

**Yeni**

```
lib/application/settings_controller.dart          ayar yazmanın tek kapısı
lib/application/usecases/recompute_nets.dart      geçmiş netleri yeniden hesapla
lib/application/usecases/export_sessions.dart     CSV paylaş
lib/domain/services/csv_builder.dart              saf CSV üretimi
lib/domain/ports/share_gateway.dart               paylaşım port'u
lib/services/export/file_share_gateway.dart       gerçek + Noop adaptör
lib/presentation/stats/stats_screen.dart          istatistik ekranı
lib/presentation/settings/catalog_screen.dart     ders/konu/tür yönetimi
lib/presentation/settings/widgets/net_coefficient_tile.dart
lib/presentation/settings/widgets/reset_data_tile.dart
test/unit/{csv_builder,recompute_nets,reset_data}_test.dart
test/widget/{settings_screen,stats_screen,catalog_screen}_test.dart
```

**Değişen**

```
lib/presentation/settings/settings_screen.dart   baştan yazıldı
lib/data/local/database.dart                     resetAllData()
lib/data/local/daos/stats_dao.dart               exportRows()
lib/data/local/daos/subject_dao.dart             includeArchived, renameTopic,
                                                 renameActivityType,
                                                 setActivityTypeArchived
lib/core/di/app_providers.dart                   7A provider'ları
lib/core/router/app_router.dart                  /stats gerçek ekran, /manage
lib/main.dart                                    FileShareGateway
lib/l10n/app_tr.arb · app_en.arb                 39 -> 130 anahtar
test/integration/router_redirect_test.dart       test yüzeyi (§4)
```

---

## 9. SAPMALAR

S1–S17 kapalı. Bu turda **yeni sapma yok**; S15 (i18n kapsamı) 7A ekranları
için kapandı, eski ekranlar için hâlâ açık.

| # | Durum |
| --- | --- |
| S15 | **Kısmen kapandı** — 7A ekranları %100 ARB'den. Eski ekranların (run, summary, onboarding, wrongs, home) metinleri hâlâ gömülü; talimat gereği dokunulmadı |
| S16 | Açık — `app_en.arb` hâlâ TR değerler taşıyor, çeviri v1.2 |
| S17 | Açık — release APK bu ortamda üretilemiyor (Android SDK yok, `dl.google.com` proxy'de 403) |

---

## 10. GİT

Koordinatör kararı gereği **git kullanılmadı** (push yok, bundle yok,
GitHub'a bağlanılmadı). Teslim: bu rapor + ZIP.

---

## 11. FAZ 7B — KALAN KAPSAM

Bu teslimde **yok**, sıradaki turda:

- **(c) Calendar** — ay ızgarası, gün başına süre/oturum
- **(d) Goals** — aktif/tamamlanan hedefler + ilerleme çubukları
- **(e) achievements** — KAYDET yolunda yazan kod (streak/goals deseni) +
  rozet listesi UI
- **(f)** 7B ekranlarının L10n'i

7B'nin zemini hazır: `goal_dao`, `achievements` tablosu, `GoalProgressCalculator`
ve `StreakCalculator` yerinde; `SessionRepository.save()` içinde
`recomputeStreak`/`recomputeGoals` çağrıları duruyor — achievements aynı
desene eklenecek.
