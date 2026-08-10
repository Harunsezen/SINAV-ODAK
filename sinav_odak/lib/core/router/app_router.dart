import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/home/home_screen.dart';
import '../../presentation/onboarding/onboarding_screen.dart';
import '../../presentation/run/break_screen.dart';
import '../../presentation/run/done_screen.dart';
import '../../presentation/run/pending_finish_controller.dart';
import '../../presentation/run/run_screen.dart';
import '../../presentation/run/summary_form.dart';
import '../../presentation/session_setup/activity_picker.dart';
import '../../presentation/session_setup/plan_setup.dart';
import '../../presentation/session_setup/subject_picker.dart';
import '../../presentation/session_setup/topic_picker.dart';
import '../../presentation/shell/app_shell.dart';
import '../../presentation/shell/db_health_page.dart';
import '../../presentation/ads/banner_ad_slot.dart';
import '../../presentation/settings/catalog_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/stats/stats_screen.dart';
import '../../presentation/shell/placeholder_page.dart';
import '../../presentation/wrongs/add_wrong_screen.dart';
import '../../presentation/wrongs/wrong_list_screen.dart';
import '../../domain/entities/ad_placement.dart';
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
Widget settingsPageFor({required bool debug}) =>
    debug ? const DbHealthPage() : const SettingsScreen();

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
        if (loc == Routes.runDone && ref.read(savedResultProvider) != null) {
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

      // --- Katalog yönetimi (Ayarlar > Ders ve konular) ---
      //
      // Shell DIŞINDA: düzenleme sırasında alt navigasyon çubuğu
      // kullanıcıyı yarım kalmış bir diyalogla başka sekmeye götürmesin.
      GoRoute(
        path: Routes.manage,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const CatalogScreen(),
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
                // Kurtarma diyaloğu ana panelin KENDİ içinde monte edilir
                // (bkz. home_screen.dart), route seviyesinde değil.
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.stats,
                builder: (_, __) => const StatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.wrongs,
                builder: (_, __) => const WrongListScreen(),
                routes: [
                  GoRoute(
                    path: 'add',
                    // Shell DIŞINDA: form ekranında alt navigasyon
                    // kullanıcıyı yarım kalmış kayıtla başka sekmeye
                    // götürmesin.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (_, __) => const AddWrongScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.calendar,
                builder: (_, __) => const _BannerPlaceholder(
                  title: 'Takvim',
                  note: 'Sonraki tur: ay görünümü + gün detayı.',
                  placement: AdPlacement.calendarBanner,
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

/// Henüz yazılmamış sekmeler için yer tutucu + banner yuvası.
///
/// Banner burada da politika kapılı: rıza yoksa hiç yer ayrılmaz. Ekranların
/// kendisi sonraki turda gelecek, ama reklam yerleşimi şimdiden test
/// edilebilir durumda.
class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({
    required this.title,
    required this.note,
    required this.placement,
  });

  final String title;
  final String note;
  final AdPlacement placement;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(child: PlaceholderPage(title: title, note: note)),
          BannerAdSlot(placement: placement),
        ],
      ),
    );
  }
}
