import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../session_setup/setup_controller.dart';
import 'pending_finish_controller.dart';

/// S11 — Tebrik ekranı.
///
/// Girdisi [savedResultProvider]'dır: kayıt tamamlandığı anda oturum artık
/// `running` değildir, dolayısıyla [runStateProvider] burada `idle` döner.
/// Ekranın gösterdiği skor, oturum sonu formunun `finishSession`'dan aldığı
/// değerdir.
///
/// Reklam **yalnızca kayıt TAMAMLANDIKTAN sonra**, yani bu ekranda
/// gösterilebilir (Adım 6). Oturum sonu formunda asla.
class DoneScreen extends ConsumerWidget {
  const DoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedResultProvider);

    if (saved == null) {
      return const Scaffold(
        key: Key('done-empty'),
        body: Center(child: Text('Gösterilecek oturum yok.')),
      );
    }

    final stat = ref.watch(dayStatsProvider(saved.dateKey)).valueOrNull;
    final goalMinutes = ref
            .watch(settingsStreamProvider)
            .valueOrNull
            ?.dailyGoalMinutes ??
        0;

    final todayStudyS = stat?.totalStudyS ?? 0;
    final goalS = goalMinutes * 60;
    final progress = goalS == 0 ? 0.0 : (todayStudyS / goalS).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tebrikler'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('done-body'),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            const Center(child: Text('Odak skorun')),
            const SizedBox(height: 8),
            Center(
              child: Text(
                // `interrupted` dışındaki her kapanışta skor hesaplanır;
                // yine de null gelirse çizgi gösterilir, ekran çökmez.
                saved.focusScore?.toString() ?? '—',
                key: const Key('done-focus-score'),
                style: AppTheme.counterStyle,
              ),
            ),
            const SizedBox(height: 24),

            Card(
              key: const Key('done-progress'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugünkü ilerleme',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text(
                      goalS == 0
                          ? formatDurationShort(todayStudyS)
                          : '${formatDurationShort(todayStudyS)}'
                              ' / ${formatDurationShort(goalS)}',
                      key: const Key('done-progress-text'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Soru: ${stat?.questionCount ?? 0}'
                      ' · Net: ${formatNet(stat?.net ?? 0)}',
                      key: const Key('done-progress-questions'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // FAZ 4 (reklam): BU EKRANDA reklam YOKTUR (G7). Interstitial
            // yalnızca [Ana panel] ile gerçekleşen Done→Home GEÇİŞİNDE,
            // frekans kapısı ve rıza kontrolünden sonra gösterilebilir (K6).

            FilledButton(
              key: const Key('done-new-session'),
              onPressed: () {
                // Yeni akış temiz seçimle başlar (R2: eski seçim sızmasın).
                ref.read(setupProvider.notifier).reset();
                ref.read(savedResultProvider.notifier).clear();
                context.go(Routes.sessionSubject);
              },
              child: const Text('Yeni oturum'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('done-home'),
              onPressed: () {
                ref.read(savedResultProvider.notifier).clear();
                context.go(Routes.home);
              },
              child: const Text('Ana panel'),
            ),
          ],
        ),
      ),
    );
  }
}
