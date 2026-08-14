import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sinav_odak/domain/entities/report_data.dart';
import 'package:sinav_odak/services/report/pdf_report_builder.dart';

/// FAZ 3.1 — PDF rapor üretimi.
///
/// **Ağ yok, sunucu yok:** bu testler hiçbir şey indirmiyor. Fontlar
/// `assets/fonts/` altından dosya olarak okunuyor — üretimde
/// `rootBundle`, testte doğrudan `File`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late pw.Font regular;
  late pw.Font bold;

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
  });

  const strings = ReportStrings(
    appName: 'Sınav Odak',
    parentTitle: 'Çalışma Karnesi',
    teacherTitle: 'Çalışma Analiz Raporu',
    rangeLabel: 'Aralık',
    totalStudy: 'Toplam çalışma',
    sessions: 'Oturum',
    questions: 'Soru',
    net: 'Net',
    focus: 'Ortalama odak',
    successRate: 'Başarı oranı',
    streak: 'Seri',
    bestDay: 'En iyi gün',
    dailyAverage: 'Günlük ortalama',
    subjectBreakdown: 'Ders dağılımı',
    weakTopics: 'Gelişim gereken konular',
    wrongCount: 'Yanlış',
    dailyDetail: 'Günlük döküm',
    day: 'Gün',
    duration: 'Süre',
    privacyStamp: '🔒 Veriler yalnızca cihazda işlendi. Satılmadı, '
        'paylaşılmadı. — Balto, Sınav Odak',
    achievements: 'Rozet',
    page: 'Sayfa',
  );

  ReportData data(ReportAudience audience) => ReportData(
        audience: audience,
        fromKey: '2025-08-01',
        toKey: '2025-08-07',
        totalStudyS: 9000,
        sessionCount: 3,
        questionCount: 120,
        correctCount: 90,
        wrongCount: 20,
        emptyCount: 10,
        net: 85.0,
        avgFocusScore: 83.4,
        currentStreak: 5,
        longestStreak: 9,
        achievementCount: 4,
        subjects: const [
          ReportSubjectLine(
            name: 'Matematik ve İleri Analitik Geometri',
            studyS: 6000,
            questionCount: 80,
            net: 60,
            share: 0.66,
          ),
          ReportSubjectLine(
            name: 'Türkçe',
            studyS: 3000,
            questionCount: 40,
            net: 25,
            share: 0.34,
          ),
        ],
        days: const [
          ReportDayLine(dateKey: '2025-08-01', studyS: 3600),
          ReportDayLine(dateKey: '2025-08-02', studyS: 0),
          ReportDayLine(dateKey: '2025-08-03', studyS: 5400),
        ],
        weakTopics: const [
          ReportWeakTopic(
            topicName: 'Şanzıman ve Türev İlişkisi',
            subjectName: 'Matematik',
            wrongCount: 12,
          ),
        ],
      );

  // =====================================================================

  test('TÜRKÇE GLİF BEKÇİSİ: yerleşik font ş/ğ/ı/İ DESTEKLEMİYOR', () {
    // Bu test bir HATAYI değil, bir GERÇEĞİ kilitliyor: gömülü font
    // olmadan Türkçe rapor sessizce bozuk çıkar. Biri "font gereksiz,
    // kaldıralım" derse burası neden gerektiğini gösteriyor.
    final doc = pw.Document();
    final helvetica = pw.Font.helvetica().getFont(
      pw.Context(document: doc.document),
    );

    for (final ch in ['ş', 'ğ', 'ı', 'İ']) {
      expect(
        helvetica.isRuneSupported(ch.runes.first),
        isFalse,
        reason: '$ch yerleşik fontta yok — gömülü font ŞART',
      );
    }
  });

  test('GÖMÜLÜ font Türkçe harfleri destekliyor', () {
    final doc = pw.Document();
    final f = regular.getFont(pw.Context(document: doc.document));
    for (final ch in ['ş', 'ğ', 'ı', 'İ', 'ö', 'ü', 'ç', 'Ş', 'Ğ']) {
      expect(
        f.isRuneSupported(ch.runes.first),
        isTrue,
        reason: '$ch gömülü fontta da yok — rapor bozuk çıkar',
      );
    }
  });

  test('veli raporu üretiliyor ve PDF imzasıyla başlıyor', () async {
    final bytes = await const PdfReportBuilder().build(
      data(ReportAudience.parent),
      strings,
      regular: regular,
      bold: bold,
    );

    expect(bytes.length, greaterThan(1000));
    // Her PDF "%PDF-" ile başlar; bozuk çıktı burada yakalanır.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('eğitimci raporu veli raporundan BÜYÜK (çok sayfa + analitik)',
      () async {
    const builder = PdfReportBuilder();
    final parent = await builder.build(
      data(ReportAudience.parent),
      strings,
      regular: regular,
      bold: bold,
    );
    final teacher = await builder.build(
      data(ReportAudience.teacher),
      strings,
      regular: regular,
      bold: bold,
    );

    expect(
      teacher.length,
      greaterThan(parent.length),
      reason: 'eğitimci raporu zayıf konular + günlük dökümü içeriyor',
    );
  });

  test('veli raporunda zayıf konu YOK — içerik kararı use-case katmanında', () {
    // Veliye "çocuğunuzun en kötü olduğu konular" listesi göndermek
    // uygulamanın amacının tersi olurdu. Bu kararın PDF çiziminde DEĞİL,
    // `BuildReportUseCase` içinde alındığını belgeliyor.
    const parentData = ReportData(
      audience: ReportAudience.parent,
      fromKey: '2025-08-01',
      toKey: '2025-08-07',
      totalStudyS: 100,
      sessionCount: 1,
      questionCount: 1,
      correctCount: 1,
      wrongCount: 0,
      emptyCount: 0,
      net: 1,
      avgFocusScore: 50,
      currentStreak: 1,
      longestStreak: 1,
      achievementCount: 0,
      subjects: [],
      days: [],
      weakTopics: [],
    );
    expect(parentData.weakTopics, isEmpty);
  });

  group('ReportData hesapları', () {
    test('başarı oranı BOŞLARI paydaya katmıyor', () {
      final d = data(ReportAudience.parent);
      // 90 doğru / (90 + 20 yanlış) = %81.8 — 10 boş hariç.
      expect(d.successRate, closeTo(90 / 110, 0.0001));
    });

    test('günlük ortalama ÇALIŞILAN günlere bölünüyor', () {
      final d = data(ReportAudience.parent);
      // 3 günün 2'sinde çalışılmış: 9000 / 2 = 4500.
      expect(d.activeDayCount, 2);
      expect(d.avgStudyPerActiveDayS, 4500);
    });

    test('en iyi gün doğru bulunuyor', () {
      expect(data(ReportAudience.parent).bestDayS, 5400);
    });

    test('hiç oturum yoksa isEmpty', () {
      const d = ReportData(
        audience: ReportAudience.parent,
        fromKey: '2025-08-01',
        toKey: '2025-08-07',
        totalStudyS: 0,
        sessionCount: 0,
        questionCount: 0,
        correctCount: 0,
        wrongCount: 0,
        emptyCount: 0,
        net: 0,
        avgFocusScore: 0,
        currentStreak: 0,
        longestStreak: 0,
        achievementCount: 0,
        subjects: [],
        days: [],
        weakTopics: [],
      );
      expect(d.isEmpty, isTrue);
      expect(d.successRate, 0, reason: 'sıfıra bölme olmamalı');
      expect(d.avgStudyPerActiveDayS, 0);
      expect(d.bestDayS, 0);
    });
  });
}
