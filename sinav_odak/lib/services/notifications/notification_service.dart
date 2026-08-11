import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/notification_prefs.dart';

/// Bildirim altyapısının kurulumu ve izin yönetimi.
///
/// **Tasarım kuralı: bu sınıf hiçbir zaman akışı durdurmaz.** İzin
/// reddedilse, eklenti bulunamasa veya saat dilimi çözülemese bile
/// uygulama çalışmaya devam eder — bildirim bir kolaylıktır, oturumun
/// doğruluğu ona bağlı değildir. Doğruluk daima çizelge + `resolve(now)`.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin plugin;

  /// Kanal adı ve açıklaması ARB'den beslenir (`main()` yüklüyor).
  ///
  /// Varsayılanlar yalnızca L10n hiç yüklenemezse devreye girer; kanal
  /// Android bildirim ayarlarında bu adla görünür.
  NotificationPrefs Function() prefsReader = () => NotificationPrefs.defaults;
  String channelName = 'Çalışma oturumu';
  String channelDescription = 'Blok ve mola bitişlerinde bilgilendirir.';

  bool _initialized = false;
  bool _timezoneReady = false;

  bool get isInitialized => _initialized;

  /// Uygulama açılışında bir kez çağrılır.
  ///
  /// Hata durumunda sessizce `false` döner; çağıran akışı sürdürür.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await _initTimezone();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        // İzinler ayrıca requestPermission() ile isteniyor; burada tekrar
        // sorulmasın diye kapalı.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      _initialized = true;
      return true;
    } on Object catch (e) {
      debugPrint('NotificationService.initialize başarısız: $e');
      return false;
    }
  }

  /// Cihazın yerel saat dilimini `timezone` paketine tanıtır.
  ///
  /// `zonedSchedule` mutlak zamanı doğru yorumlayabilmek için buna muhtaç.
  Future<void> _initTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } on Object catch (e) {
      // Çözülemezse UTC'de kalır; bildirim saati kayabilir ama akış sürer.
      debugPrint('Yerel saat dilimi çözülemedi, UTC kullanılıyor: $e');
    }
    _timezoneReady = true;
  }

  /// Android 13+ `POST_NOTIFICATIONS` ve iOS izinlerini ister.
  ///
  /// Reddedilirse `false` döner — çağıran akışı DURDURMAZ.
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        return granted ?? false;
      }
      if (Platform.isIOS) {
        final ios = plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return false;
    } on Object catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
      return false;
    }
  }

  Future<bool> hasPermission() async {
    try {
      if (Platform.isAndroid) {
        final android = plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.areNotificationsEnabled() ?? false;
      }
      // iOS'ta doğrudan sorgu yok; izin isteği idempotent olduğu için
      // requestPermission() sonucu kullanılabilir.
      return _initialized;
    } on Object {
      return false;
    }
  }

  /// Bildirim ayrıntıları — kullanıcı tercihlerine göre.
  ///
  /// Kanal Android'de ilk kullanımda oluşur ve **ses/titreşim ayarları o
  /// anda sabitlenir**; bu yüzden her kombinasyon ayrı bir `channelId`
  /// kullanıyor (bkz. [NotificationPrefs.channelId]).
  NotificationDetails detailsFor(NotificationPrefs prefs) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        prefs.channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        playSound: prefs.sound,
        enableVibration: prefs.vibration,
      ),
      iOS: DarwinNotificationDetails(presentSound: prefs.sound),
    );
  }
}
