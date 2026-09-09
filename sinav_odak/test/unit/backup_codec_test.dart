import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/backup_codec.dart';

/// v1.3 — YEDEK DOSYASI BİÇİMİ. Saf Dart, veritabanı yok.
///
/// Buradaki testlerin koruduğu asıl şey **sürüm kuralı**: eski bir
/// uygulamanın yeni bir yedeği yüklemesi sessiz veri kaybıdır — tanımadığı
/// kolonları düşürür ve kullanıcı kaybettiğini fark etmez.
void main() {
  Map<String, List<Map<String, Object?>>> sample() => {
        'subjects': [
          {'id': 'sub_1', 'name': 'Matematik', 'is_archived': 0},
        ],
        'study_sessions': [
          {'id': 's1', 'date_key': '2026-09-08', 'net': 12.5},
          {'id': 's2', 'date_key': '2026-09-09', 'net': 0.0},
        ],
      };

  String encoded({int schema = 7}) => BackupCodec.encode(
        schemaVersion: schema,
        appVersion: '1.3.0+6',
        createdAt: 1757000000000,
        tables: sample(),
      );

  group('kodlama', () {
    test('imza, sürümler ve sayımlar zarfta', () {
      final map = jsonDecode(encoded()) as Map<String, Object?>;

      expect(map['format'], 'sinav_odak_backup');
      expect(map['formatVersion'], BackupCodec.formatVersion);
      expect(map['schemaVersion'], 7);
      expect(map['appVersion'], '1.3.0+6');
      expect((map['counts']! as Map)['study_sessions'], 2);
    });

    test('BOŞ tablolar da yazılıyor', () {
      // Yoksa geri yükleme "bu tablo hiç yoktu" ile "boştu" arasındaki
      // farkı ayırt edemezdi.
      final map = jsonDecode(encoded()) as Map<String, Object?>;
      final tables = map['tables']! as Map<String, Object?>;

      for (final t in BackupCodec.tableOrder) {
        expect(tables.containsKey(t), isTrue, reason: '$t zarfta yok');
      }
      expect(tables['achievements'], isEmpty);
    });

    test('gidiş-dönüş: veri aynen geliyor', () {
      final env = BackupCodec.decode(encoded(), currentSchemaVersion: 7);

      expect(env.schemaVersion, 7);
      expect(env.appVersion, '1.3.0+6');
      expect(env.rowCount('study_sessions'), 2);
      expect(env.tables['subjects']!.single['name'], 'Matematik');
      expect(
        env.tables['study_sessions']![0]['net'],
        12.5,
        reason: 'ondalık değer int e yuvarlanmamalı',
      );
    });

    test('dosya adı tarihi taşıyor', () {
      expect(
        BackupCodec.fileName(DateTime(2026, 9, 8)),
        'sinav-odak-yedek-2026-09-08.json',
      );
      expect(
        BackupCodec.fileName(DateTime(2026, 12, 31)),
        'sinav-odak-yedek-2026-12-31.json',
      );
    });
  });

  group('SÜRÜM KURALI', () {
    test('AYNI şema sürümü kabul', () {
      expect(
        BackupCodec.decode(encoded(schema: 7), currentSchemaVersion: 7),
        isA<BackupEnvelope>(),
      );
    });

    test('ESKİ yedek yeni uygulamaya yüklenebiliyor', () {
      // Eksik kolonlar şemadaki varsayılanını alacak.
      final env =
          BackupCodec.decode(encoded(schema: 5), currentSchemaVersion: 7);
      expect(env.schemaVersion, 5);
    });

    test('YENİ yedek eski uygulamada REDDEDİLİYOR', () {
      // Kırmızı çizgi: kabul edilseydi tanınmayan kolonlar sessizce
      // düşer ve kullanıcı veri kaybettiğini fark etmezdi.
      expect(
        () => BackupCodec.decode(encoded(schema: 9), currentSchemaVersion: 7),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.reason,
            'reason',
            BackupFailureReason.tooNew,
          ),
        ),
      );
    });

    test('yeni BİÇİM sürümü de reddediliyor', () {
      final raw = jsonDecode(encoded()) as Map<String, Object?>;
      raw['formatVersion'] = BackupCodec.formatVersion + 1;

      expect(
        () => BackupCodec.decode(jsonEncode(raw), currentSchemaVersion: 7),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.reason,
            'reason',
            BackupFailureReason.tooNew,
          ),
        ),
      );
    });
  });

  group('bozuk girdi', () {
    void expectReason(String src, BackupFailureReason reason) {
      expect(
        () => BackupCodec.decode(src, currentSchemaVersion: 7),
        throwsA(
          isA<BackupFormatException>()
              .having((e) => e.reason, 'reason', reason),
        ),
      );
    }

    test('JSON değil', () {
      expectReason('bu bir yedek değil', BackupFailureReason.notJson);
      expectReason('', BackupFailureReason.notJson);
    });

    test('JSON ama liste', () {
      expectReason('[1,2,3]', BackupFailureReason.notJson);
    });

    test('BAŞKA uygulamanın JSON u', () {
      // Kullanıcı yanlış dosyayı seçebilir; imza tutmuyorsa dokunma.
      expectReason(
        '{"format":"baska_uygulama","tables":{}}',
        BackupFailureReason.notOurBackup,
      );
    });

    test('imza doğru ama sürüm alanları yok', () {
      expectReason(
        '{"format":"sinav_odak_backup","tables":{}}',
        BackupFailureReason.malformed,
      );
    });

    test('tablo listesi yerine sayı', () {
      final raw = jsonDecode(encoded()) as Map<String, Object?>;
      (raw['tables']! as Map)['subjects'] = 42;
      expectReason(jsonEncode(raw), BackupFailureReason.malformed);
    });
  });

  test('TANIMSIZ tablo sessizce atlanıyor', () {
    // İleride bir tablo kaldırılırsa eski yedek yine yüklenebilmeli.
    final raw = jsonDecode(encoded()) as Map<String, Object?>;
    (raw['tables']! as Map)['eski_tablo'] = [
      {'id': 'x'},
    ];

    final env = BackupCodec.decode(jsonEncode(raw), currentSchemaVersion: 7);
    expect(env.tables.containsKey('eski_tablo'), isFalse);
    expect(env.rowCount('study_sessions'), 2, reason: 'gerisi bozulmadı');
  });

  test('daily_stats yedeğe GİRMİYOR (türetilmiş)', () {
    expect(BackupCodec.tableOrder, isNot(contains('daily_stats')));
    expect(BackupCodec.excludedTables, contains('daily_stats'));
    expect(BackupCodec.excludedTables, contains('app_state'));
  });
}
