import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../session_setup/setup_controller.dart';
import 'recovery_gate.dart';

/// Ana panelin MİNİMAL hali.
///
/// Adım 7'de tam ana panel gelecek (bugünkü özet, streak, grafikler, son
/// oturumlar). Bu turda tek işi var: kullanıcıya oturum başlatma yolunu
/// açmak. Adım 4 sonunda run/break ekranları hazırdı ama onlara ulaşan
/// hiçbir yol yoktu.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yarıda kalan oturum kararı ana panelde, TEK kez sorulur (KARAR D2).
    // Gate ekranı sarar; kendisi görsel bir şey çizmez.
    return RecoveryGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Sınav Odak')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bugün ne çalışıyoruz?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Süre tut, soru gir, gelişimini gör.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  key: const Key('home-start'),
                  onPressed: () {
                    // Yeni akış temiz seçimle başlar (R2: eski seçim sızmasın).
                    ref.read(setupProvider.notifier).reset();
                    context.go(Routes.sessionSubject);
                  },
                  child: const Text('Oturumu Başlat'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Adım 7: bugünkü özet, streak ve grafikler buraya gelecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
