import 'block_type_codec.dart';
import 'enums.dart';
import 'schedule_codec_exception.dart';

/// Zaman damgalarını saniyeye hizalar (KARAR 11).
///
/// Çizelgedeki tüm zamanlar saniyeye hizalıdır; böylece
/// `s == (end - start) / 1000` doğrulaması her zaman tam sayı üzerinden
/// yapılabilir ve milisaniye artıkları birikip çizelgeyi kaydırmaz.
int alignToSecond(int ms) => (ms ~/ 1000) * 1000;

/// Çizelgedeki tek bir blok (çalışma veya mola).
///
/// Değişmezdir (immutable). Her değişiklik [copyWith] veya [shiftBy] ile
/// yeni bir örnek üretir — böylece `resolve(now)` hesabı sırasında paylaşılan
/// bir çizelgenin yanlışlıkla mutasyona uğraması imkânsızdır.
///
/// JSON sözleşmesi:
/// ```json
/// {"i": 0, "type": "study", "start": 1754467200000, "end": 1754468640000, "s": 1440}
/// ```
/// [skipped] ve [extendedS] yalnızca varsayılan DEĞİLSE yazılır (KARAR 4):
/// `"sk": true`, `"ex": 300`.
class ScheduleBlock {
  const ScheduleBlock({
    required this.index,
    required this.type,
    required this.startMs,
    required this.endMs,
    required this.seconds,
    this.skipped = false,
    this.extendedS = 0,
  });

  /// Çizelgedeki sıra. 0'dan başlar, çalışma ve mola blokları karışık artar.
  final int index;

  final BlockType type;

  /// Mutlak başlangıç zamanı (epoch ms, saniyeye hizalı).
  final int startMs;

  /// Mutlak bitiş zamanı (epoch ms, saniyeye hizalı).
  final int endMs;

  /// Blok süresi (saniye). Daima `(endMs - startMs) / 1000` ile eşittir.
  final int seconds;

  /// Mola "Molayı Bitir" ile erken kapatıldıysa `true`.
  /// Çalışma bloklarında her zaman `false` olmalıdır.
  final bool skipped;

  /// "+5 dk" ile eklenen toplam süre (saniye).
  final int extendedS;

  bool get isStudy => type == BlockType.study;
  bool get isBreak => type == BlockType.breakTime;

  int get durationMs => endMs - startMs;

  /// Mola uzatma sayısı (KARAR 10): MVP'de uzatma +5 dk adımlarıyla yapılır.
  int get extensionsUsed => extendedS ~/ 300;

  ScheduleBlock copyWith({
    int? index,
    BlockType? type,
    int? startMs,
    int? endMs,
    int? seconds,
    bool? skipped,
    int? extendedS,
  }) {
    return ScheduleBlock(
      index: index ?? this.index,
      type: type ?? this.type,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      seconds: seconds ?? this.seconds,
      skipped: skipped ?? this.skipped,
      extendedS: extendedS ?? this.extendedS,
    );
  }

  /// Bloğu [deltaMs] kadar kaydırır. Süre değişmez.
  /// Mola uzatma/atlama sonrası sonraki blokların kaydırılmasında kullanılır.
  ScheduleBlock shiftBy(int deltaMs) {
    if (deltaMs == 0) return this;
    return copyWith(startMs: startMs + deltaMs, endMs: endMs + deltaMs);
  }

  /// Bu bloğun kendi içinde tutarlı olduğunu doğrular.
  /// Bozukluk halinde [SessionScheduleCodecException] fırlatır.
  void validate() {
    if (index < 0) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.badIndexSequence,
        'Blok sırası negatif olamaz: $index',
        blockIndex: index,
      );
    }
    // Negatif kontrolü ÖNCE gelmeli: negatif `seconds` değerinde hizalama ve
    // süre kontrolleri farklı bir hata nedeni üretip asıl sorunu gizliyordu.
    if (startMs < 0 || endMs < 0 || seconds < 0 || extendedS < 0) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.invalidNegativeValue,
        'Zaman veya süre değeri negatif olamaz: '
        'start=$startMs end=$endMs s=$seconds ex=$extendedS',
        blockIndex: index,
      );
    }
    // Çalışma bloğunda mola bayrakları bulunamaz.
    if (isStudy && (skipped || extendedS != 0)) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.invalidStudyBlockFlags,
        'Çalışma bloğunda skipped veya extendedS bulunamaz '
        '(skipped=$skipped, extendedS=$extendedS)',
        blockIndex: index,
      );
    }
    if (startMs != alignToSecond(startMs) || endMs != alignToSecond(endMs)) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.notAlignedToSecond,
        'Zaman damgaları saniyeye hizalı değil: start=$startMs end=$endMs',
        blockIndex: index,
      );
    }
    if (startMs >= endMs) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.invalidBlockBounds,
        'Blok başlangıcı bitişinden küçük olmalı: start=$startMs end=$endMs',
        blockIndex: index,
      );
    }
    final expected = (endMs - startMs) ~/ 1000;
    if (seconds != expected) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.durationMismatch,
        'Süre uyuşmuyor: s=$seconds, hesaplanan=$expected',
        blockIndex: index,
      );
    }
  }

  // --- JSON ---

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) {
    final i = _readInt(json, 'i');
    final rawType = json['type'];
    if (rawType is! String) {
      throw SessionScheduleCodecException(
        rawType == null
            ? ScheduleCodecReason.missingField
            : ScheduleCodecReason.malformedJson,
        "Blok 'type' alanı string olmalı, gelen: $rawType",
        blockIndex: i,
      );
    }

    final block = ScheduleBlock(
      index: i,
      type: blockTypeFromJson(rawType, blockIndex: i),
      startMs: _readInt(json, 'start', blockIndex: i),
      endMs: _readInt(json, 'end', blockIndex: i),
      seconds: _readInt(json, 's', blockIndex: i),
      skipped: _readOptionalBool(json, 'sk', blockIndex: i) ?? false,
      extendedS: _readOptionalInt(json, 'ex', blockIndex: i) ?? 0,
    );
    block.validate();
    return block;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'i': index,
      'type': blockTypeToJson(type),
      'start': startMs,
      'end': endMs,
      's': seconds,
      // Varsayılan değerler JSON'a yazılmaz; round-trip yine kayıpsızdır.
      if (skipped) 'sk': true,
      if (extendedS != 0) 'ex': extendedS,
    };
  }

  static int _readInt(Map<String, dynamic> json, String key, {int? blockIndex}) {
    final v = json[key];
    if (v == null) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.missingField,
        "Blok '$key' alanı eksik",
        blockIndex: blockIndex,
      );
    }
    if (v is! int) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "Blok '$key' alanı int olmalı, gelen: ${v.runtimeType}",
        blockIndex: blockIndex,
      );
    }
    return v;
  }

  static int? _readOptionalInt(
    Map<String, dynamic> json,
    String key, {
    int? blockIndex,
  }) {
    final v = json[key];
    if (v == null) return null;
    if (v is! int) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "Blok '$key' alanı int olmalı, gelen: ${v.runtimeType}",
        blockIndex: blockIndex,
      );
    }
    return v;
  }

  static bool? _readOptionalBool(
    Map<String, dynamic> json,
    String key, {
    int? blockIndex,
  }) {
    final v = json[key];
    if (v == null) return null;
    if (v is! bool) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "Blok '$key' alanı bool olmalı, gelen: ${v.runtimeType}",
        blockIndex: blockIndex,
      );
    }
    return v;
  }

  @override
  bool operator ==(Object other) =>
      other is ScheduleBlock &&
      other.index == index &&
      other.type == type &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.seconds == seconds &&
      other.skipped == skipped &&
      other.extendedS == extendedS;

  @override
  int get hashCode =>
      Object.hash(index, type, startMs, endMs, seconds, skipped, extendedS);

  @override
  String toString() => 'ScheduleBlock(#$index ${blockTypeToJson(type)} '
      '${seconds}s${skipped ? ' skipped' : ''}${extendedS != 0 ? ' +${extendedS}s' : ''})';
}
