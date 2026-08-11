import '../../domain/entities/consent_state.dart';
import '../../domain/ports/consent_gateway.dart';

/// UMP çalıştırmayan rıza ağ geçidi.
///
/// **Varsayılan implementasyon budur.** Gerçek UMP yalnızca AdMob SDK'sı
/// kurulabildiğinde devreye girer; testlerde ve reklamsız çalıştırmada bu
/// sınıf kullanılır.
///
/// [canRequestAds] varsayılanı `true`: bu sınıf "UMP yok" demektir, "rıza
/// yok" değil. Rızanın kendisi `AdPolicyEngine`'de kullanıcının kayıtlı
/// tercihiyle birlikte değerlendirilir — yani bu sınıf tek başına reklam
/// açmaz.
class NoopConsentGateway implements ConsentGateway {
  const NoopConsentGateway({this.canRequestAds = true});

  final bool canRequestAds;

  ConsentResult get _result => ConsentResult(
        state: ConsentState.notRequired,
        canRequestAds: canRequestAds,
      );

  @override
  Future<ConsentResult> gather() async => _result;

  @override
  Future<ConsentResult> current() async => _result;

  @override
  Future<ConsentResult> showPrivacyOptions() async => _result;

  @override
  Future<void> reset() async {}
}
