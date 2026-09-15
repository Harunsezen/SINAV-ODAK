import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../../domain/entities/ad_placement.dart';

/// İnce banner yuvası.
///
/// **Politika izin vermiyorsa hiç yer AYIRMAZ** (`SizedBox.shrink`). Boş bir
/// çerçeve bırakmak, rıza vermemiş kullanıcıya "burada reklam olacaktı"
/// demekti; ayrıca çalışma ekranında sayaç yukarı kayardı.
///
/// Aktif çalışma ekranında **yalnızca bu format** kullanılabilir; tam ekran
/// reklam orada ASLA gösterilmez (G7). Kural `AdPolicyEngine`'de ve
/// `AdGateway` implementasyonunda ayrıca zorlanıyor.
class BannerAdSlot extends ConsumerWidget {
  const BannerAdSlot({required this.placement, super.key});

  final AdPlacement placement;

  /// Standart AdMob banner yüksekliği.
  static const double height = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(adAllowedProvider(placement))) {
      return const SizedBox.shrink();
    }

    // Reklam YÜKLENEMEZSE yuva hiç çizilmiyor (v1.3 yaması).
    //
    // Önceden burada "İnternet yok, reklam yok — Balto da tatilde"
    // yazan gri bir çubuk kalıyordu. İki sorunu vardı:
    //
    // 1. **Mesaj bilmediği bir şeyi iddia ediyordu.** `bannerLoadedProvider`
    //    yalnızca `true/false` döndürüyor, sebebi taşımıyor — bağlantı
    //    hiç ölçülmüyor. Yeni bir reklam biriminde en sık görülen sebep
    //    internetin yokluğu değil, AdMob'un gösterecek reklamı olmaması
    //    (no-fill). Yani çubuk, interneti tıkır tıkır çalışan kullanıcıya
    //    "internetin yok" diyordu.
    // 2. Reklamın gelmediği yerde reklam yuvası göstermek, boş çerçeveyi
    //    önlemek için konmuştu ama tam da onu yapıyordu.
    //
    // Reklam yoksa en dürüst davranış hiç yer ayırmamak. Yükleme sürerken
    // (`null`) yuva duruyor: reklam geldiğinde içerik aşağı kaymasın.
    final loaded = ref.watch(bannerLoadedProvider(placement)).valueOrNull;
    if (loaded == false) return const SizedBox.shrink();

    return Container(
      key: Key('banner-slot-${placement.name}'),
      height: height,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        // Her reklam alanının üstünde etiket ZORUNLU.
        L10n.of(context).adSponsored,
        key: Key('banner-label-${placement.name}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
