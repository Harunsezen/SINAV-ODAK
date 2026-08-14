import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../domain/services/achievement_calculator.dart';
import '../achievements/achievements_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../achievements/achievement_toast.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../ads/interstitial_controller.dart';
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

  /// Ana panele döner; izin varsa önce ara reklamı gösterir.
  Future<void> _goHome(WidgetRef ref, BuildContext context) async {
    await ref
        .read(interstitialControllerProvider)
        .maybeShow(AdPlacement.doneInterstitial);

    ref.read(savedResultProvider.notifier).clear();
    if (context.mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final saved = ref.watch(savedResultProvider);

    if (saved == null) {
      return Scaffold(
        key: const Key('done-empty'),
        body: Center(child: Text(l.doneEmpty)),
      );
    }

    final stat = ref.watch(dayStatsProvider(saved.dateKey)).valueOrNull;
    final goalMinutes =
        ref.watch(settingsStreamProvider).valueOrNull?.dailyGoalMinutes ?? 0;

    final todayStudyS = stat?.totalStudyS ?? 0;
    final goalS = goalMinutes * 60;
    final progress = goalS == 0 ? 0.0 : (todayStudyS / goalS).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.doneTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('done-body'),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            Center(child: Text(l.doneFocusScore)),
            const SizedBox(height: 8),
            Center(
              child: Semantics(
                label: saved.focusScore == null
                    ? null
                    : l.a11yFocusScore(saved.focusScore!),
                excludeSemantics: saved.focusScore != null,
                child: Text(
                  // `interrupted` dışındaki her kapanışta skor hesaplanır;
                  // yine de null gelirse çizgi gösterilir, ekran çökmez.
                  saved.focusScore?.toString() ?? '—',
                  key: const Key('done-focus-score'),
                  style: AppTheme.counterStyle,
                ),
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
                      l.doneTodayProgress,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 12),
                    Text(
                      goalS == 0
                          ? formatDurationShort(todayStudyS)
                          : l.homeProgressOf(
                              formatDurationShort(todayStudyS),
                              formatDurationShort(goalS),
                            ),
                      key: const Key('done-progress-text'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.doneQuestionsNet(
                        stat?.questionCount ?? 0,
                        formatNet(stat?.net ?? 0),
                      ),
                      key: const Key('done-progress-questions'),
                    ),
                  ],
                ),
              ),
            ),
            const _NewAchievementsCard(),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('done-new-session'),
              onPressed: () {
                // Yeni akış temiz seçimle başlar (R2: eski seçim sızmasın).
                ref.read(setupProvider.notifier).reset();
                ref.read(savedResultProvider.notifier).clear();
                context.go(Routes.sessionSubject);
              },
              child: Text(l.doneNewSession),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('done-home'),
              // BU EKRANDA reklam YOKTUR (G7). Ara reklam yalnızca ana panele
              // GEÇİŞ anında, rıza + 90 sn frekans kapısından sonra
              // gösterilebilir. Reklam gösterilse de gösterilmese de
              // yönlendirme AYNI şekilde yapılır — akış beklemez.
              onPressed: () => _goHome(ref, context),
              child: Text(l.doneHome),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bu oturumda açılan rozetleri kutlar.
///
/// Rozetler `SessionRepository.save()` içinde açılıyor ama kullanıcıya hiçbir
/// yerde söylenmiyordu. Kart yalnızca **görülmemiş** rozet varsa çıkar ve
/// gösterildiği anda rozetleri "görüldü" işaretler; aksi halde her tebrik
/// ekranında yeniden kutlanırdı.
class _NewAchievementsCard extends ConsumerStatefulWidget {
  const _NewAchievementsCard();

  @override
  ConsumerState<_NewAchievementsCard> createState() =>
      _NewAchievementsCardState();
}

class _NewAchievementsCardState extends ConsumerState<_NewAchievementsCard> {
  /// İlk görülen rozet listesi. **Sabitleniyor**: `markSeen` çağrısı akışı
  /// güncelliyor ve liste anında boşalıyordu — kart tek karede kaybolup
  /// kullanıcı kazandığı rozeti göremiyordu.
  List<String>? _shown;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final unseen = ref.watch(unseenAchievementsProvider).valueOrNull;

    if (_shown == null) {
      if (unseen == null || unseen.isEmpty) return const SizedBox.shrink();
      _shown = [for (final a in unseen) a.code];
      // Kutlama titreşimi ve "görüldü" işareti build DIŞINDA: build içinde
      // veritabanına yazmak yeniden çizim döngüsü yaratırdı.
      final codes = _shown!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // FAZ 2.1: aynı kodlar üst şeride de kuyruğa giriyor. Kullanıcı
        // tebrik ekranından hemen çıksa bile rozeti görüyor — kart
        // gezinme yığınının üstünde yaşıyor.
        ref.read(achievementToastQueueProvider.notifier).enqueue(codes);
        unawaited(ref.read(hapticGatewayProvider).celebrate());
        for (final code in codes) {
          unawaited(ref.read(achievementDaoProvider).markSeen(code));
        }
      });
    }

    final codes = _shown!;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        key: const Key('done-new-achievements'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.doneNewAchievement,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final code in codes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        achievementIcon(
                          AchievementCalculator.byCode(code)?.iconKey ?? '',
                        ),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          achievementText(l, code).title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('done-see-achievements'),
                  onPressed: () => context.push(Routes.achievements),
                  child: Text(l.doneSeeAchievements),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
