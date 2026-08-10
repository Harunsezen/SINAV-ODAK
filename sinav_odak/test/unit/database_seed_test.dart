import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/local/seed_data.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('seed verisi kurulumda yükleniyor', () async {
    final acts = await db.subjectDao.watchActivityTypes().first;
    expect(acts.length, 11, reason: 'spec bölüm 8: 11 çalışma türü');

    final yks = await db.subjectDao.watchSubjects(ExamType.yks).first;
    expect(yks.length, 15);
    expect(yks.first.name, 'Türkçe');

    final lgs = await db.subjectDao.watchSubjects(ExamType.lgs).first;
    expect(lgs.length, 8);
  });

  test('ayar satırı tek ve varsayılanları doğru', () async {
    final s = await db.settingsDao.ensure();
    expect(s.id, 'me');
    expect(s.netPenaltyCoefficient, 4.0);
    expect(s.dailyGoalMinutes, 240);
    expect(
      s.personalizedAdsConsent,
      isFalse,
      reason: 'KVKK/GDPR: kişiselleştirilmiş reklam varsayılan KAPALI',
    );
    expect(s.onboardingCompleted, isFalse);

    // ensure() ikinci çağrıda kopya oluşturmamalı
    await db.settingsDao.ensure();
    final all = await db.select(db.userSettings).get();
    expect(all.length, 1);
  });

  test('konu seed edilmiş derse bağlı', () async {
    final topics = await db.subjectDao.watchTopics('sub_yks_1').first;
    expect(topics, isNotEmpty);
    expect(topics.any((t) => t.name == 'Türev'), isTrue);
    expect(topics.every((t) => t.isCompleted == false), isTrue);
  });

  test('foreign key: olmayan derse konu eklenemez', () async {
    await expectLater(
      db.subjectDao.createTopic(
        id: 'top_bad',
        subjectId: 'yok_boyle_bir_ders',
        name: 'Test',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('seed idempotent: populate iki kez çalışabilir (P0-06)', () async {
    final before = await db.select(db.subjects).get();
    await SeedData.populate(db);
    final after = await db.select(db.subjects).get();
    expect(after.length, before.length, reason: 'PK çakışması olmamalı');
  });

  test('ayar satırı silinse bile watch hataya düşmez (P0-07)', () async {
    await db.settingsDao.ensure();
    await db.delete(db.userSettings).go();

    final first = await db.settingsDao.watch().first;
    expect(first, isNull,
        reason: 'watchSingleOrNull null dönmeli, fırlatmamalı');

    final restored = await db.settingsDao.ensure();
    expect(restored.id, 'me');
  });

  test('ders silinmez, arşivlenir', () async {
    await db.subjectDao.setArchived('sub_yks_8', archived: true);
    final visible = await db.subjectDao.watchSubjects(ExamType.yks).first;
    expect(visible.any((s) => s.id == 'sub_yks_8'), isFalse);

    final stillThere = await db.subjectDao.findSubject('sub_yks_8');
    expect(stillThere, isNotNull);
  });
}
