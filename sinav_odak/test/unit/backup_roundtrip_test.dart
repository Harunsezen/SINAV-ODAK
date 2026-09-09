import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/application/usecases/export_backup.dart';
import 'package:sinav_odak/application/usecases/finish_book_session.dart';
import 'package:sinav_odak/application/usecases/import_backup.dart';
import 'package:sinav_odak/application/usecases/start_book_session.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/enums.dart';
import 'package:sinav_odak/domain/ports/share_gateway.dart';
import 'package:sinav_odak/domain/services/backup_codec.dart';

import 'usecase_helpers.dart';

/// Yedeği paylaşmak yerine METNİ TUTAN kapı.
class CapturingShare implements ShareGateway {
  String? content;
  String? fileName;
  bool succeed = true;

  @override
  Future<bool> shareText({
    required String content,
    required String fileName,
    String? subject,
  }) async {
    this.content = content;
    this.fileName = fileName;
    return succeed;
  }

  @override
  Future<bool> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? subject,
  }) async =>
      true;
}

/// v1.3 — YEDEKLE / GERİ YÜKLE, gerçek veritabanıyla.
///
/// Bu dosyanın kanıtladığı tek şey şu: **telefon değişince hiçbir şey
/// kaybolmuyor.** Yedek bir veritabanından alınıp BAŞKA, boş bir
/// veritabanına yükleniyor — "yeni telefon" tam olarak bu.
void main() {
  late AppDatabase db;
  late CapturingShare share;

  setUp(() {
    db = newDb();
    share = CapturingShare();
  });
  tearDown(() async => db.close());

  Future<String> exportFrom(AppDatabase from) async {
    final s = CapturingShare();
    final summary = await ExportBackupUseCase(from, s)(
      nowMs: t0,
      appVersion: '1.3.0+6',
    );
    expect(summary, isNotNull, reason: 'paylaşım başarısız sayıldı');
    return s.content!;
  }

  /// Zengin bir kullanıcı geçmişi kurar.
  Future<void> seedHistory(AppDatabase target) async {
    await target.settingsDao.ensure();

    // Kullanıcı dersi yeniden adlandırmış, bir konuyu arşivlemiş.
    await target.subjectDao
        .renameSubject(subjectId, 'Matematik AYT', '#4F5BD5');
    await target.subjectDao.archiveTopic('top_sub_yks_1_23');

    for (final (i, day) in const ['2025-08-04', '2025-08-06'].indexed) {
      await target.into(target.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'bk_s$i',
              dateKey: day,
              startedAt: t0 + i * 3600000,
              plannedDurationS: 2880,
              subjectId: subjectId,
              topicId: const Value(topicId),
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{"a":1}',
              actualDurationS: Value(2400 + i * 600),
              questionCount: Value(40 + i),
              wrongCount: Value(8 - i),
              net: Value(18.5 + i),
              focusScore: Value(80 + i),
            ),
          );
      await target.statsDao.recomputeDay(day);
    }

    // YALNIZCA kitap okunan gün — özet yeniden hesaplanırken bu gün
    // unutulursa takvimde boş görünür.
    await StartBookSessionUseCase(target)(
      sessionId: 'bk_b1',
      mode: BookMode.duration,
      nowMs: t0 + 5 * 86400000,
      durationS: 1800,
    );
    await FinishBookSessionUseCase(target, newRepo(target))(
      sessionId: 'bk_b1',
      nowMs: t0 + 5 * 86400000 + 1800000,
      pagesRead: 42,
      bookTitle: 'Sefiller',
    );

    await target.wrongItemDao.addManual(
      id: 'bk_w1',
      subjectId: subjectId,
      topicId: topicId,
      note: 'Zincir kuralı',
    );
    await target.goalDao.createGoal(
      id: 'bk_g1',
      type: GoalType.dailyMinutes,
      target: 240,
    );
    await target.achievementDao.unlock(code: 'streak_7', unlockedAtMs: t0);

    // **Ayarlar EN SONDA yazılıyor.** Kitap oturumunu bitirmek
    // `saveBookSession` üzerinden `recomputeStreak` çağırıyor ve seriyi
    // kendi tarihine göre yeniden hesaplıyor; ayarlar önce yazılsaydı bu
    // test kendi kurduğu değeri değil, hesabın ürettiğini doğrulardı.
    await target.settingsDao.patchSettings(
      const UserSettingsCompanion(
        onboardingCompleted: Value(true),
        currentStreak: Value(11),
        longestStreak: Value(23),
        lastStudyDate: Value('2025-08-06'),
        dailyGoalMinutes: Value(240),
      ),
    );
  }

  test('YENİ TELEFON: her şey geri geliyor', () async {
    await seedHistory(db);
    final json = await exportFrom(db);

    // "Yeni telefon": bomboş, ayrı bir veritabanı.
    final fresh = newDb();
    addTearDown(fresh.close);
    await fresh.settingsDao.ensure();

    final result = await ImportBackupUseCase(fresh)(json);
    expect(result.sessions, 2);
    expect(result.books, 1);
    expect(result.appVersion, '1.3.0+6');

    // --- Ayarlar ve SERİ ---
    final s = await fresh.settingsDao.ensure();
    expect(s.currentStreak, 11, reason: 'seri kaybolursa kullanıcı küser');
    expect(s.longestStreak, 23);
    expect(s.lastStudyDate, '2025-08-06');
    expect(s.dailyGoalMinutes, 240);
    expect(s.onboardingCompleted, isTrue);

    // --- Katalog: yeniden adlandırma ve arşiv ---
    final subject = await fresh.subjectDao.findSubject(subjectId);
    expect(subject!.name, 'Matematik AYT');
    final archived = await fresh.subjectDao.findTopic('top_sub_yks_1_23');
    expect(archived!.isArchived, isTrue);

    // --- Oturumlar ---
    final s0 = await fresh.sessionDao.findById('bk_s0');
    expect(s0, isNotNull);
    expect(s0!.questionCount, 40);
    expect(s0.net, 18.5, reason: 'ondalık net korunmalı');
    expect(s0.topicId, topicId);
    expect(s0.scheduleJson, '{"a":1}');

    // --- Kitap ---
    final book = await fresh.bookDao.findById('bk_b1');
    expect(book!.bookTitle, 'Sefiller');
    expect(book.pagesRead, 42);
    expect(book.mode, BookMode.duration);

    // --- Yanlış defteri, hedef, rozet ---
    expect(
      (await fresh.select(fresh.wrongItems).get()).single.note,
      'Zincir kuralı',
    );
    expect((await fresh.select(fresh.goals).get()).single.id, 'bk_g1');
    expect(await fresh.achievementDao.unlockedCodes(), contains('streak_7'));
  });

  test('GÜNLÜK ÖZET yeniden hesaplanıyor — kitap günü DAHİL', () async {
    await seedHistory(db);
    final json = await exportFrom(db);

    final fresh = newDb();
    addTearDown(fresh.close);
    await ImportBackupUseCase(fresh)(json);

    final days = await fresh.select(fresh.dailyStats).get();
    final keys = days.map((d) => d.dateKey).toSet();
    expect(keys, contains('2025-08-04'));
    expect(keys, contains('2025-08-06'));

    final bookDay = days.firstWhere((d) => d.readingS > 0);
    expect(
      bookDay.pagesRead,
      42,
      reason: 'yalnızca kitap okunan gün özetsiz kalırsa takvimde boş '
          'görünür — `recomputeAll` bu günü ATLIYOR, o yüzden ayrı '
          'sorgu yazıldı',
    );
  });

  test('SÜREN oturum yedeğe girmiyor', () async {
    // Yeni cihaza taşınsaydı kurtarma akışı hiç yaşanmamış bir oturumu
    // "yarıda kalmış" diye sorardı.
    await db.settingsDao.ensure();
    await seedRunningSession(db, id: 'acik', sch: schedule());

    final json = await exportFrom(db);

    // **Metin araması DEĞİL, yapısal kontrol.** İlk denemede
    // `isNot(contains('acik'))` yazılmıştı ve düştü: müfredattaki bir
    // konu adı o harf dizisini içeriyor. Düz arama yanlış yerde eşleşir.
    final env = BackupCodec.decode(json, currentSchemaVersion: 7);
    expect(
      env.tables['study_sessions']!.map((r) => r['id']),
      isNot(contains('acik')),
    );
    expect(
      env.tables['session_blocks']!.map((r) => r['session_id']),
      isNot(contains('acik')),
      reason: 'ebeveyni olmayan blok geri yüklemede foreign key hatası '
          'verir ve TÜM geri yükleme çöker',
    );

    final fresh = newDb();
    addTearDown(fresh.close);
    await ImportBackupUseCase(fresh)(json);
    expect(await fresh.sessionDao.findActiveSession(), isNull);
  });

  test('SÜREN oturumun YANLIŞ kaydı korunuyor, bağı düşüyor', () async {
    // Yanlış kaydının kendisi kullanıcı verisi; oturum dışarıda kalınca
    // kayıt silinmemeli, elle eklenmiş kayda dönüşmeli.
    await db.settingsDao.ensure();
    await seedRunningSession(db, id: 'acik', sch: schedule());
    await db.wrongItemDao.upsertFromSession(
      id: 'wr_acik',
      sessionId: 'acik',
      subjectId: subjectId,
      topicId: topicId,
      wrongCount: 4,
    );

    final json = await exportFrom(db);
    final fresh = newDb();
    addTearDown(fresh.close);
    await ImportBackupUseCase(fresh)(json);

    final w = (await fresh.select(fresh.wrongItems).get()).single;
    expect(w.wrongCount, 4, reason: 'kayıt korunmalı');
    expect(w.sessionId, isNull, reason: 'olmayan oturuma bağlı kalmamalı');
    expect(w.source, WrongItemSource.manual);
  });

  test('GERİ YÜKLEME DEĞİŞTİRİR: mevcut veri siliniyor', () async {
    await seedHistory(db);
    final json = await exportFrom(db);

    // Başka bir cihazda başka bir geçmiş.
    final other = newDb();
    addTearDown(other.close);
    await other.settingsDao.ensure();
    await other.into(other.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'yabanci',
            dateKey: '2026-01-01',
            startedAt: t0,
            plannedDurationS: 600,
            subjectId: subjectId,
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
          ),
        );

    await ImportBackupUseCase(other)(json);

    expect(
      await other.sessionDao.findById('yabanci'),
      isNull,
      reason: 'geri yükleme BİRLEŞTİRMİYOR, değiştiriyor',
    );
    expect(await other.sessionDao.findById('bk_s0'), isNotNull);
  });

  test('BOZUK dosya veritabanına DOKUNMUYOR', () async {
    await seedHistory(db);
    final before = (await db.select(db.studySessions).get()).length;

    await expectLater(
      ImportBackupUseCase(db)('bu bir yedek değil'),
      throwsA(isA<BackupFormatException>()),
    );

    expect(
      (await db.select(db.studySessions).get()).length,
      before,
      reason: 'çözümleme yazmadan önce bitmeli',
    );
    expect((await db.settingsDao.ensure()).currentStreak, 11);
  });

  test('YABANCI JSON reddediliyor', () async {
    await seedHistory(db);
    await expectLater(
      ImportBackupUseCase(db)('{"format":"baska_uygulama"}'),
      throwsA(
        isA<BackupFormatException>().having(
          (e) => e.reason,
          'reason',
          BackupFailureReason.notOurBackup,
        ),
      ),
    );
    expect((await db.settingsDao.ensure()).currentStreak, 11);
  });

  test('dosya adı tarihli ve .json', () async {
    await db.settingsDao.ensure();
    await ExportBackupUseCase(db, share)(nowMs: t0, appVersion: '1.3.0+6');
    expect(share.fileName, endsWith('.json'));
    expect(share.fileName, contains('2025-08-06'));
  });

  test('paylaşım iptal edilirse null dönüyor', () async {
    await db.settingsDao.ensure();
    share.succeed = false;
    final r = await ExportBackupUseCase(db, share)(
      nowMs: t0,
      appVersion: '1.3.0+6',
    );
    expect(r, isNull, reason: 'iptal başarı sayılmamalı');
  });

  test('BOŞ veritabanı yedeklenip yüklenebiliyor', () async {
    // İlk gün yedek alan kullanıcı hata görmemeli.
    await db.settingsDao.ensure();
    final json = await exportFrom(db);

    final fresh = newDb();
    addTearDown(fresh.close);
    final r = await ImportBackupUseCase(fresh)(json);
    expect(r.sessions, 0);
    expect(await fresh.select(fresh.dailyStats).get(), isEmpty);
  });
}
