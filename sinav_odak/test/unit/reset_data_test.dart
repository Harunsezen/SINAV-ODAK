import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/domain/entities/ad_placement.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

import 'usecase_helpers.dart';

/// FAZ 7A — "Verileri sıfırla" (veri katmanı).
///
/// Arayüzdeki çift onay ayrı test ediliyor; burada silinenin gerçekten
/// silindiği ve fabrika ayarlarının geri geldiği doğrulanıyor.
void main() {
  late AppDatabase db;

  setUp(() => db = newDb());
  tearDown(() async => db.close());

  Future<void> seedEverything() async {
    await db.settingsDao.ensure();
    await db.settingsDao.patchSettings(
      const UserSettingsCompanion(
        onboardingCompleted: Value(true),
        currentStreak: Value(9),
        dailyGoalMinutes: Value(600),
      ),
    );

    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 's1',
            dateKey: '2025-08-06',
            startedAt: t0,
            plannedDurationS: 2880,
            subjectId: subjectId,
            topicId: const Value(topicId),
            activityTypeId: activityId,
            status: SessionStatus.completed,
            scheduleJson: '{}',
            actualDurationS: const Value(2880),
            questionCount: const Value(10),
            correctCount: const Value(8),
            wrongCount: const Value(2),
            net: const Value(7.5),
            endedAt: const Value(t0 + 2880000),
          ),
        );
    await db.statsDao.recomputeDay('2025-08-06');

    await db.wrongItemDao.addManual(
      id: 'w1',
      subjectId: subjectId,
      topicId: topicId,
      note: 'Türev sorusu',
    );

    await db.adEventDao.logShown(
      id: 'ad1',
      placement: AdPlacement.homeBanner,
      shownAtMs: t0,
    );

    // Kullanıcının kendi eklediği ders de silinmeli.
    await db.subjectDao.createSubject(
      id: 'custom-1',
      name: 'Kendi Dersim',
      colorHex: '#123456',
      exam: ExamType.yks,
    );
  }

  test('ön koşul: veriler yazılmış', () async {
    await seedEverything();
    expect(await db.sessionDao.findById('s1'), isNotNull);
    expect((await db.statsDao.summaryFor(day, day)).sessionCount, 1);
  });

  test('oturumlar ve günlük özet siliniyor', () async {
    await seedEverything();
    await db.resetAllData();

    expect(await db.sessionDao.findById('s1'), isNull);
    expect((await db.statsDao.summaryFor(day, day)).sessionCount, 0);
  });

  test('yanlış defteri siliniyor', () async {
    await seedEverything();
    await db.resetAllData();

    expect(await db.select(db.wrongItems).get(), isEmpty);
  });

  test('reklam logları siliniyor', () async {
    await seedEverything();
    await db.resetAllData();

    expect(await db.select(db.adEvents).get(), isEmpty);
  });

  test('kullanıcının eklediği ders siliniyor', () async {
    await seedEverything();
    await db.resetAllData();

    expect(await db.subjectDao.findSubject('custom-1'), isNull);
  });

  test('varsayılan katalog GERİ GELİYOR', () async {
    await seedEverything();
    await db.resetAllData();

    // Seed yeniden çalışmalı: aksi halde kullanıcı ders listesi boş bir
    // uygulamayla kalır ve oturum başlatamaz.
    expect(await db.select(db.subjects).get(), isNotEmpty);
    expect(await db.select(db.activityTypes).get(), isNotEmpty);
    expect(await db.select(db.topics).get(), isNotEmpty);
  });

  test('ayarlar fabrika değerlerine dönüyor', () async {
    await seedEverything();
    await db.resetAllData();

    final s = await db.settingsDao.read();
    expect(s.onboardingCompleted, isFalse, reason: 'onboarding baştan başlar');
    expect(s.currentStreak, 0);
    expect(s.dailyGoalMinutes, 240);
    expect(
      s.personalizedAdsConsent,
      isFalse,
      reason: 'rıza sıfırlanınca KAPALI olmalı (KVKK)',
    );
  });

  test('sıfırlama sonrası yeni oturum yazılabiliyor', () async {
    await seedEverything();
    await db.resetAllData();

    // Seed'lenen katalogdan bir ders/tür alıp yeni oturum yaz: foreign key
    // zinciri sağlam mı, gerçek kanıtı bu.
    final subject = (await db.select(db.subjects).get()).first;
    final activity = (await db.select(db.activityTypes).get()).first;

    await db.into(db.studySessions).insert(
          StudySessionsCompanion.insert(
            id: 'yeni',
            dateKey: '2025-08-07',
            startedAt: t0,
            plannedDurationS: 1200,
            subjectId: subject.id,
            activityTypeId: activity.id,
            status: SessionStatus.completed,
            scheduleJson: '{}',
          ),
        );

    expect(await db.sessionDao.findById('yeni'), isNotNull);
  });

  test('boş veritabanında sıfırlama patlamıyor', () async {
    await db.settingsDao.ensure();
    await db.resetAllData();

    expect(await db.select(db.subjects).get(), isNotEmpty);
  });
}

/// Sabit gün — testlerde `DateTime.now()` KULLANILMAZ.
final day = DateTime.parse('2025-08-06');
