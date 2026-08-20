import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../data/local/database.dart';
import '../shell/app_shell.dart';
import 'topic_tree.dart';

/// Üç seviyeli konu ağacı: **ders > konu > alt dal**.
///
/// Ders seviyesi çağıran ekranda (konu seçici dersin içinde açılıyor,
/// müfredat ekranında ders sekmeleri var); bu widget konu ve alt dal
/// seviyelerini çiziyor.
///
/// ## Neden ağaç gerekti
///
/// v1.2 müfredatı bir derse 80'e yakın satır getiriyor. v1.1'in düz
/// listesi bu boyutta okunamaz: kullanıcı "Mitoz"u bulmak için otuz kez
/// kaydırıyordu. Ağaç + arama + seviye süzgeci üçü birlikte olmadan
/// müfredat verisi ekranı kullanılamaz hâle getirirdi.
///
/// ## Seviye sekmeleri neden `ChoiceChip`
///
/// `TabBar` sekme sayısı değişince `TabController`'ın yeniden kurulmasını
/// istiyor; burada sekmeler VERİDEN üretiliyor ve derse göre değişiyor
/// (KPSS'te sınıf yok, LGS'de TYT/AYT yok). Kaydırılabilir chip satırı aynı
/// işi yapıyor, 320 px genişlikte de taşmıyor ve seçili durumu erişilebilir
/// biçimde bildiriyor.
class TopicTreeView extends StatefulWidget {
  const TopicTreeView({
    required this.topics,
    required this.onTapTopic,
    this.selectedId,
    this.trailingBuilder,
    this.emptyMessage,
    super.key,
  });

  /// Bir dersin **düz** konu listesi (alt dallar dahil).
  final List<Topic> topics;

  final ValueChanged<Topic> onTapTopic;

  /// Seçili konu vurgulanıyor (konu seçicide geri dönünce kaybolmasın).
  final String? selectedId;

  /// Satırın sağına ek düğme koymak için (müfredat ekranında "çalışıldı").
  final Widget? Function(Topic topic)? trailingBuilder;

  /// Ders hiç konu içermiyorsa gösterilecek metin.
  final String? emptyMessage;

  static const searchKey = Key('topic-tree-search');
  static const levelsKey = Key('topic-tree-levels');
  static const listKey = Key('topic-tree-list');

  @override
  State<TopicTreeView> createState() => _TopicTreeViewState();
}

class _TopicTreeViewState extends State<TopicTreeView> {
  final _search = TextEditingController();
  TopicLevel _level = TopicLevel.all;
  final _expanded = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TopicTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ders değişince seçili seviye veride karşılıksız kalabilir (KPSS'te
    // "9. sınıf" yok). Karşılıksız seviye listeyi sessizce boşaltırdı.
    if (!availableLevels(widget.topics).contains(_level)) {
      _level = TopicLevel.all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final query = _search.text;
    final levels = availableLevels(widget.topics);
    final tree = buildTopicTree(widget.topics);
    final visible = filterTopicTree(tree, level: _level, query: query);

    // GENİŞ EKRANDA İÇERİK SINIRI — kabuktakiyle aynı 720 px.
    //
    // Tablet yatayda (1280 px) satır tüm genişliğe yayılıyordu: konu adı
    // solda, "çalışıldı" düğmesi 1200 px ötede. Göz ikisini aynı satır
    // saymıyor. Kabuk ekranları bu sınırı v1.1.1'de aldı; müfredat ve konu
    // seçici kabuğun DIŞINDA açıldığı için sınırı burada kendisi koyuyor.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppShell.maxContentWidth),
        child: _content(l, levels, visible, query),
      ),
    );
  }

  Widget _content(
    L10n l,
    List<TopicLevel> levels,
    List<TopicNode> visible,
    String query,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            key: TopicTreeView.searchKey,
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.curriculumSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('topic-tree-search-clear'),
                      tooltip: l.curriculumSearchClear,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
            ),
          ),
        ),
        if (levels.length > 1)
          SingleChildScrollView(
            key: TopicTreeView.levelsKey,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final lv in levels)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('topic-level-${_levelKey(lv)}'),
                      label: Text(_levelLabel(l, lv)),
                      selected: _level == lv,
                      onSelected: (_) => setState(() => _level = lv),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(child: _body(l, visible, query)),
      ],
    );
  }

  Widget _body(L10n l, List<TopicNode> visible, String query) {
    if (widget.topics.isEmpty) {
      return _message(widget.emptyMessage ?? l.curriculumEmptySubject);
    }
    if (visible.isEmpty) {
      return _message(
        query.trim().isEmpty
            ? l.curriculumEmptyLevel
            : l.curriculumNoMatch(query),
      );
    }

    // Arama açıkken alt dallar KENDİLİĞİNDEN açık: kullanıcı eşleşmeyi
    // görmek için ayrıca dokunmak zorunda kalmamalı.
    final searching = normalizeTopicQuery(query).isNotEmpty;

    return ListView.builder(
      key: TopicTreeView.listKey,
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final node = visible[i];
        final open = searching || _expanded.contains(node.topic.id);
        return _NodeTile(
          node: node,
          expanded: open,
          selectedId: widget.selectedId,
          trailingBuilder: widget.trailingBuilder,
          onTapTopic: widget.onTapTopic,
          onToggle: () => setState(() {
            if (!_expanded.remove(node.topic.id)) _expanded.add(node.topic.id);
          }),
        );
      },
    );
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );

  static String _levelKey(TopicLevel lv) {
    if (lv.isAll) return 'all';
    return lv.grade != null ? 'g${lv.grade}' : lv.tag!;
  }

  static String _levelLabel(L10n l, TopicLevel lv) {
    if (lv.isAll) return l.curriculumLevelAll;
    if (lv.grade != null) return l.curriculumLevelGrade(lv.grade!);
    return lv.tag == 'tyt' ? l.curriculumLevelTyt : l.curriculumLevelAyt;
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.expanded,
    required this.onToggle,
    required this.onTapTopic,
    required this.selectedId,
    required this.trailingBuilder,
  });

  final TopicNode node;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Topic> onTapTopic;
  final String? selectedId;
  final Widget? Function(Topic topic)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          context,
          topic: node.topic,
          indent: 0,
          leading: node.hasChildren
              ? IconButton(
                  key: Key('topic-expand-${node.topic.id}'),
                  tooltip: expanded ? l.curriculumCollapse : l.curriculumExpand,
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )
              : null,
          // Alt dal SAYISI süzgeçten bağımsız: arama "2 alt dal"ı "1 alt
          // dal"a düşürürse müfredat hakkında yanlış bilgi verilmiş olur.
          subtitle: node.hasChildren
              ? l.curriculumSubBranches(node.totalChildren)
              : null,
        ),
        if (expanded)
          for (final c in node.children)
            _row(context, topic: c, indent: 24, leading: null, subtitle: null),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required Topic topic,
    required double indent,
    required Widget? leading,
    required String? subtitle,
  }) {
    final selected = selectedId == topic.id;
    final trailing = trailingBuilder?.call(topic);

    return ListTile(
      key: Key('topic-row-${topic.id}'),
      selected: selected,
      dense: true,
      visualDensity: VisualDensity.compact,
      // Girinti PADDING ile: sabit genişlikli bir boşluk widget'ı dar
      // ekranda başlığı sıkıştırıp taşırıyordu.
      contentPadding: EdgeInsets.only(left: 12 + indent, right: 8),
      // AÇMA OKU OLMAYAN SATIRDA DA aynı genişlikte yer ayrılıyor.
      //
      // İlk çizimde `leading: null` veriliyordu: alt dalı olan konular
      // okun genişliği kadar SAĞA kayıyor, olmayanlar solda kalıyordu.
      // Aynı seviyedeki iki konu iki farklı hizada duruyordu ve ağaç
      // "Bölme ve Bölünebilme, Sayı Basamakları'nın altındadır" gibi
      // okunuyordu — bu ekranın anlatmak zorunda olduğu tek şey hiyerarşi.
      minLeadingWidth: 0,
      horizontalTitleGap: 8,
      leading: SizedBox(width: 32, child: leading),
      // `Text` tek başına uzun konu adında satırı taşırıyordu; ListTile
      // başlığı kendiliğinden kısaltmıyor.
      title: Text(
        topic.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: topic.isCompleted && trailing == null
          ? const Icon(Icons.check_circle, size: 20)
          : trailing,
      onTap: () => onTapTopic(topic),
    );
  }
}
