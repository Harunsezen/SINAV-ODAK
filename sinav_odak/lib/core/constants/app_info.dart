/// Uygulamanın kendisi hakkındaki sabitler.
///
/// **Neden `package_info_plus` değil:** o paket bir platform kanalı daha
/// demek ve widget testinde çağrıldığında çöküyor. Sürüm elde tutuluyor,
/// `pubspec.yaml` ile aynı kalması `test/unit/app_version_test.dart`
/// tarafından zorlanıyor — v1.3'e kadar bu eşitlik elde takip ediliyordu
/// ve kaçtı: mağazada 1.3.0 yayındayken Ayarlar hâlâ "1.0.0" yazıyordu.
library;

/// Kullanıcıya gösterilen ve yedek zarfına yazılan sürüm.
///
/// `pubspec.yaml`daki `version:` alanının `+` öncesi kısmı.
const String kAppVersion = '1.3.0';
