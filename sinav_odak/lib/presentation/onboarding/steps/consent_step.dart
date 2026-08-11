import 'package:flutter/material.dart';

/// Onboarding 4/5 — KVKK/GDPR rızası ve bildirim izni.
///
/// **Rıza varsayılanı KAPALI (K4a).** Rıza alınmadan kişiselleştirilmiş
/// reklam gösterilemez; `personalizedAdsConsent` şemada da `false`
/// varsayılanıyla duruyor. Toggle'ın önceden açık gelmesi KVKK'ya aykırı
/// olurdu ("açık rıza" pasif kabulle alınamaz).
///
/// **Bildirim izni akışı DURDURMAZ (K4c).** İzin reddedilse bile kullanıcı
/// devam eder; bildirim bir kolaylıktır, oturumun doğruluğu ona bağlı
/// değildir — doğruluk daima çizelge + `resolve(now)`.
///
/// Gerçek UMP (Google Consent SDK) FAZ 4'te `google_mobile_ads` ile gelir;
/// bu turda yalnızca tercih kaydediliyor.
///
/// v1.2'de i18n (FAZ 6 / K7).
class ConsentStep extends StatelessWidget {
  const ConsentStep({
    required this.consent,
    required this.onConsent,
    required this.onRequestNotifications,
    required this.onSkipNotifications,
    required this.notificationOutcome,
    super.key,
  });

  final bool consent;
  final ValueChanged<bool> onConsent;
  final VoidCallback onRequestNotifications;
  final VoidCallback onSkipNotifications;

  /// İzin istendiyse sonucu; hiç istenmediyse `null`.
  final bool? notificationOutcome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('onboarding-step-consent'),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Gizlilik ve izinler',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verilerin cihazında kalır',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Çalışma sürelerin, soru sayıların ve notların yalnızca '
                  'bu cihazdaki veritabanında saklanır; bir sunucuya '
                  'gönderilmez. Uygulama ücretsizdir ve gelirini yalnızca '
                  'reklamdan sağlar. Dilediğin an ayarlardan verilerini '
                  'silebilir veya dışa aktarabilirsin (KVKK md. 11).',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: SwitchListTile(
            key: const Key('onboarding-consent-toggle'),
            value: consent,
            onChanged: onConsent,
            title: const Text('Kişiselleştirilmiş reklam'),
            subtitle: const Text(
              'Kapalı bırakırsan yine reklam görürsün, ama ilgi alanlarına '
              'göre seçilmez. İstediğin an ayarlardan değiştirebilirsin.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bildirimler',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Blok ve mola bitişlerini haber verir. İzin vermezsen uygulama '
          'yine çalışır.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                key: const Key('onboarding-notif-request'),
                onPressed: onRequestNotifications,
                child: const Text('Bildirim izni ver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('onboarding-notif-skip'),
                onPressed: onSkipNotifications,
                child: const Text('Atla'),
              ),
            ),
          ],
        ),
        if (notificationOutcome != null) ...[
          const SizedBox(height: 12),
          Text(
            notificationOutcome!
                ? 'Bildirim izni verildi.'
                : 'Bildirim izni verilmedi — sorun değil, devam edebilirsin.',
            key: const Key('onboarding-notif-outcome'),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }
}
