/// [BlockType] için JSON/DB serileştirme sözleşmesi.
///
/// Dart'ta `break` ayrılmış kelime olduğu için enum adı `breakTime` kaldı,
/// ancak JSON ve veritabanında **'break'** yazılır:
///
/// ```
/// BlockType.study      <->  'study'
/// BlockType.breakTime  <->  'break'
/// ```
///
/// Bu dosya saf Dart'tır: Flutter, Drift veya Riverpod import etmez.
/// Data katmanındaki `BlockTypeConverter` bu fonksiyonları kullanır —
/// tersi değil. Böylece tek bir sözleşme hem çizelge JSON'unu hem
/// `session_blocks.type` kolonunu besler.
library;

import 'enums.dart';
import 'schedule_codec_exception.dart';


/// Çalışma bloğunun JSON/DB karşılığı.
const String kBlockTypeStudy = 'study';

/// Mola bloğunun JSON/DB karşılığı.
const String kBlockTypeBreak = 'break';

/// Geçerli tüm string değerler. Doğrulama ve hata mesajları için.
const Set<String> kBlockTypeValues = {kBlockTypeStudy, kBlockTypeBreak};

/// [BlockType] -> JSON/DB string.
///
/// Saf ve toplam (total) bir fonksiyondur; hiçbir zaman hata fırlatmaz.
String blockTypeToJson(BlockType type) => switch (type) {
      BlockType.study => kBlockTypeStudy,
      BlockType.breakTime => kBlockTypeBreak,
    };

/// JSON/DB string -> [BlockType].
///
/// Tanınmayan değer için [SessionScheduleCodecException] fırlatır.
/// [blockIndex] verilirse hata mesajına eklenir.
///
/// Dikkat: eski verilerde `'breakTime'` yazıyor olabilir. Bu bilinçli olarak
/// KABUL EDİLMEZ — v1 yayında olmadığı için temiz şema değişikliği yapıldı ve
/// geliştirme cihazındaki veritabanının silinmesi gerekir.
BlockType blockTypeFromJson(String raw, {int? blockIndex}) {
  return switch (raw) {
    kBlockTypeStudy => BlockType.study,
    kBlockTypeBreak => BlockType.breakTime,
    _ => throw SessionScheduleCodecException(
        ScheduleCodecReason.unknownBlockType,
        "Bilinmeyen blok tipi: '$raw'. Beklenen: ${kBlockTypeValues.join(', ')}",
        blockIndex: blockIndex,
      ),
  };
}

/// Tanınmayan değerde hata fırlatmak yerine `null` döner.
/// Toleranslı okuma gereken yerlerde (örn. veri onarımı) kullanılır.
BlockType? tryBlockTypeFromJson(String raw) => switch (raw) {
      kBlockTypeStudy => BlockType.study,
      kBlockTypeBreak => BlockType.breakTime,
      _ => null,
    };
