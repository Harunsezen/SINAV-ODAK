import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../core/utils/formatters.dart';
import '../../domain/entities/session_state.dart';

/// S10 — Oturum Sonu Formu (İSKELET).
///
/// Bu turda yalnızca iskelet: `summarizing` state'inden gelen oturum
/// bilgisi gösteriliyor, giriş alanları ve Kaydet butonu için yer
/// ayrılıyor. `finishSessionProvider` **çağrılmıyor**; bağlantı Adım 5'in
/// devamında kurulacak.
///
/// **Bu ekranda REKLAM YOKTUR ve olmayacaktır.** Kullanıcı veri girerken
/// bölünmemeli; ürünün değişmez kurallarından biri. Reklam yalnızca kayıt
/// TAMAMLANDIKTAN sonra (tebrik ekranı) gösterilebilir.
///
/// Zaman `clockProvider`'dan okunur; `DateTime.now()` çağrılmaz.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(runStateProvider);

    // Oturum kapandıysa (veya hiç yoksa) gösterecek bir şey kalmaz.
    if (state is! SessionSummarizing) {
      return const Scaffold(
        key: Key('summary-empty'),
        body: Center(child: Text('Özetlenecek oturum yok.')),
      );
    }

    final schedule = state.schedule;
    final endedAt =
        DateTime.fromMillisecondsSinceEpoch(schedule.plannedEndAtMs);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oturum Sonu'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        key: const Key('summary-form'),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('summary-header'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline),
                      const SizedBox(width: 8),
                      Text(
                        'Oturum tamamlandı',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Çalışma: ${formatDurationShort(schedule.totalStudyS)}'),
                  Text('Mola: ${formatDurationShort(schedule.totalBreakS)}'),
                  Text(
                    'Blok sayısı: ${schedule.studyBlockCount}',
                    key: const Key('summary-blocks'),
                  ),
                  Text(
                    'Bitiş: ${endedAt.hour.toString().padLeft(2, '0')}:'
                    '${endedAt.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Soru girişi (Adım 5 devamı) ---
          const _PlaceholderSection(
            key: Key('summary-questions-placeholder'),
            title: 'Kaç soru çözdün?',
            note: 'Hızlı giriş butonları (+5 / +10 / +20) ve elle giriş '
                'buraya gelecek.',
          ),
          const _PlaceholderSection(
            key: Key('summary-breakdown-placeholder'),
            title: 'Doğru / Yanlış / Boş',
            note: 'Üç sayaç ve canlı net önizlemesi buraya gelecek.',
          ),
          const _PlaceholderSection(
            key: Key('summary-mood-placeholder'),
            title: 'Nasıl geçti?',
            note: '5 emoji seçici ve opsiyonel not alanı buraya gelecek.',
          ),

          const SizedBox(height: 24),
          FilledButton(
            key: const Key('summary-save'),
            // Adım 5 devamı: finishSessionProvider'a bağlanacak.
            onPressed: null,
            child: const Text('KAYDET'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu ekranda reklam gösterilmez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Adım 5'in devamında doldurulacak bölümler için görsel yer tutucu.
class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    required this.title,
    required this.note,
    super.key,
  });

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(note, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
