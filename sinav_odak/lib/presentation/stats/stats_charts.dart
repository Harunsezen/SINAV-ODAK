import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// FAZ 3.2 — grafik çeşitliliği.
///
/// Üçü de **saf sunum**: veriyi dışarıdan alıyorlar, sorgu yapmıyorlar.
/// Böylece boyut/tema/boş durum davranışları widget testinde veritabanı
/// olmadan denenebiliyor.

/// Haftalık eğilim — çizgi grafik.
///
/// Boş günler `0` olarak geliyor (bkz. `BuildReportUseCase`): atlanırsa
/// çizgi iki uzak günü birleştirip **olmayan bir süreklilik** gösterirdi.
class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    required this.minutesPerDay,
    required this.labels,
    super.key,
  });

  final List<int> minutesPerDay;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY = minutesPerDay.isEmpty
        ? 60.0
        : (minutesPerDay.reduce((a, b) => a > b ? a : b) * 1.2).clamp(30, 1e9);

    return SizedBox(
      key: const Key('stats-trend-chart'),
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY.toDouble(),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 34),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      labels[i],
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: scheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: scheme.primary.withOpacity(0.12),
              ),
              spots: [
                for (var i = 0; i < minutesPerDay.length; i++)
                  FlSpot(i.toDouble(), minutesPerDay[i].toDouble()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ders dağılımı — pasta grafik.
class SubjectPieChart extends StatelessWidget {
  const SubjectPieChart({required this.slices, super.key});

  /// (ad, süre saniye, renk).
  final List<({String name, int studyS, Color color})> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (a, s) => a + s.studyS);
    if (total == 0) return const SizedBox.shrink();

    return SizedBox(
      key: const Key('stats-pie-chart'),
      height: 180,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: [
                  for (final s in slices)
                    PieChartSectionData(
                      value: s.studyS.toDouble(),
                      color: s.color,
                      radius: 44,
                      title: '%${(s.studyS / total * 100).round()}',
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Efsane ayrı sütunda: pasta dilimlerinin üstüne ders adı
          // yazmak dar ekranda okunmaz hâle geliyordu.
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, color: s.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gün × saat yoğunluk haritası.
///
/// **fl_chart'ta hazır ısı haritası yok**; takvim ekranındaki yoğunluk
/// deseni burada saat ekseniyle yeniden kullanılıyor. Ek paket
/// getirmemek APK'yı da küçük tutuyor.
class HourHeatmap extends StatelessWidget {
  const HourHeatmap({
    required this.counts,
    required this.weekdayLabels,
    super.key,
  });

  /// `counts[gün][saat]` — gün 0..6 (Pazartesi başlangıç), saat 0..23.
  final List<List<int>> counts;
  final List<String> weekdayLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var max = 0;
    for (final row in counts) {
      for (final v in row) {
        if (v > max) max = v;
      }
    }

    return Column(
      key: const Key('stats-heatmap'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var d = 0; d < counts.length; d++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    weekdayLabels.length > d ? weekdayLabels[d] : '',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                // `Expanded` + `Row`: 24 hücre dar ekranda da sığsın diye
                // sabit genişlik YOK, kalan alan paylaşılıyor.
                Expanded(
                  child: Row(
                    children: [
                      for (var h = 0; h < counts[d].length; h++)
                        Expanded(
                          child: Container(
                            height: 12,
                            margin: const EdgeInsets.symmetric(horizontal: 0.5),
                            decoration: BoxDecoration(
                              color: max == 0
                                  ? scheme.surfaceContainerHighest
                                  : Color.lerp(
                                      scheme.surfaceContainerHighest,
                                      AppColors.seed,
                                      counts[d][h] / max,
                                    ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // Saat ekseni: her saati yazmak dar ekranda okunmaz; 6 saatte bir.
        const Row(
          children: [
            SizedBox(width: 24),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('00', style: TextStyle(fontSize: 9)),
                  Text('06', style: TextStyle(fontSize: 9)),
                  Text('12', style: TextStyle(fontSize: 9)),
                  Text('18', style: TextStyle(fontSize: 9)),
                  Text('23', style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
