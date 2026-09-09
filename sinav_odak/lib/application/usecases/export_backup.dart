import '../../data/local/database.dart';
import '../../domain/ports/share_gateway.dart';
import '../../domain/services/backup_codec.dart';

/// Yedek özeti — onay/başarı ekranı bunu gösteriyor.
typedef BackupSummary = ({int sessions, int books, int wrongs});

/// TÜM kullanıcı verisini tek bir JSON dosyasına yazıp paylaşır (v1.3).
///
/// ## Neden gerekli
///
/// Uygulamanın verisi yalnızca cihazda. Bu bir gizlilik güvencesi ama
/// aynı zamanda bir risk: **telefon değişince altı aylık geçmiş ölüyor.**
/// Serisi, netleri, yanlış defteri, rozetleri. Yedek olmadan uygulama
/// kimsenin iki yıllık çalışma arkadaşı olamaz.
///
/// ## Sunucu YOK
///
/// Dosya paylaşım sayfasına veriliyor; kullanıcı kendi Drive'ına,
/// e-postasına ya da kendine WhatsApp'a atıyor. Yedeği taşıyan
/// kullanıcının kendisi — "veri yalnızca cihazda" sözü bozulmuyor.
///
/// ## `running` oturum yedeğe GİRMEZ
///
/// Yedek alındığı anda süren bir oturum varsa o satır dışarıda
/// bırakılıyor. Yeni cihaza taşınsaydı, açılışta kurtarma akışı hiç
/// yaşanmamış bir oturumu "yarıda kalmış" diye sorardı.
class ExportBackupUseCase {
  const ExportBackupUseCase(this._db, this._share);

  final AppDatabase _db;
  final ShareGateway _share;

  /// Yedeği üretir ve paylaşır. Paylaşım başarısızsa `null` döner
  /// (kullanıcı iptal etti, izin yok, disk dolu — hiçbiri çökme sebebi
  /// değil).
  Future<BackupSummary?> call({
    required int nowMs,
    required String appVersion,
  }) async {
    final tables = await readAll();

    final json = BackupCodec.encode(
      schemaVersion: _db.schemaVersion,
      appVersion: appVersion,
      createdAt: nowMs,
      tables: tables,
    );

    final ok = await _share.shareText(
      content: json,
      fileName: BackupCodec.fileName(
        DateTime.fromMillisecondsSinceEpoch(nowMs),
      ),
    );
    if (!ok) return null;

    return (
      sessions: tables['study_sessions']?.length ?? 0,
      books: tables['book_sessions']?.length ?? 0,
      wrongs: tables['wrong_items']?.length ?? 0,
    );
  }

  /// Tabloları ham satır haritası olarak okur.
  ///
  /// **Kolon adları elle sayılmıyor**, `SELECT *` ile geliyor: şemaya
  /// yeni bir kolon eklendiğinde yedek onu kendiliğinden taşıyor.
  /// Kolonları elle listeleseydim, eklenen her kolonu buraya da yazmayı
  /// unutmak sessiz veri kaybı olurdu.
  Future<Map<String, List<Map<String, Object?>>>> readAll() async {
    final out = <String, List<Map<String, Object?>>>{};

    // Dışarıda bırakılan (`running`) oturumların kimlikleri. ÇOCUK
    // satırları da düşmek zorunda: blokları ya da konuları yedekte
    // kalsaydı, geri yüklerken ebeveyni olmayan satırlar foreign key
    // hatası verir ve **geri yükleme tamamen çökerdi**. (Bu, yuvarlak
    // sefer testi yazılmasaydı ancak kullanıcının cihazında görülecekti.)
    final orphaned = <String>{};

    for (final table in BackupCodec.tableOrder) {
      final rows = await _db.customSelect('SELECT * FROM $table').get();
      final kept = <Map<String, Object?>>[];

      for (final r in rows) {
        final row = Map<String, Object?>.from(r.data);

        if (_isSessionTable(table) && row['status'] == 'running') {
          orphaned.add(row['id']! as String);
          continue;
        }
        if (_hasSessionRef(table) && orphaned.contains(row['session_id'])) {
          if (table == 'wrong_items') {
            // Yanlış kaydının kendisi kullanıcı verisi — oturum
            // referansı düşürülüp KAYIT korunuyor. Şemada da bağ
            // `setNull`; elle eklenmiş bir kayda dönüşüyor.
            row['session_id'] = null;
            row['source'] = 'manual';
          } else {
            continue;
          }
        }
        kept.add(row);
      }
      out[table] = kept;
    }
    return out;
  }

  static bool _isSessionTable(String t) =>
      t == 'study_sessions' || t == 'book_sessions';

  /// `session_id` üzerinden çalışma oturumuna bağlı tablolar.
  static bool _hasSessionRef(String t) =>
      t == 'session_topics' || t == 'session_blocks' || t == 'wrong_items';
}
