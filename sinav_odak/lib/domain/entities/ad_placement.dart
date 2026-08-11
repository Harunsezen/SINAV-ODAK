// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import 'enums.dart';

/// Reklamın gösterilebileceği YERLER.
///
/// [AdKind] "hangi format" sorusunu (banner/native/interstitial/rewarded),
/// [AdPlacement] ise "hangi ekranın neresi" sorusunu yanıtlar. İkisi ayrı
/// tutuluyor çünkü politika kararı formata değil **yere** bağlı: aynı banner
/// formatı ana panelde serbest, aktif çalışma ekranında ayara bağlıdır.
///
/// Serbest metin (`'run'`, `'home'`) yerine enum kullanılmasının sebebi,
/// yazım hatasının sessizce "reklam gösterme" değil **derleme hatası**
/// üretmesi. Reklam politikasında sessiz hata, para veya politika ihlali
/// demektir.
enum AdPlacement {
  /// Ana panel üst banner'ı.
  homeBanner,

  /// İstatistik ekranı alt banner'ı.
  statsBanner,

  /// Takvim ekranı alt banner'ı.
  calendarBanner,

  /// Aktif çalışma ekranı (S08) — **YALNIZCA İNCE BANNER**.
  /// Bu yerde tam ekran formatı ASLA kullanılamaz (G7).
  runBanner,

  /// Mola ekranı (S09) büyük native kartı.
  breakNative,

  /// Tebrik ekranından ana panele geçiş anı.
  doneInterstitial,

  /// Ayarlar → "Destek ol" (kullanıcı başlatır).
  supportRewarded;

  /// Bu yerin formatı.
  AdKind get kind => switch (this) {
        AdPlacement.homeBanner => AdKind.banner,
        AdPlacement.statsBanner => AdKind.banner,
        AdPlacement.calendarBanner => AdKind.banner,
        AdPlacement.runBanner => AdKind.banner,
        AdPlacement.breakNative => AdKind.native,
        AdPlacement.doneInterstitial => AdKind.interstitial,
        AdPlacement.supportRewarded => AdKind.rewarded,
      };

  /// Ekranı kaplayan format mı?
  ///
  /// `AdGateway` ve politika motoru bunu okuyarak çalışma bloğunda tam ekran
  /// gösterimini engeller — kontrol çağıran katmanda değil, **burada**.
  bool get isFullScreen =>
      kind == AdKind.interstitial || kind == AdKind.rewarded;

  /// `ad_events.screen_name` kolonuna yazılan ad.
  String get screenName => switch (this) {
        AdPlacement.homeBanner => 'home',
        AdPlacement.statsBanner => 'stats',
        AdPlacement.calendarBanner => 'calendar',
        AdPlacement.runBanner => 'run',
        AdPlacement.breakNative => 'break',
        AdPlacement.doneInterstitial => 'done',
        AdPlacement.supportRewarded => 'settings',
      };
}
