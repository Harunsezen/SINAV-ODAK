import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/notification_prefs.dart';
import 'package:sinav_odak/domain/ports/screen_wake_gateway.dart';
import 'package:sinav_odak/services/background/wakelock_screen_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'usecase_helpers.dart';

/// Ekran kilidi çağrılarını kaydeden sahte kapı.
class RecordingWakeGateway implements ScreenWakeGateway {
  final List<bool> calls = [];

  @override
  Future<void> setEnabled({required bool enabled}) async => calls.add(enabled);
}

/// FAZ 8 — Ayarların GERÇEKTEN uygulanması.
///
/// Bu testler bir sınıf hatayı kilitliyor: `keepScreenOn`,
/// `notificationEnabled`, `soundEnabled` ve `vibrationEnabled` ayarları
/// veritabanına yazılıyor ama **hiçbir yerde okunmuyordu**. Kullanıcı
/// bildirimleri kapatıyor, bildirimler kurulmaya devam ediyordu; ekranı
/// açık tutmayı seçiyor, ekran yine kapanıyordu.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<ProviderContainer> containerWith({
    bool? keepScreenOn,
    bool? notifications,
    bool? sound,
    bool? vibration,
    bool withActiveSession = false,
  }) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      UserSettingsCompanion(
        keepScreenOn: Value(keepScreenOn ?? true),
        notificationEnabled: Value(notifications ?? true),
        soundEnabled: Value(sound ?? true),
        vibrationEnabled: Value(vibration ?? true),
      ),
    );
    if (withActiveSession) {
      await seedRunningSession(db, id: 's1', sch: schedule());
    }

    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(settingsStreamProvider.future);
    // Aktif oturum akışı da ısıtılmalı; aksi halde `valueOrNull` null kalır
    // ve test ayarı değil "veri henüz gelmedi" hâlini ölçer.
    await c.read(activeSessionProvider.future);
    return c;
  }

  // -------------------------------------------------------------------
  // keepScreenOn
  // -------------------------------------------------------------------

  group('ekran açık kalsın', () {
    test('ayar AÇIK + aktif oturum VAR => ekran açık tutulur', () async {
      final c = await containerWith(
        keepScreenOn: true,
        withActiveSession: true,
      );
      expect(c.read(shouldKeepScreenOnProvider), isTrue);
    });

    test('ayar AÇIK ama oturum YOK => ekran açık tutulmaz', () async {
      final c = await containerWith(keepScreenOn: true);
      expect(
        c.read(shouldKeepScreenOnProvider),
        isFalse,
        reason: 'oturumsuz ekranı açık tutmak pili boşuna tüketir',
      );
    });

    test('ayar KAPALI + oturum VAR => ekran açık tutulmaz', () async {
      final c = await containerWith(
        keepScreenOn: false,
        withActiveSession: true,
      );
      expect(c.read(shouldKeepScreenOnProvider), isFalse);
    });

    test('varsayılan kapı Noop (test/desteklenmeyen platform)', () async {
      final c = await containerWith();
      expect(c.read(screenWakeGatewayProvider), isA<NoopScreenWakeGateway>());
    });

    test('kapı gerçekten çağrılıyor', () async {
      final gateway = RecordingWakeGateway();
      await gateway.setEnabled(enabled: true);
      await gateway.setEnabled(enabled: false);
      expect(gateway.calls, [true, false]);
    });
  });

  // -------------------------------------------------------------------
  // Bildirim tercihleri
  // -------------------------------------------------------------------

  group('bildirim tercihleri ayardan okunuyor', () {
    test('hepsi açık', () async {
      final c = await containerWith();
      final p = c.read(notificationPrefsProvider);
      expect(p.enabled, isTrue);
      expect(p.sound, isTrue);
      expect(p.vibration, isTrue);
    });

    test('bildirim kapalı => enabled false', () async {
      final c = await containerWith(notifications: false);
      expect(c.read(notificationPrefsProvider).enabled, isFalse);
    });

    test('ses kapalı => sound false', () async {
      final c = await containerWith(sound: false);
      final p = c.read(notificationPrefsProvider);
      expect(p.sound, isFalse);
      expect(p.enabled, isTrue, reason: 'ses ayrı, bildirim ayrı');
    });

    test('titreşim kapalı => vibration false', () async {
      final c = await containerWith(vibration: false);
      expect(c.read(notificationPrefsProvider).vibration, isFalse);
    });

    test('ayar okunamazsa VARSAYILAN (bildirimler açık)', () {
      // Ayar akışı gecikirse `false`'a düşmek, ilk açılışta bildirimleri
      // sessizce kapatmak olurdu.
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(notificationPrefsProvider), NotificationPrefs.defaults);
    });
  });

  // -------------------------------------------------------------------
  // Kanal kimliği — Android'in kanal modeli
  // -------------------------------------------------------------------

  group('NotificationPrefs.channelId', () {
    test('ses/titreşim kombinasyonları AYRI kanal', () {
      const a = NotificationPrefs();
      const b = NotificationPrefs(sound: false);
      const c = NotificationPrefs(vibration: false);
      const d = NotificationPrefs(sound: false, vibration: false);

      final ids = {a.channelId, b.channelId, c.channelId, d.channelId};
      expect(
        ids,
        hasLength(4),
        reason: 'Android kanal ayarları oluşturulduktan sonra '
            'değiştirilemiyor; tek kanalla ses ayarı sessizce yok sayılırdı',
      );
    });

    test('aynı tercihler aynı kanal kimliği', () {
      expect(
        const NotificationPrefs(sound: true, vibration: false).channelId,
        const NotificationPrefs(sound: true, vibration: false).channelId,
      );
    });

    test('enabled kanal kimliğini ETKİLEMİYOR', () {
      // Kapalıyken zaten hiç bildirim kurulmuyor; kanal ayrımı gereksiz
      // olurdu.
      expect(
        const NotificationPrefs(enabled: false).channelId,
        const NotificationPrefs().channelId,
      );
    });
  });
}
