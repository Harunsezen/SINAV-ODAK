import '../../data/local/database.dart';

/// Konu ağacının bir dalı: bir konu ve ona bağlı alt dallar.
///
/// Ağaç **üç seviye**: ders > konu > alt dal. Dördüncü seviye yok —
/// `parentId`'si başka bir alt dala bakan satır tohumlanmıyor ve ekran
/// çizmiyor (bkz. `curriculum_seed_test.dart`).
class TopicNode {
  const TopicNode(this.topic, this.children, {int? totalChildren})
      : _totalChildren = totalChildren;

  final Topic topic;

  /// GÖRÜNEN alt dallar. Arama süzdüğünde bu liste kısalıyor.
  final List<Topic> children;

  final int? _totalChildren;

  /// Konunun **gerçek** alt dal sayısı — arama süzse bile değişmiyor.
  ///
  /// Ekranda "2 alt dal" yazan bir konu, "mitoz" araması yüzünden "1 alt
  /// dal"a düşerse kullanıcıya müfredat hakkında yanlış bilgi verilmiş
  /// olur. Süzgeç ne gösterileceğini belirler, kaç tane OLDUĞUNU değil.
  int get totalChildren => _totalChildren ?? children.length;

  bool get hasChildren => totalChildren > 0;
}

/// Seviye süzgeci: "Tümü", bir sınıf düzeyi ya da bir sınav etiketi.
///
/// Sekmeler **veriden** üretiliyor, sabit listeden değil: KPSS kataloğunda
/// sınıf düzeyi yok, LGS'de TYT/AYT yok. Sabit sekme listesi bu iki durumda
/// da boş sekmeler çizerdi — kullanıcı dokunur, hiçbir şey görmez.
class TopicLevel {
  const TopicLevel._(this.grade, this.tag);

  /// Süzme yok.
  static const all = TopicLevel._(null, null);

  const TopicLevel.grade(int this.grade) : tag = null;
  const TopicLevel.tag(String this.tag) : grade = null;

  final int? grade;
  final String? tag;

  bool get isAll => grade == null && tag == null;

  bool matches(Topic t) {
    if (isAll) return true;
    if (grade != null) return t.grade == grade;
    return t.examTag?.split(',').contains(tag) ?? false;
  }

  @override
  bool operator ==(Object other) =>
      other is TopicLevel && other.grade == grade && other.tag == tag;

  @override
  int get hashCode => Object.hash(grade, tag);
}

/// Düz konu listesinden ağacı kurar.
///
/// `parentId` dolu ama üst konusu listede olmayan satır **kendi başına
/// konu** sayılıyor. Üst konu arşivlenmiş olabilir; alt dalı büsbütün
/// gizlemek, kullanıcının çalıştığı konuyu ekrandan silmek olurdu.
List<TopicNode> buildTopicTree(List<Topic> flat) {
  final ids = {for (final t in flat) t.id};
  final children = <String, List<Topic>>{};
  final roots = <Topic>[];

  for (final t in flat) {
    final p = t.parentId;
    if (p != null && ids.contains(p)) {
      (children[p] ??= <Topic>[]).add(t);
    } else {
      roots.add(t);
    }
  }

  return [
    for (final r in roots) TopicNode(r, children[r.id] ?? const <Topic>[]),
  ];
}

/// Katalogda geçen seviyeler, sekme sırasıyla: Tümü · TYT · AYT · 5…12.
///
/// Yalnızca **veride karşılığı olan** seviyeler dönüyor.
List<TopicLevel> availableLevels(List<Topic> flat) {
  final tags = <String>{};
  final grades = <int>{};
  for (final t in flat) {
    final tag = t.examTag;
    if (tag != null) tags.addAll(tag.split(','));
    if (t.grade != null) grades.add(t.grade!);
  }

  return [
    TopicLevel.all,
    if (tags.contains('tyt')) const TopicLevel.tag('tyt'),
    if (tags.contains('ayt')) const TopicLevel.tag('ayt'),
    for (final g in grades.toList()..sort()) TopicLevel.grade(g),
  ];
}

/// Arama ve seviye süzgeci uygulanmış ağaç.
///
/// Arama **alt dalları da** tarıyor: "Mitoz" yazan kullanıcı onu "Hücre
/// Bölünmeleri"nin altında bulmak zorunda kalmamalı. Yalnızca alt dal
/// eşleşirse üst konu başlık olarak kalıyor ama **sadece eşleşen alt
/// dallar** listeleniyor — eşleşmeyen otuz dal aradaki tek sonucu gömerdi.
List<TopicNode> filterTopicTree(
  List<TopicNode> tree, {
  TopicLevel level = TopicLevel.all,
  String query = '',
}) {
  final q = normalizeTopicQuery(query);
  final out = <TopicNode>[];

  for (final node in tree) {
    // Alt dal, üst konunun sınıfını ve etiketini devralıyor; seviye kararı
    // üst konudan okunuyor.
    if (!level.matches(node.topic)) continue;

    if (q.isEmpty) {
      out.add(node);
      continue;
    }

    final parentHit = normalizeTopicQuery(node.topic.name).contains(q);
    final childHits = [
      for (final c in node.children)
        if (normalizeTopicQuery(c.name).contains(q)) c,
    ];

    if (parentHit) {
      out.add(node);
    } else if (childHits.isNotEmpty) {
      out.add(
        TopicNode(node.topic, childHits, totalChildren: node.totalChildren),
      );
    }
  }

  return out;
}

/// Aramayı Türkçe'ye dayanıklı hâle getirir.
///
/// `toLowerCase()` tek başına yetmiyor: 'İ' birleşik noktalı i üretiyor ve
/// "İkinci" araması "ikinci" ile eşleşmiyor. Ayrıca aksanlı harfler
/// ASCII'ye indiriliyor — telefon klavyesinde 'ı' yerine 'i' yazan
/// kullanıcı sonucu bulamamalı diye bir kural yok.
String normalizeTopicQuery(String raw) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final lower = raw.replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
  final b = StringBuffer();
  for (final ch in lower.split('')) {
    b.write(map[ch] ?? ch);
  }
  return b.toString().trim();
}
