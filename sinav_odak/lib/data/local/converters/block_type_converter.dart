import 'package:drift/drift.dart';

import '../../../domain/entities/block_type_codec.dart';
import '../../../domain/entities/enums.dart';

/// `session_blocks.type` kolonu için Drift dönüştürücüsü.
///
/// Tek sözleşme kuralı: dönüşüm mantığı domain katmanındaki
/// `block_type_codec.dart` içindedir; bu sınıf yalnızca onu Drift'e bağlar.
/// Böylece çizelge JSON'u ve veritabanı kolonu **aynı** string değerleri
/// kullanır:
///
/// ```
/// BlockType.study      <->  'study'
/// BlockType.breakTime  <->  'break'
/// ```
///
/// Öncesinde kolon `textEnum<BlockType>()` idi ve DB'ye `'breakTime'`
/// yazıyordu; JSON sözleşmesi ise `'break'` diyordu. Bu ikilik kurtarma
/// akışının tam merkezindeydi ve sessizce yanlış bloktan devam etmeye yol
/// açabilirdi.
///
/// **Temiz şema değişikliği (clean schema change):** v1 yayında olmadığı için
/// `schemaVersion` 1'de kalıyor. Ancak geliştirme cihazındaki veritabanında
/// `'breakTime'` yazılı satırlar varsa [fromSql] onları çözemez ve
/// `SessionScheduleCodecException` fırlatır —
/// **uygulamanın cihazdan silinip yeniden kurulması gerekir.**
class BlockTypeConverter extends TypeConverter<BlockType, String> {
  const BlockTypeConverter();

  @override
  BlockType fromSql(String fromDb) => blockTypeFromJson(fromDb);

  @override
  String toSql(BlockType value) => blockTypeToJson(value);
}
