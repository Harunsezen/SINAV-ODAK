import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../domain/services/achievement_calculator.dart';

/// Rozet listesi (FAZ 7B).
///
/// **Kilitli rozetler de gösteriliyor**: neyin peşinde olduğunu bilmeyen
/// kullanıcı için rozet sistemi motive edici değil, rastgele bir sürpriz
/// olurdu. Kilitli olanlar soluk ve açıklamasıyla birlikte duruyor.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final unlocked = ref.watch(achievementsProvider).valueOrNull ?? const [];
    final unlockedCodes = {for (final a in unlocked) a.code};

    return Scaffold(
      appBar: AppBar(title: Text(l.achievementsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            l.achievementsUnlockedOf(
              unlockedCodes.length,
              AchievementCalculator.catalog.length,
            ),
            key: const Key('achievements-count'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 16),
          for (final def in AchievementCalculator.catalog)
            _AchievementTile(
              code: def.code,
              iconKey: def.iconKey,
              isUnlocked: unlockedCodes.contains(def.code),
              isNew: unlocked.any((a) => a.code == def.code && !a.isSeen),
            ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.code,
    required this.iconKey,
    required this.isUnlocked,
    required this.isNew,
  });

  final String code;
  final String iconKey;
  final bool isUnlocked;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = achievementText(l, code);

    return Card(
      key: Key('achievement-$code'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: isUnlocked
            ? l.a11yAchievementUnlocked(text.title)
            : l.a11yAchievementLocked(text.title),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                isUnlocked ? scheme.primary : scheme.surfaceContainerHighest,
            child: Icon(
              achievementIcon(iconKey),
              color: isUnlocked ? scheme.onPrimary : scheme.outline,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  text.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isUnlocked ? null : scheme.outline,
                  ),
                ),
              ),
              if (isNew) ...[
                const SizedBox(width: 8),
                Container(
                  key: Key('achievement-new-$code'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l.achievementsNew,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            isUnlocked ? text.body : l.achievementsLocked,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: Icon(
            isUnlocked ? Icons.check_circle : Icons.lock_outline,
            size: 18,
            color: isUnlocked ? scheme.primary : scheme.outline,
          ),
        ),
      ),
    );
  }
}

/// Rozet kodunun başlık ve açıklaması (ARB'den).
///
/// Kodlar domain'de sabit; metinler burada eşleşiyor. Domain'e metin
/// koymak, saf Dart katmanına arayüz dili sokmak olurdu.
({String title, String body}) achievementText(L10n l, String code) =>
    switch (code) {
      'streak_3' => (title: l.achStreak3Title, body: l.achStreak3Body),
      'streak_7' => (title: l.achStreak7Title, body: l.achStreak7Body),
      'streak_30' => (title: l.achStreak30Title, body: l.achStreak30Body),
      'first_session' => (
          title: l.achFirstSessionTitle,
          body: l.achFirstSessionBody
        ),
      'hours_10' => (title: l.achHours10Title, body: l.achHours10Body),
      'hours_100' => (title: l.achHours100Title, body: l.achHours100Body),
      'questions_1000' => (
          title: l.achQuestions1000Title,
          body: l.achQuestions1000Body
        ),
      'marathon_day' => (
          title: l.achMarathonDayTitle,
          body: l.achMarathonDayBody
        ),
      'focus_90' => (title: l.achFocus90Title, body: l.achFocus90Body),
      'early_bird' => (title: l.achEarlyBirdTitle, body: l.achEarlyBirdBody),
      'night_owl' => (title: l.achNightOwlTitle, body: l.achNightOwlBody),
      // --- Sanayi Evreni (FAZ 2.2) ---
      'industry_escape' => (
          title: l.achIndustryEscapeTitle,
          body: l.achIndustryEscapeBody
        ),
      'downshift' => (title: l.achDownshiftTitle, body: l.achDownshiftBody),
      'master_waits' => (
          title: l.achMasterWaitsTitle,
          body: l.achMasterWaitsBody
        ),
      'balto_friend' => (
          title: l.achBaltoFriendTitle,
          body: l.achBaltoFriendBody
        ),
      'questions_15000' => (
          title: l.achQuestions15000Title,
          body: l.achQuestions15000Body
        ),
      _ => (title: l.achUnknownTitle, body: l.achUnknownBody),
    };

/// İkon adını `IconData`'ya çevirir.
///
/// **`IconData(codePoint)` DEĞİL**: sabit olmayan `IconData`
/// `--tree-shake-icons` derlemesini kırıyor (README'deki karar). Bu yüzden
/// switch ile sabit ikonlara eşleniyor.
IconData achievementIcon(String key) => switch (key) {
      'local_fire_department' => Icons.local_fire_department,
      'whatshot' => Icons.whatshot,
      'flag' => Icons.flag,
      'schedule' => Icons.schedule,
      'military_tech' => Icons.military_tech,
      'quiz' => Icons.quiz,
      'directions_run' => Icons.directions_run,
      'center_focus_strong' => Icons.center_focus_strong,
      'wb_twilight' => Icons.wb_twilight,
      'nightlight' => Icons.nightlight,
      // --- Sanayi Evreni (FAZ 2.2) ---
      'factory' => Icons.factory,
      'build' => Icons.build,
      'hardware' => Icons.hardware,
      'workspace_premium' => Icons.workspace_premium,
      'volunteer_activism' => Icons.volunteer_activism,
      _ => Icons.emoji_events,
    };
