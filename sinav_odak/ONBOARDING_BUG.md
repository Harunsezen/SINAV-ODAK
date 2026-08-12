# ONBOARDING 5/5 — BİRİNCİL BUTON GÖRÜNMÜYOR

**Durum:** yayın engelleyici · **Bulan:** gerçek cihaz denemesi
**Kapsam:** kod dondurma istisnası (koordinatör onaylı)

---

## 0. ÖZET

| | |
| --- | --- |
| **Belirti** | Onboarding 5/5 "Hazırsın" ekranında yalnızca "Geri" var; [Başla] yok, boş alan tepkisiz |
| **Gerçek kök neden** | `AppTheme` tüm `FilledButton`'lara **sonsuz asgari genişlik** veriyor; `Row` içinde bu geçerli olmayan bir kısıt üretiyor ve buton **hiç yerleşemiyor** |
| **Nerede** | `lib/core/theme/app_theme.dart:20` + `lib/presentation/onboarding/onboarding_screen.dart:210,216` |
| **Neden 774 test kaçırdı** | Onboarding testleri **gerçek temayı kullanmıyordu** ve yüzeyi 1200×2400'e büyütüp semptomu susturuyordu; QA gezinti turu ise onboarding'e **hiç uğramıyordu** |
| **Düzeltme** | Alt bar butonlarına yerel `minimumSize: Size(88, 56)` |
| **Yeni test** | 3 cihaz yürüyüşü + 4 tema kısıt bekçisi + 2 ekran görüntüsü; mevcut 16 onboarding testi artık gerçek temayla koşuyor |

---

## 1. TEŞHİS

### 1.1 İlk hipotez YANLIŞTI (ve nasıl elendi)

İlk tahminim "alt bar ekranın dışına taşıyor"du. Bunu **ölçtüm**: onboarding'i
8 farklı cihaz koşulunda (412×915, 360×800, 360×640; sistem çubuğu kesmeleri
var/yok; textScale 1.0/1.3/1.5) 5. adıma kadar yürütüp [Başla]'nın
dikdörtgenini yazdırdım.

```
Pixel7 insetsiz      | ekran 915 | buton T851 B899 | => OK
Pixel7 + insets      | ekran 915 | buton T803 B851 | => OK
Pixel7 + insets x1.5 | ekran 915 | buton T803 B851 | => OK
360x640 + insets     | ekran 640 | buton T528 B576 | => OK
...  8/8 OK
```

Hepsi ekranın içindeydi. **Hipotez öldü** — ve öldüğü iyi oldu, çünkü
gerçek sebep bambaşka bir katmandaydı.

Yapısal olarak da imkânsızdı: `_BottomBar`'daki `Row` **her zaman** bir
birincil buton içeriyor (`isLast` ise [Başla], değilse [İleri]) — yani
"buton hiç eklenmemiş" senaryosu yok.

### 1.2 Farkı bulan soru: test neyi taklit ETMİYOR?

Yürüyüşüm geçiyordu ama cihaz düşüyordu. Aradaki farkları listeledim:
ekran ölçüsü ✓, kesmeler ✓, font ölçeği ✓, dil ✓, yönlendirme ✓ …
**tema ✗**. Testim `MaterialApp`'i temasız kuruyordu; uygulama
`AppTheme.light()` kullanıyor.

Temayı ekledim, test **anında düştü**:

```
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞════════════════════════
The following assertion was thrown during performLayout():
BoxConstraints forces an infinite width.
The offending constraints were:
  BoxConstraints(w=Infinity, 56.0<=h<=Infinity)
The relevant error-causing widget was:
  FilledButton-[<'onboarding-next'>]
  onboarding_screen.dart:216:13
#7  _RenderInputPadding._computeSize   (button_style_button.dart)
#13 RenderFlex._computeSizes           (flex.dart)
```

### 1.3 Kök neden

`lib/core/theme/app_theme.dart`:

```dart
filledButtonTheme: FilledButtonThemeData(
  style: FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(56),   // ← Size(double.infinity, 56)
  ),
),
```

`Size.fromHeight(56)` **`Size(double.infinity, 56)` demek.** Yani
uygulamadaki *her* `FilledButton`'ın asgari genişliği sonsuz.

- **`Column` içinde sorun yok.** Çapraz eksende genişlik sınırlı olduğu için
  sonsuz asgari genişlik kolonun genişliğine kırpılıyor — istenen "tam
  genişlik birincil buton" görünümü zaten **bundan** geliyor. Kasıtlı.
- **`Row` içinde felaket.** `RenderFlex`, esnek olmayan çocuklarını ana
  eksende **sınırsız** (`maxWidth: infinity`) ölçüyor. Sonsuz asgari
  genişlik + sınırsız tavan = `BoxConstraints(w=Infinity)`, ki bu geçerli
  bir kısıt değil. `RenderPhysicalShape` yerleşemiyor.

Sonuç: butonun render nesnesi **boyut alamıyor ve çizilmiyor**. Aynı
`Row`'daki "Geri" ise `TextButton` — `filledButtonTheme`'den etkilenmediği
için sorunsuz çiziliyor.

**Kullanıcının gördüğü tam olarak bu:** yalnızca "Geri", birincil buton yok,
onun olması gereken yer boş ve tepkisiz.

### 1.4 Dürüstlük notu — açıklayamadığım kısım

Kullanıcı "önceki 4 adımda butonlar çalıştı" diyor. Oysa geçersiz kısıt
`_BottomBar` üzerinden **beş adımda da** üretiliyor; yukarıdaki hata zaten
1. adımın `onboarding-next` butonunda patladı.

Debug derlemede assertion atılıp Flutter hata kutusu çiziyor; release'de
assertion'lar **derleme dışı kalıyor**, dolayısıyla davranış farklı:
render nesnesi sessizce sonsuz genişlik alıyor ve konumuna göre kısmen
görünebiliyor. İlk adımda "Geri" olmadığı için buton x=16'dan başlayıp
ekranı dolduruyor ve normal görünüyor olabilir; son adımda farklı düşmesi
de bu yolla açıklanabilir.

**Ama bunu doğrulayamadım:** bu ortamda Android SDK yok, release APK
derlenemiyor (FAZ 6 §7 / S17). Release'deki tam çizim davranışı hakkındaki
bu cümle bir **çıkarım**, ölçüm değil. Kesin olan şu: geçersiz kısıt beş
adımda da üretiliyordu ve düzeltmeden sonra hiçbirinde üretilmiyor.

---

## 2. NEDEN 774 TESTİN HİÇBİRİ YAKALAMADI

İki bağımsız boşluk aynı anda açıktı:

**1. Onboarding testleri gerçek temayı kullanmıyordu.**
`onboarding_test.dart` `MaterialApp.router`'ı temasız kuruyordu. Hata
tamamen temadan geldiği için 16 testin hiçbiri göremezdi.

**2. Test, semptomu susturmuştu.** Aynı dosyadaki kurulum yorumu şuydu:

> `// Rıza metni + kartlar uzun; varsayılan 800x600 yüzeyde alt butonlar`
> `// görünür alanın dışında kalıyor.`
> `tester.view.physicalSize = const Size(1200, 2400);`

"Alt butonlar görünür alanın dışında kalıyor" — bu **hatanın kendisinin
tarifi**. Çözüm olarak yüzey 1200×2400'e büyütülmüş. Bu, hatayı düzeltmek
değil, testin onu göremeyeceği bir dünya kurmaktı.

**3. QA gezinti turu onboarding'e hiç uğramıyordu.** `QaSeed`'in ürettiği
kullanıcılarda `onboardingCompleted = true`; router her seferinde ana panele
yönlendiriyor. 12 turun hiçbiri bu ekrana girmedi.

Üçüncü boşluk aynı kök nedenin bir başka örneğini QA turunda **yakalamıştı**:
`GoalFormSheet`'in `Row` içindeki `FilledButton`'ı aynı
"infinite width" hatasını veriyordu (QA_RAPORU §4.1 A4). O zaman semptomu
`OverflowBar` ile kapattım ama **kök nedeni görmedim**. Bu rapor onu kapatıyor.

---

## 3. DÜZELTME

`lib/presentation/onboarding/onboarding_screen.dart` — alt bar butonlarına
yerel stil:

```dart
/// **Neden zorunlu:** `AppTheme` tüm `FilledButton`'lara
/// `minimumSize: Size.fromHeight(56)` veriyor — bu `Size(double.infinity,
/// 56)` demek. ... `Row` esnek olmayan çocuklarını **sınırsız**
/// genişlikle ölçüyor: sonsuz asgari genişlik geçerli olmayan bir kısıta
/// dönüşüyor ve buton hiç yerleşemiyor.
static ButtonStyle get _barButtonStyle =>
    FilledButton.styleFrom(minimumSize: const Size(88, 56));
```

`[İleri]` ve `[Başla]`'nın ikisine de veriliyor (ikisi de aynı `Row`'da).

**Görünüm korunuyor:** yükseklik 56'da kalıyor, tek değişen asgari
genişliğin sonlu olması. Buton içeriğine göre yine büyüyor.

### Neden temayı değiştirmedim

`Size.fromHeight(56)`'yı temadan kaldırmak kök nedeni yok ederdi ama
`Column` içindeki **tüm** birincil butonların tam genişlik görünümünü
bozardı — uygulama genelinde görsel bir gerileme, cihazda doğrulama
imkânı olmadan. Kod dondurmada bu takas doğru değil.

Bunun yerine tema dosyasına tuzağı anlatan bir uyarı ve **çalışan bir
bekçi test** koydum (§4). Tema temizliği v1.2'ye ait.

---

## 4. YENİ TESTLER

### `test/widget/onboarding_device_walk_test.dart` (3 test)

Gerçek `AppTheme` + gerçek telefon ölçüsü (412×915, sistem çubuğu
kesmeleriyle).

| Test | İddia |
| --- | --- |
| 5 adım baştan sona | her adımda birincil buton **kullanılabilir**; 5/5'te `onboarding-start` **findsOneWidget**, `onboarding-next` yok, **tap → "ANA PANEL"**, `onboardingCompleted == true` |
| dar/büyük font/koyu | 360×640, 360×800 ×1.3, 412×915 ×1.5 koyu — üçünde de [Başla] ekranın içinde, istisna yok |
| geri dönüş | 5/5 → Geri → 4/5; birincil buton yeniden [İleri] |

"Kullanılabilir" tek bir `findsOneWidget`'tan fazlası:

```dart
expect(r.width, greaterThan(0));                  // sıfır boyut değil
expect(r.width, lessThan(double.infinity));       // sonsuz genişlik değil
expect(r.right, lessThanOrEqualTo(screen.width)); // ekranın dışında değil
expect(r.bottom, lessThanOrEqualTo(screen.height));
```

Ayrıca her adımda `tester.takeException()` **null** olmalı — asıl hata
buradan yakalanıyor.

### `test/widget/theme_button_constraints_test.dart` (4 test)

Tuzağın kendisini belgeleyen bekçi:

| Test | İddia |
| --- | --- |
| `Column` içinde tam genişlik | 300 px kolonda buton 300×56 — **kasıtlı davranış korunuyor** |
| **DOĞRULANMIŞ TUZAK** | `Row` içindeki sade `FilledButton` gerçekten `infinite width` hatası veriyor |
| ÇÖZÜM | yerel `minimumSize: Size(88, 56)` → istisna yok, yükseklik 56 |
| ÇÖZÜM 2 | `Expanded` ile sınırlamak da çalışıyor |

İkinci test kasten hatayı **üretiyor**. Amacı: Flutter veya tema değişip
tuzak kapanırsa bizi uyarmak — o zaman onboarding'deki yerel stil de
gözden geçirilmeli. Hata her yerleşim geçişinde tekrar atıldığı için
`takeException()` "Multiple exceptions" özeti veriyor; ilk hatanın metnine
ulaşmak için `FlutterError.onError` geçici olarak devralınıyor.

### Görsel kanıt

`qa_screenshots/51_onboarding_summary_light.png` ve
`52_onboarding_summary_dark.png` — 5/5 "Hazırsın" ekranı, **[Başla] butonu
sağ altta görünür halde**. Düzeltmeden önce bu ekranda yalnızca "Geri"
vardı.

Görüntüler `pumpQaOnboardingSummary` ile alınıyor: onboarding'i router
üzerinden değil DOĞRUDAN kuruyor, çünkü `QaSeed` kullanıcılarında
`onboardingCompleted = true` olduğu için router bu ekranı hiç açmıyordu —
QA turunun bu ekranı hiç görmemesinin sebebi de tam olarak buydu.

### Mevcut testler güçlendirildi

`onboarding_test.dart` artık `theme: AppTheme.light()` ile koşuyor ve
yanıltıcı yorum düzeltildi. **16 testin 16'sı gerçek temayla geçiyor** —
hiçbiri gevşetilmedi.

---

## 5. BUILD CONFIG (B maddesi)

Kullanıcının modern PC'sinde yerelde çalışan düzeltmeler repoya işlendi;
taze `clone` artık bunlarla geliyor.

| Dosya | Önce | Sonra |
| --- | --- | --- |
| `android/settings.gradle` | AGP `8.1.0` · Kotlin `1.8.22` | AGP **`8.6.0`** · Kotlin **`2.1.0`** |
| `android/gradle/wrapper/gradle-wrapper.properties` | `gradle-8.3-all.zip` | **`gradle-8.9-all.zip`** |
| `android/app/build.gradle` | `compileSdk = flutter.compileSdkVersion` | **`compileSdk = 35`** |
| `android/build.gradle` | — | **`subprojects { … extraProperties.set("flutter", …) }`** |

`subprojects` bloğu eklenti modüllerine `flutter` uzantısını sabitliyor
(`compileSdkVersion: 34, minSdkVersion: 21, targetSdkVersion: 34`); yeni
AGP + Gradle çiftinde bazı eklentilerde bu uzantı çözümlenemiyor ve derleme
"Could not get unknown property 'flutter'" ile düşüyor.

**Uygulamanın çalışma davranışı değişmedi:** `app/build.gradle` kendi
`minSdk = 21`'ini ve `targetSdk`'sını belirlemeye devam ediyor; `compileSdk
= 35` yalnızca derleme hedefi.

### Doğrulama sınırı — dürüst not

Bu ortamda Android SDK yok ve `dl.google.com` erişilemiyor, dolayısıyla
**gerçek bir Gradle derlemesi çalıştıramadım**. Yapabildiğim iki şey:

1. Üç Gradle dosyasını Gradle'ın kendi Groovy'siyle **ayrıştırdım** —
   sözdizimi geçerli:
   ```
   [android/build.gradle]      GROOVY SOZDIZIMI OK
   [android/settings.gradle]   GROOVY SOZDIZIMI OK
   [android/app/build.gradle]  GROOVY SOZDIZIMI OK
   ```
2. `subprojects` bloğundaki ifadeyi sahte bir `extraProperties` üzerinde
   **çalıştırdım**:
   ```
   CALISTIRILDI -> flutter.compileSdkVersion=34 flutter.minSdkVersion=21
                   flutter.targetSdkVersion=34
   ```

Yani: sözdizimi ve mantık doğrulandı; **sürüm çiftinin gerçekten derlediği
doğrulanmadı** — o kanıt kullanıcının kendi makinesinden geliyor.

---

## 6. KANIT — 4 KOMUT

```
$ flutter analyze
No issues found!

$ flutter test
All tests passed!   (783)
```

| Ölçüt | Eşik | Sonuç |
| --- | --- | --- |
| Test sayısı | ≥ 774 (düşmeyecek) | **783** ✅ |
| analyze error / warning / info | 0 / 0 / 0 | **0 / 0 / 0** ✅ |

Artış: +3 cihaz yürüyüşü, +4 tema bekçisi, +2 ekran görüntüsü = **+9**.
774 → 783.

---

## 7. DEĞİŞEN DOSYALAR

**Yeni**
```
ONBOARDING_BUG.md
test/widget/onboarding_device_walk_test.dart
test/widget/theme_button_constraints_test.dart
qa_screenshots/51_onboarding_summary_light.png
qa_screenshots/52_onboarding_summary_dark.png
```

**Değişen**
```
lib/presentation/onboarding/onboarding_screen.dart   alt bar yerel stili (DÜZELTME)
lib/core/theme/app_theme.dart                        tuzak uyarısı (yalnızca yorum)
test/widget/onboarding_test.dart                     gerçek tema + yorum düzeltmesi
test/qa/qa_harness.dart                              pumpQaOnboardingSummary
test/qa/screenshots_test.dart                        2 onboarding görüntüsü
android/settings.gradle                              AGP 8.6.0 / Kotlin 2.1.0
android/gradle/wrapper/gradle-wrapper.properties     Gradle 8.9
android/app/build.gradle                             compileSdk 35
android/build.gradle                                 subprojects flutter uzantısı
```

G-kuralları etkilenmedi: ürün davranışı değişmedi, sayaç/reklam/silme
kurallarına dokunulmadı.

---

## 8. NE ÖĞRENDİM

**Testin taklit etmediği şey, hatanın saklandığı yerdir.** 774 test bu
ekranı 16 kez yürüdü ve hiçbiri göremedi — çünkü hepsi *temasız* bir
dünyada koşuyordu. Hata tamamen temadaydı.

**Semptomu susturan yorum, hatanın itirafıdır.** "Varsayılan yüzeyde alt
butonlar görünür alanın dışında kalıyor" cümlesi testin içinde aylarca
durdu. O cümle yazıldığı anda bir hata raporuydu; onun yerine yüzey
büyütüldü. Bir testi geçirmek için ortamı değiştirmek gerekiyorsa,
değiştirilmesi gereken genellikle üründür.

**Bir semptomu düzeltmek kök nedeni kapatmaz.** QA turunda aynı hatayı
`GoalFormSheet`'te görmüş ve `OverflowBar` ile geçmiştim. Aynı kısıt
hatası iki farklı ekranda çıktıysa sorun ekranda değil, ortak katmandadır
— o zaman sormadığım soruyu şimdi sordum.
