import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import 'achievements_screen.dart' show achievementIcon, achievementText;

/// Kuyruğa alınmış rozet bildirimi.
///
/// **Neden kuyruk:** tek bir oturum kaydı birden fazla rozet açabiliyor —
/// uzun bir aradan sonra dönen kullanıcı aynı kayıtta hem `master_waits`
/// hem bir seri rozeti alabilir. Hepsi aynı anda gösterilseydi üst üste
/// biner, biri okunmazdı.
class AchievementToastQueue extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  /// Yeni rozetleri kuyruğa ekler. Zaten kuyruktakiler tekrar eklenmez.
  void enqueue(Iterable<String> codes) {
    final fresh = codes.where((c) => !state.contains(c)).toList();
    if (fresh.isEmpty) return;
    state = [...state, ...fresh];
  }

  /// En öndeki bildirimi düşürür.
  void dismissFirst() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }

  void clear() => state = const [];
}

final achievementToastQueueProvider =
    NotifierProvider<AchievementToastQueue, List<String>>(
  AchievementToastQueue.new,
);

/// Rozet bildirimi açık mı? (Ayarlardan kapatılabilir.)
final achievementToastEnabledProvider = Provider<bool>((ref) {
  return ref
          .watch(settingsStreamProvider)
          .valueOrNull
          ?.achievementToastEnabled ??
      true;
});

/// Ekranın üstünde beliren rozet kartı — "Minecraft başarımı" hissi.
///
/// **Neden `Overlay` değil de ağaç içinde bir katman:** `Overlay` kullanmak
/// `BuildContext`'i router'ın dışına taşıyor ve rota değişiminde kart
/// asılı kalabiliyordu. Bu katman `MaterialApp`'in `builder`'ında,
/// gezinme yığınının ÜSTÜNDE ama aynı ağaçta duruyor: rota değişse de
/// kart yaşar, ekran değişince kaybolmaz.
///
/// Kart kullanıcının işini ENGELLEMEZ: `IgnorePointer` altındaki alan
/// tıklanabilir kalır, yalnızca kartın kendisi dokunulabilir (kapatmak
/// için).
class AchievementToastLayer extends ConsumerStatefulWidget {
  const AchievementToastLayer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AchievementToastLayer> createState() =>
      _AchievementToastLayerState();
}

class _AchievementToastLayerState extends ConsumerState<AchievementToastLayer> {
  Timer? _timer;
  String? _showing;

  /// Kart ekranda kalma süresi. Okunacak kadar uzun, rahatsız etmeyecek
  /// kadar kısa.
  static const visibleFor = Duration(seconds: 4);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss() {
    _timer?.cancel();
    _timer = Timer(visibleFor, () {
      if (!mounted) return;
      ref.read(achievementToastQueueProvider.notifier).dismissFirst();
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(achievementToastEnabledProvider);
    final queue = ref.watch(achievementToastQueueProvider);
    final code = enabled && queue.isNotEmpty ? queue.first : null;

    // Gösterilen rozet değiştiyse sayacı yeniden kur.
    if (code != _showing) {
      _showing = code;
      if (code != null) {
        _scheduleDismiss();
        // Titreşim kullanıcının ayarına kapılı (NoopHapticGateway
        // varsayılan; gerçek kapı yalnızca main() içinde bağlanıyor).
        unawaited(ref.read(hapticGatewayProvider).success());
      } else {
        _timer?.cancel();
      }
    }

    return Stack(
      children: [
        widget.child,
        // Kart üstte ama ALTINDAKİ ekran tıklanabilir kalıyor.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: _ToastSlot(
              code: code,
              onDismiss: () => ref
                  .read(achievementToastQueueProvider.notifier)
                  .dismissFirst(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartın animasyonlu yuvası: sağdan kayarak girer, yukarı kayarak çıkar.
class _ToastSlot extends StatelessWidget {
  const _ToastSlot({required this.code, required this.onDismiss});

  final String? code;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: code == null
          ? const SizedBox(key: ValueKey('toast-empty'), width: double.infinity)
          : _AchievementCard(
              key: ValueKey('toast-$code'),
              code: code!,
              onDismiss: onDismiss,
            ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.code,
    required this.onDismiss,
    super.key,
  });

  final String code;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final text = achievementText(l, code);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        key: const Key('achievement-toast'),
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    achievementIcon(_iconOf(code)),
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                // `Expanded` ŞART: uzun rozet adı `Row` içinde sınırsız
                // genişlik isteyip taşardı.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.achievementToastNew,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.onInverseSurface.withOpacity(0.7),
                        ),
                      ),
                      Text(
                        text.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kod → ikon adı. Katalog domain'de; burada yalnızca eşleme.
  static String _iconOf(String code) => switch (code) {
        'streak_3' || 'streak_7' => 'local_fire_department',
        'streak_30' => 'whatshot',
        'first_session' => 'flag',
        'hours_10' => 'schedule',
        'hours_100' => 'military_tech',
        'questions_1000' => 'quiz',
        'marathon_day' => 'directions_run',
        'focus_90' => 'center_focus_strong',
        'early_bird' => 'wb_twilight',
        'night_owl' => 'nightlight',
        'industry_escape' => 'factory',
        'downshift' => 'build',
        'master_waits' => 'hardware',
        'questions_15000' => 'workspace_premium',
        _ => 'emoji_events',
      };
}
