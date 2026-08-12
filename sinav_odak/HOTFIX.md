# v1.0.2 HOTFIX — FAZ GEÇİŞİNDE UYGULAMA ANA EKRANA ATIYOR

**Durum:** yayın engelleyici (ürün sahibi vetosu) · **Kapsam:** v1.0'ın son kod değişikliği

---

## 0. ÖZET

| | |
| --- | --- |
| **Belirti** | Çalışma→mola faz geçişinde, uygulama ön plandayken kullanıcı ana ekrana atılıyor. Sayaç ve zaman damgası doğru kalıyor. |
| **Elenen adaylar** | 1 (`finish`/`moveTaskToBack`), 2 (fullscreen intent), 3 (recreate/dispose), 4 (route hatası) — **hepsi kanıtla elendi** |
| **Bulunan kesin kusur** | Bildirim yolunda **hiçbir ön plan kontrolü yok**: `AppLifecycleState` `lifecycle_tracker.dart` dışında kodun hiçbir yerinde geçmiyor. Blok/mola bitişleri mutlak zamana `category: alarm`, `Importance.high` ile kuruluyor ve **kullanıcı ekrana bakarken de tetikleniyor**. |
| **Düzeltme** | `ForegroundNotificationGuard` — ön planda oturum bildirimleri iptal, arka planda yeniden kurulur. Geçiş uygulama içinde + snackbar. |
| **Test** | `phase_transition_foreground_stays_in_app` + 2 destek testi |
| **Test sayısı** | 783 → **786** |
| **Dürüstlük notu** | Aday 5'in (OEM lifecycle) tam kanıtı **cihaz gerektiriyor**; bu ortamda yok. §1.5'te açıkça yazıldı. |

---

## 1. TEŞHİS

Koordinatörün 5 adayı tek tek kovalandı. Dördü **kanıtla** elendi.

### 1.1 Aday 1 — `finish()` / `moveTaskToBack(true)` → **YOK**

```
$ grep -rn "SystemNavigator\|moveTaskToBack\|exitApp\|finish()" lib/
lib/presentation/onboarding/onboarding_screen.dart:74:  Future<void> _finish() async {
```

Tek eşleşme onboarding'in kendi `_finish()` metodu — Android `finish()` değil,
onboarding'i tamamlayan Dart fonksiyonu. **Uygulamada `SystemNavigator.pop`,
`moveTaskToBack` veya activity kapatan hiçbir çağrı yok.**

`MainActivity.kt` de stok:

```kotlin
package com.harunsezen.sinav_odak
import io.flutter.embedding.android.FlutterActivity
class MainActivity: FlutterActivity()
```

### 1.2 Aday 2 — Fullscreen intent → **YOK**

```
$ grep -rn "fullScreenIntent" lib/ android/app/src/main/
(eşleşme yok)
```

`notification_service.dart:128-142`'deki `AndroidNotificationDetails`
`fullScreenIntent` **vermiyor** (varsayılan `false`). Manifest'te de
fullscreen intent izni/filtresi yok.

Faz geçişinde tam ekran reklam da yok: mola ekranındaki yer
`AdPlacement.breakNative` — **native**, yani satır içi. `isFullScreen`
yalnızca `doneInterstitial` ve `supportRewarded` için `true` ve ikisi de
faz geçişinde tetiklenmiyor (§1.6).

### 1.3 Aday 4 — Route/navigasyon hatası → **YOK (test ile kanıtlandı)**

Geçiş `run_screen.dart:41-53`'te `ref.listen` içinden:

```dart
if (next is SessionInBreak) {
  context.go(Routes.runBreak);
}
```

`context.go` uygulama içi gezinti — activity'ye dokunmuyor. Bunu **ölçtüm**:
düzeltmeden ÖNCE yazdığım regresyon testinde faz geçişi adımları
**geçti**; testin düştüğü yer yalnızca bildirim iddiaları oldu
(satır 156 ve 210). Yani:

```
00:20 +0 -1: phase_transition_foreground_stays_in_app [E]
  Expected: non-empty / Actual: []      ← satır 156 = bildirim iptali
00:21 +1 -2: Some tests failed.         ← 3. test (arka plan→ön plan) GEÇTİ
```

Rota iddiaları (`currentRoute() == /run/break`, `BreakScreen` görünür,
"ANA PANEL" yok) **düzeltmeden önce de** geçiyordu. Route katmanı temiz.

### 1.4 Aday 3 — Activity recreate / setState-after-dispose → **YOK**

Faz geçişi `ref.listen` ile yapılıyor; dosyanın kendi yorumu sebebini
açıklıyor: `build` içinde `addPostFrameCallback` kullanılsaydı her saniye
yeni bir gezinme kuyruğa girerdi. `mounted` kontrolü var. Regresyon
testinde `tester.takeException()` **null** — dispose sonrası setState veya
başka bir istisna yok.

`android:taskAffinity=""` de incelendi ve **elendi**: Flutter'ın kendi
uygulama şablonunda zaten var
(`flutter_tools/templates/app_shared/android.tmpl/.../AndroidManifest.xml.tmpl:10`),
projeye sonradan eklenmiş bir anormallik değil.

### 1.5 KESİN KUSUR — ön plan kontrolü hiç yok

```
$ grep -rn "AppLifecycleState\|isForeground\|resumed" lib/ | grep -v lifecycle_tracker.dart
(eşleşme yok)
```

**`AppLifecycleState` kodun hiçbir yerinde, `lifecycle_tracker.dart`
dışında, geçmiyor.** O dosya da yalnızca *ölçüm* yapıyor (odak skoru için
`awayS`/`exitCount`), hiçbir davranışı değiştirmiyor.

Bu şu demek: bildirim yolunda **ön plan/arka plan ayrımı yok**. Sayaç
`Timer` tabanlı olmadığı için blok ve mola bitişleri oturum başlarken
mutlak zamana kuruluyor:

`start_session.dart:68` → `scheduleFor(...)` →
`local_session_notifier.dart:59` → `zonedSchedule(...)` ile
`AndroidScheduleMode.exactAllowWhileIdle`

ve `notification_service.dart:130-139`:

```dart
AndroidNotificationDetails(
  prefs.channelId,
  ...
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.alarm,   // ← satır 136
)
```

Yani faz sınırında, **kullanıcı ekrana bakarken**, `alarm` kategorili ve
yüksek önemli bir tam-dikkat bildirimi düşüyor. Ürün kuralı bunu açıkça
yasaklıyor: *"Bildirim YOK (ön plandayken gerekmez)."*

**Bu, kuralın doğrulanabilir ihlalidir ve düzeltildi.** Ancak dürüst olmak
gerekirse:

> **Bu bildirimin, ana ekrana atma davranışının SEBEBİ olduğunu
> kanıtlayamadım.** Stok Android'de `alarm` kategorili bir heads-up
> bildirimi uygulamayı arka plana almaz. Bazı OEM kabuklarında (MIUI,
> EMUI, ColorOS) tam-dikkat/alarm bildirimlerinin odağı çalması bilinen
> bir davranıştır, ama bunu **ölçemedim**: bu ortamda Android SDK yok,
> `dl.google.com` erişilemiyor (§4), emülatör kurulamıyor.

Elimdeki kesin bilgi şu: **kural ihlal ediliyordu ve artık edilmiyor.**
Bu, hem koordinatörün istediği düzeltme hem de semptomun en olası
tetikleyicisi. Cihazda tekrar ederse §1.6'daki ikinci şüpheliye bakılmalı.

### 1.6 Kapatılmayan şüpheli — mola ekranındaki native reklam

Faz geçişinde açılan `BreakScreen`, uygulamadaki **tek platform view**
yüzeyini kuruyor: `NativeAdSlot(placement: AdPlacement.breakNative)`
(`break_screen.dart:93`). Google Mobile Ads native reklamı Android tarafında
bir `PlatformView`; SDK'da veya platform view oluşturmada bir çökme
**activity'yi öldürür** — kullanıcı ana ekranda bulur, servis ve zaman
damgası bozulmaz. Semptomla **birebir** uyuşuyor ve tam olarak bu anda
gerçekleşiyor.

Testte doğrulanamaz: reklam kapıları testlerde Noop.

**Kod dondurmada bu özelliği söküp atmadım** — kanıt yok, ve sökmek
gerçek bir ürün kaybı olurdu. Beta'da tekrar ederse ilk denenecek şey:
mola ekranındaki native reklamı kapatmak (tek satır: `NativeAdSlot`'u
kaldırmak veya `AdPolicyEngine`'de `breakNative`'i kapatmak).

---

## 2. DÜZELTME

### 2.1 `ForegroundNotificationGuard` (yeni)

`lib/services/notifications/foreground_notification_guard.dart`

Kuralın kodda karşılığı:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.resumed:
      _isForeground = true;
      unawaited(_silence());     // ön plan: bekleyen bildirimleri İPTAL et
    case AppLifecycleState.paused:
    case AppLifecycleState.hidden:
    case AppLifecycleState.detached:
      _isForeground = false;
      unawaited(_restore());     // arka plan: bitişleri YENİDEN kur
    case AppLifecycleState.inactive:
      break;                     // bildirim paneli / gelen arama: kanal değişmez
  }
}
```

**Neden iptal/yeniden kurma?** Bildirimler OS'a mutlak zamanla teslim
edilmiş durumda; tetiklendikleri anda "uygulama ön planda mı" diye
sorulamaz. Kuralı uygulamanın tek yolu kanalı **önceden** kapatmak.

`_restore()` içindeki `scheduleFor`, `NotificationPlanner` geçmiş sınırları
atladığı için yalnızca **gelecekteki** bitişleri kuruyor — geçmişe bildirim
kurulmuyor.

**Doğruluk buna bağlı değil:** hangi blokta olunduğu daima
`ScheduleResolver.resolve(now)` ile hesaplanıyor. Bildirimler yalnızca
haber verme kanalı.

### 2.2 Uygulama içi bilgilendirme

`run_screen.dart` — faz geçişinde, gezinmeden hemen önce:

```dart
ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      key: const Key('phase-change-banner'),
      content: Text(L10n.of(context).breakStarted),
      duration: const Duration(seconds: 4),
    ),
  );
context.go(Routes.runBreak);
```

Snackbar router'ın **dışındaki** `ScaffoldMessenger`'a gidiyor; ardından
gelen `context.go` onu düşürmüyor. Yeni ARB anahtarları (tr+en):
`breakStarted`, `blockStarted`.

### 2.3 Bağlanma

`app.dart`:

```dart
// `watch` ŞART: provider tembel; okunmazsa hiç oluşmaz ve yaşam
// döngüsü gözlemcisi kaydolmaz.
ref.watch(foregroundNotificationGuardProvider);
```

### 2.4 Yasaklara uyum

| Yasak | Durum |
| --- | --- |
| `finish()` / `moveTaskToBack` / fullscreen intent | Zaten yoktu, eklenmedi |
| "Molada kullanıcıyı arka plana at" tasarımı | **Böyle bir tasarım yok** — arandı, bulunamadı (§1.1-1.2) |
| Activity recreate zorlama | Yok |

---

## 3. REGRESYON TESTİ

`test/widget/phase_transition_test.dart` — 3 test.

### `phase_transition_foreground_stays_in_app`

Koordinatörün 5 maddesi birebir:

| # | İstenen | İddia |
| --- | --- | --- |
| 1 | Oturumu başlat | `seedRunningSession` + `/run` |
| 2 | Faz geçişini tetikle (mock timer) | `fakeNow = breakStart + 1000` + elle tik (gerçek `Timer` yok, `DateTime.now()` yok) |
| 3 | Route/activity kapanmıyor | `currentRoute() == /run/break` · `find.byType(BreakScreen)` **findsOneWidget** · `find.text('ANA PANEL')` **findsNothing** |
| 4 | Snackbar gösteriliyor | `find.byKey(Key('phase-change-banner'))` **findsOneWidget** |
| 5 | Bildirim çağrılmıyor | `notifier.scheduled` **isEmpty** · `notifier.hasPending` **isFalse** |

5. madde için `verifyZeroInteractions` yerine **kaydeden sahte** kullanıldı
(`RecordingNotifier`): projede `mockito` yok ve etkileşimi saymak yetmiyordu
— asıl sorulacak şey *"ön planda OS'ta bekleyen bildirim var mı"*, o da
`scheduled.length > cancelled.length` ile ölçülüyor.

Rotanın ana panele düşmesi ayrıca **yakalanıyor**: router'a `/home` rotası
eklendi ve "ANA PANEL" metninin görünmemesi iddia ediliyor — kullanıcının
oturumdan koparıldığı senaryo testi düşürür.

### Destek testleri

- **`arka plana geçince oturum bildirimleri YENİDEN kuruluyor`** —
  kuralın diğer yarısı: arka planda kullanıcı bildirimsiz kalmamalı.
- **`faz geçişi ARKA PLANDA olduysa uygulama içinde snackbar birikmiyor`** —
  kullanıcı geri döndüğünde doğrudan mola ekranında, istisnasız.

---

## 4. KALİTE KAPILARI — 4 KOMUT ÇIKTISI

```
$ flutter analyze
Analyzing sinav_odak...
No issues found! (ran in 4.9s)

$ flutter test
01:11 +786: All tests passed!

$ dart format .
Formatted 191 files (0 changed) in 1.87 seconds.

$ flutter build apk --release
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
exit=1
```

| Kapı | Eşik | Sonuç |
| --- | --- | --- |
| `flutter test` | ≥ 774 | **786** ✅ |
| `flutter analyze` | 0 issue | **0** ✅ |
| `dart format .` | temiz | **0 changed** ✅ |
| `flutter build apk --release` | yeşil | ❌ **YAPILAMADI** |

### APK derlemesi neden yeşil değil

```
$ curl -s -o /dev/null -w '%{http_code}' https://dl.google.com/android/repository/repository2-3.xml
000
```

Android SDK bu ortamda **yok** ve indirilemiyor; ağ politikası
`dl.google.com`'u kapatıyor. Bu, FAZ 6 §7'de S17 olarak açılan ve o günden
beri değişmeyen kısıt. **Bu kapı bu ortamda geçilemez** — sahte bir "yeşil"
yazmak yerine olduğu gibi bırakıyorum.

Karşılığında yapılabilen: Gradle dosyaları Gradle'ın kendi Groovy'siyle
ayrıştırıldı ve `subprojects` bloğu çalıştırıldı (v1.0.1'de,
`ONBOARDING_BUG.md` §5). Bu turda Gradle dosyalarına **dokunulmadı**.

**Derlemeyi sizin makinenizde doğrulamak gerekiyor:**
```
flutter build apk --release
```

---

## 5. DEĞİŞEN DOSYALAR

**Yeni**
```
HOTFIX.md
lib/services/notifications/foreground_notification_guard.dart
test/widget/phase_transition_test.dart
```

**Değişen**
```
lib/core/di/app_providers.dart        foregroundNotificationGuardProvider
lib/app.dart                          bekçiyi watch ediyor
lib/presentation/run/run_screen.dart  faz geçişinde uygulama içi snackbar
lib/l10n/app_tr.arb · app_en.arb      breakStarted, blockStarted
```

**Değişmeyen (bilerek):** hiçbir Android dosyası, hiçbir Gradle ayarı,
sayaç mantığı, reklam politikası, katalog/silme kuralları. G-kuralları
etkilenmedi: pause yok, çalışma bloğunda tam ekran reklam yok, silme yok.

---

## 6. NE ÖĞRENDİM

**Adayları elemek, birini seçmekten daha değerli çıktı.** Beş adaydan
dördünü `grep` ve tek bir regresyon testiyle kesin olarak eledim; geriye
kalan tek doğrulanabilir kusur, hiçbirinin listede olmadığı yerdeydi —
bildirim yolunda ön plan kontrolünün **hiç var olmaması**.

**Testi düzeltmeden önce yazmak, teşhisin kendisi oldu.** Regresyon testi
düzeltmeden önce koşturulunca rota iddiaları geçti, bildirim iddiaları
düştü. Bu, "route hatası" adayını tahminle değil **ölçümle** eledi ve
kusuru tek bir katmana daralttı.

**Kanıtlayamadığım şeyi kanıtlamış gibi yazmıyorum.** Bildirim kusuru
gerçek ve düzeltildi; ama ana ekrana atmanın sebebi olduğu **kanıtlı
değil**. §1.6'daki native reklam şüphelisi de açık duruyor. Beta'da
tekrar ederse bakılacak yer bellidir — bu, sahte bir kesinlikten daha
işe yarar.
