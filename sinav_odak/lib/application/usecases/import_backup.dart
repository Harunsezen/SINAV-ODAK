import '../../data/local/database.dart';
import '../../domain/services/backup_codec.dart';

/// Geri yükleme sonucu.
typedef RestoreResult = ({
  int rows,
  int sessions,
  int books,
  String appVersion
});

/// Yedek dosyasını okuyup TÜM veriyi geri yükler (v1.3).
///
/// ## DEĞİŞTİRME, birleştirme DEĞİL
///
/// Geri yükleme mevcut veriyi **siliyor** ve yedektekini yazıyor.
/// Birleştirme denenmedi: aynı kimliğe sahip iki farklı oturum, aynı
/// güne ait iki farklı özet, yeniden adlandırılmış aynı konu — hepsi
/// "hangisi kazanacak" sorusunu doğuruyor ve kullanıcının cevabını
/// bilmediğimiz bir soru. Değiştirme öngörülebilir; arayüz de bunu
/// **açıkça** söyleyip çift onay alıyor.
///
/// ## Tek transaction
///
/// Silme ve yazma birlikte. Arada uygulama ölürse kullanıcı ne eski
/// verisini ne yenisini bulurdu — yarım geri yükleme, veri kaybının en
/// kötü türü.
///
/// ## `daily_stats` yedekten GELMEZ, yeniden hesaplanır
///
/// Türetilmiş veri. Yedeğe koysaydım, oturumlarla özet arasında
/// ayrışma ihtimali doğardı; hesaplamak hem küçük hem kesin.
class ImportBackupUseCase {
  ImportBackupUseCase(this._db);

  final AppDatabase _db;

  /// [source] yedek dosyasının metni.
  ///
  /// Dosya bozuk/yabancı/çok yeniyse [BackupFormatException] fırlatır ve
  /// **veritabanına hiç dokunulmaz** — çözümleme yazmadan önce bitiyor.
  Future<RestoreResult> call(String source) async {
    final env = BackupCodec.decode(
      source,
      currentSchemaVersion: _db.schemaVersion,
    );

    await _db.transaction(() async {
      // --- Sil: çocuk tablolar ÖNCE (foreign key zinciri) ---
      for (final table in BackupCodec.tableOrder.reversed) {
        await _db.customStatement('DELETE FROM $table');
      }
      // Türetilmiş özet de gidiyor; aşağıda yeniden hesaplanacak.
      await _db.customStatement('DELETE FROM daily_stats');

      // --- Yaz: ebeveyn tablolar ÖNCE ---
      for (final table in BackupCodec.tableOrder) {
        for (final row in env.tables[table] ?? const []) {
          await _insert(table, row);
        }
      }
    });

    // Özetler transaction DIŞINDA: `recomputeDay` kendi içinde okuma
    // yapıyor ve yazma transaction'ı kapanmadan tutarlı sonuç veremez.
    await _recomputeAllDays();

    return (
      rows: env.totalRows,
      sessions: env.rowCount('study_sessions'),
      books: env.rowCount('book_sessions'),
      appVersion: env.appVersion,
    );
  }

  /// Bir satırı adıyla yazar.
  ///
  /// Kolonlar satırın kendi anahtarlarından geliyor: yedek eski bir
  /// sürümden gelip yeni bir kolonu taşımıyorsa o kolon şemadaki
  /// **varsayılanını** alıyor. Kolon listesi elle yazılsaydı eski yedek
  /// hiç yüklenemezdi.
  ///
  /// Şemada artık bulunmayan bir kolon taşıyan yedek de kabul ediliyor:
  /// tanınmayan anahtarlar atılıyor.
  Future<void> _insert(String table, Map<String, Object?> row) async {
    final known = await _columnsOf(table);
    final cols = row.keys.where(known.contains).toList();
    if (cols.isEmpty) return;

    final placeholders = List.filled(cols.length, '?').join(', ');
    await _db.customStatement(
      'INSERT INTO $table (${cols.join(', ')}) VALUES ($placeholders)',
      [for (final c in cols) row[c]],
    );
  }

  final Map<String, Set<String>> _columnCache = {};

  Future<Set<String>> _columnsOf(String table) async {
    final cached = _columnCache[table];
    if (cached != null) return cached;

    final rows = await _db.customSelect("PRAGMA table_info('$table')").get();
    final names = {for (final r in rows) r.read<String>('name')};
    _columnCache[table] = names;
    return names;
  }

  /// Geri yüklenen her gün için özeti yeniden kurar.
  ///
  /// `SessionRepository.recomputeAll` YETMİYOR: o yalnızca
  /// `study_sessions` günlerini geziyor ve **sadece kitap okunan bir
  /// gün** özetsiz kalırdı — takvimde ve grafikte boş görünürdü.
  Future<void> _recomputeAllDays() async {
    final rows = await _db
        .customSelect(
          'SELECT date_key FROM study_sessions '
          'UNION SELECT date_key FROM book_sessions',
        )
        .get();

    for (final r in rows) {
      await _db.statsDao.recomputeDay(r.read<String>('date_key'));
    }
    // Seri/hedef/rozet durumu ayar satırından geri geldi; yeniden
    // hesaplamaya gerek yok. `recomputeStreak` çağırmak, yedeğin
    // taşıdığı `lastStudyDate`i bugüne çekip seriyi BOZARDI.
  }
}
