import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/ad_providers.dart';
import '../ads/rewarded_controller.dart';

/// Ayarlar ekranı (FAZ 5 — kısmi).
///
/// Bu turda yalnızca **"Destek ol"** (ödüllü reklam) var; tema, katsayı,
/// hedefler, ders/konu yönetimi ve veri sıfırlama sonraki turda gelecek.
/// Ekranın var olması `db_health_page`'in release'te Ayarlar sekmesini
/// kaplamasını bitiriyor (KARAR K3).
///
/// v1.2'de i18n (FAZ 6).
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
              ? 'Teşekkürler! Desteğin uygulamayı ücretsiz tutuyor.'
              : 'Şu an gösterilecek reklam yok. Sonra tekrar deneyebilirsin.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(adConsentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                        'Destek ol',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uygulama %100 ücretsiz ve hiçbir özelliği kilitli değil. '
                    'İstersen kısa bir reklam izleyerek destek olabilirsin — '
                    'izlemezsen hiçbir şey değişmez.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const Key('settings-support-button'),
                    // Rıza yoksa hiçbir reklam gösterilmez; buton pasif ve
                    // sebebi altında yazıyor.
                    onPressed: consent && !_busy ? _support : null,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('İzle ve destekle'),
                  ),
                  if (!consent) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Reklam tercihi kapalı olduğu için devre dışı. '
                      'Onboarding\'de verdiğin tercihi buradan '
                      'değiştirebileceksin.',
                      key: Key('settings-support-disabled-note'),
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // UMP formu yalnızca GEREKLİ olduğu bölgelerde (AEA/UK) anlamlı.
          // Gerekmeyen yerde göstermek, hiçbir şey açmayan ölü bir düğme
          // olurdu.
          if (ref.watch(consentResultProvider).privacyOptionsRequired) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                key: const Key('settings-privacy-options'),
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Gizlilik tercihleri'),
                subtitle: const Text(
                  'Reklam kişiselleştirme rızanı buradan değiştirebilirsin.',
                ),
                enabled: !_busy,
                onTap: _busy ? null : _privacyOptions,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              key: Key('settings-placeholder'),
              leading: Icon(Icons.construction_outlined),
              title: Text('Diğer ayarlar'),
              subtitle: Text(
                'Tema, net katsayısı, hedefler, ders/konu yönetimi ve '
                'veri sıfırlama sonraki turda.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
