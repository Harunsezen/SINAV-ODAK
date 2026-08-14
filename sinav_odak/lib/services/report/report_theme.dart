import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Rapor görsel dili: palet, sayı biçimi ve **çizilmiş** şekiller.
///
/// ## Neden emoji yok
///
/// Roboto'da emoji glifi yok; `pdf` paketi eksik glifi sessizce `.notdef`
/// kutusu (▯) olarak çiziyor. Veliye giden belgede bozuk kare kabul
/// edilemez, emoji fontu (~1 MB) da APK bütçesine sığmıyor. Bu yüzden
/// her simge burada **vektör olarak çiziliyor**: dosya boyutu birkaç yüz
/// bayt, her yazıcıda ve her okuyucuda aynı.
///
/// ## Neden ayrı dosya
///
/// `pdf_report_builder.dart` yerleşimden sorumlu; renk seçimi, sayı
/// biçimi ve şekil geometrisi ayrı durunca ikisi de okunur kalıyor ve
/// palet tek yerden değiştirilebiliyor.
class ReportPalette {
  const ReportPalette._();

  // --- Mürekkep -----------------------------------------------------
  /// Ana metin. Saf siyah değil: kâğıtta saf siyah sert görünüyor.
  static const ink = PdfColor.fromInt(0xFF232636);
  static const inkSoft = PdfColor.fromInt(0xFF6B7185);
  static const inkFaint = PdfColor.fromInt(0xFF9BA1B2);

  // --- Zeminler -----------------------------------------------------
  /// Veli sayfası: sıcak krem. Karne/diploma çağrışımı.
  static const cream = PdfColor.fromInt(0xFFFCF9F2);

  /// Eğitimci sayfası: soğuk lavanta beyazı. Aynı aile, daha serin.
  static const mist = PdfColor.fromInt(0xFFF7F6FC);

  static const card = PdfColor.fromInt(0xFFFFFFFF);
  static const line = PdfColor.fromInt(0xFFE4E1F0);

  // --- Aksan ailesi (hepsi yakın doygunlukta) -----------------------
  static const indigo = PdfColor.fromInt(0xFF5B5BD6);
  static const violet = PdfColor.fromInt(0xFF8A63D2);
  static const teal = PdfColor.fromInt(0xFF2FA8A0);
  static const amber = PdfColor.fromInt(0xFFE8A33D);
  static const rose = PdfColor.fromInt(0xFFE2686F);

  // --- Aksanların yumuşak zeminleri ---------------------------------
  static const indigoSoft = PdfColor.fromInt(0xFFE9E9FB);
  static const violetSoft = PdfColor.fromInt(0xFFF1EAFC);
  static const tealSoft = PdfColor.fromInt(0xFFE1F3F1);
  static const amberSoft = PdfColor.fromInt(0xFFFBEFDC);
  static const roseSoft = PdfColor.fromInt(0xFFFBE8E9);

  /// Ders çubuklarının sırayla dolaştığı renkler.
  static const cycle = [indigo, teal, amber, violet, rose];
  static const cycleSoft = [
    indigoSoft,
    tealSoft,
    amberSoft,
    violetSoft,
    roseSoft,
  ];

  static PdfColor accent(int i) => cycle[i % cycle.length];
  static PdfColor accentSoft(int i) => cycleSoft[i % cycleSoft.length];
}

/// Türkçe sayı ve tarih biçimi.
///
/// `intl` kullanmıyoruz: bu dosya `pdf` katmanında ve tek ihtiyaç ondalık
/// ayıracı. Paket eklemek yerine üç satır yazmak daha ucuz.
class ReportFormat {
  const ReportFormat._();

  /// `221.5` → `221,5` — **Türkçe ondalık ayıracı virgül**.
  static String decimal(double v, {int digits = 1}) =>
      v.toStringAsFixed(digits).replaceAll('.', ',');

  /// `0.8027` → `%80`. Yüzde işareti Türkçede sayının **önünde**.
  static String percent(double ratio) => '%${(ratio * 100).round()}';

  /// Saniye → "7 sa 25 dk".
  static String hm(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m dk';
    if (m == 0) return '$h sa';
    return '$h sa $m dk';
  }

  /// `2025-08-01` → `01.08.2025`.
  static String dateLong(String dateKey) {
    final p = dateKey.split('-');
    if (p.length != 3) return dateKey;
    return '${p[2]}.${p[1]}.${p[0]}';
  }

  /// `2025-08-01` → `01.08`. Tablolarda yıl tekrarı gürültü.
  static String dateShort(String dateKey) {
    final p = dateKey.split('-');
    if (p.length != 3) return dateKey;
    return '${p[2]}.${p[1]}';
  }
}

// ====================================================================
// ÇİZİM İLKELLERİ
// ====================================================================

/// Yay çizer (PDF'te doğrudan yay komutu yok, kübik Bézier'e bölünüyor).
///
/// Açılar **derece**, matematik yönü (0° sağ, pozitif saat yönünün
/// tersi). PDF'in y ekseni yukarı baktığı için SVG'deki gibi ters
/// çevirmeye gerek yok.
void _arcPath(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r,
  double startDeg,
  double sweepDeg,
) {
  const maxSeg = 90.0;
  final segments = (sweepDeg.abs() / maxSeg).ceil().clamp(1, 8);
  final step = sweepDeg / segments;

  var a0 = startDeg * math.pi / 180;
  final stepRad = step * math.pi / 180;

  canvas.moveTo(cx + r * math.cos(a0), cy + r * math.sin(a0));
  for (var i = 0; i < segments; i++) {
    final a1 = a0 + stepRad;
    // Çeyrek yaya en yakın Bézier: k = 4/3 · tan(Δ/4)
    final k = 4 / 3 * math.tan(stepRad / 4);

    final p0x = cx + r * math.cos(a0);
    final p0y = cy + r * math.sin(a0);
    final p3x = cx + r * math.cos(a1);
    final p3y = cy + r * math.sin(a1);

    canvas.curveTo(
      p0x - k * r * math.sin(a0),
      p0y + k * r * math.cos(a0),
      p3x + k * r * math.sin(a1),
      p3y - k * r * math.cos(a1),
      p3x,
      p3y,
    );
    a0 = a1;
  }
}

/// Halka (donut) göstergesi — başarı oranı için.
///
/// Tam daire soluk, oran kadarı renkli. Yüzdeyi hem sayı hem **şekil**
/// olarak vermek, rakama bakmadan da fikir veriyor.
pw.Widget ratioRing({
  required double ratio,
  required String centerText,
  required PdfColor color,
  required PdfColor trackColor,
  required pw.Font font,
  double size = 54,
  double stroke = 7,
}) =>
    pw.SizedBox(
      width: size,
      height: size,
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.CustomPaint(
            size: PdfPoint(size, size),
            painter: (canvas, box) {
              final c = box.x / 2;
              final r = (box.x - stroke) / 2;

              canvas
                ..setLineWidth(stroke)
                ..setLineCap(PdfLineCap.round)
                ..setStrokeColor(trackColor);
              _arcPath(canvas, c, c, r, 0, 360);
              canvas.strokePath();

              if (ratio <= 0) return;
              // 90°'den başlayıp SAAT YÖNÜNDE ilerliyor: dolan bir
              // gösterge sezgisel olarak tepeden sağa döner.
              canvas.setStrokeColor(color);
              _arcPath(canvas, c, c, r, 90, -360 * ratio.clamp(0, 1));
              canvas.strokePath();
            },
          ),
          pw.Text(
            centerText,
            style: pw.TextStyle(
              font: font,
              fontSize: 13,
              color: ReportPalette.ink,
            ),
          ),
        ],
      ),
    );

/// Yatay oranlı çubuk: soluk ray + renkli dolgu, iki ucu yuvarlak.
pw.Widget shareBar({
  required double ratio,
  required PdfColor color,
  required PdfColor trackColor,
  double height = 8,
}) =>
    pw.SizedBox(
      height: height,
      child: pw.CustomPaint(
        painter: (canvas, box) {
          final r = height / 2;
          canvas
            ..setFillColor(trackColor)
            ..drawRRect(0, 0, box.x, height, r, r)
            ..fillPath();

          final w = box.x * ratio.clamp(0, 1);
          // Çok küçük paylar çizilemeyecek kadar incelmesin: en az bir
          // yuvarlak uç kadar genişlik ver, yoksa "sıfır" gibi görünür.
          if (w <= 0) return;
          canvas
            ..setFillColor(color)
            ..drawRRect(0, 0, math.max(w, height), height, r, r)
            ..fillPath();
        },
      ),
    );

/// Günlük süreleri gösteren minik sütun grafiği.
///
/// Tabloyu **değiştirmiyor**, tamamlıyor: tablo tek tek günü verir,
/// grafik ritmi (hangi günler boş, nerede yığılma var) tek bakışta.
pw.Widget miniColumns({
  required List<int> values,
  required PdfColor color,
  required PdfColor trackColor,
  double height = 46,
}) =>
    pw.SizedBox(
      height: height,
      child: pw.CustomPaint(
        painter: (canvas, box) {
          if (values.isEmpty) return;
          final maxV = values.reduce(math.max);
          if (maxV <= 0) return;

          final gap = values.length > 40 ? 0.8 : 3.0;
          var w = (box.x - gap * (values.length - 1)) / values.length;
          // Bir haftalık raporda sütunlar sayfa genişliğine yayılınca
          // grafik değil renkli blok yığını gibi görünüyordu. Genişliği
          // sınırlayıp bütünü ortalıyoruz.
          w = math.min(w, 26);
          final span = w * values.length + gap * (values.length - 1);
          final left = (box.x - span) / 2;
          final radius = math.min(w / 2, 2.0);

          for (var i = 0; i < values.length; i++) {
            final x = left + i * (w + gap);
            final h = box.y * (values[i] / maxV);
            if (values[i] <= 0) {
              // Boş gün: silik bir taban çizgisi. Hiç çizmemek "veri
              // eksik" hissi verirdi; burada "o gün çalışılmadı" bilgisi.
              canvas
                ..setFillColor(trackColor)
                ..drawRRect(x, 0, w, 1.5, 0.75, 0.75)
                ..fillPath();
              continue;
            }
            canvas
              ..setFillColor(color)
              ..drawRRect(x, 0, w, math.max(h, 2), radius, radius)
              ..fillPath();
          }
        },
      ),
    );

/// El yazısı için çizgili alan — eğitimcinin koç notu.
pw.Widget ruledArea({int lines = 3, double gap = 18}) => pw.SizedBox(
      height: lines * gap,
      child: pw.CustomPaint(
        painter: (canvas, box) {
          // Kart kenarlığıyla aynı renk (0.7 pt / #E4E1F0) denendi ve
          // beyaz üzerinde görünmüyordu. Yazı çizgisi el yazısını
          // yönlendirecek kadar belirgin, metni bastırmayacak kadar
          // silik olmalı.
          canvas
            ..setLineWidth(0.9)
            ..setStrokeColor(const PdfColor.fromInt(0xFFD5D0E6));
          for (var i = 0; i < lines; i++) {
            final y = box.y - (i + 1) * gap + 4;
            canvas.drawLine(0, y, box.x, y);
          }
          canvas.strokePath();
        },
      ),
    );

// ====================================================================
// SİMGELER — hepsi vektör, hiçbiri font glifi değil
// ====================================================================

/// Simge türü. Her biri [iconMedallion] içinde yuvarlak zemine çiziliyor.
enum ReportIcon { clock, questions, target, streak, sessions, medal }

/// Renkli yuvarlak zemin + içine çizilmiş beyaz simge.
pw.Widget iconMedallion(
  ReportIcon icon, {
  required PdfColor color,
  double size = 26,
}) =>
    pw.SizedBox(
      width: size,
      height: size,
      child: pw.CustomPaint(
        size: PdfPoint(size, size),
        painter: (canvas, box) {
          final c = box.x / 2;
          canvas
            ..setFillColor(color)
            ..drawEllipse(c, c, c, c)
            ..fillPath();
          _paintGlyph(canvas, icon, c, box.x, color);
        },
      ),
    );

/// Simgenin beyaz çizgi/dolgu kısmı.
///
/// [bg] yalnızca madalyada gerekiyor: göbeğe zemin rengiyle bir delik
/// açılıp disk halka hâline getiriliyor.
void _paintGlyph(
  PdfGraphics canvas,
  ReportIcon icon,
  double c,
  double box,
  PdfColor bg,
) {
  final u = box / 26; // 26 pt'lik tasarım ızgarasına göre ölçek
  canvas
    ..setStrokeColor(PdfColors.white)
    ..setFillColor(PdfColors.white)
    ..setLineCap(PdfLineCap.round)
    ..setLineWidth(1.6 * u);

  switch (icon) {
    case ReportIcon.clock:
      // Kadran + iki akrep.
      _arcPath(canvas, c, c, 6.5 * u, 0, 360);
      canvas
        ..strokePath()
        ..moveTo(c, c)
        ..lineTo(c, c + 4 * u)
        ..moveTo(c, c)
        ..lineTo(c + 3 * u, c)
        ..strokePath();

    case ReportIcon.questions:
      // Üç satır — "soru listesi".
      for (var i = -1; i <= 1; i++) {
        final y = c - i * 3.6 * u;
        canvas
          ..moveTo(c - 5 * u, y)
          ..lineTo(c + 5 * u, y);
      }
      canvas.strokePath();

    case ReportIcon.target:
      // İç içe iki halka + merkez nokta: "isabet / net".
      _arcPath(canvas, c, c, 6.5 * u, 0, 360);
      canvas.strokePath();
      _arcPath(canvas, c, c, 3.4 * u, 0, 360);
      canvas
        ..strokePath()
        ..drawEllipse(c, c, 1.2 * u, 1.2 * u)
        ..fillPath();

    case ReportIcon.streak:
      // Alev: dar tepe, geniş taban. Damla değil — sivrilen uç alevi
      // okunur kılan şey, küçük boyutta ilk denemede yuvarlak bir leke
      // çıkmıştı.
      canvas
        ..moveTo(c, c + 7 * u)
        ..curveTo(
          c - 4.8 * u, c + 2.5 * u, //
          c - 3.2 * u, c - 2.5 * u, //
          c - 1.2 * u, c - 6.5 * u,
        )
        ..curveTo(
          c - 1.2 * u, c - 3 * u, //
          c + 1.4 * u, c - 3.4 * u, //
          c + 1.2 * u, c - 6.2 * u,
        )
        ..curveTo(
          c + 4.4 * u, c - 2.4 * u, //
          c + 4.8 * u, c + 2.5 * u, //
          c, c + 7 * u,
        )
        ..fillPath();

    case ReportIcon.sessions:
      // Kaydırılmış iki kart — "oturumlar". Takvim çanta gibi, iki düz
      // çubuk da eşittir işareti gibi okunuyordu. Öndeki kartın etrafına
      // zemin renginde bir boşluk bırakmak ikisini ayırıyor.
      canvas
        ..drawRRect(c - 2.2 * u, c - 2.2 * u, 8.4 * u, 8 * u, 1.7 * u, 1.7 * u)
        ..fillPath()
        ..setFillColor(bg)
        ..drawRRect(c - 7.2 * u, c - 7.2 * u, 10 * u, 9.6 * u, 2.2 * u, 2.2 * u)
        ..fillPath()
        ..setFillColor(PdfColors.white)
        ..drawRRect(c - 6.4 * u, c - 6.4 * u, 8.4 * u, 8 * u, 1.7 * u, 1.7 * u)
        ..fillPath();

    case ReportIcon.medal:
      // Kurdele uçları + disk + **yıldız**. İlk çizimde diskin göbeğinde
      // yuvarlak bir delik vardı ve simge rakam "8" gibi okunuyordu;
      // yıldız ödül anlamını tek bakışta veriyor.
      canvas
        ..moveTo(c - 5 * u, c + 7.5 * u)
        ..lineTo(c - 1.4 * u, c + 7.5 * u)
        ..lineTo(c - 2.6 * u, c + 1.5 * u)
        ..lineTo(c - 5.6 * u, c + 3.2 * u)
        ..fillPath()
        ..moveTo(c + 5 * u, c + 7.5 * u)
        ..lineTo(c + 1.4 * u, c + 7.5 * u)
        ..lineTo(c + 2.6 * u, c + 1.5 * u)
        ..lineTo(c + 5.6 * u, c + 3.2 * u)
        ..fillPath()
        ..drawEllipse(c, c - 2.6 * u, 5.4 * u, 5.4 * u)
        ..fillPath()
        ..setFillColor(bg);
      _starPath(canvas, c, c - 2.6 * u, 3.6 * u);
      canvas.fillPath();
  }
}

/// Beş köşeli yıldız yolu. Dış yarıçap [r], iç yarıçap oranı 0.42 —
/// daha büyük oran yıldızı şişman, daha küçüğü kırılgan gösteriyor.
void _starPath(PdfGraphics canvas, double cx, double cy, double r) {
  const points = 5;
  final inner = r * 0.42;
  for (var i = 0; i < points * 2; i++) {
    final rad = (i.isEven ? r : inner);
    final a = math.pi / 2 + i * math.pi / points;
    final x = cx + rad * math.cos(a);
    final y = cy + rad * math.sin(a);
    if (i == 0) {
      canvas.moveTo(x, y);
    } else {
      canvas.lineTo(x, y);
    }
  }
  canvas.closePath();
}
