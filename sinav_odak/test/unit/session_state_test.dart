import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';

/// Sabit epoch: testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;
const String sid = 's1';

/// 24 dk çalışma + 5 dk mola + 24 dk çalışma.
SessionSchedule schedule() => ScheduleBuilder.fromPreset(
      startAtMs: t0,
      workMinutes: 24,
      breakMinutes: 5,
      cycles: 2,
    ).schedule;

void main() {
  group('idle', () {
    test('hiçbir oturum bilgisi taşımıyor', () {
      const s = SessionState.idle();
      expect(s.sessionIdOrNull, isNull);
      expect(s.scheduleOrNull, isNull);
      expect(s.remainingSeconds, 0);
      expect(s.isRunning, isFalse);
      expect(s.isInStudyBlock, isFalse);
    });
  });

  group('configuring', () {
    test('çizelge henüz yok', () {
      const s = SessionState.configuring();
      expect(s.sessionIdOrNull, isNull);
      expect(s.scheduleOrNull, isNull);
      expect(s.remainingSeconds, 0);
      expect(s.isRunning, isFalse);
      expect(s.isInStudyBlock, isFalse);
    });
  });

  group('beforeStart', () {
    test('çizelge taşıyor ama henüz çalışmıyor', () {
      final s = SessionState.beforeStart(sessionId: sid, schedule: schedule());
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
      expect(s.isRunning, isFalse);
      expect(s.isInStudyBlock, isFalse);
      expect(s.remainingSeconds, 0);
    });
  });

  group('inBlock', () {
    test('çalışma bloğu sürüyor', () {
      final s = SessionState.inBlock(
        sessionId: sid,
        blockIndex: 0,
        blockEndsAtMs: t0 + 1440000,
        remainingMs: 1440000,
        schedule: schedule(),
      );
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
      expect(s.isRunning, isTrue);
      expect(s.isInStudyBlock, isTrue, reason: 'reklam yasağının dayanağı');
      expect(s.remainingSeconds, 1440000 ~/ 1000);
    });
  });

  group('inBreak', () {
    SessionState breakState({int extensionsUsed = 0}) => SessionState.inBreak(
          sessionId: sid,
          blockIndex: 1,
          breakEndsAtMs: t0 + 1740000,
          remainingMs: 300000,
          extensionsUsed: extensionsUsed,
          schedule: schedule(),
        );

    test('mola sürüyor, çalışma bloğu değil', () {
      final s = breakState();
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
      expect(s.isRunning, isTrue);
      expect(
        s.isInStudyBlock,
        isFalse,
        reason: 'molada tam ekran reklam serbest',
      );
      expect(s.remainingSeconds, 300000 ~/ 1000);
    });

    test('uzatma sayısı state içinde taşınıyor', () {
      // UI "molayı 2 kez uzattın, hakkın doldu" mesajını buradan okuyacak.
      expect((breakState(extensionsUsed: 0) as SessionInBreak).extensionsUsed, 0);
      expect((breakState(extensionsUsed: 1) as SessionInBreak).extensionsUsed, 1);
      expect((breakState(extensionsUsed: 2) as SessionInBreak).extensionsUsed, 2);
    });

    test('blok indeksi state içinde taşınıyor', () {
      expect((breakState() as SessionInBreak).blockIndex, 1);
      expect((breakState() as SessionInBreak).breakEndsAtMs, t0 + 1740000);
    });
  });

  group('summarizing', () {
    test('çizelge bitti, form bekleniyor', () {
      final s = SessionState.summarizing(sessionId: sid, schedule: schedule());
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
      expect(s.isRunning, isFalse);
      expect(s.remainingSeconds, 0);
    });
  });

  group('saved', () {
    test('odak skoru taşıyor, çizelge taşımıyor', () {
      const s = SessionState.saved(sessionId: sid, focusScore: 88);
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNull);
      expect(s.isRunning, isFalse);
      expect((s as SessionSaved).focusScore, 88);
    });
  });

  group('clockMovedBack', () {
    test('çizelge taşıyor ama çalışmıyor', () {
      final s =
          SessionState.clockMovedBack(sessionId: sid, schedule: schedule());
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
      expect(s.isRunning, isFalse);
      expect(s.isInStudyBlock, isFalse);
    });
  });

  group('remainingSeconds aşağı yuvarlıyor', () {
    SessionState withRemaining(int ms) => SessionState.inBlock(
          sessionId: sid,
          blockIndex: 0,
          blockEndsAtMs: t0 + ms,
          remainingMs: ms,
          schedule: schedule(),
        );

    test('1500 ms -> 1 sn', () => expect(withRemaining(1500).remainingSeconds, 1));
    test('999 ms -> 0 sn', () => expect(withRemaining(999).remainingSeconds, 0));
    test('0 ms -> 0 sn', () => expect(withRemaining(0).remainingSeconds, 0));
  });
}
