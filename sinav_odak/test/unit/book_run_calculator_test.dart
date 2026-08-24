import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/book_input.dart';
import 'package:sinav_odak/domain/services/book_run_calculator.dart';

import 'usecase_helpers.dart';

/// v1.3 — OKUMA SAYACI. Saf Dart; `DateTime.now()` yok, sabit `t0`.
///
/// Sayacın koruduğu ilke: **durum saklanmıyor.** Her çağrı
/// `now - startedAt` ile baştan hesaplanıyor; bu yüzden "pause" diye bir
/// şey mümkün değil ve uygulama kapanıp açılsa da süre doğru kalıyor.
void main() {
  group('SÜRE modu — geri sayım', () {
    test('başlangıçta tam süre kalıyor', () {
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0,
        plannedDurationS: 1800,
      );
      expect(s.remainingS, 1800);
      expect(s.elapsedS, 0);
      expect(s.expired, isFalse);
    });

    test('10 dakika sonra 20 dakika kalıyor', () {
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0 + 600000,
        plannedDurationS: 1800,
      );
      expect(s.remainingS, 1200);
      expect(s.elapsedS, 600);
      expect(s.expired, isFalse);
    });

    test('süre TAM dolduğunda expired', () {
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0 + 1800000,
        plannedDurationS: 1800,
      );
      expect(s.expired, isTrue);
      expect(s.remainingS, 0);
      expect(s.elapsedS, 1800);
    });

    test('süre dolduktan SONRA geçen zaman okuma sayılmıyor', () {
      // Alarm çaldığında okuma bitmişti; uygulama kapalı kaldıysa aradaki
      // zamanı okumaya yazmak uydurma olurdu.
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0 + 9 * 3600 * 1000,
        plannedDurationS: 1800,
      );
      expect(s.elapsedS, 1800, reason: 'planlanan süreyi AŞAMAZ');
      expect(s.remainingS, 0);
      expect(s.expired, isTrue);
    });
  });

  group('SAYFA HEDEFİ modu — ileri sayım', () {
    test('kalan YOK: planlanmış bir bitiş yok', () {
      final s = BookRunCalculator.resolve(startedAtMs: t0, nowMs: t0 + 60000);
      expect(s.remainingS, isNull);
      expect(s.expired, isFalse);
      expect(s.elapsedS, 60);
    });

    test('12 saatte TAVANA dayanıyor ve bunu bildiriyor', () {
      // Sayacı açık unutan kullanıcı "23 saat okudum" kaydetmesin.
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0 + 23 * 3600 * 1000,
      );
      expect(s.elapsedS, BookInput.maxReadingS);
      expect(s.capped, isTrue, reason: 'kırpma SESSİZ olmamalı');
    });

    test('tavanın altında capped false', () {
      final s = BookRunCalculator.resolve(
        startedAtMs: t0,
        nowMs: t0 + 3600 * 1000,
      );
      expect(s.capped, isFalse);
    });
  });

  test('cihaz saati geriye alındıysa süre 0, negatif DEĞİL', () {
    final s = BookRunCalculator.resolve(
      startedAtMs: t0,
      nowMs: t0 - 600000,
      plannedDurationS: 1800,
    );
    expect(s.elapsedS, 0);
    expect(s.remainingS, 1800);
    expect(s.expired, isFalse);
  });
}
