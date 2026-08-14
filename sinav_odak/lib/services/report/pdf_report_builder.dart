import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/report_data.dart';

/// Rapor metinleri — çağıran katmandan (ARB'den) geliyor.
///
/// **Neden burada string tutuluyor:** `pdf` paketi Flutter widget ağacının
/// dışında çalışıyor, `BuildContext` yok. Metinleri parametre olarak almak,
/// bu dosyayı dile bağımsız ve testte doğrudan çağrılabilir tutuyor.
class ReportStrings {
  const ReportStrings({
    required this.appName,
    required this.parentTitle,
    required this.teacherTitle,
    required this.rangeLabel,
    required this.totalStudy,
    required this.sessions,
    required this.questions,
    required this.net,
    required this.focus,
    required this.successRate,
    required this.streak,
    required this.bestDay,
    required this.dailyAverage,
    required this.subjectBreakdown,
    required this.weakTopics,
    required this.wrongCount,
    required this.dailyDetail,
    required this.day,
    required this.duration,
    required this.privacyStamp,
    required this.achievements,
    required this.page,
  });

  final String appName;
  final String parentTitle;
  final String teacherTitle;
  final String rangeLabel;
  final String totalStudy;
  final String sessions;
  final String questions;
  final String net;
  final String focus;
  final String successRate;
  final String streak;
  final String bestDay;
  final String dailyAverage;
  final String subjectBreakdown;
  final String weakTopics;
  final String wrongCount;
  final String dailyDetail;
  final String day;
  final String duration;
  final String privacyStamp;
  final String achievements;
  final String page;
}

/// [ReportData]'yı PDF baytlarına çevirir. **Ağ yok, sunucu yok.**
///
/// ## Neden font gömülüyor
///
/// `pdf` paketinin yerleşik Helvetica'sı WinAnsi (CP1252) kodlaması
/// kullanıyor ve **ş (U+015F), ğ (U+011F), ı (U+0131), İ (U+0130)
/// harflerini DESTEKLEMİYOR** — bu ölçüldü, varsayılmadı:
///
/// ```
/// PROBE ş U+15f -> false     PROBE Ç U+c7 -> true
/// PROBE ğ U+11f -> false     PROBE ç U+e7 -> true
/// PROBE ı U+131 -> false
/// PROBE İ U+130 -> false
/// ```
///
/// Gömülmeseydi PDF **hata vermeden** üretilir ama "Şanzımanı" gibi
/// kelimeler bozuk çıkardı — sessiz bir hata, üstelik veliye giden
/// belgede. Roboto (Regular + Bold, ~340 KB) `assets/fonts/` altında.
class PdfReportBuilder {
  const PdfReportBuilder();

  static const _regularPath = 'assets/fonts/Roboto-Regular.ttf';
  static const _boldPath = 'assets/fonts/Roboto-Bold.ttf';

  /// Fontları yükler. Test bunları doğrudan verebilsin diye ayrı.
  Future<(pw.Font, pw.Font)> loadFonts() async {
    final regular = pw.Font.ttf(await rootBundle.load(_regularPath));
    final bold = pw.Font.ttf(await rootBundle.load(_boldPath));
    return (regular, bold);
  }

  Future<Uint8List> build(
    ReportData data,
    ReportStrings s, {
    pw.Font? regular,
    pw.Font? bold,
  }) async {
    final (r, b) =
        (regular != null && bold != null) ? (regular, bold) : await loadFonts();

    final theme = pw.ThemeData.withFont(base: r, bold: b);
    final doc = pw.Document(theme: theme);

    switch (data.audience) {
      case ReportAudience.parent:
        doc.addPage(_parentPage(data, s));
      case ReportAudience.teacher:
        for (final page in _teacherPages(data, s)) {
          doc.addPage(page);
        }
    }

    return doc.save();
  }

  // ------------------------------------------------------------------
  // VELİ RAPORU — tek sayfa, gurur tablosu
  // ------------------------------------------------------------------

  pw.Page _parentPage(ReportData d, ReportStrings s) => pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(s.parentTitle, s, d),
            pw.SizedBox(height: 24),

            // Gurur tablosu: büyük, az sayıda, jargonsuz.
            pw.Row(
              children: [
                _bigStat(_hm(d.totalStudyS), s.totalStudy),
                _bigStat('${d.sessionCount}', s.sessions),
                _bigStat('${d.questionCount}', s.questions),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              children: [
                _bigStat(d.net.toStringAsFixed(1), s.net),
                _bigStat('%${(d.successRate * 100).round()}', s.successRate),
                _bigStat('${d.currentStreak}', s.streak),
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Text(
              s.subjectBreakdown,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _subjectTable(d, s),

            pw.Spacer(),
            _privacyFooter(s),
          ],
        ),
      );

  // ------------------------------------------------------------------
  // EĞİTİMCİ RAPORU — çok sayfa, analitik
  // ------------------------------------------------------------------

  List<pw.Page> _teacherPages(ReportData d, ReportStrings s) => [
        // Sayfa 1: özet + ders dağılımı
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(s.teacherTitle, s, d),
              pw.SizedBox(height: 20),
              _statGrid(d, s),
              pw.SizedBox(height: 20),
              pw.Text(
                s.subjectBreakdown,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              _subjectTable(d, s),
              pw.Spacer(),
              _privacyFooter(s),
            ],
          ),
        ),

        // Sayfa 2: zayıf konular + günlük döküm
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          footer: (context) => _pageFooter(context, s),
          build: (context) => [
            pw.Text(
              s.weakTopics,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (d.weakTopics.isEmpty)
              pw.Text('—')
            else
              pw.TableHelper.fromTextArray(
                headers: [s.weakTopics, s.wrongCount],
                data: [
                  for (final w in d.weakTopics)
                    ['${w.subjectName} · ${w.topicName}', '${w.wrongCount}'],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignments: {1: pw.Alignment.centerRight},
              ),
            pw.SizedBox(height: 24),
            pw.Text(
              s.dailyDetail,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [s.day, s.duration],
              data: [
                for (final day in d.days.where((x) => x.studyS > 0))
                  [day.dateKey, _hm(day.studyS)],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignments: {1: pw.Alignment.centerRight},
            ),
            pw.SizedBox(height: 24),
            _privacyFooter(s),
          ],
        ),
      ];

  // ------------------------------------------------------------------
  // Ortak parçalar
  // ------------------------------------------------------------------

  pw.Widget _header(String title, ReportStrings s, ReportData d) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                s.appName,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${s.rangeLabel}: ${d.fromKey} — ${d.toKey}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Divider(),
        ],
      );

  pw.Widget _bigStat(String value, String label) => pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      );

  pw.Widget _statGrid(ReportData d, ReportStrings s) =>
      pw.TableHelper.fromTextArray(
        headers: null,
        data: [
          [s.totalStudy, _hm(d.totalStudyS)],
          [s.sessions, '${d.sessionCount}'],
          [s.questions, '${d.questionCount}'],
          [s.net, d.net.toStringAsFixed(1)],
          [s.successRate, '%${(d.successRate * 100).round()}'],
          [s.focus, d.avgFocusScore.round().toString()],
          [s.streak, '${d.currentStreak} / ${d.longestStreak}'],
          [s.dailyAverage, _hm(d.avgStudyPerActiveDayS)],
          [s.bestDay, _hm(d.bestDayS)],
          [s.achievements, '${d.achievementCount}'],
        ],
        cellAlignments: {1: pw.Alignment.centerRight},
      );

  pw.Widget _subjectTable(ReportData d, ReportStrings s) {
    if (d.subjects.isEmpty) return pw.Text('—');
    return pw.TableHelper.fromTextArray(
      headers: [s.subjectBreakdown, s.duration, s.questions, s.net],
      data: [
        for (final sub in d.subjects)
          [
            sub.name,
            _hm(sub.studyS),
            '${sub.questionCount}',
            sub.net.toStringAsFixed(1),
          ],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignments: {
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
    );
  }

  /// **Gizlilik kaşesi** — her raporun altında, istisnasız.
  ///
  /// Ürünün sözü bu: veri cihazda kalıyor, hesap yok, sunucu yok.
  /// Veliye giden belgede bunun yazılı olması sözün kanıtı.
  pw.Widget _privacyFooter(ReportStrings s) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(
          s.privacyStamp,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
      );

  pw.Widget _pageFooter(pw.Context c, ReportStrings s) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          '${s.page} ${c.pageNumber}/${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      );

  /// Saniyeyi "2 sa 30 dk" biçimine çevirir.
  static String _hm(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }
}
