import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/report_data.dart';
import 'report_theme.dart';

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
    required this.subjectColumn,
    required this.weakTopics,
    required this.topicColumn,
    required this.wrongCount,
    required this.dailyDetail,
    required this.day,
    required this.duration,
    required this.privacyStamp,
    required this.achievements,
    required this.page,
    required this.parentNote,
    required this.coachNote,
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

  /// Bölüm başlığı: "Ders dağılımı".
  final String subjectBreakdown;

  /// Tablodaki **sütun** başlığı: "Ders". Bölüm başlığından ayrı, çünkü
  /// aynı metni ikisine birden koymak tabloyu kendi başlığıyla
  /// tekrarlatıyordu.
  final String subjectColumn;

  /// Bölüm başlığı: "Gelişim gereken konular".
  final String weakTopics;

  /// Tablodaki **sütun** başlığı: "Konu".
  final String topicColumn;

  final String wrongCount;
  final String dailyDetail;
  final String day;
  final String duration;
  final String privacyStamp;
  final String achievements;
  final String page;

  /// Veli sayfasındaki Balto notu.
  final String parentNote;

  /// Eğitimci sayfasındaki çizgili alanın başlığı.
  final String coachNote;
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
///
/// ## İki ayrı görsel dil, tek aile
///
/// **Veli:** krem zemin, üç büyük kahraman kart, ders çubukları,
/// madalyonlar — buzdolabına asılacak bir karne.
/// **Eğitimci:** lavanta zemin, sıkı ölçüm ızgarası, günlük ritim
/// grafiği, zayıf konular ve el yazısı için çizgili koç notu.
///
/// Ortak olan: palet, köşe yarıçapı, başlık bandı, gizlilik kaşesi.
/// Ayrışan: yoğunluk. Aynı ailenin iki üyesi gibi görünmeleri isteniyor.
class PdfReportBuilder {
  const PdfReportBuilder();

  static const _regularPath = 'assets/fonts/Roboto-Regular.ttf';
  static const _boldPath = 'assets/fonts/Roboto-Bold.ttf';

  /// Sayfa kenar boşluğu. Geniş: karne havası sıkışıklığı kaldırmıyor.
  static const _margin = 34.0;

  /// Kart köşe yarıçapı. Tek değer, her yerde — tutarlılık en ucuz
  /// tasarım aracı.
  static const _radius = 12.0;

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

    final theme = pw.ThemeData.withFont(base: r, bold: b).copyWith(
      defaultTextStyle: pw.TextStyle(
        font: r,
        fontSize: 10,
        color: ReportPalette.ink,
      ),
    );
    final doc = pw.Document(theme: theme);

    switch (data.audience) {
      case ReportAudience.parent:
        doc.addPage(_parentPage(data, s, theme, b));
      case ReportAudience.teacher:
        for (final page in _teacherPages(data, s, theme, b)) {
          doc.addPage(page);
        }
    }

    return doc.save();
  }

  /// Sayfa zeminini boyar. `PageTheme.buildBackground` her sayfa için
  /// çağrılıyor; renk tek bir yerden geliyor.
  pw.PageTheme _pageTheme(pw.ThemeData theme, PdfColor bg) => pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(_margin),
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: bg),
        ),
      );

  // ------------------------------------------------------------------
  // VELİ RAPORU — tek sayfa, karne
  // ------------------------------------------------------------------

  pw.Page _parentPage(
    ReportData d,
    ReportStrings s,
    pw.ThemeData theme,
    pw.Font bold,
  ) =>
      pw.Page(
        pageTheme: _pageTheme(theme, ReportPalette.cream),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _titleBand(s.parentTitle, s, d, bold, ReportPalette.indigo),
            pw.SizedBox(height: 18),

            // Kahraman kartlar: üç büyük sayı, her biri kendi renginde.
            //
            // `stretch` YOK — bkz. `_heroCard`'daki sabit yükseklik notu.
            pw.Row(
              children: [
                pw.Expanded(
                  child: _heroCard(
                    ReportFormat.hm(d.totalStudyS),
                    s.totalStudy,
                    ReportIcon.clock,
                    ReportPalette.indigo,
                    ReportPalette.indigoSoft,
                    bold,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _heroCard(
                    '${d.questionCount}',
                    s.questions,
                    ReportIcon.questions,
                    ReportPalette.teal,
                    ReportPalette.tealSoft,
                    bold,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _heroCard(
                    ReportFormat.decimal(d.net),
                    s.net,
                    ReportIcon.target,
                    ReportPalette.amber,
                    ReportPalette.amberSoft,
                    bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            // İkinci sıra: halka + iki küçük ölçüm.
            _parentSecondRow(d, s, bold),
            pw.SizedBox(height: 16),

            // Boş bölüm çizilmez.
            if (d.subjects.isNotEmpty) ...[
              _sectionTitle(s.subjectBreakdown, bold),
              pw.SizedBox(height: 8),
              _subjectBars(d, s, bold, dense: false),
              pw.SizedBox(height: 16),
            ],

            if (d.achievementCount > 0) ...[
              _medalRow(d, s, bold),
              pw.SizedBox(height: 16),
            ],

            // Günlük ritim veliye de gösteriliyor: "kaç gün çalıştı"
            // gurur veren bir bilgi ve zayıf konu listesi DEĞİL.
            if (d.days.any((x) => x.studyS > 0)) ...[
              _sectionTitle(s.dailyDetail, bold),
              pw.SizedBox(height: 8),
              _dailyChart(d),
              pw.SizedBox(height: 16),
            ],

            _baltoNote(s, bold),

            pw.Spacer(),
            _privacyFooter(s),
          ],
        ),
      );

  /// Başarı halkası + seri + oturum. Üçü tek kartta, ortada ayraçlarla.
  pw.Widget _parentSecondRow(ReportData d, ReportStrings s, pw.Font bold) =>
      _card(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  ratioRing(
                    ratio: d.successRate,
                    centerText: ReportFormat.percent(d.successRate),
                    color: ReportPalette.indigo,
                    trackColor: ReportPalette.indigoSoft,
                    font: bold,
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Text(
                      s.successRate,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: ReportPalette.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _vDivider(),
            pw.Expanded(
              child: _miniStat(
                s.streak,
                '${d.currentStreak}',
                bold,
                ReportIcon.streak,
                ReportPalette.rose,
              ),
            ),
            _vDivider(),
            pw.Expanded(
              child: _miniStat(
                s.sessions,
                '${d.sessionCount}',
                bold,
                ReportIcon.sessions,
                ReportPalette.violet,
              ),
            ),
          ],
        ),
      );

  pw.Widget _vDivider() => pw.Container(
        width: 1,
        height: 34,
        margin: const pw.EdgeInsets.symmetric(horizontal: 10),
        color: ReportPalette.line,
      );

  pw.Widget _miniStat(
    String label,
    String value,
    pw.Font bold,
    ReportIcon? icon, [
    PdfColor color = ReportPalette.indigo,
  ]) =>
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            iconMedallion(icon, color: color, size: 22),
            pw.SizedBox(width: 8),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                if (value.isNotEmpty)
                  pw.Text(
                    value,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 16,
                      color: ReportPalette.ink,
                    ),
                  ),
                pw.Text(
                  label,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: ReportPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  /// Rozet madalyonları. Sayı kadar madalya çiziliyor (en fazla 6),
  /// çünkü "3 rozet" yazısı bir çocuk için "üç madalya" kadar sevindirici
  /// değil.
  pw.Widget _medalRow(ReportData d, ReportStrings s, pw.Font bold) => _card(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              '${d.achievementCount}',
              style: pw.TextStyle(
                font: bold,
                fontSize: 22,
                color: ReportPalette.amber,
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              s.achievements,
              style: const pw.TextStyle(
                fontSize: 10,
                color: ReportPalette.inkSoft,
              ),
            ),
            pw.Spacer(),
            for (var i = 0; i < d.achievementCount.clamp(0, 6); i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 5),
                child: iconMedallion(
                  ReportIcon.medal,
                  color: ReportPalette.accent(i),
                  size: 24,
                ),
              ),
          ],
        ),
      );

  /// Balto'nun notu — markanın sesi karnede de duyulsun.
  pw.Widget _baltoNote(ReportStrings s, pw.Font bold) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: ReportPalette.violetSoft,
          borderRadius: pw.BorderRadius.circular(_radius),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Marka çizgisi: sol kenarda ince renkli şerit.
            pw.Container(width: 3, height: 26, color: ReportPalette.violet),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Text(
                s.parentNote,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: 10,
                  color: ReportPalette.ink,
                  lineSpacing: 2.5,
                ),
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------------------
  // EĞİTİMCİ RAPORU — çok sayfa, analitik
  // ------------------------------------------------------------------

  List<pw.Page> _teacherPages(
    ReportData d,
    ReportStrings s,
    pw.ThemeData theme,
    pw.Font bold,
  ) =>
      [
        pw.MultiPage(
          pageTheme: _pageTheme(theme, ReportPalette.mist),
          footer: (context) => _pageFooter(context, s),
          build: (context) => [
            _titleBand(s.teacherTitle, s, d, bold, ReportPalette.violet),
            pw.SizedBox(height: 16),

            _measureGrid(d, s, bold),
            pw.SizedBox(height: 16),

            if (d.subjects.isNotEmpty) ...[
              _sectionTitle(s.subjectBreakdown, bold),
              pw.SizedBox(height: 8),
              _subjectBars(d, s, bold, dense: true),
              pw.SizedBox(height: 16),
            ],

            // Zayıf konular YALNIZCA eğitimci raporunda ve yalnızca
            // veri varsa.
            if (d.weakTopics.isNotEmpty) ...[
              _sectionTitle(s.weakTopics, bold),
              pw.SizedBox(height: 8),
              _weakTopicList(d, s, bold),
              pw.SizedBox(height: 16),
            ],

            if (d.days.any((x) => x.studyS > 0)) ...[
              _sectionTitle(s.dailyDetail, bold),
              pw.SizedBox(height: 8),
              ..._dailyBlocks(d, s, bold),
              pw.SizedBox(height: 12),
            ],

            _coachNote(s, bold),
          ],
        ),
      ];

  /// On ölçüm, beşerli iki sıra. Tablo yerine kart ızgarası: eğitimci
  /// aradığı sayıyı taramadan buluyor.
  pw.Widget _measureGrid(ReportData d, ReportStrings s, pw.Font bold) {
    final cells = <(String, String)>[
      (s.totalStudy, ReportFormat.hm(d.totalStudyS)),
      (s.sessions, '${d.sessionCount}'),
      (s.questions, '${d.questionCount}'),
      (s.net, ReportFormat.decimal(d.net)),
      (s.successRate, ReportFormat.percent(d.successRate)),
      (s.focus, '${d.avgFocusScore.round()}'),
      (s.streak, '${d.currentStreak} / ${d.longestStreak}'),
      (s.dailyAverage, ReportFormat.hm(d.avgStudyPerActiveDayS)),
      // **Tarih değere değil ETİKETE giriyor.** İlk denemede değer
      // "03.08 · 1 sa 30 dk" idi; 12 pt kalın metin ~100 pt'lik hücreye
      // sığmayınca `pdf` paketi hücreyi BOŞ çizdi — sessiz kayıp.
      // Etiket 7.5 pt ve iki satıra sarabiliyor, orası güvenli.
      (
        d.bestDayKey == null
            ? s.bestDay
            : '${s.bestDay} · ${ReportFormat.dateShort(d.bestDayKey!)}',
        d.bestDayKey == null ? '—' : ReportFormat.hm(d.bestDayS),
      ),
      (s.achievements, '${d.achievementCount}'),
    ];

    // **Sabit yükseklik, `stretch` DEĞİL.** `MultiPage` çocuklarını
    // dikeyde sınırsız kısıtla ölçüyor; bir `Row`'a
    // `CrossAxisAlignment.stretch` verilince hücreler sonsuza uzayıp
    // `TooManyPagesException` fırlatıyor. Ölçüldü: eğitimci raporu hiç
    // üretilemedi. Sabit yükseklik hem kutuları eşitliyor hem güvenli.
    pw.Widget cell((String, String) c) => pw.Expanded(
          child: pw.Container(
            height: 42,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            margin: const pw.EdgeInsets.only(right: 6),
            decoration: pw.BoxDecoration(
              color: ReportPalette.card,
              borderRadius: pw.BorderRadius.circular(9),
              border: pw.Border.all(color: ReportPalette.line, width: 0.7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  c.$2,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 12,
                    color: ReportPalette.ink,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  c.$1,
                  maxLines: 2,
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: ReportPalette.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        );

    return pw.Column(
      children: [
        pw.Row(children: [for (final c in cells.take(5)) cell(c)]),
        pw.SizedBox(height: 6),
        pw.Row(children: [for (final c in cells.skip(5)) cell(c)]),
      ],
    );
  }

  /// Zayıf konular: her satırda konu, yanlış sayısı ve **en çok yanlışa
  /// göre** oranlı bir çubuk. Sayı tek başına ölçek vermiyor.
  pw.Widget _weakTopicList(ReportData d, ReportStrings s, pw.Font bold) {
    final maxWrong = d.weakTopics
        .map((w) => w.wrongCount)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return _card(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: pw.Column(
        children: [
          for (final (i, w) in d.weakTopics.indexed) ...[
            if (i > 0) pw.SizedBox(height: 9),
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(
                    '${w.subjectName} · ${w.topicName}',
                    maxLines: 1,
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  flex: 4,
                  child: shareBar(
                    ratio: maxWrong == 0 ? 0 : w.wrongCount / maxWrong,
                    color: ReportPalette.rose,
                    trackColor: ReportPalette.roseSoft,
                    height: 7,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 46,
                  child: pw.Text(
                    '${w.wrongCount} ${s.wrongCount.toLowerCase()}',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 9,
                      color: ReportPalette.rose,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bir liste kartına giren en fazla satır (iki sütun × 12).
  ///
  /// **Neden parçalanıyor:** `Container` `MultiPage` içinde **bölünemez**
  /// bir kutu. Tüm günleri tek karta koysaydım 8 aylık bir rapor sayfadan
  /// uzun bir kart üretir ve `TooManyPagesException` fırlatırdı. Küçük
  /// kartlar sayfalar arasında doğal akıyor.
  static const _daysPerCard = 24;

  /// Günlük ritim: önce sütun grafiği kartı, sonra parçalanmış liste
  /// kartları.
  List<pw.Widget> _dailyBlocks(ReportData d, ReportStrings s, pw.Font bold) {
    final active = d.days.where((x) => x.studyS > 0).toList();
    final out = <pw.Widget>[_dailyChart(d)];

    for (var i = 0; i < active.length; i += _daysPerCard) {
      final slice = active.skip(i).take(_daysPerCard).toList();
      out
        ..add(pw.SizedBox(height: 6))
        ..add(_dailyListCard(slice));
    }
    return out;
  }

  pw.Widget _dailyListCard(List<ReportDayLine> rows) {
    // Liste iki sütuna bölünüyor: tek sütunda aynı bilgi iki kat yer
    // kaplardı ve sayfanın yarısı boş kalırdı.
    final half = (rows.length / 2).ceil();

    pw.Widget column(Iterable<ReportDayLine> rows) => pw.Expanded(
          child: pw.Column(
            children: [
              for (final r in rows)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 3),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        ReportFormat.dateShort(r.dateKey),
                        style: const pw.TextStyle(
                          fontSize: 8.5,
                          color: ReportPalette.inkSoft,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          child: pw.Container(
                            height: 0.7,
                            color: ReportPalette.line,
                          ),
                        ),
                      ),
                      pw.Text(
                        ReportFormat.hm(r.studyS),
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

    return _card(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          column(rows.take(half)),
          pw.SizedBox(width: 24),
          column(rows.skip(half)),
        ],
      ),
    );
  }

  /// Günlük ritim grafiği: hangi günler boş, nerede yığılma var.
  pw.Widget _dailyChart(ReportData d) => _card(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            miniColumns(
              values: [for (final x in d.days) x.studyS],
              color: ReportPalette.violet,
              trackColor: ReportPalette.line,
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  ReportFormat.dateShort(d.fromKey),
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: ReportPalette.inkFaint,
                  ),
                ),
                pw.Text(
                  ReportFormat.dateShort(d.toKey),
                  style: const pw.TextStyle(
                    fontSize: 7.5,
                    color: ReportPalette.inkFaint,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// El yazısıyla doldurulacak alan. Eğitimci raporu bir **belge**;
  /// üstüne not düşülebilmesi onu kullanışlı kılıyor.
  pw.Widget _coachNote(ReportStrings s, pw.Font bold) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: pw.BoxDecoration(
          color: ReportPalette.card,
          borderRadius: pw.BorderRadius.circular(_radius),
          border: pw.Border.all(color: ReportPalette.line, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              children: [
                pw.Container(width: 3, height: 12, color: ReportPalette.violet),
                pw.SizedBox(width: 7),
                pw.Text(
                  s.coachNote,
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 10,
                    color: ReportPalette.ink,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            ruledArea(),
          ],
        ),
      );

  // ------------------------------------------------------------------
  // Ortak parçalar
  // ------------------------------------------------------------------

  /// Renkli başlık bandı. İki rapor da bununla açılıyor; kimliği taşıyan
  /// ilk şey bu.
  pw.Widget _titleBand(
    String title,
    ReportStrings s,
    ReportData d,
    pw.Font bold,
    PdfColor color,
  ) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(_radius + 2),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 21,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${s.rangeLabel}: ${ReportFormat.dateLong(d.fromKey)} — '
                    '${ReportFormat.dateLong(d.toKey)}',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.white,
                      lineSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              s.appName,
              style: pw.TextStyle(
                font: bold,
                fontSize: 10,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      );

  pw.Widget _sectionTitle(String text, pw.Font bold) => pw.Row(
        children: [
          pw.Container(width: 3, height: 12, color: ReportPalette.indigo),
          pw.SizedBox(width: 7),
          pw.Text(
            text,
            style: pw.TextStyle(
              font: bold,
              fontSize: 11.5,
              color: ReportPalette.ink,
            ),
          ),
        ],
      );

  pw.Widget _card({required pw.Widget child, required pw.EdgeInsets padding}) =>
      pw.Container(
        width: double.infinity,
        padding: padding,
        decoration: pw.BoxDecoration(
          color: ReportPalette.card,
          borderRadius: pw.BorderRadius.circular(_radius),
          border: pw.Border.all(color: ReportPalette.line, width: 0.7),
        ),
        child: child,
      );

  /// Kahraman kart: renkli yumuşak zemin, büyük sayı, çizilmiş madalyon.
  pw.Widget _heroCard(
    String value,
    String label,
    ReportIcon icon,
    PdfColor color,
    PdfColor soft,
    pw.Font bold,
  ) =>
      pw.Container(
        // **Sabit yükseklik, `stretch` DEĞİL.** `Row`'a
        // `CrossAxisAlignment.stretch` verilince çocuklar satırın
        // yüksekliğine uzatılıyor, satırın yüksekliği de çocuklardan
        // geliyor — döngü. Ölçüldü: bant dışında sayfada HİÇBİR ŞEY
        // çizilmedi. Sabit değer hem kartları eşitliyor hem güvenli.
        height: 104,
        padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: pw.BoxDecoration(
          color: soft,
          borderRadius: pw.BorderRadius.circular(_radius),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            iconMedallion(icon, color: color),
            pw.Spacer(),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: bold,
                fontSize: 20,
                color: ReportPalette.ink,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: ReportPalette.inkSoft,
              ),
            ),
          ],
        ),
      );

  /// Ders dağılımı — tablo değil **çubuk**. Payı okumak için sayıları
  /// karşılaştırmak gerekmiyor, uzunluklara bakmak yetiyor.
  pw.Widget _subjectBars(
    ReportData d,
    ReportStrings s,
    pw.Font bold, {
    required bool dense,
  }) =>
      _card(
        padding: pw.EdgeInsets.symmetric(
          horizontal: 14,
          vertical: dense ? 12 : 14,
        ),
        child: pw.Column(
          children: [
            for (final (i, sub) in d.subjects.indexed) ...[
              if (i > 0) pw.SizedBox(height: dense ? 10 : 13),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      sub.name,
                      maxLines: 1,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: dense ? 9.5 : 10.5,
                        color: ReportPalette.ink,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 6,
                    child: shareBar(
                      ratio: sub.share,
                      color: ReportPalette.accent(i),
                      trackColor: ReportPalette.accentSoft(i),
                      height: dense ? 7 : 9,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.SizedBox(
                    width: 62,
                    child: pw.Text(
                      ReportFormat.hm(sub.studyS),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                  pw.SizedBox(
                    width: 44,
                    child: pw.Text(
                      '${sub.questionCount}',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: ReportPalette.inkSoft,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: 46,
                    child: pw.Text(
                      ReportFormat.decimal(sub.net),
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: ReportPalette.accent(i),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            pw.SizedBox(height: 8),
            // Sütun anahtarı en altta ve soluk: çubuklar zaten konuşuyor,
            // başlıklar üstte olsa gürültü yapardı.
            pw.Row(
              children: [
                pw.Expanded(flex: 10, child: pw.SizedBox()),
                pw.SizedBox(width: 10),
                _colKey(s.duration, 62),
                _colKey(s.questions, 44),
                _colKey(s.net, 46),
              ],
            ),
          ],
        ),
      );

  pw.Widget _colKey(String text, double width) => pw.SizedBox(
        width: width,
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(
            fontSize: 7.5,
            color: ReportPalette.inkFaint,
          ),
        ),
      );

  /// **Gizlilik kaşesi** — her raporun altında, istisnasız.
  ///
  /// Ürünün sözü bu: veri cihazda kalıyor, hesap yok, sunucu yok.
  /// Veliye giden belgede bunun yazılı olması sözün kanıtı.
  pw.Widget _privacyFooter(ReportStrings s) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: pw.BoxDecoration(
          color: ReportPalette.indigoSoft,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _lockGlyph(),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                s.privacyStamp,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: ReportPalette.inkSoft,
                ),
              ),
            ),
          ],
        ),
      );

  /// Kilit simgesi — **çizim**, emoji değil.
  ///
  /// Eskiden burada `🔒` vardı; Roboto'da o glif yok ve `pdf` paketi
  /// sessizce `.notdef` kutusu (▯) çiziyordu. Vektör hem her yerde
  /// aynı görünüyor hem de emoji fontunun ~1 MB'ını APK'ya eklemiyor.
  pw.Widget _lockGlyph() => pw.SizedBox(
        width: 11,
        height: 12,
        child: pw.CustomPaint(
          size: const PdfPoint(11, 12),
          painter: (canvas, box) {
            final w = box.x;
            canvas
              // Gövde
              ..setFillColor(ReportPalette.indigo)
              ..drawRRect(0, 0, w, box.y * 0.62, 1.6, 1.6)
              ..fillPath()
              // Kanca
              ..setStrokeColor(ReportPalette.indigo)
              ..setLineWidth(1.5)
              ..moveTo(w * 0.24, box.y * 0.6)
              ..lineTo(w * 0.24, box.y * 0.78)
              ..curveTo(
                w * 0.24, box.y * 1.02, //
                w * 0.76, box.y * 1.02, //
                w * 0.76, box.y * 0.78,
              )
              ..lineTo(w * 0.76, box.y * 0.6)
              ..strokePath();
          },
        ),
      );

  /// `MultiPage`'in **her sayfasına** çizilen alt bilgi.
  ///
  /// **Neden kaşe burada, akışın sonunda değil:** kaşe eskiden `build`
  /// listesinin son elemanıydı. `MultiPage` çocukları sayfalara akıtıyor,
  /// dolayısıyla kaşe yalnızca *son* sayfaya düşüyordu. 80 günlük bir
  /// aralıkla ölçüldü: rapor 5 sayfa, kaşe yalnızca 1. ve 5. sayfada,
  /// aradaki 3 sayfa kaşesiz. `footer` ise her sayfa için çağrılıyor.
  pw.Widget _pageFooter(pw.Context c, ReportStrings s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _privacyFooter(s),
            _pageNumber(c, s),
          ],
        ),
      );

  pw.Widget _pageNumber(pw.Context c, ReportStrings s) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${s.page} ${c.pageNumber}/${c.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: ReportPalette.inkFaint,
            ),
          ),
        ),
      );
}
