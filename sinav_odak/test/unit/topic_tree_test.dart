import 'package:flutter_test/flutter_test.dart';
import 'package:sinav_odak/data/local/database.dart';
import 'package:sinav_odak/presentation/curriculum/topic_tree.dart';

/// v1.2 — konu ağacının SAF mantığı.
///
/// Ağaç kurma, seviye süzme ve arama Flutter'a bağımlı değil; burada
/// widget kurmadan test ediliyor. Ekran testleri (bkz.
/// `curriculum_screen_test.dart`) bu kuralların ARAYÜZE bağlandığını
/// doğruluyor, kuralların kendisini değil.
void main() {
  Topic t(
    String id,
    String name, {
    String? parentId,
    int? grade,
    String? tag,
    String subject = 'sub',
  }) =>
      Topic(
        id: id,
        subjectId: subject,
        name: name,
        isCompleted: false,
        sortOrder: 0,
        parentId: parentId,
        grade: grade,
        examTag: tag,
        isArchived: false,
        createdAt: 1754467200000,
      );

  final flat = <Topic>[
    t('a', 'Hücre', grade: 9, tag: 'tyt'),
    t('a1', 'Hücre Organelleri', parentId: 'a', grade: 9, tag: 'tyt'),
    t('a2', 'Madde Geçişleri', parentId: 'a', grade: 9, tag: 'tyt'),
    t('b', 'Hücre Bölünmeleri', grade: 10, tag: 'tyt,ayt'),
    t('b1', 'Mitoz', parentId: 'b', grade: 10, tag: 'tyt,ayt'),
    t('b2', 'Mayoz', parentId: 'b', grade: 10, tag: 'tyt,ayt'),
    t('c', 'Genden Proteine', grade: 12, tag: 'ayt'),
    t('d', 'Genel Deneme'),
  ];

  group('ağaç kurma', () {
    test('üst konular kök, alt dallar altında', () {
      final tree = buildTopicTree(flat);
      expect(tree.map((n) => n.topic.id), ['a', 'b', 'c', 'd']);
      expect(tree[0].children.map((c) => c.name), [
        'Hücre Organelleri',
        'Madde Geçişleri',
      ]);
      expect(tree[3].hasChildren, isFalse);
    });

    test('üst konusu listede olmayan alt dal KÖK sayılıyor', () {
      // Üst konu arşivlenmiş olabilir. Alt dalı büsbütün gizlemek,
      // kullanıcının çalıştığı satırı ekrandan silmek olurdu.
      final tree = buildTopicTree([
        t('x1', 'Öksüz Alt Dal', parentId: 'yok'),
      ]);
      expect(tree, hasLength(1));
      expect(tree.single.topic.name, 'Öksüz Alt Dal');
    });

    test('boş liste boş ağaç', () {
      expect(buildTopicTree(const []), isEmpty);
    });
  });

  group('seviye sekmeleri', () {
    test('yalnızca VERİDE geçen seviyeler dönüyor', () {
      final levels = availableLevels(flat);
      expect(levels.first.isAll, isTrue);
      expect(
        levels.map((l) => l.isAll ? 'all' : (l.tag ?? '${l.grade}')),
        ['all', 'tyt', 'ayt', '9', '10', '12'],
        reason: '11. sınıf veride yok — sekmesi de olmamalı',
      );
    });

    test('etiketsiz ve sınıfsız katalogda yalnızca "Tümü"', () {
      final levels = availableLevels([t('d', 'Genel Deneme')]);
      expect(levels, hasLength(1));
      expect(levels.single.isAll, isTrue);
    });

    test('çift etiket iki sekmeye birden giriyor', () {
      final tyt = filterTopicTree(
        buildTopicTree(flat),
        level: const TopicLevel.tag('tyt'),
      );
      final ayt = filterTopicTree(
        buildTopicTree(flat),
        level: const TopicLevel.tag('ayt'),
      );
      expect(tyt.map((n) => n.topic.id), ['a', 'b']);
      expect(ayt.map((n) => n.topic.id), ['b', 'c']);
    });

    test('sınıf süzgeci', () {
      final g10 = filterTopicTree(
        buildTopicTree(flat),
        level: const TopicLevel.grade(10),
      );
      expect(g10.map((n) => n.topic.name), ['Hücre Bölünmeleri']);
      expect(g10.single.children, hasLength(2), reason: 'alt dallar düşmüyor');
    });
  });

  group('arama', () {
    test('üst konu adında eşleşme', () {
      final r = filterTopicTree(buildTopicTree(flat), query: 'genden');
      expect(r.map((n) => n.topic.name), ['Genden Proteine']);
    });

    test('ALT DAL adında eşleşme — üst konu başlık olarak kalıyor', () {
      // "Mitoz" yazan kullanıcı onu "Hücre Bölünmeleri"nin altında
      // aramak zorunda kalmamalı.
      final r = filterTopicTree(buildTopicTree(flat), query: 'mitoz');
      expect(r, hasLength(1));
      expect(r.single.topic.name, 'Hücre Bölünmeleri');
      expect(
        r.single.children.map((c) => c.name),
        ['Mitoz'],
        reason: 'eşleşmeyen alt dallar tek sonucu gömerdi',
      );
    });

    test('üst konu eşleşince TÜM alt dallar geliyor', () {
      final r = filterTopicTree(buildTopicTree(flat), query: 'bölünme');
      expect(r.single.children, hasLength(2));
    });

    test('Türkçe büyük/küçük harf ve aksan', () {
      // 'İ'.toLowerCase() birleşik noktalı i üretiyor; ham karşılaştırma
      // "İkinci" aramasını "ikinci" ile eşleştirmiyordu.
      final list = [t('e', 'İkinci Dereceden Denklemler')];
      for (final q in ['İkinci', 'ikinci', 'IKINCI', 'ıkıncı']) {
        expect(
          filterTopicTree(buildTopicTree(list), query: q),
          hasLength(1),
          reason: q,
        );
      }
    });

    test('eşleşme yoksa boş', () {
      expect(filterTopicTree(buildTopicTree(flat), query: 'zzzz'), isEmpty);
    });

    test('boş ve boşluklu arama süzmüyor', () {
      expect(filterTopicTree(buildTopicTree(flat), query: ''), hasLength(4));
      expect(filterTopicTree(buildTopicTree(flat), query: '   '), hasLength(4));
    });

    test('arama ve seviye BİRLİKTE uygulanıyor', () {
      final r = filterTopicTree(
        buildTopicTree(flat),
        level: const TopicLevel.grade(9),
        query: 'hücre',
      );
      expect(
        r.map((n) => n.topic.name),
        ['Hücre'],
        reason: '10. sınıftaki "Hücre Bölünmeleri" seviye süzgecine takılmalı',
      );
    });
  });

  group('normalizeTopicQuery', () {
    test('Türkçe harfleri ASCII\'ye indiriyor', () {
      expect(normalizeTopicQuery('Çözelti'), 'cozelti');
      expect(normalizeTopicQuery('Işık'), 'isik');
      expect(normalizeTopicQuery('  Ölçme  '), 'olcme');
    });
  });

  group('TopicLevel', () {
    test('eşitlik değere göre — sekme seçimi kimliğe bağlı olamaz', () {
      expect(const TopicLevel.grade(9), const TopicLevel.grade(9));
      expect(const TopicLevel.tag('tyt'), const TopicLevel.tag('tyt'));
      expect(const TopicLevel.grade(9), isNot(const TopicLevel.grade(10)));
      expect(TopicLevel.all.isAll, isTrue);
    });

    test('etiket süzmesi tam parça eşleşiyor', () {
      // 'tyt,ayt' içinde `contains('ayt')` düz metinde de doğru döner ama
      // 'ayt' arayan bir sekmenin 'ayt2' gibi bir etikete takılmaması için
      // parçalara ayrılıyor.
      final t1 = Topic(
        id: 'x',
        subjectId: 's',
        name: 'n',
        isCompleted: false,
        sortOrder: 0,
        examTag: 'tyt,ayt',
        isArchived: false,
        createdAt: 0,
      );
      expect(const TopicLevel.tag('tyt').matches(t1), isTrue);
      expect(const TopicLevel.tag('ayt').matches(t1), isTrue);
      expect(const TopicLevel.tag('ydt').matches(t1), isFalse);
    });
  });
}
