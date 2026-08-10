import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import 'setup_controller.dart';

/// S04 — Ders Seç.
///
/// Ders ekleme/düzenleme bu turun kapsamı dışında (KARAR K4); yönetim
/// ekranları Adım 7'de gelecek.
class SubjectPicker extends ConsumerWidget {
  const SubjectPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tip çıkarımı ile tüketiliyor: presentation katmanı Drift tiplerini
    // doğrudan import etmiyor.
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ders Seç')),
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Dersler yüklenemedi: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Bu sınav türü için ders yok.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final s = list[i];
              return _SubjectCard(
                name: s.name,
                colorHex: s.colorHex,
                onTap: () {
                  ref.read(setupProvider.notifier).selectSubject(
                        id: s.id,
                        name: s.name,
                        colorHex: s.colorHex,
                      );
                  context.go(Routes.sessionTopic);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.name,
    required this.colorHex,
    required this.onTap,
  });

  final String name;
  final String colorHex;
  final VoidCallback onTap;

  /// '#4F5BD5' -> Color. Bozuk değerde temanın rengine düşer.
  Color _parse(BuildContext context) {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return Theme.of(context).colorScheme.primary;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _parse(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(width: 8, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
