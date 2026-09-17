import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Yüklenmiş bir AdMob reklamını EKRANA KOYAN köprü.
///
/// **Neden ayrı bir dosya:** `AdWidget` `google_mobile_ads` paketinden
/// geliyor ve o paket platform kanalı kullanıyor — ekran widget'ları onu
/// tanırsa host testlerinde çalışamaz hale gelirler. Bu yüzden ekranlar
/// `adViewBuilderProvider` üzerinden soyut bir yapıcı çağırıyor; gerçek
/// adaptör yalnızca `main()` tarafından bağlanıyor.
///
/// **Neden var olması gerekiyordu:** v1.5.1'e kadar projede `AdWidget`
/// kelimesi HİÇ geçmiyordu. Banner yükleniyor, nesne `handle != null`
/// diye bool'a çevriliyor ve ATILIYORDU; yuva yalnızca gri bir kutu ile
/// "Sponsorlu" yazısı çiziyordu. Reklam ekrana hiç konmadığı için
/// gösterim de hiç oluşmadı, kazanç da.
Widget? admobAdView(Object? handle) {
  // `BannerAd` ve `NativeAd` ikisi de `AdWithView`. Başka bir şey gelirse
  // (testlerdeki sahte nesne gibi) sessizce `null` dönüyoruz: yuva
  // etiketini çizer, içi boş kalır, hiçbir şey çökmez.
  if (handle is! AdWithView) return null;
  return AdWidget(ad: handle);
}
