import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/curriculum_data.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/data/local/seed_data.dart';
import 'package:sinav_odak/domain/entities/enums.dart';

/// v1.2 — MÜFREDAT TOHUMLAMASI.
///
/// Bu dosya iki ayrı şeyi koruyor:
///
/// 1. **Veri bütünlüğü**: konusuz ders kalmasın, aynı derste yinelenen ad
///    olmasın, alt dal yetim kalmasın, ağaç ikiden derin olmasın.
/// 2. **Yükseltme güvenliği**: v1.1'den gelen konuların KİMLİĞİ değişmesin
///    ve aynı konu iki satıra bölünmesin. Kimlik değişirse geçmiş
///    oturumlar ve yanlış defteri kayıtları boşluğa bağlanır.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<Topic>> topicsOf(String subjectId) =>
      (db.select(db.topics)..where((t) => t.subjectId.equals(subjectId))).get();

  group('veri bütünlüğü', () {
    test('SIFIR KONULU DERS YOK', () async {
      final subjects = await db.select(db.subjects).get();
      final topics = await db.select(db.topics).get();
      expect(subjects, isNotEmpty);

      final bos = <String>[];
      for (final s in subjects) {
        if (!topics.any((t) => t.subjectId == s.id)) {
          bos.add('${s.examType.name}/${s.name}');
        }
      }
      expect(
        bos,
        isEmpty,
        reason: 'konusuz ders, konu seçme ekranını boş bırakıp oturum '
            'kurulumunu çıkmaza sokuyor',
      );
    });

    test('aynı derste yinelenen konu adı yok', () async {
      final topics = await db.select(db.topics).get();
      final seen = <String>{};
      final dup = <String>[];
      for (final t in topics) {
        if (!seen.add('${t.subjectId} ${t.name}')) {
          dup.add('${t.subjectId}/${t.name}');
        }
      }
      expect(
        dup,
        isEmpty,
        reason: 'aynı ad iki satır = bölünmüş istatistik, kullanıcı hangi '
            'satıra çalıştığını bilemez',
      );
    });

    test('konu kimlikleri benzersiz', () async {
      final topics = await db.select(db.topics).get();
      expect(topics.map((t) => t.id).toSet().length, topics.length);
    });

    test('alt dal yetim değil, aynı derste ve TEK seviye derin', () async {
      final topics = await db.select(db.topics).get();
      final byId = {for (final t in topics) t.id: t};

      for (final t in topics) {
        final pid = t.parentId;
        if (pid == null) continue;
        final parent = byId[pid];
        expect(parent, isNotNull, reason: '${t.name} yetim alt dal');
        expect(
          parent!.subjectId,
          t.subjectId,
          reason: 'alt dal başka bir dersin konusuna bağlanmış',
        );
        expect(
          parent.parentId,
          isNull,
          reason: 'ağaç 3 seviye: ders > konu > alt dal. Dördüncü seviye '
              'ekranda çizilmiyor, kaydedilirse GÖRÜNMEZ olur',
        );
      }
    });

    test('alt dal, üst konunun sınıf ve etiketini devralıyor', () async {
      final topics = await db.select(db.topics).get();
      final byId = {for (final t in topics) t.id: t};
      for (final t in topics) {
        final parent = t.parentId == null ? null : byId[t.parentId!];
        if (parent == null) continue;
        expect(t.grade, parent.grade, reason: t.name);
        expect(t.examTag, parent.examTag, reason: t.name);
      }
    });
  });

  group('seviye sekmeleri', () {
    test('5–12 arası HER sınıfın konusu var', () async {
      final topics = await db.select(db.topics).get();
      for (var g = 5; g <= 12; g++) {
        expect(
          topics.where((t) => t.grade == g),
          isNotEmpty,
          reason: '$g. sınıf sekmesi boş açılırdı',
        );
      }
    });

    test('TYT ve AYT süzgeçleri boş değil', () async {
      final topics = await db.select(db.topics).get();
      expect(
        topics.where((t) => t.examTag?.contains('tyt') ?? false),
        isNotEmpty,
      );
      expect(
        topics.where((t) => t.examTag?.contains('ayt') ?? false),
        isNotEmpty,
      );
    });

    test('etiket yalnızca tyt/ayt değerlerinden kuruluyor', () async {
      final topics = await db.select(db.topics).get();
      const izin = {'tyt', 'ayt', 'tyt,ayt'};
      for (final t in topics) {
        if (t.examTag == null) continue;
        expect(izin, contains(t.examTag), reason: '${t.name}: ${t.examTag}');
      }
    });

    test('sınıf düzeyi 5–12 aralığının dışına çıkmıyor', () async {
      final topics = await db.select(db.topics).get();
      for (final t in topics) {
        if (t.grade == null) continue;
        expect(t.grade, inInclusiveRange(5, 12), reason: t.name);
      }
    });
  });

  group('sınava göre süzme', () {
    test('LGS: 9. sınıf ve üstü konu YOK', () async {
      final lgs = await db.select(db.subjects).get();
      final ids =
          lgs.where((s) => s.examType == ExamType.lgs).map((s) => s.id).toSet();
      final topics = await db.select(db.topics).get();
      final fazla = topics.where(
        (t) => ids.contains(t.subjectId) && (t.grade ?? 0) > 8,
      );
      expect(fazla, isEmpty, reason: 'LGS adayına lise konusu gösterilmez');
    });

    test('LGS: TYT/AYT etiketi taşınmıyor', () async {
      final subs = await db.select(db.subjects).get();
      final ids = subs
          .where((s) => s.examType == ExamType.lgs)
          .map((s) => s.id)
          .toSet();
      final topics = await db.select(db.topics).get();
      for (final t in topics.where((t) => ids.contains(t.subjectId))) {
        expect(t.examTag, isNull, reason: 'LGS\'de TYT/AYT oturumu yok');
      }
    });

    test('LGS Matematik 8. sınıf geometrisini kaybetmiyor', () async {
      // Sınıf süzgeci tek başına bunu eliyordu: YKS listesinde geometri
      // 9–12'de. LGS'nin kendi listesi olmasaydı aday yarım müfredatla
      // kalırdı.
      final names = (await topicsOf('sub_lgs_1')).map((t) => t.name).toSet();
      expect(names, containsAll(['Üçgenler', 'Dönüşüm Geometrisi']));
      expect(names, containsAll(['Eşlik ve Benzerlik', 'Geometrik Cisimler']));
    });

    test('LGS Türkçe 8. sınıf dil bilgisini kaybetmiyor', () async {
      final names = (await topicsOf('sub_lgs_0')).map((t) => t.name).toSet();
      expect(names, containsAll(['Fiilimsiler', 'Cümlenin Ögeleri']));
      expect(names, containsAll(['Fiilde Çatı', 'Anlatım Bozuklukları']));
    });

    test('KPSS/ALES/DGS: sınıf düzeyi taşınmıyor', () async {
      final subs = await db.select(db.subjects).get();
      const sinifsiz = {ExamType.kpss, ExamType.ales, ExamType.dgs};
      final ids = subs
          .where((s) => sinifsiz.contains(s.examType))
          .map((s) => s.id)
          .toSet();
      final topics = await db.select(db.topics).get();
      for (final t in topics.where((t) => ids.contains(t.subjectId))) {
        expect(
          t.grade,
          isNull,
          reason: 'KPSS adayına "9. sınıf" demek anlamsız',
        );
      }
    });

    test('bilinmeyen ders çökmüyor, boş liste dönüyor', () {
      expect(
        CurriculumData.forSubject(ExamType.yks, 'Yok Böyle Ders'),
        isEmpty,
      );
    });
  });

  group('v1.1 yükseltmesi', () {
    test('v1.1 konu kimlikleri KORUNUYOR', () async {
      // Bu kimlikler geçmiş oturumlarda ve yanlış defterinde yazılı.
      // Değişirlerse o kayıtlar konusuz kalır.
      final turev = await (db.select(db.topics)
            ..where((t) => t.id.equals('top_sub_yks_1_22')))
          .getSingleOrNull();
      expect(turev?.name, 'Türev');

      final ilk = await (db.select(db.topics)
            ..where((t) => t.id.equals('top_sub_yks_0_0')))
          .getSingleOrNull();
      expect(ilk?.name, 'Sözcükte Anlam');
    });

    test('v1.1 adı yeniden adlandırıldı, İKİZLENMEDİ', () async {
      final mat = await topicsOf('sub_yks_1');
      final names = mat.map((t) => t.name).toList();

      expect(names, isNot(contains('Köklü Sayılar')));
      expect(names, contains('Kareköklü İfadeler'));

      // Kimlik eski satırın kimliği: UPDATE yapıldı, yeni satır açılmadı.
      final k = mat.firstWhere((t) => t.name == 'Kareköklü İfadeler');
      expect(k.id, 'top_sub_yks_1_8');
      expect(k.grade, 8, reason: 'boş kalan sınıf alanı müfredattan doldu');
    });

    test('yükseltme tekrarı satır sayısını büyütmüyor', () async {
      final before = (await db.select(db.topics).get()).length;
      await SeedData.populate(db);
      await SeedData.populate(db);
      final after = (await db.select(db.topics).get()).length;
      expect(after, before, reason: 'her açılışta katalog şişemez');
    });

    test('v1.1 biçimli satır ikizlenmiyor', () async {
      // Gerçek yükseltme taklidi: dersin konularını silip v1.1 Kimya
      // listesini AYNI adlar ve AYNI indeks kimlikleriyle geri yaz, sonra
      // tohumlamayı yeniden çalıştır. Kısmi bir taklit (birkaç satır)
      // yanlış indeks kullanıp gerçekte olmayan bir ikizlenme üretiyordu —
      // liste birebir olmalı.
      await (db.delete(db.topics)
            ..where((t) => t.subjectId.equals('sub_yks_4')))
          .go();
      const eski = [
        'Kimya Bilimi',
        'Atom ve Periyodik Sistem',
        'Kimyasal Türler Arası Etkileşim',
        'Maddenin Halleri',
        'Kimyanın Temel Kanunları',
        'Mol Kavramı',
        'Karışımlar',
        'Asit–Baz–Tuz',
        'Kimya Her Yerde',
        'Modern Atom Teorisi',
        'Gazlar',
        'Çözeltiler',
        'Kimyasal Tepkimelerde Enerji',
        'Kimyasal Denge',
        'Organik Kimya',
      ];
      for (var i = 0; i < eski.length; i++) {
        await db.into(db.topics).insert(
              TopicsCompanion.insert(
                id: 'top_sub_yks_4_$i',
                subjectId: 'sub_yks_4',
                name: eski[i],
                sortOrder: Value(i),
                createdAt: 1754467200000,
              ),
            );
      }

      await SeedData.populate(db);

      final after = await topicsOf('sub_yks_4');
      final names = after.map((t) => t.name).toList();

      // Eski adlar kalmadı...
      expect(names, isNot(contains('Maddenin Halleri')));
      expect(names, isNot(contains('Çözeltiler')));
      expect(names, isNot(contains('Kimyasal Denge')));

      // ...ve kanonik adlar TEK satır.
      for (final n in const [
        'Maddenin Hâlleri',
        'Sıvı Çözeltiler',
        'Tepkime Hızı ve Denge',
        'Asitler Bazlar ve Tuzlar',
        'Doğa ve Kimya',
      ]) {
        expect(names.where((x) => x == n).length, 1, reason: n);
      }

      // Kimlik eski satırınki kaldı: bağlı oturumlar kopmadı.
      expect(
        after.firstWhere((t) => t.name == 'Sıvı Çözeltiler').id,
        'top_sub_yks_4_11',
      );
      expect(
        after.firstWhere((t) => t.name == 'Maddenin Hâlleri').id,
        'top_sub_yks_4_3',
      );
    });

    test('kullanıcının doldurduğu alan EZİLMİYOR', () async {
      await (db.update(db.topics)
            ..where((t) => t.id.equals('top_sub_yks_1_22')))
          .write(const TopicsCompanion(grade: Value(7), examTag: Value('tyt')));

      await SeedData.populate(db);

      final t = await (db.select(db.topics)
            ..where((x) => x.id.equals('top_sub_yks_1_22')))
          .getSingleOrNull();
      expect(t?.grade, 7, reason: 'kullanıcı taşımışsa müfredat geri almaz');
      expect(t?.examTag, 'tyt');
    });
  });

  group('müfredat sözlüğü', () {
    test('her ders adı seed listesinde karşılık buluyor', () async {
      final subjects = await db.select(db.subjects).get();
      final adlar = subjects.map((s) => s.name).toSet();
      for (final ders in CurriculumData.bySubject.keys) {
        expect(
          adlar,
          contains(ders),
          reason: '$ders müfredatta var ama hiçbir sınavın ders listesinde '
              'yok — kimse göremez',
        );
      }
    });

    test('alt dal adı, üst konu adıyla çakışmıyor', () async {
      for (final entry in CurriculumData.bySubject.entries) {
        final seen = <String>{};
        for (final t in entry.value) {
          expect(seen.add(t.name), isTrue, reason: '${entry.key}: ${t.name}');
          for (final c in t.children ?? const <String>[]) {
            expect(seen.add(c), isTrue, reason: '${entry.key}: $c');
          }
        }
      }
    });
  });
}
