// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import '../entities/ad_placement.dart';

/// Reklam altyapısının domain sözleşmesi (port).
///
/// **Neden port?** Reklam gösterimi `google_mobile_ads` gerektirir; o paket
/// platform kanalı kullanır ve host testinde çağrılamaz. Bu arayüz sayesinde
/// ekranlar ve politika motoru AdMob'u hiç tanımadan çalışır, testlerde
/// `NoopAdGateway` verilir.
///
/// **Yüklenen reklam nesnesi `Object?` olarak dönüyor.** Domain katmanı
/// `BannerAd`/`NativeAd` tiplerini tanımamalı; widget'lar bu nesneyi tip
/// çıkarımıyla tüketir. `null` dönmesi "reklam yok" demektir ve **hata
/// değildir**: ağ yoksa, envanter boşsa veya politika izin vermiyorsa akış
/// beklemeden devam eder (kural: reklam yüklenemezse akış DURMAZ).
abstract interface class AdGateway {
  /// SDK kurulumu. Sesi kapatır (`setAppMuted(true)`).
  /// Başarısız olursa akışı DURDURMAZ.
  Future<void> initialize();

  /// Banner yükler. Politika kontrolü **çağıranın** değil, bu
  /// implementasyonun içindedir.
  Future<Object?> loadBanner(AdPlacement placement);

  /// Native kart yükler.
  Future<Object?> loadNative(AdPlacement placement);

  /// Tam ekran ara reklam gösterir; gösterildiyse `true`.
  ///
  /// **Aktif çalışma bloğunda ASLA gösterilmez** — bu kontrol implementasyonun
  /// İÇİNDE olmak zorundadır (ürünün değişmez kuralı G7). Çağıran katmana
  /// bırakılırsa yeni bir çağrı yolu açan kişi kuralı sessizce deler.
  Future<bool> showInterstitial(AdPlacement placement);

  /// Ödüllü reklam gösterir; kullanıcı ödülü hak ettiyse `true`.
  /// Yalnızca kullanıcının kendi başlattığı akıştan çağrılır.
  Future<bool> showRewarded(AdPlacement placement);

  /// Yüklü reklamları serbest bırakır.
  Future<void> dispose();
}
