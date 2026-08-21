/// Dışa aktarılacak tek bir oturum satırı.
///
/// Drift'in `StudySession`'ı DEĞİL: domain katmanı `drift` import edemez
/// (G4). Veri katmanı kendi satırını buna çevirir; böylece CSV üretimi
/// veritabanından tamamen bağımsız ve saf kalır.
class SessionExportRow {
  const SessionExportRow({
    required this.dateKey,
    required this.startedAt,
    required this.subjectName,
    required this.activityTypeName,
    required this.plannedDurationS,
    required this.actualDurationS,
    required this.totalBreakS,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.emptyCount,
    required this.net,
    required this.status,
    this.topicName,
    this.focusScore,
    this.mood,
    this.note,
  });

  final String dateKey;

  /// Oturumun başladığı yerel saat — 'HH:mm' olarak yazılır.
  final DateTime startedAt;
  final String subjectName;
  final String? topicName;
  final String activityTypeName;
  final int plannedDurationS;
  final int actualDurationS;
  final int totalBreakS;
  final int questionCount;
  final int correctCount;
  final int wrongCount;
  final int emptyCount;
  final double net;
  final int? focusScore;
  final int? mood;
  final String? note;
  final String status;
}

/// Oturumları CSV metnine çevirir.
///
/// **Saf ve durumsuz.** Dosya yazma ve paylaşma servis katmanının işi;
/// burada yalnızca metin üretiliyor, böylece kaçış kuralları (tırnak,
/// noktalı virgül, satır sonu) dosya sistemi olmadan test edilebiliyor.
///
/// **Ayraç `;`** — Excel'in TR yerelinde `,` ayraçlı dosyayı tek sütuna
/// yapıştırması ve ondalık ayracın da `,` olması yüzünden. Ondalıklar da
/// TR biçiminde (`12,5`) yazılıyor; ikisi birlikte "Excel'de açınca
/// bozuluyor" şikâyetini kökten kaldırıyor.
abstract final class CsvBuilder {
  static const String delimiter = ';';

  /// Excel'in UTF-8'i tanıması için BOM. Olmadan Türkçe karakterler
  /// (ğ, ş, İ) bozuk görünüyor.
  static const String bom = '﻿';

  /// Türkçe sütun başlıkları — varsayılan.
  ///
  /// v1.2/E: başlıklar artık [build]'e parametre olarak da verilebiliyor;
  /// arayüz İngilizceyken dışa aktarılan dosya da İngilizce başlık taşısın.
  ///
  /// **Ayraç ve ondalık biçimi dile göre DEĞİŞMİYOR** (`;` ve `12,5`).
  /// Bu bilinçli: dosyayı açan Excel kurulumu büyük ihtimalle Türkçe ve
  /// ayracı dile göre değiştirmek, aynı cihazda üretilmiş iki dosyanın
  /// farklı biçimde olması demek olurdu. Başlık kullanıcının OKUDUĞU şey;
  /// ayraç Excel'in okuduğu şey.
  static const List<String> headers = [
    'Tarih',
    'Başlangıç',
    'Ders',
    'Konu',
    'Tür',
    'Planlanan (dk)',
    'Çalışılan (dk)',
    'Mola (dk)',
    'Soru',
    'Doğru',
    'Yanlış',
    'Boş',
    'Net',
    'Odak Puanı',
    'Motivasyon',
    'Durum',
    'Not',
  ];

  /// Bir hücreyi CSV kurallarına göre kaçırır (RFC 4180).
  ///
  /// Ayraç, tırnak veya satır sonu içeren hücre tırnak içine alınır;
  /// içerideki tırnak ikilenir. Kullanıcının serbest metin "not" alanı
  /// bunların hepsini içerebiliyor.
  static String escape(String? value) {
    final v = value ?? '';
    final needsQuotes = v.contains(delimiter) ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    if (!needsQuotes) return v;
    return '"${v.replaceAll('"', '""')}"';
  }

  /// Saniyeyi dakikaya çevirir (tam sayıya yuvarlar).
  static int _minutes(int seconds) => (seconds / 60).round();

  /// Ondalık sayıyı TR biçiminde yazar: `12.5` → `12,5`.
  static String _decimal(double value) =>
      value.toStringAsFixed(2).replaceAll('.', ',');

  static String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String buildRow(SessionExportRow r) => [
        r.dateKey,
        _time(r.startedAt),
        r.subjectName,
        r.topicName ?? '',
        r.activityTypeName,
        '${_minutes(r.plannedDurationS)}',
        '${_minutes(r.actualDurationS)}',
        '${_minutes(r.totalBreakS)}',
        '${r.questionCount}',
        '${r.correctCount}',
        '${r.wrongCount}',
        '${r.emptyCount}',
        _decimal(r.net),
        r.focusScore?.toString() ?? '',
        r.mood?.toString() ?? '',
        r.status,
        r.note ?? '',
      ].map(escape).join(delimiter);

  /// Tam CSV metni. Kayıt yoksa **yalnızca başlık satırı** döner —
  /// boş dosya paylaşmak kullanıcıya "dışa aktarma bozuk" hissi veriyordu.
  static String build(
    List<SessionExportRow> rows, {
    List<String> headers = CsvBuilder.headers,
  }) {
    final buffer = StringBuffer(bom)
      ..writeln(headers.map(escape).join(delimiter));
    for (final r in rows) {
      buffer.writeln(buildRow(r));
    }
    return buffer.toString();
  }

  /// Paylaşım dosyasının adı: `sinav-odak-2025-08-01_2025-08-31.csv`.
  static String fileNameFor(String fromKey, String toKey) =>
      'sinav-odak-${fromKey}_$toKey.csv';
}
