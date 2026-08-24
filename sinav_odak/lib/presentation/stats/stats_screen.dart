import 'package:fl_chart/fl_chart.dart';
import '../../core/utils/color_hex.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/l10n/format_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../application/usecases/export_sessions.dart';
import '../../core/utils/date_key.dart';
import '../../domain/entities/ad_placement.dart';
import '../ads/banner_ad_slot.dart';
import 'report_button.dart';
import 'stats_charts.dart';

/// İstatistik ekranı (FAZ 7A).
///
/// Kaynak `daily_stats`: oturumlar her kaydedildiğinde `recomputeDay` ile
/// güncellenen denormalize özet. Grafik çizmek için ham oturumları taramak
/// yerine bu tablo okunuyor.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final daily = ref.watch(statsDailyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.statsTitle),
        actions: const [ReportButton(), _ExportButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: daily.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const _RangeSelector(),
                  const SizedBox(height: 16),
                  if (rows.isEmpty)
                    const _EmptyState()
                  else ...[
                    const _SummaryGrid(),
                    const SizedBox(height: 20),
                    // v1.3 — KİTAP kartı. Hiç okuma yoksa ÇİZİLMİYOR:
                    // "0 sayfa" yazan bir kart, olmayan bir özelliği
                    // eksik gibi gösterirdi.
                    const _BookCard(),
                    _DailyChart(
                      rows: [
                        for (final r in rows)
                          (
                            dateKey: r.dateKey,
                            studyS: r.totalStudyS,
                            readingS: r.readingS,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // FAZ 3.2 — üç grafik: çizgi, pasta, ısı haritası.
                    const _TrendSection(),
                    const SizedBox(height: 20),
                    const _HeatmapSection(),
                    const SizedBox(height: 20),
                    // Pasta ve liste AYNI başlık altında: ikisi de ders
                    // dağılımı. Ayrı başlıklarla dursalardı ekranda iki
                    // kez "Ders dağılımı" yazardı (UX_REVIEW FAZ 3).
                    const _PieSection(),
                    const _SubjectBreakdown(),
                    const SizedBox(height: 20),
                    const _WeakestTopics(),
                  ],
                ],
              ),
            ),
          ),
          const BannerAdSlot(placement: AdPlacement.statsBanner),
        ],
      ),
    );
  }
}

/// Hafta / Ay seçimi.
class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return SegmentedButton<StatsRange>(
      key: const Key('stats-range'),
      segments: [
        ButtonSegment(value: StatsRange.week, label: Text(l.statsRangeWeek)),
        ButtonSegment(value: StatsRange.month, label: Text(l.statsRangeMonth)),
      ],
      selected: {ref.watch(statsRangeProvider)},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(statsRangeProvider.notifier).state = s.first,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      key: const Key('stats-empty'),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.insights_outlined, size: 48),
          const SizedBox(height: 12),
          Text(l.statsEmpty, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            l.statsEmptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Aralık toplamları.
class _SummaryGrid extends ConsumerWidget {
  const _SummaryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final summary = ref.watch(statsSummaryProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();

    return Wrap(
      key: const Key('stats-summary'),
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatChip(
          label: l.statsTotalStudy,
          value: formatDuration(context, summary.totalStudyS),
          icon: Icons.schedule,
        ),
        _StatChip(
          label: l.statsSessionCount,
          value: '${summary.sessionCount}',
          icon: Icons.play_circle_outline,
        ),
        _StatChip(
          label: l.statsNet,
          value: l.decimalFixed(summary.net, 1),
          icon: Icons.functions,
        ),
        _StatChip(
          label: l.statsAvgFocus,
          value: summary.avgFocusScore.round().toString(),
          icon: Icons.center_focus_strong_outlined,
        ),
        if (summary.questionCount > 0)
          _StatChip(
            label: l.statsSuccessRate,
            value: l.percentValue((summary.successRate * 100).round()),
            icon: Icons.check_circle_outline,
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 11)),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// KİTAP OKUMA kartı (v1.3) — okuma süresi + toplam sayfa.
///
/// **Çalışma kartlarından AYRI.** Okuma süresi `totalStudyS`'e
/// katılmıyor; kendi kartında, kendi rakamlarıyla duruyor. Aynı satıra
/// karıştırılsaydı "bu hafta 12 saat çalıştım" cümlesi doğru olmaktan
/// çıkardı.
class _BookCard extends ConsumerWidget {
  const _BookCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final summary = ref.watch(statsSummaryProvider).valueOrNull;
    if (summary == null || !summary.hasReading) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        key: const Key('stats-book-card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l.statsBookTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BookMetric(
                      slug: 'duration',
                      label: l.statsBookDuration,
                      value: formatDuration(context, summary.readingS),
                    ),
                  ),
                  Expanded(
                    child: _BookMetric(
                      slug: 'pages',
                      label: l.statsBookPages,
                      value: '${summary.pagesRead}',
                    ),
                  ),
                  Expanded(
                    child: _BookMetric(
                      slug: 'sessions',
                      label: l.statsBookSessions,
                      value: '${summary.bookSessionCount}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookMetric extends StatelessWidget {
  const _BookMetric({
    required this.slug,
    required this.label,
    required this.value,
  });

  final String slug;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // `FittedBox`: 360 px + textScale 1.5'te "2 sa 30 dk" iki satıra
        // bölünüyor ve okunmaz oluyordu (ana paneldeki `_Metric` ile aynı
        // ders).
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            key: Key('stats-book-$slug'),
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Günlük çalışma çubuk grafiği.
///
/// Drift'in `DailyStat` satırını DEĞİL, sade kayıtlar alıyor: grafik
/// veritabanı şemasını bilmek zorunda değil (G4).
///
/// v1.3 — **okuma süresi de bu grafikte**, ama çalışmanın ÜSTÜNE yığılmış
/// ayrı bir renkte. Tek renge katılsaydı grafiğe bakan öğrenci "iki saat
/// çalışmışım" sanırdı; hiç gösterilmeseydi o gün kitap okuyan öğrenci
/// grafikte boş bir sütun görürdü. Yığılmış çubuk ikisini birden veriyor:
/// toplam yükseklik günün tamamı, renkler kırılımı.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.rows});

  final List<({String dateKey, int studyS, int readingS})> rows;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    final studyMinutes = rows.map((r) => r.studyS / 60).toList();
    final readMinutes = rows.map((r) => r.readingS / 60).toList();
    final totals = [
      for (var i = 0; i < rows.length; i++) studyMinutes[i] + readMinutes[i],
    ];
    final hasReading = rows.any((r) => r.readingS > 0);

    // maxY 0 olursa fl_chart ekseni çizemiyor; en az 60 dk'lık bir tavan
    // veriliyor ki boş günlerde grafik "ezik" görünmesin.
    final maxY = totals.fold<double>(60, (a, b) => b > a ? b : a) * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık v1.3'te "Günlük çalışma"dan "Günlük süre"ye çevrildi:
        // çubuklara okuma da girdikten sonra "çalışma" demek, grafiğe
        // bakan öğrenciye okuma dakikalarını çalışma diye saydırırdı.
        // Efsane kırılımı hemen altında veriyor.
        Text(
          l.statsDailyChart,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        // Efsane YALNIZCA okuma varken: hiç kitap okumamış kullanıcıya
        // tek renkli grafiğin altında iki renkli bir açıklama göstermek
        // gereksiz gürültü olurdu.
        if (hasReading) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('stats-chart-legend'),
            children: [
              _LegendDot(color: scheme.primary, label: l.statsLegendStudy),
              const SizedBox(width: 16),
              _LegendDot(color: scheme.tertiary, label: l.statsLegendReading),
            ],
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          key: const Key('stats-daily-chart'),
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 34),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= rows.length) {
                        return const SizedBox.shrink();
                      }
                      // Ay görünümünde her günün etiketi okunmuyor;
                      // seyreltiliyor.
                      final step = (rows.length / 7).ceil();
                      if (step > 1 && i % step != 0) {
                        return const SizedBox.shrink();
                      }
                      final d = dateKeyToLocal(rows[i].dateKey);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${d.day}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < rows.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totals[i],
                        width: rows.length > 14 ? 6 : 14,
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(4),
                        // Okuma çalışmanın ÜSTÜNE yığılıyor. `rodStackItems`
                        // boşsa `color` geçerli; yani okuma yoksa çubuk
                        // v1.2'deki gibi tek renk kalıyor.
                        rodStackItems: readMinutes[i] <= 0
                            ? const []
                            : [
                                BarChartRodStackItem(
                                  0,
                                  studyMinutes[i],
                                  scheme.primary,
                                ),
                                BarChartRodStackItem(
                                  studyMinutes[i],
                                  totals[i],
                                  scheme.tertiary,
                                ),
                              ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Grafik efsanesi: renk noktası + etiket.
class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

/// Ders dağılımı — süreye göre oransal çubuklar.
class _SubjectBreakdown extends ConsumerWidget {
  const _SubjectBreakdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final rows = ref.watch(statsBreakdownProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    final total = rows.fold<int>(0, (a, r) => a + r.studyS);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      key: const Key('stats-breakdown'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.statsSubjectBreakdown,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          _BreakdownBar(
            subjectName: r.subjectName,
            colorHex: r.colorHex,
            studyS: r.studyS,
            total: total,
          ),
      ],
    );
  }
}

class _BreakdownBar extends StatelessWidget {
  const _BreakdownBar({
    required this.subjectName,
    required this.colorHex,
    required this.studyS,
    required this.total,
  });

  final String subjectName;
  final String colorHex;
  final int studyS;
  final int total;

  Color get _color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return const Color(0xFF4F5BD5);
    return Color(hex.length <= 6 ? 0xFF000000 | value : value);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = studyS / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subjectName,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                formatDuration(context, studyS),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 8),
              Text(
                L10n.of(context).percentValue((ratio * 100).round()),
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ],
      ),
    );
  }
}

/// En çok yanlış yapılan konular.
class _WeakestTopics extends ConsumerWidget {
  const _WeakestTopics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final rows = ref.watch(statsWeakestProvider).valueOrNull ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('stats-weakest'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.statsWeakestTopics,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final r in rows.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trending_down, size: 20),
            title: Text(r.topicName, style: const TextStyle(fontSize: 13)),
            subtitle: Text(r.subjectName, style: const TextStyle(fontSize: 11)),
            trailing: Text(l.statsWeakestTopicWrongs(r.wrongCount)),
          ),
      ],
    );
  }
}

/// CSV dışa aktarma.
class _ExportButton extends ConsumerStatefulWidget {
  const _ExportButton();

  @override
  ConsumerState<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends ConsumerState<_ExportButton> {
  bool _busy = false;

  Future<void> _export() async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    final bounds = ref.read(statsBoundsProvider);
    final outcome = await ref.read(exportSessionsProvider)(
      from: bounds.from,
      to: bounds.to,
      subject: l.statsExportSubject,
      // Başlıklar arayüzle aynı dilden: İngilizce bir uygulamadan
      // Türkçe başlıklı dosya çıkmasın.
      headers: ref.read(csvHeadersProvider),
    );

    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          switch (outcome) {
            ExportOutcome.shared => l.statsExportDone,
            ExportOutcome.empty => l.statsExportEmpty,
            ExportOutcome.failed => l.statsExportFailed,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return IconButton(
      key: const Key('stats-export'),
      tooltip: l.statsExport,
      onPressed: _busy ? null : _export,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share),
    );
  }
}

/// Saniyeyi "2sa 15dk" / "45dk" biçimine çevirir (ARB'den).
///
/// v1.2/E öncesinde uygulamada **iki ayrı süre biçimi** vardı: burası ve
/// takvim "1 sa 36 dk" yazarken ana panel, plan, özet ve karşılama
/// `formatDurationShort` ile "1sa 36dk" yazıyordu. Aynı uygulamada aynı
/// verinin iki yazımı. Tek uygulamaya indirildi; biçim artık yalnızca
/// `L10n.durationShort` içinde.
String formatDuration(BuildContext context, int seconds) =>
    L10n.of(context).durationShort(seconds);

// =====================================================================
// FAZ 3.2 — grafikler
// =====================================================================

/// Haftalık eğilim (çizgi).
class _TrendSection extends ConsumerWidget {
  const _TrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final rows = ref.watch(statsDailyProvider).valueOrNull ?? const [];

    // **HAFTALIK toplam — günlük DEĞİL.**
    //
    // İlk uygulamada bu grafik günlük dakikaları çiziyordu, yani hemen
    // üstündeki çubuk grafikle AYNI veriyi gösteriyordu (UX_REVIEW FAZ 3).
    // İki farklı biçimde aynı seri bilgi değil gürültü; brief de zaten
    // "haftalık trend" diyordu.
    //
    // Hafta aralığında tek nokta çıkacağı için gizleniyor: anlamlı bir
    // eğilim en az iki hafta ister.
    final weeks = <String, int>{};
    for (final r in rows) {
      final key = dateKeyOf(startOfWeek(DateTime.parse(r.dateKey)));
      weeks[key] = (weeks[key] ?? 0) + r.totalStudyS;
    }
    if (weeks.length < 2) return const SizedBox.shrink();

    final keys = weeks.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.statsChartTrend, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TrendLineChart(
          minutesPerDay: [for (final k in keys) weeks[k]! ~/ 60],
          // Haftanın başladığı gün ("04"); tam tarih dar ekranda üst üste
          // biniyordu.
          labels: [for (final k in keys) k.split('-').last],
        ),
      ],
    );
  }
}

/// Ders dağılımı (pasta).
class _PieSection extends ConsumerWidget {
  const _PieSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(statsBreakdownProvider).valueOrNull;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();

    // **Başlık YOK — hemen altındaki `_SubjectBreakdown` zaten
    // "Ders dağılımı" diyor.** İlk uygulamada ikisinin de başlığı vardı
    // ve ekranda aynı başlık iki kez görünüyordu; dar ekran görüntüsünde
    // yakalandı (UX_REVIEW FAZ 3).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubjectPieChart(
          slices: [
            for (final r in rows)
              (
                name: r.subjectName,
                studyS: r.studyS,
                color: colorFromHex(
                  r.colorHex,
                  fallback: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Gün × saat yoğunluğu (ısı haritası).
class _HeatmapSection extends ConsumerWidget {
  const _HeatmapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final grid = ref.watch(statsHourHeatmapProvider).valueOrNull;
    if (grid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.statsChartHeat, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        HourHeatmap(
          counts: grid,
          weekdayLabels: [
            l.calendarWeekdayMon,
            l.calendarWeekdayTue,
            l.calendarWeekdayWed,
            l.calendarWeekdayThu,
            l.calendarWeekdayFri,
            l.calendarWeekdaySat,
            l.calendarWeekdaySun,
          ],
        ),
      ],
    );
  }
}
