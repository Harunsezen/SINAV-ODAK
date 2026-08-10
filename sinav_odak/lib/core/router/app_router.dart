import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/home/home_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/run/break_screen.dart';
import '../../presentation/run/done_screen.dart';
import '../../presentation/run/recovery_gate.dart';
import '../../presentation/run/run_screen.dart';
import '../../presentation/run/summary_form.dart';
import '../../presentation/session_setup/activity_picker.dart';
import '../../presentation/session_setup/plan_setup.dart';
import '../../presentation/session_setup/subject_picker.dart';
import '../../presentation/session_setup/topic_picker.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/shell/db_health_page.dart';
import '../../presentation/shell/placeholder_page.dart';
import '../di/app_providers.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Ayarlar sekmesinin içeriği (KARAR D4).
///
/// [DbHealthPage] bir geliştirme aracıdır ve Ayarlar sekmesinin tamamını
/// kaplıyordu. Adım 7'de gerçek Ayarlar ekranıyla değiştirilecek, ama
/// unutulursa production'a sızardı.
///
/// `kDebugMode` doğrudan gövdeye yazılsaydı release dalı test edilemezdi:
/// testler debug modda koşar ve o dal derleme zamanında elenir. Karar
/// parametreye alınarak **iki dal da** doğrulanabilir hale geldi.
@visibleForTesting
Widget settingsPageFor({required bool debug}) => debug
    ? const DbHealthPage()
    : const PlaceholderPage(
        title: 'Ayarlar',
        note: 'Adım 7: tema, hedefler, rıza tercihi.',
      );

/// Router artık provider'a bağlı: onboarding ve aktif oturum yönlendirmesi
/// için DB durumunu okuması gerekiyor.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,

    // --- Yönlendirme kuralları ---
    //
    // 1) Onboarding tamamlanmadıysa her yol /onboarding'e gider.
    //    `onboardingCompleted` alanı Adım 1'den beri şemada duruyordu ama
    //    HİÇ OKUNMUYORDU. Sınav türü seçilmeden LGS öğrencisine YKS dersleri
    //    gösteriliyordu; ayrıca UMP rıza akışı buraya bağlanacak (KVKK).
    //
    // 2) Aktif oturum varsa kullanıcı ana panele kaçamaz; /run'a döner.
    //    Aksi halde devam eden oturumu görmezden gelip yenisini başlatabilir
    //    ve iki `running` kayıt oluşur.
    redirect: (context, state) async {
      final db = ref.read(databaseProvider);
      final loc = state.matchedLocation;

      final settings = await db.settingsDao.read();
      if (!settings.onboardingCompleted) {
        return loc == Routes.onboarding ? null : Routes.onboarding;
      }
      if (loc == Routes.onboarding) return Routes.home;

      // Aktif oturum koruması — run katmanındaki yollar serbest.
      final isRunLayer = loc.startsWith(Routes.run);
      final active = await db.sessionDao.findActiveSession();
      if (active != null && !isRunLayer) return Routes.run;
      if (active == null && isRunLayer) {
        // Tebrik ekranı (S11) TANIM GEREĞİ aktif oturum olmadan gösterilir:
        // kayıt tamamlandığı anda `running` satır kalmaz. Bu muafiyet
        // olmasaydı form KAYDET'e basar basmaz kullanıcı ana panele
        // düşer, skorunu hiç göremezdi.
        if (loc == Routes.runDone && ref.read(savedSessionProvider) != null) {
          return null;
        }
        return Routes.home;
      }

      return null;
    },

    routes: [
      // --- Onboarding: shell DIŞINDA, alt navigasyon gizli ---
      GoRoute(
        path: Routes.onboarding,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const OnboardingScreen(),
      ),

      // --- OTURUM KURULUM AKIŞI (S04-S07) ---
      //
      // Shell DIŞINDA (KARAR K3): kurulum sırasında alt navigasyon gizli,
      // akış odaklı kalıyor. Run katmanından farkı: geri tuşu SERBEST —
      // geri gitmek bir önceki kurulum adımına döner, PopScope yok.
      //
      // Not: aktif oturum varken bu yollara girilemez; redirect /run'a
      // gönderir (R4).
      GoRoute(
        path: Routes.sessionSubject,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const SubjectPicker(),
      ),
      GoRoute(
        path: Routes.sessionTopic,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const TopicPicker(),
      ),
      GoRoute(
        path: Routes.sessionType,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const ActivityPicker(),
      ),
      GoRoute(
        path: Routes.sessionPlan,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const PlanSetup(),
      ),

      // --- AKTİF OTURUM KATMANI ---
      //
      // parentNavigatorKey: _rootNavigatorKey → StatefulShellRoute'un DIŞINDA
      // açılır, dolayısıyla BottomNavigationBar GÖRÜNMEZ. Shell içine
      // konsaydı kullanıcı çalışma sırasında sekme değiştirebilirdi.
      GoRoute(
        path: Routes.run,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const RunScreen(),
        routes: [
          GoRoute(
            path: 'break',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const BreakScreen(),
          ),
          GoRoute(
            path: 'summary',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const SummaryForm(),
          ),
          GoRoute(
            path: 'done',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (_, __) => const DoneScreen(),
          ),
        ],
      ),

      // --- 5 sekmeli shell ---
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.home,
                // Kurtarma diyaloğu ana panel seviyesinde TEK kez tüketilir
                // (KARAR D2).
                builder: (_, __) =>
                    const RecoveryGate(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stats,
                builder: (_, __) => const PlaceholderPage(
                  title: 'İstatistik',
                  note: 'Adım 7: günlük/haftalık/aylık grafikler.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.wrongs,
                builder: (_, __) => const PlaceholderPage(
                  title: 'Yanlışlar',
                  note: 'Adım 5: yanlış defteri + "Bu konuyu çalış".',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (_, __) => const PlaceholderPage(
                  title: 'Takvim',
                  note: 'Adım 7: ay görünümü + gün detayı.',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, __) => settingsPageFor(debug: kDebugMode),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
