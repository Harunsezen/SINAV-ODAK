// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod, AdMob import etmez.

/// UMP (Google User Messaging Platform) rıza durumunun domain karşılığı.
///
/// `google_mobile_ads` paketinin kendi `ConsentStatus` tipi kullanılmıyor:
/// domain katmanı AdMob'u tanımamalı. Adaptör (`UmpConsentGateway`) SDK
/// tipini buraya çevirir.
enum ConsentState {
  /// Henüz sorulmadı / bilinmiyor.
  unknown,

  /// Rıza gerekiyor ama henüz alınmadı (form gösterilmeli).
  required_,

  /// Kullanıcı formu doldurdu.
  obtained,

  /// Bölge gereği rıza gerekmiyor (ör. AEA dışı).
  notRequired,
}

/// UMP akışının sonucu.
///
/// [canRequestAds] SDK'nın kendi kararıdır ve **tek başına bağlayıcıdır**:
/// rıza alınmamışsa reklam isteği yapılamaz. `AdPolicyEngine` bunu bir
/// GİRDİ olarak alır; son söz yine motorundur.
class ConsentResult {
  const ConsentResult({
    required this.state,
    required this.canRequestAds,
    this.privacyOptionsRequired = false,
    this.error,
  });

  /// UMP çalıştırılamadığında kullanılan güvenli varsayılan.
  ///
  /// **`canRequestAds: false`** — SDK'ya ulaşılamadığında "izin var" saymak,
  /// rızasız reklam göstermek demekti.
  static const unavailable = ConsentResult(
    state: ConsentState.unknown,
    canRequestAds: false,
  );

  final ConsentState state;

  /// Reklam isteği yapılabilir mi (UMP'nin kararı).
  final bool canRequestAds;

  /// Ayarlarda "gizlilik tercihlerini değiştir" gösterilmeli mi (KVKK/GDPR).
  final bool privacyOptionsRequired;

  /// Form hatası; akışı DURDURMAZ, yalnızca raporlanır.
  final String? error;

  @override
  String toString() => 'ConsentResult($state, canRequestAds: $canRequestAds)';
}
