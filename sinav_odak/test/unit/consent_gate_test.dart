import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/core/di/ad_providers.dart';
import 'package:sinav_odak/core/di/app_providers.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/consent_state.dart';
import 'package:sinav_odak/domain/ports/consent_gateway.dart';
import 'package:sinav_odak/services/ads/noop_consent_gateway.dart';

import 'usecase_helpers.dart';

/// Test amaçlı UMP: gerçek SDK'yı çağırmadan kararı biz veriyoruz.
///
/// `UmpConsentGateway`'in KENDİSİ burada test edilmiyor — platform kanalı
/// gerektiriyor ve `flutter test` içinde çağrı hiç tamamlanmıyor. Test
/// edilen, ürünün asıl kuralı: UMP sonucu uygulamanın reklam kararına NASIL
/// giriyor.
class FakeConsentGateway implements ConsentGateway {
  FakeConsentGateway(this.result);

  ConsentResult result;
  int gatherCount = 0;
  int privacyCount = 0;

  @override
  Future<ConsentResult> gather() async {
    gatherCount++;
    return result;
  }

  @override
  Future<ConsentResult> current() async => result;

  @override
  Future<ConsentResult> showPrivacyOptions() async {
    privacyCount++;
    return result;
  }

  @override
  Future<void> reset() async {}
}

void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> setStoredConsent(bool value) async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      UserSettingsCompanion(personalizedAdsConsent: Value(value)),
    );
  }

  /// Rıza kapısını, açılıştaki UMP sonucu [boot] ile kurar.
  Future<ProviderContainer> containerWith(ConsentResult boot) async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => t0),
        consentBootResultProvider.overrideWithValue(boot),
        uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    addTearDown(c.dispose);
    // Ayar akışı ısıtılmadan `valueOrNull` null kalır ve test, rızayı değil
    // "ayar henüz gelmedi" hâlini ölçerdi.
    await c.read(settingsStreamProvider.future);
    return c;
  }

  const umpYes = ConsentResult(
    state: ConsentState.obtained,
    canRequestAds: true,
  );
  const umpNo = ConsentResult(
    state: ConsentState.required_,
    canRequestAds: false,
  );

  // ---------------------------------------------------------------------
  // İKİ KAPI: kullanıcı tercihi VE UMP. İkisi de açık olmalı.
  // ---------------------------------------------------------------------

  group('adConsentProvider — iki kapı', () {
    test('kullanıcı EVET + UMP EVET => reklam VAR', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpYes);
      expect(c.read(adConsentProvider), isTrue);
    });

    test('kullanıcı EVET + UMP HAYIR => reklam YOK', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpNo);
      expect(
        c.read(adConsentProvider),
        isFalse,
        reason: 'UMP kısıtlaması kullanıcı tercihini EZER',
      );
    });

    test('kullanıcı HAYIR + UMP EVET => reklam YOK', () async {
      await setStoredConsent(false);
      final c = await containerWith(umpYes);
      expect(
        c.read(adConsentProvider),
        isFalse,
        reason: 'UMP "evet" demek kullanıcı adına rıza vermek DEĞİL',
      );
    });

    test('kullanıcı HAYIR + UMP HAYIR => reklam YOK', () async {
      await setStoredConsent(false);
      final c = await containerWith(umpNo);
      expect(c.read(adConsentProvider), isFalse);
    });
  });

  group('UMP erişilemediğinde', () {
    test('ConsentResult.unavailable rızayı KAPATIR', () async {
      await setStoredConsent(true);
      final c = await containerWith(ConsentResult.unavailable);
      expect(
        c.read(adConsentProvider),
        isFalse,
        reason: 'hata hâlinde "izin var" saymak rızasız reklam olurdu',
      );
    });

    test('unavailable canRequestAds=false taşır', () {
      expect(ConsentResult.unavailable.canRequestAds, isFalse);
      expect(ConsentResult.unavailable.state, ConsentState.unknown);
    });

    test('UMP hiç çalışmamışsa karar kullanıcı tercihine düşer', () async {
      // Varsayılan (override YOK) = UMP devrede değil.
      await setStoredConsent(true);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(settingsStreamProvider.future);

      expect(
        c.read(adConsentProvider),
        isTrue,
        reason: 'UMP yokluğu "rıza yok" demek değil; toggle hâlâ kapı',
      );
    });
  });

  // ---------------------------------------------------------------------
  // Ayarlardan formun yeniden açılması (KVKK/GDPR: rıza geri alınabilir)
  // ---------------------------------------------------------------------

  group('gizlilik tercihi güncellemesi', () {
    test('override açılış kararını EZER', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpYes);
      expect(c.read(adConsentProvider), isTrue);

      c.read(consentResultOverrideProvider.notifier).state = umpNo;

      expect(
        c.read(adConsentProvider),
        isFalse,
        reason: 'kullanıcı formu açıp reddettiyse reklam ANINDA durmalı',
      );
    });

    test('override yokken açılış kararı geçerli', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpNo);
      expect(c.read(consentResultProvider).canRequestAds, isFalse);
    });

    test('privacyOptionsRequired sonuçtan okunuyor', () async {
      await setStoredConsent(true);
      final c = await containerWith(
        const ConsentResult(
          state: ConsentState.obtained,
          canRequestAds: true,
          privacyOptionsRequired: true,
        ),
      );
      expect(c.read(consentResultProvider).privacyOptionsRequired, isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Rıza kapısı, yer politikasının ÖNÜNDE
  // ---------------------------------------------------------------------

  group('yer politikasıyla birlikte', () {
    test('UMP HAYIR ise hiçbir yer gösterilemez', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpNo);

      for (final p in AdPlacement.values) {
        expect(
          c.read(adAllowedProvider(p)),
          isFalse,
          reason: '$p UMP reddine rağmen açık kaldı',
        );
      }
    });

    test('UMP EVET iken ana panel banner AÇIK', () async {
      await setStoredConsent(true);
      final c = await containerWith(umpYes);
      expect(c.read(adAllowedProvider(AdPlacement.homeBanner)), isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Varsayılan adaptör
  // ---------------------------------------------------------------------

  group('NoopConsentGateway', () {
    test('varsayılan sağlayıcı Noop', () async {
      final c = await containerWith(umpYes);
      expect(c.read(consentGatewayProvider), isA<NoopConsentGateway>());
    });

    test('gather UMP\'siz çalışmayı ENGELLEMEZ', () async {
      final r = await const NoopConsentGateway().gather();
      expect(
        r.canRequestAds,
        isTrue,
        reason: 'UMP kurulu değil demek, kullanıcı reddetti demek değil',
      );
      expect(r.privacyOptionsRequired, isFalse);
    });

    test('showPrivacyOptions gösterecek form olmadığını bildiriyor', () async {
      final r = await const NoopConsentGateway().showPrivacyOptions();
      expect(r.privacyOptionsRequired, isFalse);
    });
  });

  group('FakeConsentGateway ile akış', () {
    test('gather sonucu rıza kapısına giriyor', () async {
      await setStoredConsent(true);
      final fake = FakeConsentGateway(umpNo);

      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          consentGatewayProvider.overrideWithValue(fake),
          uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(settingsStreamProvider.future);

      // `main()`'in yaptığı: topla, sonucu boot kararı olarak kullan.
      final gathered = await c.read(consentGatewayProvider).gather();
      c.read(consentResultOverrideProvider.notifier).state = gathered;

      expect(fake.gatherCount, 1);
      expect(c.read(adConsentProvider), isFalse);
    });

    test('showPrivacyOptions çağrısı sonucu tazeliyor', () async {
      await setStoredConsent(true);
      final fake = FakeConsentGateway(umpYes);

      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => t0),
          consentGatewayProvider.overrideWithValue(fake),
          uiTickerProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
      );
      addTearDown(c.dispose);
      await c.read(settingsStreamProvider.future);

      fake.result = umpNo;
      final r = await c.read(consentGatewayProvider).showPrivacyOptions();
      c.read(consentResultOverrideProvider.notifier).state = r;

      expect(fake.privacyCount, 1);
      expect(c.read(adConsentProvider), isFalse);
    });
  });
}
