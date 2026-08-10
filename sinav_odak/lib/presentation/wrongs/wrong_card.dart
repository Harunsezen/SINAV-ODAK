import 'package:flutter/material.dart';

import '../../core/utils/color_hex.dart';
import '../../domain/entities/enums.dart';

/// Yanlış defteri liste kartı.
///
/// **Drift tipi almaz.** Görüntülenecek alanlar tek tek parametre olarak
/// geliyor; böylece kart hem otomatik hem manuel kayıtla, hem de ileride
/// başka bir kaynakla çalışabilir ve `presentation` katmanı `data`'ya
/// bağlanmaz.
class WrongCard extends StatelessWidget {
  const WrongCard({
    required this.subjectName,
    required this.colorHex,
    required this.wrongCount,
    required this.status,
    required this.source,
    required this.onTap,
    required this.onAdvance,
    this.topicName,
    this.note,
    super.key,
  });

  final String subjectName;
  final String colorHex;
  final String? topicName;
  final int wrongCount;
  final String? note;
  final WrongItemStatus status;
  final WrongItemSource source;

  /// Karta dokunma — detay sayfasını açar.
  final VoidCallback onTap;

  /// Durum ilerlet: active → reviewed → mastered.
  /// `mastered` kayıtta `null` gelir ve buton gizlenir.
  final VoidCallback? onAdvance;

  static String labelOf(WrongItemStatus s) => switch (s) {
        WrongItemStatus.active => 'Aktif',
        WrongItemStatus.reviewed => 'Tekrar edildi',
        WrongItemStatus.mastered => 'Öğrenildi',
      };

  /// Bir sonraki adımın buton metni.
  static String? advanceLabelOf(WrongItemStatus s) => switch (s) {
        WrongItemStatus.active => 'Tekrar ettim',
        WrongItemStatus.reviewed => 'Öğrendim',
        WrongItemStatus.mastered => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromHex(colorHex, fallback: theme.colorScheme.primary);
    final advanceLabel = advanceLabelOf(status);
    final trimmedNote = note?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ders renk şeridi.
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topicName == null || topicName!.isEmpty
                                  ? subjectName
                                  : '$subjectName · $topicName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SourceBadge(source: source),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$wrongCount yanlış',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (trimmedNote != null && trimmedNote.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          trimmedNote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (advanceLabel != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onAdvance,
                            child: Text(advanceLabel),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kaydın elle mi yoksa oturum sonu formundan mı geldiğini gösterir.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final WrongItemSource source;

  @override
  Widget build(BuildContext context) {
    final isAuto = source == WrongItemSource.auto;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:
            isAuto ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isAuto ? 'oturumdan' : 'elle',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }
}
