import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/discard_book_session.dart';
import 'package:sinav_odak/application/usecases/finish_book_session.dart';
import 'package:sinav_odak/application/usecases/start_book_session.dart';
import 'package:sinav_odak/application/usecases/start_session.dart';
import 'package:sinav_odak/core/errors/failures.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/services/book_input.dart';

import 'usecase_helpers.dart';

/// v1.3 — KİTAP OKUMA, veri tarafı.
///
/// Bu dosyanın koruduğu asıl şey **iki modun kaydettiği veri**: süre
/// modunda süre, sayfa modunda sayfa; ikisinde de doğru/yanlış YOK ve
/// okuma süresi `total_study_s`'e KARIŞMIYOR.
void main() {
  late AppDatabase db;
  late StartBookSessionUseCase start;
  late FinishBookSessionUseCase finish;

  setUp(() {
    db = newDb();
    start = StartBookSessionUseCase(db);
    finish = FinishBookSessionUseCase(db, newRepo(db));
  });
  tearDown(() async => db.close());

  Future<String> startDuration({int minutes = 30, int startMs = t0}) async {
    return start(
      sessionId: 'b1',
      mode: BookMode.duration,
      nowMs: startMs,
      durationS: minutes * 60,
    );
  }

  Future<String> startPages({int target = 40, int startMs = t0}) async {
    return start(
      sessionId: 'b1',
      mode: BookMode.pageTarget,
      nowMs: startMs,
      pageTarget: target,
    );
  }

  group('MOD A — SÜRE', () {
    test('başlatınca planlanan süre yazılıyor, sayfa hedefi BOŞ', () async {
      await startDuration(minutes: 45);

      final s = await db.bookDao.findById('b1');
      expect(s!.mode, BookMode.duration);
      expect(s.plannedDurationS, 2700);
      expect(
        s.pageTarget,
        isNull,
        reason: 'karşı modun alanı uydurulmamalı',
      );
      expect(s.status, SessionStatus.running);
      expect(s.dateKey, '2025-08-06');
    });

    test('süre dolunca completed, süre TAM planlanan kadar', () async {
      await startDuration(minutes: 30);
      await finish(
        sessionId: 'b1',
        nowMs: t0 + 1800000,
        pagesRead: 25,
        bookTitle: 'Sefiller',
      );

      final s = await db.bookDao.findById('b1');
      expect(s!.status, SessionStatus.completed);
      expect(s.actualDurationS, 1800);
      expect(s.pagesRead, 25);
      expect(s.bookTitle, 'Sefiller');
      expect(s.endedAt, t0 + 1800000);
    });

    test('erken bitirmede earlyFinished ve GERÇEKLEŞEN süre', () async {
      await startDuration(minutes: 30);
      await finish(sessionId: 'b1', nowMs: t0 + 600000, pagesRead: 8);

      final s = await db.bookDao.findById('b1');
      expect(s!.status, SessionStatus.earlyFinished);
      expect(s.actualDurationS, 600, reason: '10 dakika okundu');
    });

    test('süre dolduktan çok sonra kaydedilse bile PLANLANAN kadar', () async {
      // Uygulama kapalı kaldı, kullanıcı ertesi gün açtı.
      await startDuration(minutes: 30);
      await finish(
        sessionId: 'b1',
        nowMs: t0 + 20 * 3600 * 1000,
        pagesRead: 25,
      );

      final s = await db.bookDao.findById('b1');
      expect(s!.actualDurationS, 1800);
    });
  });

  group('MOD B — SAYFA HEDEFİ', () {
    test('başlatınca hedef yazılıyor, planlanan süre BOŞ', () async {
      await startPages(target: 40);

      final s = await db.bookDao.findById('b1');
      expect(s!.mode, BookMode.pageTarget);
      expect(s.pageTarget, 40);
      expect(
        s.plannedDurationS,
        isNull,
        reason: 'sayfa modunda planlanmış süre YOK',
      );
    });

    test('hedefe ulaşılırsa completed', () async {
      await startPages(target: 40);
      await finish(sessionId: 'b1', nowMs: t0 + 3600000, pagesRead: 40);

      final s = await db.bookDao.findById('b1');
      expect(s!.status, SessionStatus.completed);
      expect(s.actualDurationS, 3600);
      expect(s.pagesRead, 40);
    });

    test('hedefin ALTINDA kalınırsa earlyFinished — ama veri KAYDEDİLİR',
        () async {
      await startPages(target: 40);
      await finish(sessionId: 'b1', nowMs: t0 + 1800000, pagesRead: 22);

      final s = await db.bookDao.findById('b1');
      expect(s!.status, SessionStatus.earlyFinished);
      expect(s.pagesRead, 22, reason: 'hedefe ulaşamamak kaydı silmez');
      expect(s.pageTarget, 40, reason: 'hedef vs gerçekleşen karşılaştırması');
    });

    test('12 saati aşan sayaç TAVANA çekiliyor', () async {
      await startPages();
      await finish(
        sessionId: 'b1',
        nowMs: t0 + 23 * 3600 * 1000,
        pagesRead: 100,
      );

      final s = await db.bookDao.findById('b1');
      expect(s!.actualDurationS, BookInput.maxReadingS);
    });
  });

  group('KİTAP ADI — boş bırakılabilir', () {
    test('boş ad null olarak saklanıyor', () async {
      await startDuration();
      await finish(
        sessionId: 'b1',
        nowMs: t0 + 600000,
        pagesRead: 5,
        bookTitle: '   ',
      );

      expect((await db.bookDao.findById('b1'))!.bookTitle, isNull);
    });

    test('hiç verilmezse null', () async {
      await startDuration();
      await finish(sessionId: 'b1', nowMs: t0 + 600000, pagesRead: 5);

      expect((await db.bookDao.findById('b1'))!.bookTitle, isNull);
    });

    test('uzun ad şema sınırında kesiliyor — kayıt REDDEDİLMİYOR', () async {
      // Sınırı aşan ad exception fırlatsaydı kullanıcı okumasını
      // kaydedemezdi.
      await startDuration();
      await finish(
        sessionId: 'b1',
        nowMs: t0 + 600000,
        pagesRead: 5,
        bookTitle: 'K' * 300,
      );

      final s = await db.bookDao.findById('b1');
      expect(s!.bookTitle, hasLength(BookInput.maxTitleLength));
    });
  });

  group('TEK AÇIK OTURUM', () {
    test('ikinci okuma başlatılamıyor', () async {
      await startDuration();
      await expectLater(
        start(
          sessionId: 'b2',
          mode: BookMode.duration,
          nowMs: t0,
          durationS: 1800,
        ),
        throwsA(isA<SessionFailure>()),
      );
    });

    test('çalışma oturumu açıkken okuma başlatılamıyor', () async {
      await StartSessionUseCase(db, FakeNotifier(), FakeTracker())(
        sessionId: 's1',
        schedule: schedule(),
        subjectId: subjectId,
        activityTypeId: activityId,
      );

      await expectLater(
        startDuration(),
        throwsA(isA<SessionFailure>()),
      );
    });

    test('şema seviyesinde de imkânsız (kısmi unique index)', () async {
      await startDuration();
      await expectLater(
        db.bookDao.insertSession(
          BookSessionsCompanion.insert(
            id: 'b2',
            dateKey: '2025-08-06',
            mode: BookMode.duration,
            startedAt: t0,
            plannedDurationS: const Value(1800),
            status: SessionStatus.running,
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('kapanan okumadan SONRA yenisi başlatılabiliyor', () async {
      await startDuration();
      await finish(sessionId: 'b1', nowMs: t0 + 600000, pagesRead: 5);

      await start(
        sessionId: 'b2',
        mode: BookMode.pageTarget,
        nowMs: t0 + 700000,
        pageTarget: 30,
      );
      expect((await db.bookDao.findActive())!.id, 'b2');
    });
  });

  group('geçersiz giriş', () {
    test('5 dakikanın altı reddediliyor', () async {
      await expectLater(
        start(
          sessionId: 'b1',
          mode: BookMode.duration,
          nowMs: t0,
          durationS: 60,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await db.bookDao.findActive(), isNull);
    });

    test('sayfa hedefi 0 reddediliyor', () async {
      await expectLater(
        start(
          sessionId: 'b1',
          mode: BookMode.pageTarget,
          nowMs: t0,
          pageTarget: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('SİLME', () {
    test('silinen okuma hiçbir toplamda görünmüyor', () async {
      await startDuration();
      await DiscardBookSessionUseCase(db.bookDao)('b1');

      expect(await db.bookDao.findById('b1'), isNull);
      expect(await db.bookDao.findActive(), isNull);
      final totals = await db.bookDao.totalsForDay('2025-08-06');
      expect(totals.readingS, 0);
      expect(totals.sessionCount, 0);
    });
  });

  group('TOPLAMLAR', () {
    test('AÇIK oturum toplamlara GİRMİYOR', () async {
      await startDuration();
      final totals = await db.bookDao.totalsForDay('2025-08-06');
      expect(
        totals.sessionCount,
        0,
        reason: 'süresi ölçülmemiş, sayfası sorulmamış oturum sayılamaz',
      );
    });

    test('iki okuma toplanıyor', () async {
      await startDuration(minutes: 30);
      await finish(sessionId: 'b1', nowMs: t0 + 1800000, pagesRead: 25);
      await start(
        sessionId: 'b2',
        mode: BookMode.pageTarget,
        nowMs: t0 + 2000000,
        pageTarget: 20,
      );
      await finish(sessionId: 'b2', nowMs: t0 + 2600000, pagesRead: 18);

      final totals = await db.bookDao.totalsForDay('2025-08-06');
      expect(totals.readingS, 1800 + 600);
      expect(totals.pagesRead, 43);
      expect(totals.sessionCount, 2);
    });
  });

  group('GÜNLÜK ÖZET — okuma çalışmaya KARIŞMIYOR', () {
    test('yalnızca kitap okunan gün satır ÜRETİYOR', () async {
      await startDuration(minutes: 30);
      await finish(sessionId: 'b1', nowMs: t0 + 1800000, pagesRead: 25);

      final day = await (db.select(db.dailyStats)
            ..where((t) => t.dateKey.equals('2025-08-06')))
          .getSingleOrNull();

      expect(day, isNotNull, reason: 'takvimde ve grafikte boş görünmemeli');
      expect(day!.readingS, 1800);
      expect(day.pagesRead, 25);
      expect(
        day.totalStudyS,
        0,
        reason: 'okuma süresi ÇALIŞMA süresine eklenmiyor — '
            'yoksa günlük çalışma hedefi kendiliğinden dolardı',
      );
      expect(day.sessionCount, 0, reason: 'çalışma oturumu sayısı');
      expect(day.questionCount, 0);
      expect(day.net, 0);
    });

    test('aralık özeti okuma alanlarını taşıyor', () async {
      await startDuration(minutes: 30);
      await finish(sessionId: 'b1', nowMs: t0 + 1800000, pagesRead: 25);

      final day = DateTime(2025, 8, 6);
      final summary = await db.statsDao.summaryFor(day, day);
      expect(summary.readingS, 1800);
      expect(summary.pagesRead, 25);
      expect(summary.bookSessionCount, 1);
      expect(summary.hasReading, isTrue);
      expect(summary.totalStudyS, 0);
    });

    test('hiç okuma yoksa hasReading false', () async {
      final day = DateTime(2025, 8, 6);
      final summary = await db.statsDao.summaryFor(day, day);
      expect(summary.hasReading, isFalse);
    });
  });
}
