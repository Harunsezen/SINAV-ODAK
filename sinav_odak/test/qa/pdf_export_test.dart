import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sinav_odak/application/usecases/build_report.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/entities/report_data.dart';
import 'package:sinav_odak/services/report/pdf_report_builder.dart';

import '../unit/usecase_helpers.dart';

/// QA — PDF GÖRSEL DENETİM ÇIKTISI.
///
/// Gerçekçi tohum verisiyle **Veli** ve **Eğitimci** raporlarını üretip
/// `qa_pdf/` altına yazar. Ekran görüntüsü pasının PDF karşılığı: amaç
/// insan gözüyle bakılacak çıktı üretmek.
///
/// **Neden kalıcı test:** rapor düzeni değiştiğinde çıktı yeniden
/// üretilebilsin ve gözle denetlenebilsin. Ayrıca üretim sırasında
/// istisna atılmadığını her koşuda doğruluyor.
///
/// **Ağ yok.** Fontlar `assets/fonts/` altından dosya olarak okunuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late pw.Font regular;
  late pw.Font bold;
  late Directory outDir;

  // Seed kataloğundaki sabit ID'ler. Türkçe harf kapsamı BİLİNÇLİ seçildi:
  // Türkçe (ü, ç) · Coğrafya (ğ) · İntegral (İ) · Çalışma/Başarı (ş, ı) ·
  // döküm (ö). Font kilidi `pdf_report_test.dart`'ta; burada GÖRSEL prova.
  const matematik = 'sub_yks_1';
  const turkce = 'sub_yks_0';
  const cografya = 'sub_yks_7';
  const turev = 'top_sub_yks_1_22';
  // `İntegral` SADECE font provası için değil: büyük İ (U+0130) gömülü
  // fontun kanıtlaması gereken harflerden biri ve ilk çıktıda RAPORUN
  // HİÇBİR YERİNDE geçmiyordu — yani İ görsel olarak doğrulanmamıştı.
  const integral = 'top_sub_yks_1_23';

  setUpAll(() async {
    regular = pw.Font.ttf(
      File('assets/fonts/Roboto-Regular.ttf')
          .readAsBytesSync()
          .buffer
          .asByteData(),
    );
    bold = pw.Font.ttf(
      File('assets/fonts/Roboto-Bold.ttf')
          .readAsBytesSync()
          .buffer
          .asByteData(),
    );
    outDir = Directory('qa_pdf');
    if (outDir.existsSync()) outDir.deleteSync(recursive: true);
    outDir.createSync(recursive: true);
  });

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  const strings = ReportStrings(
    appName: 'Sınav Odak',
    parentTitle: 'Çalışma Karnesi',
    teacherTitle: 'Çalışma Analiz Raporu',
    rangeLabel: 'Dönem',
    totalStudy: 'Toplam çalışma',
    sessions: 'Oturum',
    questions: 'Soru',
    net: 'Net',
    focus: 'Ortalama odak',
    successRate: 'Başarı oranı',
    streak: 'Seri (güncel / en uzun)',
    bestDay: 'En iyi gün',
    dailyAverage: 'Günlük ortalama',
    subjectBreakdown: 'Ders dağılımı',
    subjectColumn: 'Ders',
    weakTopics: 'Gelişim gereken konular',
    topicColumn: 'Konu',
    wrongCount: 'Yanlış',
    dailyDetail: 'Günlük döküm',
    day: 'Gün',
    duration: 'Süre',
    // Balto metni — ş, ı, ç harfleri burada.
    privacyStamp: 'Veriler yalnızca cihazda işlendi. Satılmadı, '
        'paylaşılmadı. — Balto, Sınav Odak',
    achievements: 'Rozet',
    page: 'Sayfa',
    parentNote:
        'Bu karne cihazında üretildi; hiçbir yere gönderilmedi. — Balto',
    coachNote: 'Koç notu',
  );

  /// 7 oturum · 3 ders · 2 konu · yanlışlar · rozet · seri.
  Future<void> seedRealistic() async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(
        onboardingCompleted: Value(true),
        examType: Value(ExamType.yks),
        currentStreak: Value(6),
        longestStreak: Value(11),
        lastStudyDate: Value('2025-08-06'),
      ),
    );

    // (gün, ders, konu, süre sn, soru, doğru, yanlış, boş, odak)
    const rows = [
      ('2025-08-01', matematik, turev, 4200, 45, 34, 8, 3, 88),
      ('2025-08-02', turkce, null, 3000, 40, 31, 6, 3, 82),
      ('2025-08-03', matematik, turev, 5400, 60, 44, 12, 4, 91),
      ('2025-08-04', cografya, null, 2400, 30, 24, 4, 2, 76),
      ('2025-08-05', turkce, null, 3600, 50, 38, 9, 3, 85),
      ('2025-08-06', matematik, turev, 4800, 55, 41, 10, 4, 93),
      ('2025-08-07', matematik, integral, 3300, 35, 24, 9, 2, 79),
    ];

    for (final (i, r) in rows.indexed) {
      final (day, subject, topic, studyS, q, correct, wrong, empty, focus) = r;
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'pdf_s$i',
              dateKey: day,
              startedAt: t0 + i * 86400000,
              plannedDurationS: studyS,
              subjectId: subject,
              topicId: Value(topic),
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              actualDurationS: Value(studyS),
              totalBreakS: const Value(300),
              questionCount: Value(q),
              correctCount: Value(correct),
              wrongCount: Value(wrong),
              emptyCount: Value(empty),
              net: Value(correct - wrong / 4),
              focusScore: Value(focus),
              mood: const Value(4),
              endedAt: Value(t0 + i * 86400000 + studyS * 1000),
            ),
          );
      await db.statsDao.recomputeDay(day);
    }

    // Yanlış defteri.
    //
    // **DİKKAT — burası raporu BESLEMİYOR.** `statsDao.weakestTopics`
    // `study_sessions.wrong_count` toplamını konuya göre gruplar;
    // `wrong_items` tablosuna hiç bakmaz. Yani öğrencinin defterine
    // elle yazdığı yanlışlar rapora YANSIMIYOR (bkz. PDF_DENETIM.md).
    // Tohumda yine de duruyor ki rapor gerçek bir kurulumu temsil etsin.
    await db.wrongItemDao.addManual(
      id: 'pdf_w1',
      subjectId: matematik,
      topicId: turev,
      wrongCount: 12,
      note: 'Zincir kuralı ve kapalı fonksiyon türevi karışıyor',
    );
    await db.wrongItemDao.addManual(
      id: 'pdf_w2',
      subjectId: matematik,
      topicId: turev,
      wrongCount: 7,
      note: 'Belirsizlik durumları',
    );
    await db.wrongItemDao.addManual(
      id: 'pdf_w3',
      subjectId: turkce,
      wrongCount: 5,
      note: 'Paragrafta ana düşünce',
    );

    // Rozet + seri.
    await db.achievementDao.unlock(code: 'streak_3', unlockedAtMs: t0);
  }

  Future<ReportData> build(ReportAudience audience) => BuildReportUseCase(db)(
        audience: audience,
        from: DateTime(2025, 8, 1),
        to: DateTime(2025, 8, 7),
      );

  Future<void> write(String name, ReportData data) async {
    final bytes = await const PdfReportBuilder().build(
      data,
      strings,
      regular: regular,
      bold: bold,
    );
    expect(
      String.fromCharCodes(bytes.take(5)),
      '%PDF-',
      reason: '$name geçerli bir PDF değil',
    );
    File('${outDir.path}/$name').writeAsBytesSync(bytes);
  }

  // =====================================================================

  test('VELİ raporu üretiliyor → qa_pdf/rapor_veli.pdf', () async {
    await seedRealistic();
    final data = await build(ReportAudience.parent);

    // Gerçekçi mi?
    expect(data.sessionCount, 7);
    expect(data.subjects.length, 3, reason: '3 ders bekleniyor');
    expect(data.currentStreak, 6);
    expect(data.achievementCount, 1);

    // **VELİ RAPORUNDA ZAYIF KONU YOK** — ürün kararı.
    expect(
      data.weakTopics,
      isEmpty,
      reason: 'veliye "en kötü olduğu konular" listesi gitmez',
    );

    await write('rapor_veli.pdf', data);
  });

  test('EĞİTİMCİ raporu üretiliyor → qa_pdf/rapor_egitimci.pdf', () async {
    await seedRealistic();
    final data = await build(ReportAudience.teacher);

    expect(data.sessionCount, 7);
    expect(data.subjects.length, 3);
    expect(
      data.weakTopics,
      isNotEmpty,
      reason: 'eğitimci raporu zayıf konuları İÇERİR',
    );

    await write('rapor_egitimci.pdf', data);
  });

  test('iki rapor da Türkçe harf taşıyan içerikle üretiliyor', () async {
    await seedRealistic();

    // Ders adları raporda basılıyor; Türkçe harf kapsamı buradan geliyor.
    final data = await build(ReportAudience.teacher);
    final names = data.subjects.map((s) => s.name).join(' ');

    expect(names, contains('Matematik'));
    // Konu adları da basılıyor — büyük İ buradan geliyor.
    final topics = data.weakTopics.map((w) => w.topicName).join(' ');
    expect(
      topics,
      contains('İntegral'),
      reason: 'büyük İ (U+0130) raporda GÖRÜNÜR olmalı; font kilidinin '
          'kanıtlaması gereken harf ve ilk çıktıda hiç geçmiyordu',
    );

    expect(
      names +
          topics +
          strings.privacyStamp +
          strings.parentTitle +
          strings.dailyDetail, // "Günlük döküm" → ö
      allOf([
        contains('ş'), // Çalışma / paylaşılmadı
        contains('ğ'), // Coğrafya
        contains('ı'), // Satılmadı / yalnızca
        contains('İ'), // İntegral
        contains('ç'), // Türkçe
        contains('ö'), // döküm
        contains('ü'), // Türkçe / Süre
      ]),
      reason: 'gömülü font provası: brief\'teki YEDİ harfin hepsi '
          'basılan içerikte geçmeli',
    );
  });

  test('FONT BEKÇİSİ: veli PDF byte\'larında Türkçe metin ÇÖZÜLÜYOR', () async {
    // **Byte seviyesinde probe — görsel doğrulamaya güvenmiyor.**
    //
    // NEDEN DÜZ ARAMA İŞE YARAMIYOR: gömülü font Identity-H kodlamasıyla
    // yazılıyor; içerik akışında harfler değil **2 baytlık glif
    // indeksleri** duruyor:
    //
    //     BT /F5 21 Tf ... [<0001000200030004000500060002>]TJ ET
    //                        Ç   a   l   ı   ş   m   a
    //
    // Bu yüzden "Çalışma" dizesi DOĞRU üretilmiş bir PDF'te bile ham
    // baytlarda ARANMAZ — ölçüldü: iki raporda da düz arama 0 sonuç
    // veriyor, eğitimci raporunda da. Düz arama iyi ile bozuğu
    // ayırt edemiyor.
    //
    // Doğrusu: her fontun kendi `ToUnicode` CMap'i çözülüp glif
    // indeksleri metne geri çevriliyor, sonra dize aranıyor. Bir glif
    // ancak GERÇEKTEN çizildiyse akışta bulunuyor, dolayısıyla bu
    // "şu metin bu belgede gömülü Roboto ile basıldı"nın doğrudan
    // kanıtı.
    await seedRealistic();
    final data = await build(ReportAudience.parent);

    final bytes = await const PdfReportBuilder().build(
      data,
      strings,
      regular: regular,
      bold: bold,
    );
    final pdf = _decodePdfText(bytes);

    // 1) Koordinatörün istediği üç dize — üretim metniyle.
    for (final needle in ['Çalışma', 'gönderilmedi', 'Satılmadı']) {
      expect(
        pdf.text,
        contains(needle),
        reason: 'veli PDF\'inde "$needle" çözülemedi — Türkçe düşüyor',
      );
    }

    // 2) Hiçbir glif eşlenemeden kalmamalı.
    expect(
      pdf.unmapped,
      0,
      reason: '${pdf.unmapped} glif ToUnicode ile eşlenemedi',
    );

    // 3) Ayrı font yolu/nesnesi KALMAMALI: belgede yalnızca iki
    //    gömülü Roboto olabilir.
    expect(
      pdf.baseFonts,
      {'Roboto-Bold', 'Roboto-Regular'},
      reason: 'veli şablonunda beklenmedik font kaynağı var',
    );
    final raw = String.fromCharCodes(bytes.map((b) => b & 0xff));
    for (final builtin in ['Helvetica', 'Times-', 'Courier']) {
      expect(
        raw,
        isNot(contains(builtin)),
        reason: 'yerleşik font $builtin sızmış — Türkçe sessizce düşer',
      );
    }
  });

  test('FONT BEKÇİSİ: veli şablonu YEDİ Türkçe harfi de basabiliyor', () async {
    // Veli raporu normalde İ içermiyor (İntegral eğitimciye ait). Şablonun
    // İ'yi basabildiğini kanıtlamak için yedi harf Balto notundan
    // geçiriliyor — üretim metni değişmiyor, yalnızca bu ölçümde farklı
    // bir dize veriliyor.
    await seedRealistic();
    final data = await build(ReportAudience.parent);

    const probe = 'İşte şu ğ ı İ ç ö ü prova satırı';
    final bytes = await const PdfReportBuilder().build(
      data,
      _withParentNote(strings, probe),
      regular: regular,
      bold: bold,
    );
    final pdf = _decodePdfText(bytes);

    expect(pdf.text, contains(probe), reason: 'prova satırı çözülemedi');
    for (final ch in ['ş', 'ğ', 'ı', 'İ', 'ç', 'ö', 'ü']) {
      expect(
        pdf.text,
        contains(ch),
        reason: '"$ch" veli PDF\'inde Roboto ile basılmamış',
      );
    }
    expect(pdf.unmapped, 0);
  });

  test('BOŞ veri: bölüm başlıkları hiç ÇİZİLMİYOR', () async {
    // Kırmızı çizgi: "boş veri bölümü çizilmez". Kullanıcı ilk gün rapor
    // almayı deneyebilir; boş başlıklarla dolu bir belge hem çirkin hem
    // "bir şeyler bozuk" hissi verir.
    //
    // Ölçüm: dosya boyutu kıyaslaması denendi ve İŞE YARAMADI — gömülü
    // font baytları farkı bastırıyor (boş 14 KB, dolu 17,6 KB). Bunun
    // yerine Helvetica + ASCII metinle üretip sayfa içerik akışlarında
    // başlıkları ARIYORUZ.
    const marker = 'PRIVACYSTAMP';
    final helvetica = pw.Font.helvetica();

    Future<String> render(ReportAudience audience) async {
      final data = await build(audience);
      final bytes = await const PdfReportBuilder().build(
        data,
        _asciiStrings(marker),
        regular: helvetica,
        bold: pw.Font.helveticaBold(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      return _inflatedStreams(bytes).join('\n');
    }

    await db.settingsDao.ensure();
    for (final audience in ReportAudience.values) {
      final drawn = await render(audience);
      expect(
        drawn,
        allOf([
          isNot(contains('Subjects')), // ders dağılımı
          isNot(contains('WeakTopics')), // gelişim gereken konular
          isNot(contains('Daily')), // günlük döküm
        ]),
        reason: '$audience: veri yokken bölüm başlığı çizilmemeli',
      );
      expect(drawn, contains(marker), reason: 'kaşe her koşulda kalır');
    }

    // KARŞIT KONTROL: veri varken başlıklar gerçekten çiziliyor.
    // Bu olmadan yukarıdaki iddia "hiçbir şey bulamayan bozuk bir
    // arama" ile de geçerdi.
    await seedRealistic();
    final full = await render(ReportAudience.teacher);
    expect(
      full,
      allOf([
        contains('Subjects'),
        contains('WeakTopics'),
        contains('Daily'),
      ]),
      reason: 'arama yöntemi başlıkları bulabiliyor olmalı',
    );
  });

  test('gizlilik kaşesi SPILL eden raporda da her sayfada', () async {
    // **Regresyon.** Kaşe eskiden `MultiPage.build` listesinin son
    // elemanıydı; `MultiPage` çocukları akıttığı için kaşe yalnızca son
    // sayfaya düşüyordu. 6 oturumluk tohum bunu GİZLİYOR (her şey 2
    // sayfaya sığıyor), o yüzden burada bilerek uzun bir aralık var.
    //
    // Ölçüm yolu: yerleşik Helvetica ile üretip (gömülü fontta metin
    // subset glif indeksine dönüşüyor, aranamıyor) sayfa içerik
    // akışlarını zlib'den çözüp işareti sayıyoruz.
    //
    // **İkinci iş:** bu test aynı zamanda uzun raporun ÜRETİLEBİLDİĞİNİ
    // kanıtlıyor. Kartlar `Container`; `MultiPage` onları bölemiyor.
    // Günlük liste parçalanmasaydı 8 aylık rapor sayfadan uzun tek bir
    // kart üretip `TooManyPagesException` fırlatırdı.
    for (var i = 0; i < 250; i++) {
      final d = DateTime(2025, 1, 1).add(Duration(days: i));
      final key = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      await db.into(db.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'spill$i',
              dateKey: key,
              startedAt: t0 + i * 86400000,
              plannedDurationS: 3600,
              subjectId: matematik,
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
              actualDurationS: const Value(3600),
              questionCount: const Value(10),
              correctCount: const Value(8),
              wrongCount: const Value(2),
              net: const Value(7.5),
              endedAt: Value(t0 + i * 86400000 + 3600000),
            ),
          );
      await db.statsDao.recomputeDay(key);
    }

    final data = await BuildReportUseCase(db)(
      audience: ReportAudience.teacher,
      from: DateTime(2025, 1, 1),
      to: DateTime(2025, 9, 30),
    );

    const marker = 'PRIVACYSTAMP';
    final helvetica = pw.Font.helvetica();
    final bytes = await const PdfReportBuilder().build(
      data,
      _asciiStrings(marker),
      regular: helvetica,
      bold: pw.Font.helveticaBold(),
    );

    final streams = _inflatedStreams(bytes);
    final pages = streams.where((s) => s.contains('BT')).toList();
    final stamped = pages.where((s) => s.contains(marker)).length;

    expect(
      pages.length,
      greaterThanOrEqualTo(3),
      reason: 'tohum yeterince uzun değilse test hiçbir şey kanıtlamaz',
    );
    expect(
      stamped,
      pages.length,
      reason: 'gizlilik kaşesi ${pages.length} sayfanın $stamped tanesinde; '
          'ürünün sözü HER sayfada yazılı olmalı',
    );
  });

  test('qa_pdf/ dizininde iki dosya var ve boş değil', () async {
    // Önceki iki test dosyaları yazdı; bu test çıktının GERÇEKTEN
    // diske indiğini doğruluyor (bayt üretip yazmamak kolay bir hata).
    final files = outDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.pdf'))
        .toList();

    expect(files.length, 2);
    for (final f in files) {
      expect(
        f.lengthSync(),
        greaterThan(2000),
        reason: '${f.path} şüpheli derecede küçük',
      );
    }
  });
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Yalnızca ASCII metin taşıyan `ReportStrings` — Helvetica ile üretip
/// içerik akışında düz metin arayabilmek için.
ReportStrings _asciiStrings(String marker) => ReportStrings(
      appName: 'App',
      parentTitle: 'Parent',
      teacherTitle: 'Teacher',
      rangeLabel: 'Range',
      totalStudy: 'Total',
      sessions: 'Sessions',
      questions: 'Questions',
      net: 'Net',
      focus: 'Focus',
      successRate: 'Rate',
      streak: 'Streak',
      bestDay: 'BestDay',
      dailyAverage: 'Average',
      subjectBreakdown: 'Subjects',
      subjectColumn: 'Subject',
      weakTopics: 'WeakTopics',
      topicColumn: 'Topic',
      wrongCount: 'Wrong',
      dailyDetail: 'Daily',
      day: 'Day',
      duration: 'Duration',
      privacyStamp: marker,
      achievements: 'Badges',
      page: 'Page',
      parentNote: 'Note',
      coachNote: 'Coach',
    );

/// PDF içindeki zlib akışlarını çözüp metin olarak döndürür.
///
/// Sözlükleri ayrıştırmıyor: `stream`/`endstream` arasını deneyip
/// çözülemeyenleri atlıyor. Helvetica kullanıldığı için gömülü font
/// akışı yok — geriye yalnızca sayfa içerik akışları kalıyor.
List<String> _inflatedStreams(List<int> bytes) {
  const begin = 'stream';
  const end = 'endstream';
  final raw = String.fromCharCodes(bytes.map((b) => b & 0xff));
  final out = <String>[];

  var i = 0;
  while (true) {
    final s = raw.indexOf(begin, i);
    if (s < 0) break;
    final e = raw.indexOf(end, s);
    if (e < 0) break;

    // `stream` anahtar sözcüğünden sonra CR/LF geliyor.
    var from = s + begin.length;
    while (from < e &&
        (raw.codeUnitAt(from) == 13 || raw.codeUnitAt(from) == 10)) {
      from++;
    }
    final chunk = bytes.sublist(from, e);
    try {
      out.add(String.fromCharCodes(ZLibDecoder().convert(chunk)));
    } on FormatException {
      // Sıkıştırılmamış ya da akış olmayan eşleşme — atla.
    } on ArgumentError {
      // Aynı sebep.
    }
    i = e + end.length;
  }
  return out;
}

/// [ReportStrings]'i yalnızca Balto notu değiştirilmiş hâlde kopyalar.
ReportStrings _withParentNote(ReportStrings s, String note) => ReportStrings(
      appName: s.appName,
      parentTitle: s.parentTitle,
      teacherTitle: s.teacherTitle,
      rangeLabel: s.rangeLabel,
      totalStudy: s.totalStudy,
      sessions: s.sessions,
      questions: s.questions,
      net: s.net,
      focus: s.focus,
      successRate: s.successRate,
      streak: s.streak,
      bestDay: s.bestDay,
      dailyAverage: s.dailyAverage,
      subjectBreakdown: s.subjectBreakdown,
      subjectColumn: s.subjectColumn,
      weakTopics: s.weakTopics,
      topicColumn: s.topicColumn,
      wrongCount: s.wrongCount,
      dailyDetail: s.dailyDetail,
      day: s.day,
      duration: s.duration,
      privacyStamp: s.privacyStamp,
      achievements: s.achievements,
      page: s.page,
      parentNote: note,
      coachNote: s.coachNote,
    );

/// PDF'ten çözülen görünür metin.
class _PdfText {
  const _PdfText(this.text, this.baseFonts, this.unmapped);

  /// Çizilen tüm metin koşuları (aralarında boşlukla).
  final String text;

  /// Belgede geçen gömülü font adları.
  final Set<String> baseFonts;

  /// `ToUnicode` ile eşlenemeyen glif sayısı. Sıfır olmalı.
  final int unmapped;
}

/// PDF baytlarından **görünür metni** geri çözer.
///
/// Identity-H kodlamasında içerik akışında harf yok, 2 baytlık glif
/// indeksi var. Her fontun kendi `ToUnicode` CMap'i o indeksleri Unicode'a
/// geri çeviriyor. Doğru fontu seçmek şart: Regular ve Bold'un glif
/// numaraları çakışıyor, yanlış CMap ile çözülen metin çöp çıkıyor
/// (ölçüldü — "ilk uyan CMap" sezgisi yanlış sonuç veriyordu).
_PdfText _decodePdfText(List<int> bytes) {
  final raw = String.fromCharCodes(bytes.map((b) => b & 0xff));

  // 1) Nesne numarası -> açılmış akış.
  final streams = <int, String>{};
  final objs = RegExp(r'(\d+)\s+0\s+obj').allMatches(raw).toList();
  for (var i = 0; i < objs.length; i++) {
    final n = int.parse(objs[i].group(1)!);
    final limit = i + 1 < objs.length ? objs[i + 1].start : raw.length;
    final sm =
        RegExp(r'stream\r?\n').firstMatch(raw.substring(objs[i].end, limit));
    if (sm == null) continue;
    final from = objs[i].end + sm.end;
    final to = raw.indexOf('endstream', from);
    if (to < 0) continue;
    try {
      streams[n] = String.fromCharCodes(
        ZLibDecoder().convert(bytes.sublist(from, to)),
      );
    } on FormatException {
      // Sıkıştırılmamış akış — atla.
    } on ArgumentError {
      // Aynı sebep.
    }
  }

  // 2) /Fn -> ToUnicode nesnesi, ve gömülü font adları.
  final fontToCmapObj = <String, int>{};
  final baseFonts = <String>{};
  for (var i = 0; i < objs.length; i++) {
    final limit = i + 1 < objs.length ? objs[i + 1].start : raw.length;
    final body = raw.substring(objs[i].end, limit);
    if (!body.contains('/Type0')) continue;
    final name = RegExp(r'/Name\s*/(F\d+)').firstMatch(body);
    final tou = RegExp(r'/ToUnicode\s+(\d+)\s+0\s+R').firstMatch(body);
    final base = RegExp(r'/BaseFont\s*/([A-Za-z0-9\-+,]+)').firstMatch(body);
    if (base != null) baseFonts.add(base.group(1)!);
    if (name != null && tou != null) {
      fontToCmapObj[name.group(1)!] = int.parse(tou.group(1)!);
    }
  }

  // 3) CMap'leri ayrıştır.
  final cmaps = <String, Map<int, String>>{};
  fontToCmapObj.forEach((font, obj) {
    final src = streams[obj];
    if (src == null) return;
    final map = <int, String>{};
    for (final blk
        in RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true).allMatches(src)) {
      for (final m in RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>')
          .allMatches(blk.group(1)!)) {
        map[int.parse(m.group(1)!, radix: 16)] = _utf16be(m.group(2)!);
      }
    }
    for (final blk in RegExp(r'beginbfrange(.*?)endbfrange', dotAll: true)
        .allMatches(src)) {
      for (final m in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>',
      ).allMatches(blk.group(1)!)) {
        final a = int.parse(m.group(1)!, radix: 16);
        final b = int.parse(m.group(2)!, radix: 16);
        final d = int.parse(m.group(3)!, radix: 16);
        for (var k = a; k <= b; k++) {
          map[k] = String.fromCharCode(d + k - a);
        }
      }
    }
    cmaps[font] = map;
  });

  // 4) İçerik akışlarını yürü: `Tf` ile fontu izle, `TJ` dizilerini çöz.
  final out = <String>[];
  var unmapped = 0;
  final token = RegExp(r'/(F\d+)\s+[\d.]+\s+Tf|\[(.*?)\]\s*TJ', dotAll: true);
  final hex = RegExp('<([0-9A-Fa-f]+)>');

  for (final src in streams.values) {
    if (!src.contains('TJ')) continue;
    String? current;
    for (final m in token.allMatches(src)) {
      if (m.group(1) != null) {
        current = m.group(1);
        continue;
      }
      final map = cmaps[current];
      if (map == null) continue;
      final buf = StringBuffer();
      for (final h in hex.allMatches(m.group(2)!)) {
        final digits = h.group(1)!;
        for (var i = 0; i + 4 <= digits.length; i += 4) {
          final gid = int.parse(digits.substring(i, i + 4), radix: 16);
          final ch = map[gid];
          if (ch == null) {
            unmapped++;
          } else {
            buf.write(ch);
          }
        }
      }
      if (buf.isNotEmpty) out.add(buf.toString());
    }
  }

  return _PdfText(out.join(' '), baseFonts, unmapped);
}

String _utf16be(String hexDigits) {
  final units = <int>[];
  for (var i = 0; i + 4 <= hexDigits.length; i += 4) {
    units.add(int.parse(hexDigits.substring(i, i + 4), radix: 16));
  }
  return String.fromCharCodes(units);
}
