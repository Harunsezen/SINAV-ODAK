import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../../domain/entities/ad_placement.dart';

/// İnce banner yuvası.
///
/// **Politika izin vermiyorsa hiç yer AYIRMAZ** (`SizedBox.shrink`). Boş bir
/// çerçeve bırakmak, reklamı olmayan kullanıcıya "burada reklam olacaktı"
/// demekti.
///
/// Çalışma ekranında (`AdPlacement.runBanner`) bu yuva **her koşulda**
/// reddediliyor — kural `AdPolicyEngine` içinde (v1.5).
///
/// ## v1.5.1 — reklam artık GERÇEKTEN çiziliyor
///
/// Önceki hâlinde bu widget yalnızca gri bir kutu ile "Sponsorlu" yazısı
/// çiziyordu: projede `AdWidget` hiç kullanılmamıştı, yüklenen reklam
/// nesnesi `handle != null` diye bool'a çevrilip atılıyordu. Reklam ekrana
/// hiç konmadığı için **gösterim de hiç oluşmadı, kazanç da**. Kullanıcı
/// yarım saniye "Sponsorlu" yazan boş bir şerit görüp kayboluşunu
/// izliyordu.
///
/// Artık `bannerAdProvider` nesnenin kendisini taşıyor ve
/// `adViewBuilderProvider` onu widget'a çeviriyor. Bu dolaylılık şart:
/// `google_mobile_ads` platform kanalı kullanıyor, ekranlar onu tanırsa
/// host testlerinde çalışamaz hale gelir.
class BannerAdSlot extends ConsumerWidget {
  const BannerAdSlot({required this.placement, super.key});

  final AdPlacement placement;

  /// Standart AdMob banner yüksekliği.
  static const double adHeight = 50;

  /// "Sponsorlu" etiketi için ayrılan şerit.
  static const double labelHeight = 16;

  /// Yuvanın toplam yüksekliği.
  static const double height = adHeight + labelHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adAllowedProvider(placement))) {
      return const SizedBox.shrink();
    }

    // Reklam GELMEDİYSE (ya da henüz yüklenmediyse) hiç yer ayrılmıyor.
    //
    // v1.4'te burada "İnternet yok, reklam yok — Balto da tatilde" yazan
    // gri bir çubuk kalıyordu ve bu metin bilmediği bir şeyi iddia
    // ediyordu: yükleyici sebebi taşımıyor, bağlantı hiç ölçülmüyor. Yeni
    // bir reklam biriminde en sık sebep internetin yokluğu değil, AdMob'un
    // gösterecek reklamı olmaması.
    final ad = ref.watch(bannerAdProvider(placement)).valueOrNull;
    if (ad == null) return const SizedBox.shrink();

    final view = ref.watch(adViewBuilderProvider)(ad);

    return SizedBox(
      key: Key('banner-slot-${placement.name}'),
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Her reklam alanının üstünde etiket ZORUNLU.
          SizedBox(
            height: labelHeight,
            child: Text(
              L10n.of(context).adSponsored,
              key: Key('banner-label-${placement.name}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          SizedBox(
            height: adHeight,
            width: double.infinity,
            // `view` yalnızca testlerde ve Noop kurulumda null olur; o
            // durumda etiketli boş şerit kalır, hiçbir şey çökmez.
            child: view ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
