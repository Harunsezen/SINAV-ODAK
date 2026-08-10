import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/services/ad_policy_engine.dart';

import 'usecase_helpers.dart';

/// FAZ 4 — Reklam politikası (saf Dart).
///
/// Bu dosya ürünün en kolay sessizce bozulan kuralını kilitler: çalışma
/// bloğunda tam ekran reklam ve rızasız reklam. Bir ekran kestirme yaparsa
/// burada yakalanır.
void main() {
  final sch = schedule();

  SessionState inBlock() => SessionState.inBlock(
        sessionId: 's1',
        blockIndex: 0,
        blockEndsAtMs: breakStart,
        remainingMs: 600000,
        schedule: sch,
      );

  SessionState inBreak() => SessionState.inBreak(
        sessionId: 's1',
        blockIndex: breakIndex,
        breakEndsAtMs: breakEnd,
        remainingMs: 300000,
        extensionsUsed: 0,
        schedule: sch,
      );

  SessionState summarizing() =>
      SessionState.summarizing(sessionId: 's1', schedule: sch);

  const idle = SessionState.idle();

  // ---------------------------------------------------------------------
  group('RIZA KAPISI — rıza yoksa HİÇBİR reklam yok', () {
    test('rıza kapalıyken YEDİ yerin hepsi reddediliyor', () {
      for (final p in AdPlacement.values) {
        expect(
          AdPolicyEngine.allows(
            placement: p,
            state: idle,
            consent: false,
            breakRemainingS: 600,
            nowMs: t0,
          ),
          isFalse,
          reason: '$p rızasız gösterilemez',
        );
      }
    });

    test('banner: rıza kapalı → false', () {
      expect(
        AdPolicyEngine.banner(
          placement: AdPlacement.homeBanner,
          consent: false,
          showAdsInFocusScreen: true,
        ),
        isFalse,
      );
    });

    test('native: rıza kapalı → false (mola uzun olsa bile)', () {
      expect(
        AdPolicyEngine.nativeBreak(
          state: inBreak(),
          consent: false,
          breakRemainingS: 600,
        ),
        isFalse,
      );
    });

    test('interstitial: rıza kapalı → false (kapı açık olsa bile)', () {
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: false,
          nowMs: t0,
          lastShownAtMs: null,
        ),
        isFalse,
      );
    });

    test('rewarded: rıza kapalı → false', () {
      expect(
        AdPolicyEngine.rewarded(state: idle, consent: false),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------
  group('ÇALIŞMA BLOĞU — tam ekran ASLA (G7)', () {
    test('inBlock: tüm TAM EKRAN yerler reddediliyor', () {
      final fullScreen =
          AdPlacement.values.where((p) => p.isFullScreen).toList();
      expect(fullScreen, hasLength(2), reason: 'interstitial + rewarded');

      for (final p in fullScreen) {
        expect(
          AdPolicyEngine.allows(
            placement: p,
            state: inBlock(),
            consent: true,
            nowMs: t0,
            breakRemainingS: 600,
          ),
          isFalse,
          reason: '$p çalışma bloğunda ASLA',
        );
      }
    });

    test('inBlock: interstitial frekans kapısı açık olsa bile false', () {
      expect(
        AdPolicyEngine.interstitial(
          state: inBlock(),
          consent: true,
          nowMs: t0,
          lastShownAtMs: null,
        ),
        isFalse,
      );
    });

    test('inBlock: rewarded false', () {
      expect(
        AdPolicyEngine.rewarded(state: inBlock(), consent: true),
        isFalse,
      );
    });

    test('inBlock: native false (mola değil)', () {
      expect(
        AdPolicyEngine.nativeBreak(
          state: inBlock(),
          consent: true,
          breakRemainingS: 600,
        ),
        isFalse,
      );
    });

    test('inBlock: İNCE BANNER serbest — ayar açıksa', () {
      expect(
        AdPolicyEngine.allows(
          placement: AdPlacement.runBanner,
          state: inBlock(),
          consent: true,
        ),
        isTrue,
        reason: 'banner ekranı kaplamaz; yasak TAM EKRAN için',
      );
    });
  });

  // ---------------------------------------------------------------------
  group('BANNER', () {
    test('run banner: ayar KAPALI → false', () {
      expect(
        AdPolicyEngine.banner(
          placement: AdPlacement.runBanner,
          consent: true,
          showAdsInFocusScreen: false,
        ),
        isFalse,
      );
    });

    test('run banner: ayar AÇIK → true', () {
      expect(
        AdPolicyEngine.banner(
          placement: AdPlacement.runBanner,
          consent: true,
          showAdsInFocusScreen: true,
        ),
        isTrue,
      );
    });

    test('run DIŞI bannerlar odak ayarından ETKİLENMEZ', () {
      for (final p in [
        AdPlacement.homeBanner,
        AdPlacement.statsBanner,
        AdPlacement.calendarBanner,
      ]) {
        expect(
          AdPolicyEngine.banner(
            placement: p,
            consent: true,
            showAdsInFocusScreen: false,
          ),
          isTrue,
          reason: '$p ayara bağlı değil',
        );
      }
    });

    test('banner kuralı banner OLMAYAN yerlere uygulanmaz', () {
      for (final p in [
        AdPlacement.breakNative,
        AdPlacement.doneInterstitial,
        AdPlacement.supportRewarded,
      ]) {
        expect(
          AdPolicyEngine.banner(
            placement: p,
            consent: true,
            showAdsInFocusScreen: true,
          ),
          isFalse,
          reason: '$p banner değil',
        );
      }
    });
  });

  // ---------------------------------------------------------------------
  group('NATIVE — mola kartı', () {
    test('molada kalan 181 sn → true (sınırın hemen üstü)', () {
      expect(
        AdPolicyEngine.nativeBreak(
          state: inBreak(),
          consent: true,
          breakRemainingS: 181,
        ),
        isTrue,
      );
    });

    test('molada kalan TAM 180 sn → false (sınır dahil DEĞİL)', () {
      expect(
        AdPolicyEngine.nativeBreak(
          state: inBreak(),
          consent: true,
          breakRemainingS: 180,
        ),
        isFalse,
      );
    });

    test('molada kalan 179 sn → false', () {
      expect(
        AdPolicyEngine.nativeBreak(
          state: inBreak(),
          consent: true,
          breakRemainingS: 179,
        ),
        isFalse,
      );
    });

    test('mola DIŞINDAKİ state\'lerde native yok', () {
      for (final s in [idle, summarizing(), inBlock()]) {
        expect(
          AdPolicyEngine.nativeBreak(
            state: s,
            consent: true,
            breakRemainingS: 600,
          ),
          isFalse,
          reason: '$s molada değil',
        );
      }
    });
  });

  // ---------------------------------------------------------------------
  group('INTERSTITIAL — 90 sn frekans kapısı', () {
    test('hiç gösterilmemişse (null) kapı AÇIK', () {
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: true,
          nowMs: t0,
          lastShownAtMs: null,
        ),
        isTrue,
      );
    });

    test('89 sn sonra → false', () {
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: true,
          nowMs: t0 + 89000,
          lastShownAtMs: t0,
        ),
        isFalse,
      );
    });

    test('TAM 90 sn sonra → true (sınır dahil)', () {
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: true,
          nowMs: t0 + 90000,
          lastShownAtMs: t0,
        ),
        isTrue,
      );
    });

    test('91 sn sonra → true', () {
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: true,
          nowMs: t0 + 91000,
          lastShownAtMs: t0,
        ),
        isTrue,
      );
    });

    test('cihaz saati geriye alınmışsa kapı KAPALI kalır', () {
      // now < last: fark negatif, eşiği geçemez. Saat oynatarak reklam
      // frekansı sömürülemesin.
      expect(
        AdPolicyEngine.interstitial(
          state: idle,
          consent: true,
          nowMs: t0 - 600000,
          lastShownAtMs: t0,
        ),
        isFalse,
      );
    });

    test('kayıt sonrası (summarizing/idle) gösterilebilir', () {
      for (final s in [idle, summarizing()]) {
        expect(
          AdPolicyEngine.interstitial(
            state: s,
            consent: true,
            nowMs: t0,
            lastShownAtMs: null,
          ),
          isTrue,
        );
      }
    });
  });

  // ---------------------------------------------------------------------
  group('REWARDED', () {
    test('rıza varsa ve çalışma bloğunda değilse izinli', () {
      expect(AdPolicyEngine.rewarded(state: idle, consent: true), isTrue);
      expect(
        AdPolicyEngine.rewarded(state: inBreak(), consent: true),
        isTrue,
      );
    });

    test('frekans kapısı YOK: kullanıcı başlattığı için ardışık izinli', () {
      expect(
        AdPolicyEngine.allows(
          placement: AdPlacement.supportRewarded,
          state: idle,
          consent: true,
          lastShownAtMs: t0,
          nowMs: t0 + 1000,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------
  group('AdPlacement sözleşmesi', () {
    test('format eşlemesi doğru', () {
      expect(AdPlacement.homeBanner.kind, AdKind.banner);
      expect(AdPlacement.runBanner.kind, AdKind.banner);
      expect(AdPlacement.breakNative.kind, AdKind.native);
      expect(AdPlacement.doneInterstitial.kind, AdKind.interstitial);
      expect(AdPlacement.supportRewarded.kind, AdKind.rewarded);
    });

    test('isFullScreen YALNIZCA interstitial ve rewarded için true', () {
      for (final p in AdPlacement.values) {
        final expected = p.kind == AdKind.interstitial ||
            p.kind == AdKind.rewarded;
        expect(p.isFullScreen, expected, reason: '$p');
      }
    });

    test('banner ve native TAM EKRAN DEĞİL', () {
      expect(AdPlacement.homeBanner.isFullScreen, isFalse);
      expect(AdPlacement.runBanner.isFullScreen, isFalse);
      expect(AdPlacement.breakNative.isFullScreen, isFalse);
    });

    test('screenName ad_events için benzersiz ve okunabilir', () {
      expect(AdPlacement.runBanner.screenName, 'run');
      expect(AdPlacement.breakNative.screenName, 'break');
      expect(AdPlacement.doneInterstitial.screenName, 'done');
    });
  });

  // ---------------------------------------------------------------------
  group('allows() — tek giriş noktası', () {
    test('her yer için doğru kurala yönlendiriyor', () {
      // Native: mola + uzun kalan gerekiyor.
      expect(
        AdPolicyEngine.allows(
          placement: AdPlacement.breakNative,
          state: inBreak(),
          consent: true,
          breakRemainingS: 600,
        ),
        isTrue,
      );
      // Aynı yer, kısa mola: red.
      expect(
        AdPolicyEngine.allows(
          placement: AdPlacement.breakNative,
          state: inBreak(),
          consent: true,
          breakRemainingS: 60,
        ),
        isFalse,
      );
    });

    test('çalışma bloğunda geçen HİÇBİR yer tam ekran değil', () {
      final allowed = AdPlacement.values
          .where(
            (p) => AdPolicyEngine.allows(
              placement: p,
              state: inBlock(),
              consent: true,
              nowMs: t0,
              breakRemainingS: 600,
            ),
          )
          .toList();

      expect(
        allowed.where((p) => p.isFullScreen),
        isEmpty,
        reason: 'G7: çalışma bloğunda TAM EKRAN ASLA',
      );
      expect(
        allowed,
        isNot(contains(AdPlacement.breakNative)),
        reason: 'çalışma bloğu mola değil',
      );
      expect(
        allowed,
        contains(AdPlacement.runBanner),
        reason: 'ince banner serbest',
      );
      // Diğer ekranların bannerları politika olarak serbest ama pratikte
      // erişilemez: aktif oturum varken router zaten /run'a yönlendirir.
      expect(allowed.every((p) => p.kind == AdKind.banner), isTrue);
    });
  });
}
