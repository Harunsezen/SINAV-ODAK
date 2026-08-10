import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/domain/services/csv_builder.dart';

/// FAZ 7A — CSV dışa aktarma (saf domain).
///
/// Dosya sistemi ve paylaşım katmanı burada YOK: kaçış kuralları ve biçim
/// kararları platformdan bağımsız doğrulanıyor.
void main() {
  SessionExportRow row({
    String dateKey = '2025-08-06',
    DateTime? startedAt,
    String subjectName = 'Matematik',
    String? topicName = 'Türev',
    String activityTypeName = 'Soru Çözümü',
    int plannedDurationS = 3000,
    int actualDurationS = 2880,
    int totalBreakS = 300,
    int questionCount = 40,
    int correctCount = 30,
    int wrongCount = 8,
    int emptyCount = 2,
    double net = 28.0,
    int? focusScore = 82,
    int? mood = 4,
    String? note,
    String status = 'completed',
  }) =>
      SessionExportRow(
        dateKey: dateKey,
        startedAt: startedAt ?? DateTime(2025, 8, 6, 9, 5),
        subjectName: subjectName,
        topicName: topicName,
        activityTypeName: activityTypeName,
        plannedDurationS: plannedDurationS,
        actualDurationS: actualDurationS,
        totalBreakS: totalBreakS,
        questionCount: questionCount,
        correctCount: correctCount,
        wrongCount: wrongCount,
        emptyCount: emptyCount,
        net: net,
        focusScore: focusScore,
        mood: mood,
        note: note,
        status: status,
      );

  group('kaçış (escape)', () {
    test('sade metin tırnaklanmıyor', () {
      expect(CsvBuilder.escape('Matematik'), 'Matematik');
    });

    test('ayraç içeren hücre tırnaklanıyor', () {
      expect(CsvBuilder.escape('a;b'), '"a;b"');
    });

    test('tırnak İKİLENİYOR', () {
      expect(CsvBuilder.escape('12" ekran'), '"12"" ekran"');
    });

    test('satır sonu içeren not tırnaklanıyor', () {
      expect(CsvBuilder.escape('ilk\nikinci'), '"ilk\nikinci"');
    });

    test('null boş hücre', () {
      expect(CsvBuilder.escape(null), '');
    });
  });

  group('satır üretimi', () {
    test('alan sırası başlıkla AYNI uzunlukta', () {
      final cells = CsvBuilder.buildRow(row()).split(CsvBuilder.delimiter);
      expect(
        cells.length,
        CsvBuilder.headers.length,
        reason: 'sütun sayısı başlıkla uyuşmazsa dosya Excel\'de kayar',
      );
    });

    test('süreler DAKİKAYA çevriliyor', () {
      final cells = CsvBuilder.buildRow(
        row(plannedDurationS: 3000, actualDurationS: 2880, totalBreakS: 300),
      ).split(CsvBuilder.delimiter);
      expect(cells[5], '50'); // planlanan
      expect(cells[6], '48'); // çalışılan
      expect(cells[7], '5'); // mola
    });

    test('başlangıç saati HH:mm', () {
      final cells = CsvBuilder.buildRow(
        row(startedAt: DateTime(2025, 8, 6, 9, 5)),
      ).split(CsvBuilder.delimiter);
      expect(cells[1], '09:05');
    });

    test('net TR ondalık ayracıyla yazılıyor', () {
      final cells =
          CsvBuilder.buildRow(row(net: 28.5)).split(CsvBuilder.delimiter);
      expect(
        cells[12],
        '28,50',
        reason: 'Excel TR yerelinde nokta ondalık ayracı değil',
      );
    });

    test('konusuz oturumda konu hücresi BOŞ', () {
      final cells =
          CsvBuilder.buildRow(row(topicName: null)).split(CsvBuilder.delimiter);
      expect(cells[3], '');
    });

    test('boş odak/motivasyon hücreleri boş kalıyor', () {
      final cells = CsvBuilder.buildRow(
        row(focusScore: null, mood: null),
      ).split(CsvBuilder.delimiter);
      expect(cells[13], '');
      expect(cells[14], '');
    });

    test('ayraç içeren not satırı BOZMUYOR', () {
      // Kullanıcı notu ayraç içeriyor: tırnaklanmazsa sütunlar kayar.
      final line = CsvBuilder.buildRow(row(note: 'zor; ama bitti'));
      expect(line, contains('"zor; ama bitti"'));
      expect(
        line.split(CsvBuilder.delimiter).length,
        CsvBuilder.headers.length + 1,
        reason: 'tırnak içindeki ayraç naif split ile ikiye bölünür — '
            'bu test tırnağın VAR olduğunu gösteriyor',
      );
    });
  });

  group('tam dosya', () {
    test('BOM ile başlıyor', () {
      expect(
        CsvBuilder.build([]).startsWith(CsvBuilder.bom),
        isTrue,
        reason: 'BOM olmadan Excel Türkçe karakterleri bozuyor',
      );
    });

    test('kayıt yoksa YALNIZCA başlık satırı', () {
      final lines = CsvBuilder.build([]).trim().split('\n');
      expect(lines.length, 1);
      expect(lines.first, contains('Tarih'));
    });

    test('kayıt sayısı kadar satır + başlık', () {
      final csv = CsvBuilder.build([row(), row(), row()]);
      expect(csv.trim().split('\n').length, 4);
    });

    test('başlık ayracı veri ayracıyla aynı', () {
      final lines = CsvBuilder.build([row()]).trim().split('\n');
      expect(
        lines[0].split(CsvBuilder.delimiter).length,
        lines[1].split(CsvBuilder.delimiter).length,
      );
    });
  });

  group('dosya adı', () {
    test('aralığı içeriyor', () {
      expect(
        CsvBuilder.fileNameFor('2025-08-01', '2025-08-31'),
        'sinav-odak-2025-08-01_2025-08-31.csv',
      );
    });
  });
}
