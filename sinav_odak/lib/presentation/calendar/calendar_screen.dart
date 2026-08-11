import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../core/utils/date_key.dart';
import '../../domain/entities/ad_placement.dart';
import '../ads/banner_ad_slot.dart';

/// Takvim ekranı (FAZ 7B).
///
/// Kaynak `daily_stats` — oturum kaydedildikçe `recomputeDay` ile güncellenen
/// denormalize günlük özet. Ay ızgarası için ham oturumları taramaya gerek yok.
///
/// **Saat `clockProvider`'dan.** `DateTime.now()` doğrudan çağrılsaydı ekran
/// test edilemezdi; "bugün" vurgusu ve açılış ayı sabit `t0` ile
/// doğrulanabiliyor.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final month = ref.watch(calendarMonthProvider);
    final daily = ref.watch(calendarDaysProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.calendarTitle)),
      body: Column(
        children: [
          Expanded(
            child: daily.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) {
                // dateKey -> (süre, oturum). Izgara her hücrede sözlükten
                // okuyor; listeyi 42 kez taramak gereksiz.
                final byDay = {
                  for (final r in rows)
                    r.dateKey: (
                      studyS: r.totalStudyS,
                      sessions: r.sessionCount
                    ),
                };
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const _MonthHeader(),
                    const SizedBox(height: 12),
                    _MonthGrid(month: month, byDay: byDay),
                    const SizedBox(height: 16),
                    if (byDay.isEmpty)
                      const _EmptyState()
                    else
                      _MonthSummary(byDay: byDay),
                  ],
                );
              },
            ),
          ),
          // Yuva FAZ 4'ten beri burada; politika kapılı (rıza yoksa yer
          // ayrılmaz).
          const BannerAdSlot(placement: AdPlacement.calendarBanner),
        ],
      ),
    );
  }
}

/// Ay başlığı + ileri/geri gezinme.
class _MonthHeader extends ConsumerWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final month = ref.watch(calendarMonthProvider);
    final today = ref.watch(calendarTodayProvider);
    final isCurrentMonth =
        month.year == today.year && month.month == today.month;

    return Row(
      children: [
        IconButton(
          key: const Key('calendar-prev'),
          tooltip: l.calendarPrevMonth,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(calendarMonthProvider.notifier).state =
              DateTime(month.year, month.month - 1),
        ),
        Expanded(
          child: Text(
            '${l.monthName(month.month.toString())} ${month.year}',
            key: const Key('calendar-month-label'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // İleri gitmek yalnızca geçmiş aylardayken anlamlı: gelecek ayda
        // veri olamaz, boş ızgarada gezdirmek kullanıcıyı yorar.
        IconButton(
          key: const Key('calendar-next'),
          tooltip: l.calendarNextMonth,
          icon: const Icon(Icons.chevron_right),
          onPressed: isCurrentMonth
              ? null
              : () => ref.read(calendarMonthProvider.notifier).state =
                  DateTime(month.year, month.month + 1),
        ),
      ],
    );
  }
}

/// 7 sütunlu ay ızgarası (Pazartesi başlangıçlı).
class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.month, required this.byDay});

  final DateTime month;
  final Map<String, ({int studyS, int sessions})> byDay;

  /// Yoğunluk kademeleri (dakika). Çalışılan gün ne kadar koyu görünecek.
  static const List<int> _tiers = [30, 90, 180];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final today = ref.watch(calendarTodayProvider);
    final scheme = Theme.of(context).colorScheme;

    final first = DateTime(month.year, month.month);
    // `DateTime(y, m+1, 0)` bir önceki ayın son günü = bu ayın gün sayısı.
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Pazartesi = 1 ... Pazar = 7 → ızgarada kaç boş hücre var.
    final leading = first.weekday - DateTime.monday;

    final weekdays = [
      l.calendarWeekdayMon,
      l.calendarWeekdayTue,
      l.calendarWeekdayWed,
      l.calendarWeekdayThu,
      l.calendarWeekdayFri,
      l.calendarWeekdaySat,
      l.calendarWeekdaySun,
    ];

    return Column(
      key: const Key('calendar-grid'),
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, i) {
            if (i < leading) return const SizedBox.shrink();

            final dayNumber = i - leading + 1;
            final date = DateTime(month.year, month.month, dayNumber);
            final entry = byDay[dateKeyOf(date)];
            final minutes = (entry?.studyS ?? 0) ~/ 60;
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;

            return _DayCell(
              key: Key('calendar-day-$dayNumber'),
              day: dayNumber,
              monthLabel: l.monthName(month.month.toString()),
              minutes: minutes,
              sessions: entry?.sessions ?? 0,
              isToday: isToday,
              color: _colorFor(minutes, scheme),
            );
          },
        ),
        const SizedBox(height: 10),
        const _Legend(tiers: _tiers),
      ],
    );
  }

  Color _colorFor(int minutes, ColorScheme scheme) {
    if (minutes <= 0) return scheme.surfaceContainerHighest;
    if (minutes < _tiers[0]) return scheme.primary.withOpacity(0.25);
    if (minutes < _tiers[1]) return scheme.primary.withOpacity(0.50);
    if (minutes < _tiers[2]) return scheme.primary.withOpacity(0.75);
    return scheme.primary;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.monthLabel,
    required this.minutes,
    required this.sessions,
    required this.isToday,
    required this.color,
    super.key,
  });

  final int day;
  final String monthLabel;
  final int minutes;
  final int sessions;
  final bool isToday;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;

    // Koyu dolgu üzerinde koyu yazı okunmuyor: eşik üstünde ters renk.
    final onColor = minutes >= 180 ? scheme.onPrimary : scheme.onSurface;

    return Tooltip(
      message: minutes > 0
          ? l.calendarDayDetail('$day', _duration(context, minutes), sessions)
          : l.calendarDayEmpty('$day'),
      // Ekran okuyucu için: sadece "5" demek yerine günün özeti.
      child: Semantics(
        label: minutes > 0
            ? l.a11yCalendarDay(
                day,
                monthLabel,
                _duration(context, minutes),
                sessions,
              )
            : l.a11yCalendarDayEmpty(day, monthLabel),
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border:
                isToday ? Border.all(color: scheme.primary, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: onColor,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              if (sessions > 0)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _duration(BuildContext context, int minutes) {
    final l = L10n.of(context);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return h == 0 ? l.durationM(m) : l.durationHm(h, m);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.tiers});

  final List<int> tiers;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final shades = [
      scheme.surfaceContainerHighest,
      scheme.primary.withOpacity(0.25),
      scheme.primary.withOpacity(0.50),
      scheme.primary.withOpacity(0.75),
      scheme.primary,
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(l.calendarLegendLess, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 6),
        for (final c in shades)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        const SizedBox(width: 6),
        Text(l.calendarLegendMore, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.byDay});

  final Map<String, ({int studyS, int sessions})> byDay;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final totalS = byDay.values.fold<int>(0, (a, e) => a + e.studyS);
    final studiedDays = byDay.values.where((e) => e.studyS > 0).length;
    final totalMinutes = totalS ~/ 60;

    return Card(
      key: const Key('calendar-summary'),
      child: ListTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(l.calendarMonthTotal),
        subtitle: Text(l.calendarStudyDays(studiedDays)),
        trailing: Text(
          totalMinutes >= 60
              ? l.durationHm(totalMinutes ~/ 60, totalMinutes % 60)
              : l.durationM(totalMinutes),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      key: const Key('calendar-empty'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined, size: 40),
          const SizedBox(height: 8),
          Text(l.calendarEmpty, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            l.calendarEmptyHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
