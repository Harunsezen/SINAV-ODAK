import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/app_providers.dart';
import '../../domain/entities/enums.dart';

/// Adım 2 doğrulama ekranı.
/// `flutter run` sonrası buraya bakarak veritabanının kurulduğunu,
/// seed verisinin yüklendiğini ve ayar satırının oluştuğunu görebilirsin.
/// Adım 7'de gerçek Ayarlar ekranıyla değiştirilecek.
class DbHealthPage extends ConsumerWidget {
  const DbHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(subjectDaoProvider).watchSubjects(ExamType.yks);
    final activities = ref.watch(subjectDaoProvider).watchActivityTypes();
    final settings = ref.watch(settingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Veritabanı Durumu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          settings.when(
            data: (s) => _Row(
              label: 'Ayar satırı',
              value: 'OK · net katsayısı ${s.netPenaltyCoefficient} · '
                  'hedef ${s.dailyGoalMinutes} dk',
            ),
            loading: () => const _Row(label: 'Ayar satırı', value: '...'),
            error: (e, _) => _Row(label: 'Ayar satırı', value: 'HATA: $e'),
          ),
          StreamBuilder(
            stream: subjects,
            builder: (context, snap) => _Row(
              label: 'YKS dersleri',
              value: snap.hasData
                  ? '${snap.data!.length} kayıt'
                  : (snap.hasError ? 'HATA: ${snap.error}' : '...'),
            ),
          ),
          StreamBuilder(
            stream: activities,
            builder: (context, snap) => _Row(
              label: 'Çalışma türleri',
              value: snap.hasData
                  ? '${snap.data!.length} kayıt'
                  : (snap.hasError ? 'HATA: ${snap.error}' : '...'),
            ),
          ),
          const Divider(height: 32),
          const Text(
            'Beklenen: 15 YKS dersi, 11 çalışma türü, ayar satırı OK.\n'
            'Bunları görüyorsan Adım 1–2 çalışıyor demektir.',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
