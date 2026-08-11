import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/schedule_block.dart';
import 'package:sinav_odak/domain/entities/schedule_codec_exception.dart';
import 'package:sinav_odak/domain/entities/session_schedule.dart';

/// Sabit epoch: 2025-08-06 08:00:00 UTC. Testlerde DateTime.now() KULLANILMAZ.
const int t0 = 1754467200000;

/// Geçerli çizelge: 24dk çalışma + 5dk mola + 24dk çalışma.
List<ScheduleBlock> validBlocks() => [
      const ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0,
        endMs: t0 + 1440000,
        seconds: 1440,
      ),
      const ScheduleBlock(
        index: 1,
        type: BlockType.breakTime,
        startMs: t0 + 1440000,
        endMs: t0 + 1740000,
        seconds: 300,
      ),
      const ScheduleBlock(
        index: 2,
        type: BlockType.study,
        startMs: t0 + 1740000,
        endMs: t0 + 3180000,
        seconds: 1440,
      ),
    ];

SessionSchedule validSchedule() =>
    SessionSchedule.fromBlocks(createdAtMs: t0, blocks: validBlocks());

Matcher codecReason(ScheduleCodecReason reason) => throwsA(
      isA<SessionScheduleCodecException>()
          .having((e) => e.reason, 'reason', reason),
    );

void main() {
  group('ScheduleBlock doğrulama', () {
    test('çalışma bloğunda skipped kabul edilmiyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0,
        endMs: t0 + 1000,
        seconds: 1,
        skipped: true,
      );
      expect(
        b.validate,
        codecReason(ScheduleCodecReason.invalidStudyBlockFlags),
      );
    });

    test('çalışma bloğunda extendedS kabul edilmiyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0,
        endMs: t0 + 1000,
        seconds: 1,
        extendedS: 300,
      );
      expect(
        b.validate,
        codecReason(ScheduleCodecReason.invalidStudyBlockFlags),
      );
    });

    test('mola bloğunda skipped ve extendedS serbest', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.breakTime,
        startMs: t0,
        endMs: t0 + 300000,
        seconds: 300,
        skipped: true,
        extendedS: 300,
      );
      expect(b.validate, returnsNormally);
      expect(b.extensionsUsed, 1);
    });

    test('negatif startMs reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: -2000,
        endMs: -1000,
        seconds: 1,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.invalidNegativeValue));
    });

    test('negatif endMs reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: 0,
        endMs: -1000,
        seconds: 1,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.invalidNegativeValue));
    });

    test('negatif seconds reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0,
        endMs: t0 + 1000,
        seconds: -1,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.invalidNegativeValue));
    });

    test('negatif extendedS reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.breakTime,
        startMs: t0,
        endMs: t0 + 300000,
        seconds: 300,
        extendedS: -300,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.invalidNegativeValue));
    });

    test('saniyeye hizalı olmayan zaman reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0 + 1,
        endMs: t0 + 1001,
        seconds: 1,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.notAlignedToSecond));
    });

    test('süre uyuşmazlığı reddediliyor', () {
      const b = ScheduleBlock(
        index: 0,
        type: BlockType.study,
        startMs: t0,
        endMs: t0 + 60000,
        seconds: 99,
      );
      expect(b.validate, codecReason(ScheduleCodecReason.durationMismatch));
    });

    test('alignToSecond milisaniye artığını kırpıyor', () {
      expect(alignToSecond(t0 + 999), t0);
      expect(alignToSecond(t0), t0);
    });

    test('shiftBy süreyi bozmuyor', () {
      final b = validBlocks().first.shiftBy(60000);
      expect(b.startMs, t0 + 60000);
      expect(b.endMs, t0 + 1440000 + 60000);
      expect(b.seconds, 1440);
      expect(b.validate, returnsNormally);
    });
  });

  group('SessionSchedule doğrulama', () {
    test('geçerli çizelge kuruluyor ve toplamlar hesaplanıyor', () {
      final s = validSchedule();
      expect(s.version, 1);
      expect(s.totalStudyS, 2880);
      expect(s.totalBreakS, 300);
      expect(s.plannedEndAtMs, t0 + 3180000);
      expect(s.firstStartMs, t0);
      expect(s.blockCount, 3);
      expect(s.studyBlockCount, 2);
      expect(s.studyOrdinalOf(2), 2, reason: 'molalar sayılmamalı');
      expect(s.studyOrdinalOf(1), 0, reason: 'mola bloğu 0 dönmeli');
    });

    test('negatif createdAtMs reddediliyor', () {
      expect(
        () =>
            SessionSchedule.fromBlocks(createdAtMs: -1, blocks: validBlocks()),
        codecReason(ScheduleCodecReason.invalidNegativeValue),
      );
    });

    test('boş blok listesi reddediliyor', () {
      expect(
        () => SessionSchedule.fromBlocks(createdAtMs: t0, blocks: const []),
        codecReason(ScheduleCodecReason.emptyBlocks),
      );
    });

    test('ardışık olmayan bloklar reddediliyor (fromBlocks validate ediyor)',
        () {
      final blocks = validBlocks();
      // İkinci blokta 1 saniyelik boşluk yarat.
      blocks[1] = blocks[1].copyWith(
        startMs: blocks[1].startMs + 1000,
        seconds: 299,
      );
      expect(
        () => SessionSchedule.fromBlocks(createdAtMs: t0, blocks: blocks),
        codecReason(ScheduleCodecReason.nonContiguousBlocks),
      );
    });

    test('sıra numarası ardışık değilse reddediliyor', () {
      final blocks = validBlocks();
      blocks[2] = blocks[2].copyWith(index: 5);
      expect(
        () => SessionSchedule.fromBlocks(createdAtMs: t0, blocks: blocks),
        codecReason(ScheduleCodecReason.badIndexSequence),
      );
    });

    test('çağıranın listesi sonradan değişse bile çizelge etkilenmiyor', () {
      final blocks = validBlocks();
      final s = SessionSchedule.fromBlocks(createdAtMs: t0, blocks: blocks);
      blocks.clear();
      expect(s.blockCount, 3);
      expect(() => s.blocks.clear(), throwsUnsupportedError);
    });
  });

  group('copyWith', () {
    test('createdAtMs değiştiriyor ve doğrulama geçiyor', () {
      final s = validSchedule();
      final c = s.copyWith(createdAtMs: t0 + 5000);
      expect(c.createdAtMs, t0 + 5000);
      expect(c.blocks, s.blocks);
      expect(c.totalStudyS, s.totalStudyS);
      expect(c.plannedEndAtMs, s.plannedEndAtMs);
    });

    test('parametresiz çağrı aynı çizelgeyi üretiyor', () {
      final s = validSchedule();
      expect(s.copyWith(), s);
    });

    // API kısıtı testi: copyWith blok veya toplam parametresi ALMAZ.
    // Blokları değiştirmek isteyen kod fromBlocks kullanmak zorundadır.
    // Aşağıdaki satır derlenmediği için bu kısıt derleme zamanında garantidir:
    //   s.copyWith(blocks: [...]);  // <- compile error
    test('blok değiştirmek fromBlocks üzerinden yapılıyor', () {
      final s = validSchedule();
      final shifted =
          s.blocks.map((b) => b.shiftBy(60000)).toList(growable: false);
      final s2 = SessionSchedule.fromBlocks(createdAtMs: t0, blocks: shifted);
      expect(s2.firstStartMs, t0 + 60000);
      expect(s2.totalStudyS, s.totalStudyS);
    });
  });

  group('JSON round-trip', () {
    test('kayıpsız', () {
      final s = validSchedule();
      final back = SessionSchedule.fromJson(s.toJson());
      expect(back, s);
      expect(back.toJson(), s.toJson());
    });

    test('varsayılan sk/ex alanları JSON’a yazılmıyor', () {
      final s = validSchedule();
      final json = s.toJson();
      final blocks = json['blocks'] as List;
      for (final b in blocks) {
        expect((b as Map).containsKey('sk'), isFalse);
        expect(b.containsKey('ex'), isFalse);
      }
    });

    test('sk true round-trip kayıpsız', () {
      final blocks = validBlocks();
      blocks[1] = blocks[1].copyWith(skipped: true);
      final s = SessionSchedule.fromBlocks(createdAtMs: t0, blocks: blocks);

      final json = s.toJson();
      expect(((json['blocks'] as List)[1] as Map)['sk'], isTrue);
      expect(SessionSchedule.fromJson(json), s);
    });

    test('ex 300 round-trip kayıpsız', () {
      final blocks = validBlocks();
      blocks[1] = blocks[1].copyWith(extendedS: 300);
      final s = SessionSchedule.fromBlocks(createdAtMs: t0, blocks: blocks);

      final json = s.toJson();
      expect(((json['blocks'] as List)[1] as Map)['ex'], 300);
      expect(SessionSchedule.fromJson(json), s);
    });

    test('BlockType mapping sözleşmesi: study/break', () {
      final json = validSchedule().toJson();
      final blocks = json['blocks'] as List;
      expect((blocks[0] as Map)['type'], 'study');
      expect((blocks[1] as Map)['type'], 'break');
    });

    test('version != 1 reddediliyor', () {
      final json = validSchedule().toJson()..['version'] = 2;
      expect(
        () => SessionSchedule.fromJson(json),
        codecReason(ScheduleCodecReason.unsupportedVersion),
      );
    });

    test('bilinmeyen blok tipi reddediliyor (breakTime dahil)', () {
      final json = validSchedule().toJson();
      ((json['blocks'] as List)[1] as Map)['type'] = 'breakTime';
      expect(
        () => SessionSchedule.fromJson(json),
        codecReason(ScheduleCodecReason.unknownBlockType),
      );
    });

    test('eksik alan reddediliyor', () {
      final json = validSchedule().toJson()..remove('plannedEndAt');
      expect(
        () => SessionSchedule.fromJson(json),
        codecReason(ScheduleCodecReason.missingField),
      );
    });

    test('totalStudyS uyuşmazlığı reddediliyor', () {
      final json = validSchedule().toJson()..['totalStudyS'] = 9999;
      expect(
        () => SessionSchedule.fromJson(json),
        codecReason(ScheduleCodecReason.totalStudyMismatch),
      );
    });

    test('plannedEndAt uyuşmazlığı reddediliyor', () {
      final json = validSchedule().toJson()..['plannedEndAt'] = t0 + 1;
      expect(
        () => SessionSchedule.fromJson(json),
        codecReason(ScheduleCodecReason.plannedEndMismatch),
      );
    });
  });
}
