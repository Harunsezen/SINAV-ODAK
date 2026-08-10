import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';

/// Net katsayısı ayarı + **geçmiş netlerin yeniden hesaplanması**.
///
/// `study_sessions.net` denormalize: oturum kaydedilirken o anki katsayıyla
/// hesaplanıp yazılıyor. Katsayı değişince geçmiş satırlar eski değerde
/// kalıyordu ve toplam net **sessizce yanlış** oluyordu — istatistik ekranı
/// iki farklı katsayının karışımını tek sayı gibi gösteriyordu.
///
/// Bu yüzden değişiklik **onay ister**: kullanıcı ne olacağını görüp
/// kabul eder, sonra `RecomputeNetsUseCase` çalışır.
class NetCoefficientTile extends ConsumerStatefulWidget {
  const NetCoefficientTile({required this.current, super.key});

  final double current;

  /// Yaygın sınav katsayıları. Serbest metin alanı DEĞİL: 0 veya negatif
  /// katsayı `NetCalculator`'ı `ValidationFailure` ile patlatıyor ve
  /// kullanıcının böyle bir değeri yazabilmesi için hiçbir sebep yok.
  static const List<double> options = [3, 4, 5];

  @override
  ConsumerState<NetCoefficientTile> createState() => _NetCoefficientTileState();
}

class _NetCoefficientTileState extends ConsumerState<NetCoefficientTile> {
  bool _busy = false;

  static String label(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  /// [value] listede yoksa en yakın seçeneği döner.
  static double _nearestOption(double value) {
    var best = NetCoefficientTile.options.first;
    for (final o in NetCoefficientTile.options) {
      if ((o - value).abs() < (best - value).abs()) best = o;
    }
    return best;
  }

  Future<void> _select(double next) async {
    if (next == widget.current || _busy) return;
    final l = L10n.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('net-recompute-dialog'),
        title: Text(l.settingsNetRecomputeTitle),
        content: Text(
          l.settingsNetRecomputeBody(label(widget.current), label(next)),
        ),
        actions: [
          TextButton(
            key: const Key('net-recompute-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('net-recompute-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.settingsNetRecomputeConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);

    // Ayar yazma + geçmiş netlerin yeniden hesaplanması TEK yerde
    // (`SettingsController`): sıra kritik ve arayüzde tekrarlanmamalı.
    final updated =
        await ref.read(settingsControllerProvider).setNetCoefficient(next);

    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.settingsNetRecomputeDone(updated))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l.settingsNetCoefficient)),
            if (_busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              SegmentedButton<double>(
                key: const Key('settings-net-coefficient'),
                segments: [
                  for (final v in NetCoefficientTile.options)
                    ButtonSegment(value: v, label: Text(label(v))),
                ],
                // `selected` segmentlerde OLMAK ZORUNDA: aksi halde
                // SegmentedButton assertion atıyor ve Ayarlar ekranı
                // tamamen çöküyor. Veritabanında listede olmayan bir
                // katsayı varsa (eski sürüm, elle düzenleme) en yakınına
                // düşülüyor.
                selected: {_nearestOption(widget.current)},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _select(s.first),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.settingsNetCoefficientNote,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
