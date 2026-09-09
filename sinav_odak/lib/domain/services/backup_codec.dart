// Bu dosya SAF DART'tır: Flutter, Drift, Riverpod import etmez.

import 'dart:convert';

/// Yedek dosyasının çözümlenmiş hâli.
class BackupEnvelope {
  const BackupEnvelope({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.tables,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final int createdAt;

  /// Tablo adı → satırlar. Satır: kolon adı → değer.
  final Map<String, List<Map<String, Object?>>> tables;

  int rowCount(String table) => tables[table]?.length ?? 0;

  int get totalRows => tables.values.fold(0, (sum, rows) => sum + rows.length);
}

/// Yedek dosyası okunamadığında fırlar. Mesaj **kullanıcıya
/// gösterilmez**; arayüz kendi ARB metnini seçmek için [reason]'a bakar.
class BackupFormatException implements Exception {
  const BackupFormatException(this.reason, [this.detail]);

  final BackupFailureReason reason;
  final String? detail;

  @override
  String toString() => 'BackupFormatException($reason, $detail)';
}

/// Yedek reddedilme sebepleri — arayüz her biri için ayrı metin gösteriyor.
enum BackupFailureReason {
  /// Dosya JSON değil ya da bozuk.
  notJson,

  /// JSON ama bu uygulamanın yedeği değil (imza tutmuyor).
  notOurBackup,

  /// Yedek, uygulamadan **daha yeni** bir sürümden geliyor.
  tooNew,

  /// Beklenen alanlar eksik.
  malformed,
}

/// Yedek dosyasının kodlayıcı/çözücüsü (v1.3).
///
/// ## Neden JSON, neden tek dosya
///
/// Kullanıcı dosyayı kendi Drive'ına, e-postasına ya da WhatsApp'ta
/// kendine gönderiyor. **Sunucu yok** — uygulamanın "veri yalnızca
/// cihazda" sözü bozulmuyor; yedeği taşıyan kullanıcının kendisi.
/// Gözle okunabilir olması ayrıca bir güvence: dosyayı açan kullanıcı
/// içinde ne olduğunu görebiliyor.
///
/// ## Sürüm kuralları
///
/// İki ayrı sürüm var ve ikisi de gerekli:
///
/// - [formatVersion] — **bu dosya biçiminin** sürümü. Zarf yapısı
///   değişirse artar.
/// - [schemaVersion] — yedeği üreten uygulamanın **veritabanı** sürümü.
///
/// Kural: yedek uygulamadan **yeniyse REDDEDİLİR**. Eski bir uygulama
/// yeni bir yedeği okumaya çalışırsa tanımadığı kolonları sessizce
/// düşürür ve kullanıcı veri kaybettiğini fark etmez. Eski yedek yeni
/// uygulamaya yüklenebiliyor: eksik kolonlar şemadaki varsayılanını
/// alıyor.
abstract final class BackupCodec {
  /// Dosya imzası. Başka bir uygulamanın JSON'u yanlışlıkla yüklenmesin.
  static const signature = 'sinav_odak_backup';

  /// Zarf biçiminin sürümü. Yapı değişirse ARTIR.
  static const formatVersion = 1;

  /// Yedeğe giren tablolar ve **yazılma sırası**.
  ///
  /// Sıra foreign key zincirini izliyor: ebeveyn önce. Ters sırada
  /// yazmak `SQLITE_CONSTRAINT_FOREIGNKEY` demek.
  static const tableOrder = <String>[
    'user_settings',
    'activity_types',
    'subjects',
    'topics',
    'study_sessions',
    'session_topics',
    'session_blocks',
    'book_sessions',
    'goals',
    'wrong_items',
    'achievements',
  ];

  /// Yedeğe **girmeyen** tablolar ve gerekçeleri.
  ///
  /// | tablo | neden |
  /// | --- | --- |
  /// | `daily_stats` | türetilmiş; geri yüklemede yeniden hesaplanıyor |
  /// | `ad_events` | yerel reklam analitiği, 30 günde temizleniyor |
  /// | `app_state` | kurtarma bayrakları cihaza ait; eski bir "oturum |
  /// | | açık" bayrağını yeni cihaza taşımak hayalet oturum üretirdi |
  static const excludedTables = <String>[
    'daily_stats',
    'ad_events',
    'app_state',
  ];

  /// Zarfı JSON metnine çevirir.
  ///
  /// [pretty] varsayılan `true`: dosyayı açan kullanıcı ne yedeklediğini
  /// okuyabilsin. Boyut farkı sıkıştırılmamış birkaç yüz KB mertebesinde
  /// ve dosya zaten tek seferlik.
  static String encode({
    required int schemaVersion,
    required String appVersion,
    required int createdAt,
    required Map<String, List<Map<String, Object?>>> tables,
    bool pretty = true,
  }) {
    final map = <String, Object?>{
      'format': signature,
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt,
      // Sayımlar zarfın kendisinde: kullanıcı dosyayı açtığında ne
      // taşıdığını görebiliyor, arayüz de onay ekranında satır satır
      // okumadan özet gösterebiliyor.
      'counts': {
        for (final t in tableOrder) t: tables[t]?.length ?? 0,
      },
      'tables': {
        for (final t in tableOrder) t: tables[t] ?? const [],
      },
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  /// JSON metnini çözer ve **doğrular**.
  ///
  /// [currentSchemaVersion] uygulamanın şu anki şema sürümü; yedek daha
  /// yeniyse [BackupFailureReason.tooNew] ile reddediliyor.
  static BackupEnvelope decode(
    String source, {
    required int currentSchemaVersion,
  }) {
    final Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException catch (e) {
      throw BackupFormatException(BackupFailureReason.notJson, e.message);
    }

    if (raw is! Map<String, Object?>) {
      throw const BackupFormatException(BackupFailureReason.notJson);
    }
    if (raw['format'] != signature) {
      throw BackupFormatException(
        BackupFailureReason.notOurBackup,
        'format=${raw['format']}',
      );
    }

    final fv = _asInt(raw['formatVersion']);
    final sv = _asInt(raw['schemaVersion']);
    if (fv == null || sv == null) {
      throw const BackupFormatException(BackupFailureReason.malformed);
    }
    if (fv > formatVersion || sv > currentSchemaVersion) {
      throw BackupFormatException(
        BackupFailureReason.tooNew,
        'yedek f$fv/s$sv, uygulama f$formatVersion/s$currentSchemaVersion',
      );
    }

    final tablesRaw = raw['tables'];
    if (tablesRaw is! Map<String, Object?>) {
      throw const BackupFormatException(BackupFailureReason.malformed);
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in tablesRaw.entries) {
      // Tanımadığımız tablo adı SESSİZCE atlanıyor: ileride bir tablo
      // kaldırılırsa eski yedek yine yüklenebilsin.
      if (!tableOrder.contains(entry.key)) continue;

      final rows = entry.value;
      if (rows is! List) {
        throw BackupFormatException(
          BackupFailureReason.malformed,
          '${entry.key} liste değil',
        );
      }
      tables[entry.key] = [
        for (final r in rows)
          if (r is Map<String, Object?>)
            r
          else
            throw BackupFormatException(
              BackupFailureReason.malformed,
              '${entry.key} içinde satır nesne değil',
            ),
      ];
    }

    return BackupEnvelope(
      formatVersion: fv,
      schemaVersion: sv,
      appVersion: raw['appVersion'] as String? ?? '?',
      createdAt: _asInt(raw['createdAt']) ?? 0,
      tables: tables,
    );
  }

  /// Yedek dosyasının adı: `sinav-odak-yedek-2026-09-09.json`.
  ///
  /// Tarih adın içinde: kullanıcının indirilenler klasöründe yan yana
  /// duran üç yedekten hangisinin yeni olduğu dosya adından okunuyor.
  static String fileName(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'sinav-odak-yedek-'
        '${at.year}-${two(at.month)}-${two(at.day)}.json';
  }

  static int? _asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
}
