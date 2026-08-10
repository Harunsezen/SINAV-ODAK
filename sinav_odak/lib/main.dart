import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'core/di/app_providers.dart';
import 'core/utils/time.dart';
import 'data/repositories/session_repository.dart';
import 'services/notifications/notification_service.dart';
import 'application/recovery_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge: alt kontrol çubuğu ve banner reklam safe-area'ya oturacak.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final db = AppDatabase();
  // Ayar satırını ve seed'i garanti et, eski reklam loglarını temizle.
  await db.settingsDao.ensure();
  await db.pruneAdEvents();

  // Yarıda kalmış oturumu AÇILIŞTA değerlendir. Bu adım olmadan `running`
  // satır kalıcı olarak takılı kalıyor ve kullanıcının çalışması
  // istatistiklere hiç yansımıyordu.
  // Bildirim altyapısı: başarısız olursa akış DURMAZ.
  final notifications = NotificationService();
  await notifications.initialize();

  final sessionRepo = SessionRepository(db);
  final recovery =
      await RecoveryService(db, sessionRepo).check(nowMs: nowMs());

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        pendingRecoveryProvider.overrideWithValue(recovery),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const SinavOdakApp(),
    ),
  );
}
