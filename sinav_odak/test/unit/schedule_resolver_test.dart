import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/entities/schedule_codec_exception.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';
import 'package:sinav_odak/domain/entities/session_state.dart';
import 'package:sinav_odak/domain/services/schedule_builder.dart';
import 'package:sinav_odak/domain/services/schedule_modifier.dart';
import 'package:sinav_odak/domain/services/schedule_resolver.dart';

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

const int studyEnd = t0 + 1440000; // 24 dk
const int breakEnd = studyEnd + 300000; // + 5 dk
const int lastEnd = breakEnd + 1440000; // + 24 dk

SessionState at(int nowMs, [SessionSchedule? s]) => ScheduleResolver.resolve(
      sessionId: sid,
      schedule: s ?? schedule(),
      nowMs: nowMs,
    );

void main() {
  group('blok sınırları', () {
    test('now = başlangıç -> ilk çalışma bloğu', () {
      final s = at(t0);
      expect(s, isA<SessionInBlock>());
      expect((s as SessionInBlock).blockIndex, 0);
      expect(s.remainingMs, 1440000);
    });

    test('now = başlangıç + 1 sn -> kalan 1 sn azalır', () {
      final s = at(t0 + 1000) as SessionInBlock;
      expect(s.blockIndex, 0);
      expect(s.remainingMs, 1439000);
    });

    test('çalışma bitişinden 1 sn önce -> hâlâ ilk blok', () {
      final s = at(studyEnd - 1000);
      expect(s, isA<SessionInBlock>());
      expect((s as SessionInBlock).blockIndex, 0);
      expect(s.remainingMs, 1000);
    });

    test('now = çalışma bitişi -> sonraki bloğa GEÇMİŞ sayılır (mola)', () {
      final s = at(studyEnd);
      expect(s, isA<SessionInBreak>());
      expect((s as SessionInBreak).blockIndex, 1);
      expect(s.remainingMs, 300000);
    });

    test('mola bitişinden 1 sn önce -> hâlâ mola', () {
      final s = at(breakEnd - 1000);
      expect(s, isA<SessionInBreak>());
      expect((s as SessionInBreak).remainingMs, 1000);
    });

    test('now = mola bitişi -> ikinci çalışma bloğu', () {
      final s = at(breakEnd);
      expect(s, isA<SessionInBlock>());
      expect((s as SessionInBlock).blockIndex, 2);
      expect(s.remainingMs, 1440000);
    });

    test('son bitişten 1 sn önce -> hâlâ son blok', () {
      final s = at(lastEnd - 1000);
      expect(s, isA<SessionInBlock>());
      expect((s as SessionInBlock).blockIndex, 2);
    });

    test('now = son bitiş -> summarizing', () {
      expect(at(lastEnd), isA<SessionSummarizing>());
    });

    test('now = son bitiş + 1 sn -> summarizing', () {
      expect(at(lastEnd + 1000), isA<SessionSummarizing>());
    });
  });

  group('saat kayması toleransı (3000 ms)', () {
    test('1 sn geri -> tolerans içinde, ilk blok', () {
      final s = at(t0 - 1000);
      expect(s, isA<SessionInBlock>());
      expect(
        (s as SessionInBlock).remainingMs,
        1440000,
        reason: 'kalan süre planlanan süreyi aşmamalı',
      );
    });

    test('tam 3 sn geri -> hâlâ tolerans içinde', () {
      expect(at(t0 - ScheduleResolver.clockSkewToleranceMs),
          isA<SessionInBlock>());
    });

    test('3001 ms geri -> clockMovedBack', () {
      final s = at(t0 - 3001);
      expect(s, isA<SessionClockMovedBack>());
      expect(s.sessionIdOrNull, sid);
      expect(s.scheduleOrNull, isNotNull);
    });

    test('clockMovedBack durumunda oturum çalışmıyor sayılır', () {
      final s = at(t0 - 60000);
      expect(s.isRunning, isFalse);
      expect(s.isInStudyBlock, isFalse);
    });
  });

  group('state içeriği', () {
    test('inBlock çizelgeyi ve bitiş anını taşır', () {
      final s = at(t0) as SessionInBlock;
      expect(s.sessionId, sid);
      expect(s.blockEndsAtMs, studyEnd);
      expect(s.schedule.blockCount, 3);
      expect(s.isInStudyBlock, isTrue);
    });

    test('inBreak uzatma sayısını taşır', () {
      // Molayı +5 dk uzat, sonra mola içinde bir ana çözümle.
      final extended = ScheduleModifier.extendBreak(schedule(), 1, 300);
      final s = at(studyEnd + 1000, extended) as SessionInBreak;
      expect(s.blockIndex, 1);
      expect(s.extensionsUsed, 1, reason: 'extendedS 300 -> 300 ~/ 300 = 1');
      expect(s.isInStudyBlock, isFalse);
    });

    test('uzatılmamış molada extensionsUsed 0', () {
      final s = at(studyEnd + 1000) as SessionInBreak;
      expect(s.extensionsUsed, 0);
    });
  });

  group('boş çizelge', () {
    // SessionSchedule private constructor'a sahip olduğu için dışarıdan boş
    // çizelge üretilemez. Resolver'daki guard'ı test etmek yerine, boş
    // çizelgenin hiç oluşturulamadığını doğruluyoruz.
    test('boş blok listesiyle çizelge kurulamaz', () {
      expect(
        () => SessionSchedule.fromBlocks(createdAtMs: t0, blocks: const []),
        throwsA(
          isA<SessionScheduleCodecException>().having(
            (e) => e.reason,
            'reason',
            ScheduleCodecReason.emptyBlocks,
          ),
        ),
      );
    });
  });
}
