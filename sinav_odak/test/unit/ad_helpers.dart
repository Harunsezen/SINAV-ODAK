import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/ports/ad_gateway.dart';

/// Testlerde çağrıları SAYAN reklam ağ geçidi.
///
/// `NoopAdGateway`'den ayrı ve **test klasöründe**: production yolunda sayaç
/// taşımanın anlamı yok, üstelik test ikizini `lib/` altında tutmak onu
/// uygulamayla birlikte sevk etmek demekti.
class RecordingAdGateway implements AdGateway {
  RecordingAdGateway({this.interstitialResult = true});

  /// `showInterstitial` çağrısının döneceği değer.
  final bool interstitialResult;

  final List<AdPlacement> shownInterstitials = [];
  final List<AdPlacement> shownRewarded = [];
  final List<AdPlacement> loadedBanners = [];
  final List<AdPlacement> loadedNatives = [];
  int initializeCount = 0;
  int disposeCount = 0;

  @override
  Future<void> initialize() async => initializeCount++;

  @override
  Future<Object?> loadBanner(AdPlacement placement) async {
    loadedBanners.add(placement);
    return null;
  }

  @override
  Future<Object?> loadNative(AdPlacement placement) async {
    loadedNatives.add(placement);
    return null;
  }

  @override
  Future<bool> showInterstitial(AdPlacement placement) async {
    shownInterstitials.add(placement);
    return interstitialResult;
  }

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    shownRewarded.add(placement);
    return true;
  }

  @override
  Future<void> dispose() async => disposeCount++;
}
