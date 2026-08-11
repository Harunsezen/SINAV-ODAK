import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/app_providers.dart';
import '../../core/router/routes.dart';
import '../session_setup/setup_controller.dart';

/// Yanlış kaydının detay/aksiyon sayfası (alttan açılır).
///
/// Kartta yalnızca en sık kullanılan aksiyon (durum ilerlet) duruyor;
/// not düzenleme, silme ve "Bu konuyu çalış" buraya alındı — dört butonu
/// birden karta koymak listeyi okunmaz hale getiriyordu. Her aksiyon
/// karttan **tek dokunuş** uzakta.
class WrongDetailSheet extends ConsumerStatefulWidget {
  const WrongDetailSheet({
    required this.itemId,
    required this.subjectId,
    required this.subjectName,
    required this.colorHex,
    required this.wrongCount,
    this.topicId,
    this.topicName,
    this.note,
    super.key,
  });

  final String itemId;
  final String subjectId;
  final String subjectName;
  final String colorHex;
  final int wrongCount;
  final String? topicId;
  final String? topicName;
  final String? note;

  /// Kurulum akışına önceden doldurulacak çalışma türü.
  /// Yanlış defterinden gelen çalışma doğal olarak "Analiz"dir.
  static const analysisActivityId = 'act_analiz';

  @override
  ConsumerState<WrongDetailSheet> createState() => _WrongDetailSheetState();
}

class _WrongDetailSheetState extends ConsumerState<WrongDetailSheet> {
  late final TextEditingController _noteCtrl =
      TextEditingController(text: widget.note ?? '');

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _noteCtrl.text.trim();
    await ref
        .read(wrongItemDaoProvider)
        .setNote(widget.itemId, text.isEmpty ? null : text);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('wrong-delete-dialog'),
        title: Text(L10n.of(context).wrongsDeleteTitle),
        content: Text(
          L10n.of(context).wrongsDeleteBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(L10n.of(context).commonCancel),
          ),
          FilledButton(
            key: const Key('wrong-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(L10n.of(context).wrongsDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(wrongItemDaoProvider).deleteItem(widget.itemId);
    if (mounted) Navigator.of(context).pop();
  }

  /// Kurulum akışını bu ders/konuyla önceden doldurup plan adımına atlar.
  ///
  /// Ders ve tür dolu olduğu için `SetupSelection.isReadyForPlan` sağlanır;
  /// kullanıcı ders/konu/tür ekranlarını tekrar gezmez.
  void _studyThisTopic() {
    final activities = ref.read(activityTypesProvider).valueOrNull ?? const [];
    final matches =
        activities.where((a) => a.id == WrongDetailSheet.analysisActivityId);
    final analysis = matches.isEmpty ? null : matches.first;

    // Sayfa kapandıktan sonra bu State'in context'i kullanılamaz;
    // yönlendirici önceden alınıyor.
    final router = GoRouter.of(context);

    final setup = ref.read(setupProvider.notifier)
      ..reset()
      ..selectSubject(
        id: widget.subjectId,
        name: widget.subjectName,
        colorHex: widget.colorHex,
      );

    final topicId = widget.topicId;
    if (topicId != null) {
      setup.selectTopic(id: topicId, name: widget.topicName ?? '');
    }

    setup.selectActivityType(
      id: analysis?.id ?? WrongDetailSheet.analysisActivityId,
      name: analysis?.name ?? L10n.of(context).wrongsDetailTitle,
    );

    Navigator.of(context).pop();
    router.go(Routes.sessionPlan);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.topicName == null || widget.topicName!.isEmpty
        ? widget.subjectName
        : L10n.of(context)
            .wrongsSubjectTopic(widget.subjectName, widget.topicName!);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(L10n.of(context).wrongsCount(widget.wrongCount)),
          const SizedBox(height: 16),
          TextField(
            key: const Key('wrong-note-field'),
            controller: _noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: L10n.of(context).wrongsNote,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('wrong-study-topic'),
            onPressed: _studyThisTopic,
            child: Text(L10n.of(context).wrongsStudyThisTopic),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('wrong-save-note'),
                  onPressed: _saveNote,
                  child: Text(L10n.of(context).wrongsSaveNote),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('wrong-delete'),
                  onPressed: _delete,
                  child: Text(L10n.of(context).wrongsDelete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kart dokunuşundan çağrılır.
Future<void> showWrongDetailSheet(
  BuildContext context, {
  required String itemId,
  required String subjectId,
  required String subjectName,
  required String colorHex,
  required int wrongCount,
  String? topicId,
  String? topicName,
  String? note,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => WrongDetailSheet(
      itemId: itemId,
      subjectId: subjectId,
      subjectName: subjectName,
      colorHex: colorHex,
      wrongCount: wrongCount,
      topicId: topicId,
      topicName: topicName,
      note: note,
    ),
  );
}
