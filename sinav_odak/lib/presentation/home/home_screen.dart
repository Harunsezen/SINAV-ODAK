import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/ad_placement.dart';
import '../../domain/entities/session_state.dart';
import '../ads/banner_ad_slot.dart';
import '../session_setup/setup_controller.dart';
import 'recovery_gate.dart';
import '../run/minimize_session.dart';

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
    final l = L10n.of(context);
    final today = ref.watch(todayKeyProvider);
    final stat = ref.watch(dayStatsProvider(today)).valueOrNull;
    final settings = ref.watch(settingsStreamProvider).valueOrNull;
    final streak = ref.watch(displayStreakProvider);

    final goalMinutes = settings?.dailyGoalMinutes ?? 0;
    final goalQuestions = settings?.dailyGoalQuestions ?? 0;
    final studyS = stat?.totalStudyS ?? 0;
    final goalS = goalMinutes * 60;
    final ratio = goalS == 0 ? 0.0 : (studyS / goalS).clamp(0.0, 1.0);
    final hasActiveSession = ref.watch(showActiveSessionBannerProvider);

    // Yarıda kalan oturum kararı ana panelde, TEK kez sorulur (KARAR D2).
    return RecoveryGate(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.appTitle),
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
            // Oturum küçültülmüşken KALICI dönüş kapısı (FAZ 1.1).
            //
            // Bu şerit olmadan küçültme bir çıkmaz olurdu: kullanıcı
            // oturumdan çıkar, sayaç arka planda işlemeye devam eder ve
            // geri dönecek hiçbir yol bulamazdı. Listenin EN ÜSTÜNDE,
            // reklamdan da önce.
            if (hasActiveSession) ...[
              const _ActiveSessionBanner(),
              const SizedBox(height: 12),
            ],
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
                      l.homeToday,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 12),
                    Text(
                      goalS == 0
                          ? formatDurationShort(studyS)
                          : l.homeProgressOf(
                              formatDurationShort(studyS),
                              formatDurationShort(goalS),
                            ),
                      key: const Key('home-today-duration'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            slug: 'questions',
                            label: l.homeQuestions,
                            value: goalQuestions == 0
                                ? '${stat?.questionCount ?? 0}'
                                : '${stat?.questionCount ?? 0}/$goalQuestions',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            slug: 'net',
                            label: l.homeNet,
                            value: formatNet(stat?.net ?? 0),
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            slug: 'focus',
                            label: l.homeFocus,
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
            // **Aktif oturum varken YENİ oturum başlatılamaz.**
            //
            // UX incelemesinde bulundu (FAZ 1, UX_REVIEW §1.3): küçültme
            // eklendikten sonra bu buton hâlâ etkindi. Kullanıcı dört
            // kurulum adımını geçip BAŞLAT'a basınca `StartSessionUseCase`
            // `SessionFailure` fırlatıyordu — veri bozulmuyordu ama
            // kullanıcı dört ekran sonunda duvara çarpıyordu.
            // Artık buton doğrudan oturuma döndürüyor.
            FilledButton(
              key: const Key('home-start'),
              onPressed: () {
                if (hasActiveSession) {
                  returnToSession(context, ref);
                  return;
                }
                // Yeni akış temiz seçimle başlar (R2: eski seçim sızmasın).
                ref.read(setupProvider.notifier).reset();
                context.go(Routes.sessionSubject);
              },
              child: Text(
                hasActiveSession ? l.runBackToSession : l.homeStartSession,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l.homeRecentSessions,
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

/// Küçültülmüş oturum şeridi — ana panelden geri dönüş kapısı.
///
/// **Kalan süreyi gösteriyor.** UX incelemesinde ilk hâli yalnızca "Sayaç
/// işliyor" diyordu; kullanıcı 20 dakika önce küçülttüyse ne kadar kaldığını
/// bilmeden geri dönmek zorundaydı. Süre zaten `runStateProvider`'da
/// hesaplanıyor, göstermemek için sebep yoktu.
class _ActiveSessionBanner extends ConsumerWidget {
  const _ActiveSessionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final state = ref.watch(runStateProvider);

    final remaining = switch (state) {
      SessionInBlock(:final remainingSeconds) => remainingSeconds,
      SessionInBreak(:final remainingSeconds) => remainingSeconds,
      _ => null,
    };

    return Card(
      key: const Key('home-active-session'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
        title: Text(l.homeActiveSessionTitle),
        subtitle: Text(
          remaining == null
              ? l.homeActiveSessionBody
              : l.homeActiveSessionRemaining(formatClock(remaining)),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => returnToSession(context, ref),
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
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          L10n.of(context).homeNoSessions,
          key: const Key('home-recent-empty'),
          style: const TextStyle(fontSize: 12),
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
                L10n.of(context).homeSessionLine(
                  s.dateKey,
                  s.questionCount,
                  formatNet(s.net),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
