import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../../domain/entities/ad_placement.dart';

/// Mola ekranı native kart yuvası.
///
/// Ürün kuralları burada görünür hale geliyor:
/// - Politika izin vermiyorsa **hiç yer ayrılmaz**
/// - Kart [revealDelay] kadar gecikmeli belirir: mola başlar başlamaz
///   ekrana kart fırlamak, dinlenmeye geçen öğrenciyi rahatsız eder
/// - **"Sponsorlu" etiketi zorunlu**
/// - Karttan en yakın butona **en az [minButtonGap] dp** boşluk: kazara
///   tıklama hem kullanıcıyı hem de reklam hesabını yakar
class NativeAdSlot extends ConsumerStatefulWidget {
  const NativeAdSlot({required this.placement, super.key});

  final AdPlacement placement;

  static const Duration revealDelay = Duration(milliseconds: 1200);
  static const double minButtonGap = 48;
  static const double cardHeight = 120;

  @override
  ConsumerState<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends ConsumerState<NativeAdSlot> {
  Timer? _timer;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(NativeAdSlot.revealDelay, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void dispose() {
    // Timer bırakılmazsa mola ekranı kapandıktan sonra da tetiklenir;
    // widget testleri de "askıda timer" diye hata verir.
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(adAllowedProvider(widget.placement))) {
      return const SizedBox.shrink();
    }
    if (!_revealed) {
      // Gecikme boyunca da yer AYRILMAZ: kart belirince düzen kaysın,
      // öncesinde boş kutu durmasın.
      return const SizedBox.shrink();
    }

    return Padding(
      // Butonlardan güvenli mesafe.
      padding: const EdgeInsets.only(bottom: NativeAdSlot.minButtonGap),
      child: Container(
        key: Key('native-slot-${widget.placement.name}'),
        height: NativeAdSlot.cardHeight,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  L10n.of(context).adSponsored,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
