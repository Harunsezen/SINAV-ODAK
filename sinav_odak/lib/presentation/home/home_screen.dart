import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../ads/banner_ad_slot.dart';
import '../session_setup/setup_controller.dart';
import 'recovery_gate.dart';

/// Ana panel (FAZ 5).
///
/// Önceki hali tek butondan ibaretti. Artık kullanıcı uygulamayı açtığında
/// **bugün ne yaptığını** görüyor: streak, günlük ilerleme halkası, soru/net
/// özeti ve son oturumlar.
///
/// Gösterilen streak DB'deki ham değer değil, `StreakCalculator.displayStreak`
/// sonucudur: zincir koptuysa kullanıcıya 0 görünür ama DB'deki değere
/// dokunulmaz — yazma yolu yalnızca kayıt anıdır.
///
/// v1.2'de i18n (FAZ 6).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayKeyProvider);
    final stat = ref.watch(dayStatsProvider(today)).valueOrNull;
    final settings = ref.watch(settingsStreamProvider).valueOrNull;
    final streak = ref.watch(displayStreakProvider);

    final goalMinutes = settings?.dailyGoalMinutes ?? 0;
    final goalQuestions = settings?.dailyGoalQuestions ?? 0;
    final studyS = stat?.totalStudyS ?? 0;
    final goalS = goalMinutes * 60;
    final ratio = goalS == 0 ? 0.0 : (studyS / goalS).clamp(0.0, 1.0);

    // Yarıda kalan oturum kararı ana panelde, TEK kez sorulur (KARAR D2).
    return RecoveryGate(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sınav Odak'),
          actions: [
            if (streak > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: AppColors.streak,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      key: const Key('home-streak'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: ListView(
          key: const Key('home-body'),
          padding: const EdgeInsets.all(16),
          children: [
            const BannerAdSlot(placement: AdPlacement.homeBanner),
            const SizedBox(height: 12),
            Card(
              key: const Key('home-today'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 12),
                    Text(
                      goalS == 0
                          ? formatDurationShort(studyS)
                          : '${formatDurationShort(studyS)}'
                              ' / ${formatDurationShort(goalS)}',
                      key: const Key('home-today-duration'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            slug: 'questions',
                            label: 'Soru',
                            value: goalQuestions == 0
                                ? '${stat?.questionCount ?? 0}'
                                : '${stat?.questionCount ?? 0}/$goalQuestions',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            slug: 'net',
                            label: 'Net',
                            value: formatNet(stat?.net ?? 0),
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            slug: 'focus',
                            label: 'Odak',
                            value: stat == null || stat.avgFocusScore == 0
                                ? '—'
                                : stat.avgFocusScore.round().toString(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('home-start'),
              onPressed: () {
                // Yeni akış temiz seçimle başlar (R2: eski seçim sızmasın).
                ref.read(setupProvider.notifier).reset();
                context.go(Routes.sessionSubject);
              },
              child: const Text('Oturumu Başlat'),
            ),
            const SizedBox(height: 24),
            Text(
              'Son oturumlar',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _RecentSessions(),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
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
        Text(
          value,
          key: Key('home-metric-$slug'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _RecentSessions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSessionsProvider).valueOrNull;

    if (recent == null || recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Henüz kayıtlı oturum yok.',
          key: Key('home-recent-empty'),
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return Column(
      children: [
        for (final s in recent)
          Card(
            key: Key('home-recent-${s.id}'),
            child: ListTile(
              dense: true,
              title: Text(formatDurationShort(s.actualDurationS)),
              subtitle: Text(
                '${s.dateKey} · ${s.questionCount} soru'
                ' · net ${formatNet(s.net)}',
              ),
              trailing: Text(
                s.focusScore?.toString() ?? '—',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}
