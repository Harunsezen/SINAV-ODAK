import '../../core/utils/date_key.dart';
import '../../data/local/database.dart';
import '../../domain/ports/share_gateway.dart';
import '../../domain/services/csv_builder.dart';

/// CSV dışa aktarmanın sonucu.
///
/// Ekranın hangi mesajı göstereceğini belirler; `bool` yerine enum, "boş"
/// ile "başarısız" durumlarının karışmasını engelliyor.
enum ExportOutcome { shared, empty, failed }

/// Seçili aralıktaki oturumları CSV olarak paylaşır.
///
/// Ekran artık ne DAO'ya ne de dosya sistemine dokunuyor: aralığı verir,
/// sonucu alır.
class ExportSessionsUseCase {
  ExportSessionsUseCase(this._db, this._share);

  final AppDatabase _db;
  final ShareGateway _share;

  /// [headers] verilmezse Türkçe başlıklar kullanılır. Arayüz dili
  /// İngilizceyken ekran ARB'den okuduğu başlıkları geçiriyor: kullanıcı
  /// İngilizce bir uygulamadan Türkçe başlıklı bir dosya almasın.
  Future<ExportOutcome> call({
    required DateTime from,
    required DateTime to,
    String? subject,
    List<String>? headers,
  }) async {
    final rows = await _db.statsDao.exportRows(from, to);
    // Boş dosya paylaşmak yerine kullanıcıya durumu söylüyoruz: yalnızca
    // başlık satırı içeren bir CSV "dışa aktarma bozuk" hissi veriyor.
    if (rows.isEmpty) return ExportOutcome.empty;

    final ok = await _share.shareText(
      content: CsvBuilder.build(rows, headers: headers ?? CsvBuilder.headers),
      fileName: CsvBuilder.fileNameFor(dateKeyOf(from), dateKeyOf(to)),
      subject: subject,
    );
    return ok ? ExportOutcome.shared : ExportOutcome.failed;
  }
}
