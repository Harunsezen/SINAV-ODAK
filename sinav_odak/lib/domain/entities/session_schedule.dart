import 'schedule_block.dart';
import 'schedule_codec_exception.dart';

/// Bir çalışma oturumunun mutlak zaman damgalı çizelgesi.
///
/// **Bu sınıf uygulamanın zaman mimarisinin merkezidir.** Sayaç bir `Timer`
/// değildir; doğruluk kaynağı daima bu çizelge ile `nowMs`'in
/// karşılaştırılmasıdır (bkz. `ScheduleResolver`). Uygulama öldürülse,
/// telefon kapansa veya iOS arka planda kodu durdursa bile çizelge DB'de
/// durduğu için oturum kaldığı yerden doğru şekilde hesaplanır.
///
/// Değişmezdir. [ScheduleModifier] her değişiklikte yeni örnek üretir.
///
/// JSON sözleşmesi:
/// ```json
/// {
///   "version": 1,
///   "createdAt": 1754467200000,
///   "blocks": [ ... ],
///   "totalStudyS": 4320,
///   "totalBreakS": 600,
///   "plannedEndAt": 1754472120000
/// }
/// ```
class SessionSchedule {
  /// Tek gerçek kurucu; **private**.
  ///
  /// Dışarıya yalnızca iki giriş noktası açıktır ve ikisi de doğrulama yapar:
  /// [SessionSchedule.fromBlocks] ve [SessionSchedule.fromJson].
  /// Böylece "doğrulanmamış çizelge" üretmek dil seviyesinde imkânsızdır.
  ///
  /// Blok listesi burada [List.unmodifiable] ile sarılır; çağıranın elindeki
  /// mutable liste sonradan değiştirilse bile çizelge etkilenmez.
  SessionSchedule._({
    required this.createdAtMs,
    required List<ScheduleBlock> blocks,
    required this.totalStudyS,
    required this.totalBreakS,
    required this.plannedEndAtMs,
    this.version = currentVersion,
  }) : blocks = List<ScheduleBlock>.unmodifiable(blocks);

  /// Bloklardan toplamları hesaplayarak çizelge kurar ve doğrular.
  /// `ScheduleBuilder` ve `ScheduleModifier` bu fabrikayı kullanır.
  factory SessionSchedule.fromBlocks({
    required int createdAtMs,
    required List<ScheduleBlock> blocks,
  }) {
    if (blocks.isEmpty) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.emptyBlocks,
        'Çizelge en az bir blok içermeli',
      );
    }
    var study = 0;
    var brk = 0;
    for (final b in blocks) {
      if (b.isStudy) {
        study += b.seconds;
      } else {
        brk += b.seconds;
      }
    }
    final schedule = SessionSchedule._(
      createdAtMs: createdAtMs,
      blocks: blocks,
      totalStudyS: study,
      totalBreakS: brk,
      plannedEndAtMs: blocks.last.endMs,
    );
    schedule.validate();
    return schedule;
  }

  /// Desteklenen tek çizelge sürümü.
  static const int currentVersion = 1;

  final int version;

  /// Çizelgenin oluşturulduğu an (epoch ms).
  final int createdAtMs;

  /// Çalışma ve mola blokları, zaman sırasına göre, kesintisiz.
  final List<ScheduleBlock> blocks;

  /// Yalnızca çalışma bloklarının toplam süresi (saniye). Molalar hariç.
  final int totalStudyS;

  /// Yalnızca mola bloklarının toplam süresi (saniye).
  final int totalBreakS;

  /// Son bloğun bitiş anı (epoch ms).
  final int plannedEndAtMs;

  // --- Türetilmiş bilgiler ---

  /// İlk bloğun başlangıcı. `ScheduleResolver` saat kayması kontrolünde
  /// bu değeri kullanır.
  int get firstStartMs => blocks.first.startMs;

  int get lastEndMs => blocks.last.endMs;

  /// Molalar dahil toplam süre (saniye).
  int get totalDurationS => totalStudyS + totalBreakS;

  int get blockCount => blocks.length;

  Iterable<ScheduleBlock> get studyBlocks => blocks.where((b) => b.isStudy);

  Iterable<ScheduleBlock> get breakBlocks => blocks.where((b) => b.isBreak);

  /// Kullanıcıya gösterilen "3. çalışma bloğu / 5" ifadesi için:
  /// molalar hariç, bu bloğun kaçıncı çalışma bloğu olduğu (1'den başlar).
  /// Blok bir molaysa 0 döner.
  int studyOrdinalOf(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= blocks.length) return 0;
    if (!blocks[blockIndex].isStudy) return 0;
    var n = 0;
    for (var i = 0; i <= blockIndex; i++) {
      if (blocks[i].isStudy) n++;
    }
    return n;
  }

  int get studyBlockCount => studyBlocks.length;

  /// Yalnızca [createdAtMs] değiştirilebilir ve sonuç doğrulanır.
  ///
  /// Blok listesi veya toplamlar bilinçli olarak değiştirilemez: bunlar
  /// birbirine bağımlı değerlerdir ve tek tek değiştirilmeleri çizelgeyi
  /// sessizce tutarsız hale getirirdi. Blokları değiştirmesi gereken kod
  /// (örn. `ScheduleModifier`) [SessionSchedule.fromBlocks] kullanmalıdır;
  /// orada toplamlar yeniden hesaplanır ve doğrulama zorunludur.
  SessionSchedule copyWith({int? createdAtMs}) {
    final copy = SessionSchedule._(
      version: version,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      blocks: blocks,
      totalStudyS: totalStudyS,
      totalBreakS: totalBreakS,
      plannedEndAtMs: plannedEndAtMs,
    );
    copy.validate();
    return copy;
  }

  /// Çizelgenin bütünlüğünü doğrular.
  ///
  /// Bu doğrulama, kurtarma akışının güvenliğini sağlar: bozuk bir çizelge
  /// sessizce yanlış bloktan devam etmek yerine burada yakalanır.
  void validate() {
    if (version != currentVersion) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.unsupportedVersion,
        'Desteklenmeyen çizelge sürümü: $version (beklenen $currentVersion)',
      );
    }
    if (createdAtMs < 0) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.invalidNegativeValue,
        'createdAt negatif olamaz: $createdAtMs',
      );
    }
    if (blocks.isEmpty) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.emptyBlocks,
        'Çizelge en az bir blok içermeli',
      );
    }

    var study = 0;
    var brk = 0;

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      b.validate();

      if (b.index != i) {
        throw SessionScheduleCodecException(
          ScheduleCodecReason.badIndexSequence,
          'Blok sırası ardışık değil: beklenen $i, gelen ${b.index}',
          blockIndex: i,
        );
      }
      if (i > 0 && blocks[i - 1].endMs != b.startMs) {
        throw SessionScheduleCodecException(
          ScheduleCodecReason.nonContiguousBlocks,
          'Bloklar kesintisiz olmalı: önceki end=${blocks[i - 1].endMs}, '
          'bu start=${b.startMs}',
          blockIndex: i,
        );
      }
      if (b.isStudy) {
        study += b.seconds;
      } else {
        brk += b.seconds;
      }
    }

    if (totalStudyS != study) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.totalStudyMismatch,
        'totalStudyS uyuşmuyor: $totalStudyS, hesaplanan $study',
      );
    }
    if (totalBreakS != brk) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.totalBreakMismatch,
        'totalBreakS uyuşmuyor: $totalBreakS, hesaplanan $brk',
      );
    }
    if (plannedEndAtMs != blocks.last.endMs) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.plannedEndMismatch,
        'plannedEndAt son bloğun bitişine eşit olmalı: '
        '$plannedEndAtMs != ${blocks.last.endMs}',
      );
    }
  }

  // --- JSON ---

  factory SessionSchedule.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version == null) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.missingField,
        "'version' alanı eksik",
      );
    }
    if (version is! int) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "'version' int olmalı, gelen: ${version.runtimeType}",
      );
    }
    if (version != currentVersion) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.unsupportedVersion,
        'Desteklenmeyen çizelge sürümü: $version (beklenen $currentVersion)',
      );
    }

    final rawBlocks = json['blocks'];
    if (rawBlocks == null) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.missingField,
        "'blocks' alanı eksik",
      );
    }
    if (rawBlocks is! List) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "'blocks' liste olmalı, gelen: ${rawBlocks.runtimeType}",
      );
    }
    if (rawBlocks.isEmpty) {
      throw const SessionScheduleCodecException(
        ScheduleCodecReason.emptyBlocks,
        'Çizelge en az bir blok içermeli',
      );
    }

    final blocks = <ScheduleBlock>[];
    for (final raw in rawBlocks) {
      if (raw is! Map) {
        throw SessionScheduleCodecException(
          ScheduleCodecReason.malformedJson,
          'Blok nesne olmalı, gelen: ${raw.runtimeType}',
        );
      }
      blocks.add(ScheduleBlock.fromJson(Map<String, dynamic>.from(raw)));
    }

    final schedule = SessionSchedule._(
      version: version,
      createdAtMs: _readInt(json, 'createdAt'),
      blocks: blocks,
      totalStudyS: _readInt(json, 'totalStudyS'),
      totalBreakS: _readInt(json, 'totalBreakS'),
      plannedEndAtMs: _readInt(json, 'plannedEndAt'),
    );
    schedule.validate();
    return schedule;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'createdAt': createdAtMs,
      'blocks': blocks.map((b) => b.toJson()).toList(growable: false),
      'totalStudyS': totalStudyS,
      'totalBreakS': totalBreakS,
      'plannedEndAt': plannedEndAtMs,
    };
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.missingField,
        "'$key' alanı eksik",
      );
    }
    if (v is! int) {
      throw SessionScheduleCodecException(
        ScheduleCodecReason.malformedJson,
        "'$key' int olmalı, gelen: ${v.runtimeType}",
      );
    }
    return v;
  }

  @override
  bool operator ==(Object other) {
    if (other is! SessionSchedule) return false;
    if (other.version != version ||
        other.createdAtMs != createdAtMs ||
        other.totalStudyS != totalStudyS ||
        other.totalBreakS != totalBreakS ||
        other.plannedEndAtMs != plannedEndAtMs ||
        other.blocks.length != blocks.length) {
      return false;
    }
    for (var i = 0; i < blocks.length; i++) {
      if (other.blocks[i] != blocks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        version,
        createdAtMs,
        totalStudyS,
        totalBreakS,
        plannedEndAtMs,
        Object.hashAll(blocks),
      );

  @override
  String toString() => 'SessionSchedule(v$version, ${blocks.length} blok, '
      'çalışma ${totalStudyS}s, mola ${totalBreakS}s)';
}
