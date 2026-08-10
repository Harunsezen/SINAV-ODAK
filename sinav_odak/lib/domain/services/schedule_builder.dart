import '../../core/errors/failures.dart';
import '../entities/enums.dart';
import '../entities/schedule_block.dart';
import '../entities/session_schedule.dart';

/// Plan kurulurken üretilen, akışı durdurmayan uyarılar.
///
/// Domain metin üretmez; UI kendi Türkçe metnini yazar.
enum ScheduleWarning {
  /// Bir çalışma bloğu 120 dakikayı aşıyor. İzin verilir ama uyarılır.
  blockTooLong,

  /// `lastBreakLong` istendi ve son mola iki katına çıkarıldı.
  lastBreakLongApplied,
}

/// [ScheduleBuilder] çıktısı: çizelge + uyarılar.
class ScheduleBuildResult {
  const ScheduleBuildResult(this.schedule, this.warnings);

  final SessionSchedule schedule;
  final List<ScheduleWarning> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

/// Kullanıcının plan tercihinden mutlak zaman damgalı çizelge üretir.
///
/// Saf fonksiyonlardan oluşur: Flutter, Drift veya Riverpod import etmez,
/// `DateTime.now()` çağırmaz — tüm zamanlar parametre olarak gelir.
/// Bu sayede tamamen deterministik test edilebilir.
abstract final class ScheduleBuilder {
  /// Bir çalışma bloğunun alt sınırı (dakika).
  static const int minStudyBlockMinutes = 10;

  /// Uyarı üretilen üst sınır (saniye). 120 dakika **tam olarak** uyarı üretmez.
  static const int maxStudyBlockS = 120 * 60;

  // --- A) Hazır plan ---

  /// Şablon plan: `workMinutes` çalışma + `breakMinutes` mola, `cycles` kez.
  ///
  /// Son çalışma bloğundan sonra mola **eklenmez** (KARAR 8):
  /// 25/5/3 → study 25, break 5, study 25, break 5, study 25.
  static ScheduleBuildResult fromPreset({
    required int startAtMs,
    required int workMinutes,
    required int breakMinutes,
    required int cycles,
  }) {
    if (cycles <= 0) {
      throw const PlanFailure('Döngü sayısı en az 1 olmalı.');
    }
    if (workMinutes < minStudyBlockMinutes) {
      throw const PlanFailure(
        'Çalışma bloğu en az $minStudyBlockMinutes dakika olmalı.',
      );
    }
    // Negatif kontrolü ÖNCE: aksi halde `cycles: 3, breakMinutes: -5`
    // çağrısında kullanıcı "sıfır olamaz" mesajı alıyordu, oysa sorun
    // negatif değerdi. Davranış aynı (PlanFailure), mesaj artık doğru.
    if (breakMinutes < 0) {
      throw const PlanFailure('Mola süresi negatif olamaz.');
    }
    if (cycles > 1 && breakMinutes <= 0) {
      throw const PlanFailure(
        'Birden fazla döngüde mola süresi sıfır olamaz.',
      );
    }

    final warnings = <ScheduleWarning>[];
    // 120 dakika TAM OLARAK uyarı üretmez; yalnızca aşan değerler uyarır.
    if (workMinutes * 60 > maxStudyBlockS) {
      warnings.add(ScheduleWarning.blockTooLong);
    }

    final studySeconds = List<int>.filled(cycles, workMinutes * 60);
    final breakSeconds = List<int>.filled(
      cycles - 1,
      breakMinutes * 60,
    );

    return ScheduleBuildResult(
      _assemble(
        startAtMs: startAtMs,
        studySeconds: studySeconds,
        breakSeconds: breakSeconds,
      ),
      warnings,
    );
  }

  // --- B) Özel plan ---

  /// Kullanıcının girdiği toplam çalışma süresini bloklara böler.
  ///
  /// `breakCount = 0` ise tek blok üretilir.
  /// `lastBreakLong = true` ise son mola iki katına çıkar (KARAR 9).
  ///
  /// Not: `equalDistribution` parametresi kaldırıldı. Hiçbir etkisi yoktu ve
  /// "blokları farklı dağıtabilirim" gibi yanlış bir vaat oluşturuyordu.
  /// Manuel blok düzenleme Adım 4'te ayrı bir modelle gelecek.
  static ScheduleBuildResult fromSpecial({
    required int startAtMs,
    required int totalStudyMinutes,
    required int breakCount,
    required int breakMinutes,
    bool lastBreakLong = false,
  }) {
    if (breakCount < 0) {
      throw const PlanFailure('Mola sayısı negatif olamaz.');
    }
    if (breakCount > 0 && breakMinutes <= 0) {
      throw const PlanFailure('Mola süresi en az 1 dakika olmalı.');
    }
    if (totalStudyMinutes <= 0) {
      throw const PlanFailure('Toplam çalışma süresi sıfırdan büyük olmalı.');
    }

    final warnings = <ScheduleWarning>[];
    final blockCount = breakCount + 1;
    final studySeconds = _splitStudyMinutes(totalStudyMinutes, blockCount);

    for (final s in studySeconds) {
      if (s > maxStudyBlockS) {
        warnings.add(ScheduleWarning.blockTooLong);
        break;
      }
    }

    final breakSeconds = List<int>.filled(breakCount, breakMinutes * 60);
    if (lastBreakLong && breakCount > 0) {
      breakSeconds[breakCount - 1] = breakMinutes * 60 * 2;
      warnings.add(ScheduleWarning.lastBreakLongApplied);
    }

    return ScheduleBuildResult(
      _assemble(
        startAtMs: startAtMs,
        studySeconds: studySeconds,
        breakSeconds: breakSeconds,
      ),
      warnings,
    );
  }

  // --- C) Bitiş saatine göre plan ---

  /// "22:30'da bitirmek istiyorum" senaryosu.
  ///
  /// Toplam mola süresi mevcut süreden düşülür, kalan çalışma bloklarına
  /// bölünür. Artık saniyeler **son çalışma bloğuna** eklenir; böylece
  /// `plannedEndAtMs` istenen bitiş anına **tam olarak** eşit olur.
  static ScheduleBuildResult fromEndTime({
    required int nowMs,
    required int endAtMs,
    required int breakCount,
    required int breakMinutes,
  }) {
    if (breakCount < 0) {
      throw const PlanFailure('Mola sayısı negatif olamaz.');
    }
    if (breakCount > 0 && breakMinutes <= 0) {
      throw const PlanFailure('Mola süresi en az 1 dakika olmalı.');
    }

    final alignedNow = alignToSecond(nowMs);
    final alignedEnd = alignToSecond(endAtMs);
    if (alignedEnd <= alignedNow) {
      throw const PlanFailure('Bitiş saati şu andan sonra olmalı.');
    }

    final availableS = (alignedEnd - alignedNow) ~/ 1000;
    final totalBreakS = breakCount * breakMinutes * 60;
    final studyS = availableS - totalBreakS;

    if (studyS < minStudyBlockMinutes * 60) {
      throw const PlanFailure(
        'Bu saate kadar yeterli çalışma süresi yok. '
        'Molalar düşüldükten sonra $minStudyBlockMinutes dakikadan az kalıyor.',
      );
    }

    final studyMinutes = studyS ~/ 60;
    final leftoverS = studyS % 60;

    final warnings = <ScheduleWarning>[];
    final studySeconds = _splitStudyMinutes(studyMinutes, breakCount + 1);

    // Dakikaya sığmayan artık saniyeler kaybolmasın: son bloğa eklenir.
    if (leftoverS > 0) {
      studySeconds[studySeconds.length - 1] += leftoverS;
    }

    for (final s in studySeconds) {
      if (s > maxStudyBlockS) {
        warnings.add(ScheduleWarning.blockTooLong);
        break;
      }
    }

    final breakSeconds = List<int>.filled(breakCount, breakMinutes * 60);

    return ScheduleBuildResult(
      _assemble(
        startAtMs: alignedNow,
        studySeconds: studySeconds,
        breakSeconds: breakSeconds,
      ),
      warnings,
    );
  }

  // --- İç yardımcılar ---

  /// Toplam çalışma süresini **dakika bazında** bloklara böler.
  ///
  /// Artık dakikalar ilk bloklara dağıtılır:
  /// - 120 dk / 5 blok → [24, 24, 24, 24, 24]
  /// - 100 dk / 4 blok → [25, 25, 25, 25]
  /// - 101 dk / 4 blok → [26, 25, 25, 25]
  ///
  /// Bölme saniye üzerinden yapılırsa 101 dk / 4 blok "25dk 15sn × 4" üretir;
  /// bu hem kullanıcıya tuhaf görünür hem de ürün sözleşmesine aykırıdır.
  /// Bu yüzden dağıtım dakika tamsayısı üzerinden yapılıp sonra saniyeye
  /// çevrilir.
  ///
  /// Dönen liste **saniye** cinsindendir.
  static List<int> _splitStudyMinutes(int totalStudyMinutes, int studyBlocks) {
    if (studyBlocks <= 0) {
      throw const PlanFailure('Çalışma bloğu sayısı en az 1 olmalı.');
    }
    if (totalStudyMinutes <= 0) {
      throw const PlanFailure('Toplam çalışma süresi sıfırdan büyük olmalı.');
    }

    final base = totalStudyMinutes ~/ studyBlocks;
    final rem = totalStudyMinutes % studyBlocks;

    if (base < minStudyBlockMinutes) {
      throw const PlanFailure(
        'Blok başına en az $minStudyBlockMinutes dakika gerekiyor. '
        'Mola sayısını azalt veya toplam süreyi artır.',
      );
    }

    return List<int>.generate(
      studyBlocks,
      (i) => (i < rem ? base + 1 : base) * 60,
      growable: true,
    );
  }

  /// Çalışma ve mola sürelerini sırayla dizip mutlak zaman damgalı
  /// çizelgeye çevirir. `study, break, study, break, ..., study` düzeni.
  static SessionSchedule _assemble({
    required int startAtMs,
    required List<int> studySeconds,
    required List<int> breakSeconds,
  }) {
    final blocks = <ScheduleBlock>[];
    var cursor = alignToSecond(startAtMs);
    var index = 0;

    for (var i = 0; i < studySeconds.length; i++) {
      final s = studySeconds[i];
      blocks.add(
        ScheduleBlock(
          index: index++,
          type: BlockType.study,
          startMs: cursor,
          endMs: cursor + s * 1000,
          seconds: s,
        ),
      );
      cursor += s * 1000;

      if (i < breakSeconds.length) {
        final b = breakSeconds[i];
        blocks.add(
          ScheduleBlock(
            index: index++,
            type: BlockType.breakTime,
            startMs: cursor,
            endMs: cursor + b * 1000,
            seconds: b,
          ),
        );
        cursor += b * 1000;
      }
    }

    return SessionSchedule.fromBlocks(
      createdAtMs: alignToSecond(startAtMs),
      blocks: blocks,
    );
  }
}
