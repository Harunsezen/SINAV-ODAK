import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// 5 sekmeli navigasyon — yüzeye göre **alt çubuk** veya **yan ray**.
///
/// Aktif oturum ekranlarında (Routes.run*) bu shell KULLANILMAZ —
/// odak ekranında navigasyon çubuğu gizli olacak.
///
/// ## Neden iki düzen
///
/// Alt çubuk her yerde kullanılınca iki ayrı sorun ölçüldü
/// (`qa_devices/` ekran görüntüleri):
///
/// 1. **Yatay telefonda** (640x360) alt çubuk zaten kısa olan yüksekliğin
///    ~%25'ini yiyor ve birincil eylem ("Oturumu Başlat") ekranın altında
///    kalıyordu. Taşma hatası YOKTU — sadece görünmüyordu.
/// 2. **Geniş ekranda** (1920x1080) içerik kenardan kenara yayılıyor;
///    tek bir düğme 1900 px genişliyor, satırlar okunamayacak kadar uzun
///    oluyor ve alt yarı bomboş kalıyordu.
///
/// Yan ray ikisini birden çözüyor: dikey alanı geri veriyor ve geniş
/// yüzeyde gezinme yatayda yer kaplıyor. Bu aynı zamanda Play'in büyük
/// ekran kalite kılavuzunun önerdiği desen.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// İçeriğin yayılabileceği en fazla genişlik.
  ///
  /// Sabit bir düzen ölçüsü değil, **okunabilirlik sınırı**: bundan geniş
  /// satırlar göz için takip edilemez hâle geliyor. Dar ekranlarda hiçbir
  /// etkisi yok (kısıt zaten daha küçük).
  static const maxContentWidth = 720.0;

  /// Alt çubuk da yan ray da bu anahtarı taşıyor.
  ///
  /// Testler "shell navigasyonu görünür mü" sorusunu soruyor; hangi
  /// Material widget'ının çizildiği bir uygulama ayrıntısı. Anahtara
  /// bağlanmak iddiayı düzenden bağımsız kılıyor.
  static const navKey = Key('app-shell-nav');

  /// Yan raya geçiş eşiği. Sabit piksel değil, **yüzey oranı + genişlik**:
  /// yatay ve en az bu kadar geniş yüzeylerde ray kullanılıyor.
  static const railBreakpoint = 640.0;

  @override
  Widget build(BuildContext context) {
    // Etiketler ARB'den (FAZ 6 i18n altyapısı).
    final l = L10n.of(context);

    final destinations = <({IconData icon, IconData selected, String label})>[
      (icon: Icons.home_outlined, selected: Icons.home, label: l.navHome),
      (
        icon: Icons.bar_chart_outlined,
        selected: Icons.bar_chart,
        label: l.navStats
      ),
      (icon: Icons.error_outline, selected: Icons.error, label: l.navWrongs),
      (
        icon: Icons.calendar_month_outlined,
        selected: Icons.calendar_month,
        label: l.navCalendar
      ),
      (
        icon: Icons.settings_outlined,
        selected: Icons.settings,
        label: l.navSettings
      ),
    ];

    void go(int i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        );

    // İçerik hiçbir zaman `maxContentWidth`'ten geniş olmuyor ve ortalanıyor.
    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: navigationShell,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= railBreakpoint &&
            constraints.maxWidth > constraints.maxHeight;

        if (!useRail) {
          return Scaffold(
            body: body,
            bottomNavigationBar: NavigationBar(
              key: navKey,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: go,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: d.label,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              // **Ray kaydırılabilir olmalı.** 5 hedef + etiket, 360 px
              // yüksekliğinde sığmıyor; `NavigationRail` kendiliğinden
              // kaydırmıyor ve taşardı. `IntrinsicHeight` + `minHeight`
              // Flutter'ın bu durum için belgelediği kalıp.
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      key: navKey,
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: go,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selected),
                            label: Text(d.label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
