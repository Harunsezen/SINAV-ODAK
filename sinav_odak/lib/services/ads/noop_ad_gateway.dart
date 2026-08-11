import '../../domain/entities/ad_placement.dart';
import '../../domain/ports/ad_gateway.dart';

/// Hiçbir şey yapmayan reklam ağ geçidi.
///
/// **Varsayılan implementasyon budur.** `AdMobGateway` yalnızca gerçek
/// cihazda, `google_mobile_ads` başarıyla kurulduğunda devreye girer;
/// testlerde ve reklamsız çalıştırmada bu sınıf kullanılır.
///
/// Gösterim istekleri `false`, yükleme istekleri `null` döner — ikisi de
/// "reklam yok" anlamına gelir ve **hata değildir**: çağıran akış beklemeden
/// devam eder.
class NoopAdGateway implements AdGateway {
  const NoopAdGateway();

  @override
  Future<void> initialize() async {}

  @override
  Future<Object?> loadBanner(AdPlacement placement) async => null;

  @override
  Future<Object?> loadNative(AdPlacement placement) async => null;

  @override
  Future<bool> showInterstitial(AdPlacement placement) async => false;

  @override
  Future<bool> showRewarded(AdPlacement placement) async => false;

  @override
  Future<void> dispose() async {}
}
