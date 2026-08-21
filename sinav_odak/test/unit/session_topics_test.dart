import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/application/usecases/start_session.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// v1.2/D — ÇOKLU KONU, veritabanı tarafı.
///
/// Bu dosyanın koruduğu asıl şey **denormalizasyon riski**:
/// `study_sessions.topic_id` birincil konuyu tutuyor, `session_topics`
/// tam listeyi. İkisi ayrışırsa oturum bir ekranda konusuz, başka bir
/// ekranda üç konulu görünür. Buradaki testler her yazma yolundan sonra
/// **`topic_id == session_topics[0]`** eşitliğini kontrol ediyor.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  const t1 = 'top_sub_yks_1_22'; // Türev
  const t2 = 'top_sub_yks_1_23'; // İntegral
  const t3 = 'top_sub_yks_1_0'; // Temel Kavramlar

  late StartSessionUseCase start;

  setUp(() {
    start = StartSessionUseCase(db, FakeNotifier(), FakeTracker());
  });

  Future<String> startWith(List<String> topicIds, {String id = 's1'}) async {
    await start(
      sessionId: id,
      schedule: schedule(),
      subjectId: subjectId,
      topicIds: topicIds,
      activityTypeId: activityId,
    );
    return id;
  }

  /// Şemanın iki tarafı hâlâ aynı şeyi mi söylüyor?
  Future<void> expectPrimaryMatchesList(String sessionId) async {
    final session = await db.sessionDao.findById(sessionId);
    final topics = await db.sessionDao.topicsOf(sessionId);
    expect(
      session!.topicId,
      topics.isEmpty ? isNull : topics.first.id,
      reason: 'topic_id ile session_topics[0] AYRIŞTI — bir ekran konusuz, '
          'diğeri konulu gösterir',
    );
  }

  group('oturum başlatma', () {
    test('tek konu: hem topic_id hem liste yazılıyor', () async {
      await startWith([t1]);

      final s = await db.sessionDao.findById('s1');
      expect(s!.topicId, t1);

      final topics = await db.sessionDao.topicsOf('s1');
      expect(topics.map((t) => t.id), [t1]);
      await expectPrimaryMatchesList('s1');
    });

    test('üç konu: birincil İLK, liste SIRAYLA', () async {
      await startWith([t2, t1, t3]);

      final s = await db.sessionDao.findById('s1');
      expect(s!.topicId, t2, reason: 'ilk seçilen birincil');

      final topics = await db.sessionDao.topicsOf('s1');
      expect(topics.map((t) => t.id), [t2, t1, t3]);
      await expectPrimaryMatchesList('s1');
    });

    test('konusuz: topic_id null, liste boş', () async {
      await startWith(const []);

      final s = await db.sessionDao.findById('s1');
      expect(s!.topicId, isNull);
      expect(await db.sessionDao.topicsOf('s1'), isEmpty);
      await expectPrimaryMatchesList('s1');
    });

    test('konular oturumla AYNI transaction içinde yazılıyor', () async {
      // Ayrı çağrıya bırakılsaydı arada uygulama ölünce `topic_id` dolu
      // ama liste boş bir oturum kalırdı.
      await startWith([t1, t2]);
      final rows = await db.select(db.sessionTopics).get();
      expect(rows, hasLength(2));
      expect(rows.every((r) => r.sessionId == 's1'), isTrue);
    });
  });

  group('setSessionTopics', () {
    test('listeyi DEĞİŞTİRİYOR ve birincili güncelliyor', () async {
      await startWith([t1]);

      await db.sessionDao.setSessionTopics('s1', [t2, t3]);

      final topics = await db.sessionDao.topicsOf('s1');
      expect(topics.map((t) => t.id), [t2, t3]);
      expect((await db.sessionDao.findById('s1'))!.topicId, t2);
      await expectPrimaryMatchesList('s1');
    });

    test('boş liste: oturum konusuza dönüyor', () async {
      await startWith([t1, t2]);

      await db.sessionDao.setSessionTopics('s1', const []);

      expect(await db.sessionDao.topicsOf('s1'), isEmpty);
      expect((await db.sessionDao.findById('s1'))!.topicId, isNull);
      await expectPrimaryMatchesList('s1');
    });

    test('eski satırlar SİLİNİYOR, birikmiyor', () async {
      await startWith([t1, t2, t3]);
      await db.sessionDao.setSessionTopics('s1', [t1]);

      final rows = await db.select(db.sessionTopics).get();
      expect(rows, hasLength(1));
    });

    test('aynı listeyi iki kez yazmak satır sayısını büyütmüyor', () async {
      await startWith([t1, t2]);
      await db.sessionDao.setSessionTopics('s1', [t1, t2]);
      await db.sessionDao.setSessionTopics('s1', [t1, t2]);

      expect(await db.sessionDao.topicsOf('s1'), hasLength(2));
    });
  });

  group('okuma', () {
    test('sıra sortOrder ile, ekleme sırasıyla DEĞİL', () async {
      await startWith([t3, t1, t2]);
      final topics = await db.sessionDao.topicsOf('s1');
      expect(topics.map((t) => t.id), [t3, t1, t2]);
    });

    test('ARŞİVLENMİŞ konu da dönüyor', () async {
      // Geçmiş bir oturumun başlığı, konu sonradan arşivlendi diye
      // boşalmamalı.
      await startWith([t1, t2]);
      await db.subjectDao.archiveTopic(t2);

      final topics = await db.sessionDao.topicsOf('s1');
      expect(topics.map((t) => t.id), [t1, t2]);
    });

    test('başka oturumun konuları karışmıyor', () async {
      await startWith([t1], id: 's1');
      await db.sessionDao.patchSession(
        's1',
        const StudySessionsCompanion(status: Value(SessionStatus.completed)),
      );
      await startWith([t2, t3], id: 's2');

      expect((await db.sessionDao.topicsOf('s1')).map((t) => t.id), [t1]);
      expect(
        (await db.sessionDao.topicsOf('s2')).map((t) => t.id),
        [t2, t3],
      );
    });
  });

  group('silme ve bütünlük', () {
    test('oturum silinince konu satırları da düşüyor (cascade)', () async {
      await startWith([t1, t2]);
      await db.sessionDao.deleteSession('s1');

      expect(await db.select(db.sessionTopics).get(), isEmpty);
    });

    test('olmayan konu eklenemiyor (foreign key)', () async {
      await startWith([t1]);
      await expectLater(
        db.sessionDao.setSessionTopics('s1', ['yok_boyle_konu']),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('v5 -> v6 yükseltmesi', () {
    test('mevcut oturumun TEK konusu listeye taşınıyor', () async {
      // v5 taklidi: tabloyu düşürüp `topic_id`si dolu bir oturum bırak,
      // sonra migration'ın yaptığı taşımayı uygula.
      final raw = AppDatabase(NativeDatabase.memory());
      await raw.into(raw.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'eski',
              dateKey: '2025-08-06',
              startedAt: t0,
              plannedDurationS: 1500,
              subjectId: subjectId,
              topicId: const Value(t1),
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
            ),
          );
      await raw.customStatement('DELETE FROM session_topics');

      expect(
        await raw.sessionDao.topicsOf('eski'),
        isEmpty,
        reason: 'taşıma öncesi durum kurulamadıysa bu test bir şey kanıtlamaz',
      );

      await raw.customStatement(
        'INSERT OR IGNORE INTO session_topics '
        '(session_id, topic_id, sort_order) '
        'SELECT id, topic_id, 0 FROM study_sessions WHERE topic_id IS NOT NULL',
      );

      final topics = await raw.sessionDao.topicsOf('eski');
      expect(topics.map((t) => t.id), [t1]);
      expect((await raw.sessionDao.findById('eski'))!.topicId, t1);

      await raw.close();
    });

    test('konusuz eski oturum konusuz KALIYOR', () async {
      final raw = AppDatabase(NativeDatabase.memory());
      await raw.into(raw.studySessions).insert(
            StudySessionsCompanion.insert(
              id: 'konusuz',
              dateKey: '2025-08-06',
              startedAt: t0,
              plannedDurationS: 1500,
              subjectId: subjectId,
              activityTypeId: activityId,
              status: SessionStatus.completed,
              scheduleJson: '{}',
            ),
          );
      await raw.customStatement(
        'INSERT OR IGNORE INTO session_topics '
        '(session_id, topic_id, sort_order) '
        'SELECT id, topic_id, 0 FROM study_sessions WHERE topic_id IS NOT NULL',
      );

      expect(await raw.sessionDao.topicsOf('konusuz'), isEmpty);
      await raw.close();
    });
  });
}
