import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

import '../../domain/entities/consent_state.dart';
import '../../domain/ports/consent_gateway.dart';

/// Gerçek UMP (Google User Messaging Platform) adaptörü.
///
/// KVKK/GDPR açık rızası artık uygulama içi bir toggle'la değil, Google'ın
/// resmi rıza formuyla alınıyor. Toggle (`personalizedAdsConsent`) kullanıcının
/// kendi tercihi olarak duruyor; **UMP ise yalnızca KISITLAYABİLİR** —
/// SDK "reklam isteği yapamazsın" diyorsa kullanıcı tercihi ne olursa olsun
/// reklam gösterilmez. Son söz `AdPolicyEngine`'dedir.
///
/// **Akışı ASLA durdurmaz.** Ağ yoksa, form yüklenemezse veya SDK hata
/// verirse `ConsentResult.unavailable` döner (`canRequestAds: false`) ve
/// uygulama reklamsız çalışmaya devam eder. Hata durumunda "izin var"
/// saymak, rızasız reklam göstermek olurdu.
class UmpConsentGateway implements ConsentGateway {
  UmpConsentGateway({gma.ConsentInformation? consentInformation})
      : _info = consentInformation ?? gma.ConsentInformation.instance;

  final gma.ConsentInformation _info;

  /// Form/güncelleme çağrıları bu süreyi aşarsa akış beklemez.
  ///
  /// Kullanıcı uygulamayı açtığında rıza formu yüklenemedi diye beyaz
  /// ekranda bekletilemez; süre dolunca reklamsız devam edilir.
  static const Duration timeout = Duration(seconds: 8);

  ConsentState _mapState(gma.ConsentStatus s) => switch (s) {
        gma.ConsentStatus.notRequired => ConsentState.notRequired,
        gma.ConsentStatus.obtained => ConsentState.obtained,
        gma.ConsentStatus.required => ConsentState.required_,
        gma.ConsentStatus.unknown => ConsentState.unknown,
      };

  Future<ConsentResult> _read({String? error}) async {
    final status = await _info.getConsentStatus();
    final canRequest = await _info.canRequestAds();
    final privacy = await _info.getPrivacyOptionsRequirementStatus();
    return ConsentResult(
      state: _mapState(status),
      canRequestAds: canRequest,
      privacyOptionsRequired:
          privacy == gma.PrivacyOptionsRequirementStatus.required,
      error: error,
    );
  }

  /// UMP bilgisini tazeler; gerekiyorsa formu gösterir.
  @override
  Future<ConsentResult> gather() async {
    try {
      return await _gather().timeout(timeout);
    } on TimeoutException {
      debugPrint('UMP zaman aşımı (${timeout.inSeconds} sn) — reklamsız devam');
      return ConsentResult.unavailable;
    } on Object catch (e) {
      debugPrint('UMP gather hatası: $e');
      return ConsentResult.unavailable;
    }
  }

  Future<ConsentResult> _gather() async {
    final completer = Completer<String?>();

    _info.requestConsentInfoUpdate(
      gma.ConsentRequestParameters(),
      () => completer.complete(null),
      (gma.FormError e) => completer.complete(e.message),
    );

    final updateError = await completer.future;
    if (updateError != null) {
      debugPrint('UMP bilgi güncellemesi başarısız: $updateError');
      return _read(error: updateError);
    }

    // Form gerekiyorsa göster. Yükle-ve-göster tek adımda; gerekmiyorsa
    // SDK hiçbir şey göstermeden geri döner.
    //
    // `unawaited`: SDK'nın döndürdüğü Future BEKLENMEZ — sonuç geri
    // çağrımla geliyor ve beklenen şey `formCompleter`. Future'ı awaitlemek
    // form kapanana kadar ikinci bir bekleme daha eklerdi.
    final formCompleter = Completer<String?>();
    unawaited(
      gma.ConsentForm.loadAndShowConsentFormIfRequired(
        (gma.FormError? e) => formCompleter.complete(e?.message),
      ),
    );
    final formError = await formCompleter.future;

    return _read(error: formError);
  }

  @override
  Future<ConsentResult> current() async {
    try {
      return await _read().timeout(timeout);
    } on Object catch (e) {
      debugPrint('UMP durum okunamadı: $e');
      return ConsentResult.unavailable;
    }
  }

  /// Ayarlardan "gizlilik tercihimi değiştir" — KVKK/GDPR gereği zorunlu yol.
  @override
  Future<ConsentResult> showPrivacyOptions() async {
    try {
      final completer = Completer<String?>();
      unawaited(
        gma.ConsentForm.showPrivacyOptionsForm(
          (gma.FormError? e) => completer.complete(e?.message),
        ),
      );
      final err = await completer.future.timeout(timeout);
      return _read(error: err);
    } on Object catch (e) {
      debugPrint('UMP gizlilik formu açılamadı: $e');
      return ConsentResult.unavailable;
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _info.reset();
    } on Object catch (e) {
      debugPrint('UMP reset hatası: $e');
    }
  }
}
