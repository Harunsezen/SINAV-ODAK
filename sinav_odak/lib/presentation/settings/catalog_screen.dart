import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/app_providers.dart';

/// Ders / konu / çalışma türü yönetimi.
///
/// **SİLME YOK — arşivleme var (G8).** Silinen bir ders geçmiş oturumların
/// bağlı olduğu satırı yok eder; şemada `onDelete: restrict` zaten buna izin
/// vermiyor. Arşivlenen kayıt oturum kurulumunda görünmez ama geçmiş
/// istatistikler sağlam kalır.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.catalogTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.catalogTabSubjects),
              Tab(text: l.catalogTabActivities),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('catalog-toggle-archived'),
              tooltip: l.catalogShowArchived,
              icon: Icon(
                _showArchived ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _showArchived = !_showArchived),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _SubjectsTab(showArchived: _showArchived),
            _ActivityTypesTab(showArchived: _showArchived),
          ],
        ),
      ),
    );
  }
}

/// Ortak: ad soran diyalog. Boş ad KAYDEDİLEMEZ.
Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, label: label, initial: initial),
  );
}

/// Ad soran diyalog.
///
/// Controller **State içinde** tutuluyor. `showDialog(...).whenComplete(
/// controller.dispose)` denendi ve çöktü: `whenComplete`, diyaloğun kapanma
/// ANİMASYONU bitmeden çalışıyor; TextField hâlâ build edilirken controller
/// dispose edilmiş oluyor ve Flutter "A TextEditingController was used after
/// being disposed" fırlatıyor. Ömrü widget'a bağlamak tek doğru yol.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.initial,
  });

  final String title;
  final String label;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      key: const Key('catalog-name-dialog'),
      title: Text(widget.title),
      content: TextField(
        key: const Key('catalog-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          key: const Key('catalog-name-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('catalog-name-save'),
          onPressed: _submit,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dersler + konular
// ---------------------------------------------------------------------------

class _SubjectsTab extends ConsumerWidget {
  const _SubjectsTab({required this.showArchived});

  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final subjects = ref.watch(allSubjectsProvider);

    return Scaffold(
      body: subjects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final visible =
              showArchived ? list : list.where((s) => !s.isArchived).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.catalogNoDelete,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              for (final s in visible)
                _SubjectTile(
                  id: s.id,
                  name: s.name,
                  colorHex: s.colorHex,
                  isArchived: s.isArchived,
                  showArchived: showArchived,
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('catalog-add-subject'),
        onPressed: () async {
          final name = await _promptName(
            context,
            title: l.catalogAddSubject,
            label: l.catalogSubjectName,
          );
          if (name == null) return;
          await ref.read(subjectDaoProvider).createSubject(
                id: const Uuid().v4(),
                name: name,
                colorHex: _nextColor(ref),
                exam: ref.read(examTypeProvider),
              );
        },
        icon: const Icon(Icons.add),
        label: Text(l.catalogAddSubject),
      ),
    );
  }

  /// Yeni derse paletten sıradaki rengi verir.
  ///
  /// Renk seçtirmek ayrı bir ekran demek; ilk sürümde otomatik atanan renk
  /// yeterli ve düzenleme diyaloğundan değiştirilebiliyor.
  static const List<String> palette = [
    '#4F5BD5',
    '#E4405F',
    '#F77737',
    '#00A884',
    '#8E44AD',
    '#2980B9',
    '#16A085',
    '#D35400',
  ];

  String _nextColor(WidgetRef ref) {
    final list = ref.read(allSubjectsProvider).valueOrNull ?? const [];
    return palette[list.length % palette.length];
  }
}

/// Bir ders satırı.
///
/// Drift'in `Subject` satırını DEĞİL, ihtiyaç duyduğu alanları alıyor:
/// `presentation` katmanı `data/local` tiplerini import etmemeli (G4).
class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isArchived,
    required this.showArchived,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool isArchived;
  final bool showArchived;

  Color get _color {
    final hex = colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16);
    // Bozuk renk kodu ekranı çökertmemeli; markanın indigosuna düş.
    if (value == null) return const Color(0xFF4F5BD5);
    return Color(hex.length <= 6 ? 0xFF000000 | value : value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final topics = ref.watch(allTopicsProvider(id));
    final list = topics.valueOrNull ?? const [];
    final visibleTopics =
        showArchived ? list : list.where((t) => !t.isArchived).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ExpansionTile(
        key: Key('catalog-subject-$id'),
        leading: CircleAvatar(radius: 12, backgroundColor: _color),
        title: Text(
          name,
          style: TextStyle(
            decoration: isArchived ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          isArchived
              ? l.catalogArchived
              : l.catalogTopicCount(visibleTopics.length),
          style: const TextStyle(fontSize: 11),
        ),
        children: [
          if (visibleTopics.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.catalogEmptyTopics,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          for (final t in visibleTopics)
            ListTile(
              key: Key('catalog-topic-${t.id}'),
              dense: true,
              title: Text(
                t.name,
                style: TextStyle(
                  decoration: t.isArchived ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: Key('catalog-topic-edit-${t.id}'),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () async {
                      final name = await _promptName(
                        context,
                        title: l.catalogEditTopic,
                        label: l.catalogTopicName,
                        initial: t.name,
                      );
                      if (name == null) return;
                      await ref
                          .read(subjectDaoProvider)
                          .renameTopic(t.id, name);
                    },
                  ),
                  IconButton(
                    key: Key('catalog-topic-archive-${t.id}'),
                    tooltip:
                        t.isArchived ? l.catalogUnarchive : l.catalogArchive,
                    icon: Icon(
                      t.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      size: 18,
                    ),
                    onPressed: () => ref
                        .read(subjectDaoProvider)
                        .archiveTopic(t.id, archived: !t.isArchived),
                  ),
                ],
              ),
            ),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                key: Key('catalog-add-topic-$id'),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l.catalogAddTopic),
                onPressed: () async {
                  final name = await _promptName(
                    context,
                    title: l.catalogAddTopic,
                    label: l.catalogTopicName,
                  );
                  if (name == null) return;
                  await ref.read(subjectDaoProvider).createTopic(
                        id: const Uuid().v4(),
                        subjectId: id,
                        name: name,
                      );
                },
              ),
              TextButton.icon(
                key: Key('catalog-subject-edit-$id'),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l.commonEdit),
                onPressed: () async {
                  final newName = await _promptName(
                    context,
                    title: l.catalogEditSubject,
                    label: l.catalogSubjectName,
                    initial: name,
                  );
                  if (newName == null) return;
                  await ref
                      .read(subjectDaoProvider)
                      .renameSubject(id, newName, colorHex);
                },
              ),
              TextButton.icon(
                key: Key('catalog-subject-archive-$id'),
                icon: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: 18,
                ),
                label: Text(
                  isArchived ? l.catalogUnarchive : l.catalogArchive,
                ),
                onPressed: () => ref
                    .read(subjectDaoProvider)
                    .setArchived(id, archived: !isArchived),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Çalışma türleri
// ---------------------------------------------------------------------------

class _ActivityTypesTab extends ConsumerWidget {
  const _ActivityTypesTab({required this.showArchived});

  final bool showArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final types = ref.watch(allActivityTypesProvider);

    return Scaffold(
      body: types.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final visible =
              showArchived ? list : list.where((t) => !t.isArchived).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l.catalogNoDelete,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              for (final t in visible)
                ListTile(
                  key: Key('catalog-activity-${t.id}'),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      decoration:
                          t.isArchived ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: t.isArchived
                      ? Text(
                          l.catalogArchived,
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('catalog-activity-edit-${t.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          final name = await _promptName(
                            context,
                            title: l.catalogEditActivity,
                            label: l.catalogActivityName,
                            initial: t.name,
                          );
                          if (name == null) return;
                          await ref
                              .read(subjectDaoProvider)
                              .renameActivityType(t.id, name);
                        },
                      ),
                      IconButton(
                        key: Key('catalog-activity-archive-${t.id}'),
                        tooltip: t.isArchived
                            ? l.catalogUnarchive
                            : l.catalogArchive,
                        icon: Icon(
                          t.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 18,
                        ),
                        onPressed: () => ref
                            .read(subjectDaoProvider)
                            .setActivityTypeArchived(
                              t.id,
                              archived: !t.isArchived,
                            ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('catalog-add-activity'),
        onPressed: () async {
          final name = await _promptName(
            context,
            title: l.catalogAddActivity,
            label: l.catalogActivityName,
          );
          if (name == null) return;
          await ref.read(subjectDaoProvider).createActivityType(
                id: const Uuid().v4(),
                name: name,
              );
        },
        icon: const Icon(Icons.add),
        label: Text(l.catalogAddActivity),
      ),
    );
  }
}
