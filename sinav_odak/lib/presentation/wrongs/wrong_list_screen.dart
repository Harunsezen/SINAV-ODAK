import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../../domain/entities/enums.dart';
import 'wrong_card.dart';
import 'wrong_detail_sheet.dart';

/// Yanlış defteri — 3 sekmeli liste.
///
/// `wrong_items` tablosu ve DAO Adım 2'den beri hazırdı ama ekranı yoktu:
/// oturum sonu formunun ürettiği kayıtlar kullanıcıya hiç görünmüyordu.
class WrongListScreen extends ConsumerStatefulWidget {
  const WrongListScreen({super.key});

  @override
  ConsumerState<WrongListScreen> createState() => _WrongListScreenState();
}

class _WrongListScreenState extends ConsumerState<WrongListScreen> {
  WrongItemStatus _status = WrongItemStatus.active;

  /// Kayıt bir sonraki duruma geçer: active → reviewed → mastered.
  Future<void> _advance(String id, WrongItemStatus current) {
    final next = switch (current) {
      WrongItemStatus.active => WrongItemStatus.reviewed,
      WrongItemStatus.reviewed => WrongItemStatus.mastered,
      // `mastered` son durak; kartta buton zaten gizli.
      WrongItemStatus.mastered => WrongItemStatus.mastered,
    };
    return ref.read(wrongItemDaoProvider).setStatus(id, next);
  }

  String get _emptyMessage => switch (_status) {
        WrongItemStatus.active => L10n.of(context).wrongsEmptyActive,
        WrongItemStatus.reviewed => L10n.of(context).wrongsEmptyReviewed,
        WrongItemStatus.mastered => L10n.of(context).wrongsEmptyMastered,
      };

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wrongItemsProvider(_status));

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).wrongsTitle)),
      floatingActionButton: FloatingActionButton(
        key: const Key('wrongs-add'),
        onPressed: () => context.go(Routes.wrongsAdd),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<WrongItemStatus>(
              key: const Key('wrongs-filter'),
              segments: [
                for (final s in WrongItemStatus.values)
                  ButtonSegment(
                    value: s,
                    label: Text(WrongCard.labelOf(L10n.of(context), s)),
                  ),
              ],
              selected: {_status},
              showSelectedIcon: false,
              onSelectionChanged: (sel) => setState(() => _status = sel.first),
            ),
          ),
          Expanded(
            child: items.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text(L10n.of(context).wrongsFailed('$e'))),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyMessage,
                        key: const Key('wrongs-empty'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  key: const Key('wrongs-list'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final v = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WrongCard(
                        key: Key('wrong-card-${v.item.id}'),
                        subjectName: v.subjectName,
                        colorHex: v.colorHex,
                        topicName: v.topicName,
                        wrongCount: v.item.wrongCount,
                        note: v.item.note,
                        status: v.item.status,
                        source: v.item.source,
                        onAdvance: v.item.status == WrongItemStatus.mastered
                            ? null
                            : () => _advance(v.item.id, v.item.status),
                        onTap: () => showWrongDetailSheet(
                          context,
                          itemId: v.item.id,
                          subjectId: v.item.subjectId,
                          subjectName: v.subjectName,
                          colorHex: v.colorHex,
                          wrongCount: v.item.wrongCount,
                          topicId: v.item.topicId,
                          topicName: v.topicName,
                          note: v.item.note,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
