// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod, AdMob import etmez.

import '../entities/consent_state.dart';

/// KVKK/GDPR rıza akışının domain sözleşmesi (port).
///
/// **Neden port?** UMP `google_mobile_ads` içinden gelir, platform kanalı
/// kullanır ve host testinde çağrılamaz. Bu arayüz sayesinde politika motoru
/// ve ekranlar Google SDK'sını hiç tanımadan rıza durumunu okuyabiliyor;
/// testlerde sahte implementasyon veriliyor.
abstract interface class ConsentGateway {
  /// Rıza bilgisini tazeler ve gerekiyorsa formu gösterir.
  ///
  /// **Akışı ASLA durdurmaz:** hata olursa `ConsentResult.unavailable`
  /// döner ve uygulama reklamsız çalışmaya devam eder.
  Future<ConsentResult> gather();

  /// Form göstermeden mevcut durumu okur (açılışta hızlı yol).
  Future<ConsentResult> current();

  /// Kullanıcı ayarlardan tercihini değiştirmek isterse formu yeniden açar.
  /// KVKK/GDPR gereği bu yol her zaman erişilebilir olmalı.
  Future<ConsentResult> showPrivacyOptions();

  /// Rızayı sıfırlar (yalnızca geliştirme/test).
  Future<void> reset();
}
