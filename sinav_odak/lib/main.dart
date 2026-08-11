import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/local/database.dart';
import 'core/config/ad_config.dart';
import 'core/di/ad_providers.dart';
import 'core/di/app_providers.dart';
import 'core/utils/time.dart';
import 'data/repositories/session_repository.dart';
import 'domain/ports/ad_gateway.dart';
import 'services/ads/admob_gateway.dart';
import 'services/ads/ump_consent_gateway.dart';
import 'services/export/file_share_gateway.dart';
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
  // Eski reklam logları: saat DIŞARIDAN veriliyor (nowMs), böylece davranış
  // test edilebilir kalıyor.
  await db.adEventDao.pruneOlderThan(nowMs());

  // Yarıda kalmış oturumu AÇILIŞTA değerlendir. Bu adım olmadan `running`
  // satır kalıcı olarak takılı kalıyor ve kullanıcının çalışması
  // istatistiklere hiç yansımıyordu.
  // Bildirim altyapısı: başarısız olursa akış DURMAZ.
  final notifications = NotificationService();
  await notifications.initialize();

  final sessionRepo = SessionRepository(db);
  final recovery = await RecoveryService(db, sessionRepo).check(nowMs: nowMs());

  // UMP (KVKK/GDPR) — reklam İSTEĞİNDEN ÖNCE çalışmak ZORUNDA. Google'ın
  // kuralı bu; sonradan sorup arada reklam istemek ihlal olurdu. Gecikme
  // `UmpConsentGateway.timeout` ile sınırlı ve hata/zaman aşımı hâlinde
  // sonuç `unavailable` (canRequestAds: false) — yani reklamsız devam.
  final consentGateway = UmpConsentGateway();
  final consent = await consentGateway.gather();
  debugPrint(
    'UMP: ${consent.state.name} canRequestAds=${consent.canRequestAds} '
    'testIds=${AdConfig.usingTestIds}',
  );

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        pendingRecoveryProvider.overrideWithValue(recovery),
        notificationServiceProvider.overrideWithValue(notifications),
        consentGatewayProvider.overrideWithValue(consentGateway),
        consentBootResultProvider.overrideWithValue(consent),
        // Gerçek reklam adaptörü YALNIZCA burada devreye giriyor; varsayılan
        // hâlâ `NoopAdGateway`, yani testler ve reklamsız derleme etkilenmez.
        adGatewayProvider.overrideWith(_buildAdGateway),
        // CSV dışa aktarma: varsayılan Noop, gerçek cihazda dosya + paylaşım.
        shareGatewayProvider.overrideWithValue(const FileShareGateway()),
      ],
      child: const SinavOdakApp(),
    ),
  );
}

/// Reklam adaptörünü DI'dan besler.
///
/// Okuyucular `ref.read` ile ANLIK durumu alır: politika kararı reklam
/// gösterilmeye çalışıldığı anda verilmeli, gateway kurulduğu anda değil.
AdGateway _buildAdGateway(Ref ref) => AdMobGateway(
      eventDao: ref.watch(adEventDaoProvider),
      stateReader: () => ref.read(runStateProvider),
      consentReader: () => ref.read(adConsentProvider),
      clock: ref.read(clockProvider),
      focusScreenAdsReader: () => ref.read(focusScreenAdsProvider),
    );
