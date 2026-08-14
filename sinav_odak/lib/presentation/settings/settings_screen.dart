import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/ad_config.dart';
import '../../core/di/ad_providers.dart';
import '../../core/di/app_providers.dart';
import '../../application/settings_controller.dart';
import '../../core/router/routes.dart';
import '../../domain/entities/enums.dart';
import '../ads/rewarded_controller.dart';
import 'widgets/net_coefficient_tile.dart';
import 'widgets/reset_data_tile.dart';

/// Ayarlar ekranı (FAZ 7A — tamamlandı).
///
/// FAZ 5'te yalnızca "Destek ol" kartı vardı, FAZ 6'da gizlilik tercihleri
/// eklendi. Bu turda görünüm, çalışma, bildirim, katalog, veri ve hakkında
/// bölümleri geldi.
///
/// **Ayarlar tek satırlık DB kaydından okunuyor** (SharedPreferences değil):
/// net katsayısı ve günlük hedef istatistik sorgularıyla aynı transaction
/// içinde okunuyor.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  /// UMP "gizlilik seçenekleri" formunu yeniden açar.
  ///
  /// KVKK/GDPR: verilen rıza her zaman GERİ ALINABİLİR olmalı. Form
  /// kapandıktan sonra sonucu okuyup [consentResultProvider]'ı tazeliyoruz;
  /// aksi halde kullanıcı "reddet" dese bile uygulama eski kararla reklam
  /// göstermeye devam ederdi.
  Future<void> _privacyOptions() async {
    setState(() => _busy = true);
    final result = await ref.read(consentGatewayProvider).showPrivacyOptions();
    if (!mounted) return;
    setState(() => _busy = false);
    ref.read(consentResultOverrideProvider.notifier).state = result;
  }

  Future<void> _support() async {
    setState(() => _busy = true);
    final earned = await ref.read(rewardedControllerProvider).maybeShow();
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          earned
              ? L10n.of(context).supportThanks
              : L10n.of(context).supportNoAd,
        ),
      ),
    );
  }

  /// Ayar yazma tek kapıdan: Drift companion'ları arayüze sızmıyor (G4).
  SettingsController get _settings => ref.read(settingsControllerProvider);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final consent = ref.watch(adConsentProvider);
    final settings = ref.watch(settingsStreamProvider).valueOrNull;

    // Ayarlar henüz gelmediyse anahtarları VARSAYILAN değerle çizmek,
    // kullanıcının kapattığı bir ayarı bir an açık göstermek demekti.
    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.settingsTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // --- Görünüm ---
          _SectionCard(
            title: l.settingsAppearance,
            icon: Icons.palette_outlined,
            children: [
              // ListTile DEĞİL: `trailing` olarak verilen SegmentedButton
              // dar ekranda (≈430 px) satırın tamamını kaplıyor ve
              // ListTile "Trailing widget consumes entire tile width"
              // assertion'ı ile Ayarlar ekranını ÇÖKERTİYORDU. Etiket ve
              // seçici artık alt alta.
              Column(
                key: const Key('settings-theme'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.settingsTheme),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemeModeSetting>(
                    segments: [
                      ButtonSegment(
                        value: ThemeModeSetting.system,
                        label: Text(l.settingsThemeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeModeSetting.light,
                        icon: const Icon(Icons.light_mode_outlined),
                        tooltip: l.settingsThemeLight,
                      ),
                      ButtonSegment(
                        value: ThemeModeSetting.dark,
                        icon: const Icon(Icons.dark_mode_outlined),
                        tooltip: l.settingsThemeDark,
                      ),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _settings.setThemeMode(s.first),
                  ),
                ],
              ),
              SwitchListTile(
                key: const Key('settings-keep-screen-on'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsKeepScreenOn),
                subtitle: Text(
                  l.settingsKeepScreenOnNote,
                  style: const TextStyle(fontSize: 11),
                ),
                value: settings.keepScreenOn,
                onChanged: (v) => _settings.setKeepScreenOn(value: v),
              ),
            ],
          ),

          // --- Çalışma ---
          _SectionCard(
            title: l.settingsStudy,
            icon: Icons.timer_outlined,
            children: [
              NetCoefficientTile(current: settings.netPenaltyCoefficient),
              const Divider(height: 24),
              _DailyGoalTile(current: settings.dailyGoalMinutes),
            ],
          ),

          // --- Bildirim ve ses ---
          _SectionCard(
            title: l.settingsNotifications,
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                key: const Key('settings-notifications'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsNotificationEnabled),
                subtitle: Text(
                  l.settingsNotificationNote,
                  style: const TextStyle(fontSize: 11),
                ),
                value: settings.notificationEnabled,
                onChanged: (v) => _settings.setNotificationEnabled(value: v),
              ),
              SwitchListTile(
                key: const Key('settings-sound'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsSound),
                value: settings.soundEnabled,
                // Bildirim kapalıyken ses/titreşim ayarı anlamsız: kapalı
                // bir bildirimin sesi olmaz.
                onChanged: settings.notificationEnabled
                    ? (v) => _settings.setSoundEnabled(value: v)
                    : null,
              ),
              SwitchListTile(
                key: const Key('settings-vibration'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsVibration),
                value: settings.vibrationEnabled,
                onChanged: settings.notificationEnabled
                    ? (v) => _settings.setVibrationEnabled(value: v)
                    : null,
              ),
              // FAZ 2.1 — rozet şeridi. Bildirim ayarından BAĞIMSIZ:
              // bu uygulama içi bir kart, sistem bildirimi değil.
              // `notificationEnabled`a kapılsaydı, bildirimleri kapatan
              // kullanıcı rozetlerini de sessizce kaybederdi.
              SwitchListTile(
                key: const Key('settings-achievement-toast'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsAchievementToast),
                subtitle: Text(l.settingsAchievementToastNote),
                value: settings.achievementToastEnabled,
                onChanged: (v) =>
                    _settings.setAchievementToastEnabled(value: v),
              ),
            ],
          ),

          // --- İlerleme: hedefler ve rozetler ---
          _SectionCard(
            title: l.goalsTitle,
            icon: Icons.flag_outlined,
            children: [
              ListTile(
                key: const Key('settings-goals'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.track_changes_outlined),
                title: Text(l.goalsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.goals),
              ),
              ListTile(
                key: const Key('settings-achievements'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events_outlined),
                title: Text(l.achievementsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.achievements),
              ),
            ],
          ),

          // --- Ders ve konular ---
          _SectionCard(
            title: l.settingsCatalog,
            icon: Icons.menu_book_outlined,
            children: [
              ListTile(
                key: const Key('settings-catalog'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.settingsCatalogNote),
                titleTextStyle: Theme.of(context).textTheme.bodyMedium,
                // `trailing` olarak buton verilmişti; dar ekranda buton
                // satırın tamamını kaplayıp ListTile assertion'ı ile
                // ekranı çökertiyordu. Hedefler/Rozetler satırlarıyla aynı
                // desene çekildi: küçük ok + satırın tamamı dokunulabilir.
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.manage),
              ),
            ],
          ),

          // --- Destek ol (FAZ 5) ---
          Card(
            key: const Key('settings-support'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.favorite_outline),
                      const SizedBox(width: 8),
                      Text(
                        l.supportTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.supportBody,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('settings-support-button'),
                    // Rıza yoksa hiçbir reklam gösterilmez; buton pasif ve
                    // sebebi altında yazıyor.
                    onPressed: consent && !_busy ? _support : null,
                    icon: const Icon(Icons.play_circle_outline),
                    label: Text(l.supportWatch),
                  ),
                  if (!consent) ...[
                    const SizedBox(height: 8),
                    Text(
                      l.supportDisabledNote,
                      key: const Key('settings-support-disabled-note'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // --- Gizlilik tercihleri (FAZ 6) ---
          //
          // UMP formu yalnızca GEREKLİ olduğu bölgelerde (AEA/UK) anlamlı.
          // Gerekmeyen yerde göstermek, hiçbir şey açmayan ölü bir düğme
          // olurdu.
          if (ref.watch(consentResultProvider).privacyOptionsRequired) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const Key('settings-privacy-options'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l.settingsPrivacyTitle),
                subtitle: Text(
                  l.settingsPrivacyNote,
                ),
                enabled: !_busy,
                onTap: _busy ? null : _privacyOptions,
              ),
            ),
          ],

          // --- Veri ---
          _SectionCard(
            title: l.settingsData,
            icon: Icons.storage_outlined,
            children: const [ResetDataTile()],
          ),

          // --- Hakkında ---
          _SectionCard(
            title: l.settingsAbout,
            icon: Icons.info_outline,
            children: [
              Text(l.settingsAboutBody, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.settingsVersion),
                  const Text(
                    kAppVersion,
                    key: Key('settings-version'),
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // Test kimlikleriyle yayına çıkmak gelir kaybı; uyarı burada
              // dursun ki release derlemede gözden kaçmasın.
              if (AdConfig.usingTestIds) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.settingsTestAdsWarning,
                        key: const Key('settings-test-ads-warning'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Uygulama sürümü. `pubspec.yaml` ile ELDE senkron tutuluyor:
/// `package_info_plus` bir platform kanalı daha demek ve testte çöküyor.
const String kAppVersion = '1.0.0';

/// Başlıklı ayar bölümü — tekrar eden Card/Padding/başlık üçlüsü.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Günlük hedef (dakika) — 30 dk adımlarla.
class _DailyGoalTile extends ConsumerWidget {
  const _DailyGoalTile({required this.current});

  final int current;

  static const int min = 30;
  static const int max = 720;
  static const int step = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return Row(
      children: [
        Expanded(child: Text(l.settingsDailyGoal)),
        IconButton(
          key: const Key('settings-goal-minus'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: current <= min
              ? null
              : () => ref
                  .read(settingsControllerProvider)
                  .setDailyGoalMinutes(current - step),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$current',
            key: const Key('settings-goal-value'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const Key('settings-goal-plus'),
          icon: const Icon(Icons.add_circle_outline),
          onPressed: current >= max
              ? null
              : () => ref
                  .read(settingsControllerProvider)
                  .setDailyGoalMinutes(current + step),
        ),
      ],
    );
  }
}
