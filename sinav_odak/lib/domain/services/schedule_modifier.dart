import '../../core/errors/failures.dart';
import '../entities/schedule_block.dart';
import '../entities/session_schedule.dart';

/// Mola uzatma ve mola atlama işlemleri.
///
/// Her işlem **yeni** bir [SessionSchedule] üretir; girdi çizelge değişmez.
/// Sonuç daima [SessionSchedule.fromBlocks] üzerinden kurulur, yani
/// toplamlar yeniden hesaplanır ve tam doğrulamadan geçer — tutarsız bir
/// çizelge üretmek mümkün değildir.
///
/// Saf fonksiyondur: `DateTime.now()` çağırmaz.
abstract final class ScheduleModifier {
  /// Bir oturumda toplam mola uzatma limiti (saniye). Ürün kararı: +10 dk.
  static const int maxTotalExtensionS = 600;

  /// [breakBlockIndex] numaralı molayı [addS] saniye uzatır ve sonraki
  /// tüm blokları ileri kaydırır.
  static SessionSchedule extendBreak(
    SessionSchedule schedule,
    int breakBlockIndex,
    int addS,
  ) {
    // Yalnızca ön koşul kontrolü için çağrılır; dönen blok kullanılmıyor.
    _requireBreakBlock(schedule, breakBlockIndex);

    if (addS <= 0) {
      throw const ValidationFailure(
        'Uzatma süresi sıfırdan büyük olmalı.',
        field: 'addS',
      );
    }

    // Limit oturum geneli için geçerlidir, tek mola için değil.
    final usedS = schedule.blocks.fold<int>(0, (sum, b) => sum + b.extendedS);
    if (usedS + addS > maxTotalExtensionS) {
      final remaining = maxTotalExtensionS - usedS;
      throw PlanFailure(
        'Mola uzatma limiti aşıldı. '
        'Kalan uzatma hakkı: ${remaining ~/ 60} dakika.',
      );
    }

    final deltaMs = addS * 1000;
    final blocks = <ScheduleBlock>[];

    for (final b in schedule.blocks) {
      if (b.index < breakBlockIndex) {
        blocks.add(b);
      } else if (b.index == breakBlockIndex) {
        blocks.add(
          b.copyWith(
            endMs: b.endMs + deltaMs,
            seconds: b.seconds + addS,
            extendedS: b.extendedS + addS,
          ),
        );
      } else {
        blocks.add(b.shiftBy(deltaMs));
      }
    }

    return SessionSchedule.fromBlocks(
      createdAtMs: schedule.createdAtMs,
      blocks: blocks,
    );
  }

  /// [breakBlockIndex] numaralı molayı [nowMs] anında erken bitirir ve
  /// sonraki tüm blokları öne çeker.
  static SessionSchedule skipBreak(
    SessionSchedule schedule,
    int breakBlockIndex,
    int nowMs,
  ) {
    final target = _requireBreakBlock(schedule, breakBlockIndex);
    final alignedNow = alignToSecond(nowMs);

    if (alignedNow <= target.startMs) {
      throw const ValidationFailure(
        'Mola henüz başlamadı; atlanamaz.',
        field: 'nowMs',
      );
    }
    // Tam bitiş anında da hata: mola zaten bitmişse skip anlamsızdır,
    // resolver kendiliğinden sonraki bloğa geçer.
    if (alignedNow >= target.endMs) {
      throw const ValidationFailure(
        'Mola zaten bitmiş; atlamak anlamsız.',
        field: 'nowMs',
      );
    }

    // Uzatma süresi GERÇEKTEN KULLANILAN kadarına düşürülür.
    //
    // Kullanıcı molayı +5 dk uzatıp hemen bitirirse, kullanmadığı uzatma
    // odak skorunda mola disiplini cezası olarak yazılmamalı. Bu yüzden
    // önce molanın uzatmasız özgün süresi bulunur, fiilen kullanılan süre
    // bunun üzerine ne kadar taştıysa yeni `extendedS` odur.
    final originalS = target.seconds - target.extendedS;
    final safeOriginalS = originalS < 0 ? 0 : originalS;
    final newSeconds = (alignedNow - target.startMs) ~/ 1000;
    final overflowS = newSeconds - safeOriginalS;
    final newExtendedS = overflowS < 0 ? 0 : overflowS;

    // Negatif delta: sonraki bloklar öne çekilir.
    final deltaMs = alignedNow - target.endMs;
    final blocks = <ScheduleBlock>[];

    for (final b in schedule.blocks) {
      if (b.index < breakBlockIndex) {
        blocks.add(b);
      } else if (b.index == breakBlockIndex) {
        blocks.add(
          b.copyWith(
            endMs: alignedNow,
            seconds: newSeconds,
            skipped: true,
            extendedS: newExtendedS,
          ),
        );
      } else {
        blocks.add(b.shiftBy(deltaMs));
      }
    }

    return SessionSchedule.fromBlocks(
      createdAtMs: schedule.createdAtMs,
      blocks: blocks,
    );
  }

  /// Ortak ön koşullar: geçerli indeks, mola tipi, atlanmamış olma.
  ///
  /// İndeks kontrolü listeye erişimden ÖNCE yapılır; aksi halde çağıran
  /// tarafa tipsiz bir `RangeError` sızıyordu.
  static ScheduleBlock _requireBreakBlock(
    SessionSchedule schedule,
    int breakBlockIndex,
  ) {
    if (breakBlockIndex < 0 || breakBlockIndex >= schedule.blockCount) {
      throw ValidationFailure(
        'Geçersiz blok indeksi: $breakBlockIndex',
        field: 'breakBlockIndex',
      );
    }

    final target = schedule.blocks[breakBlockIndex];

    if (!target.isBreak) {
      throw ValidationFailure(
        'Hedef blok bir mola değil: #$breakBlockIndex',
        field: 'breakBlockIndex',
      );
    }
    if (target.skipped) {
      throw const ValidationFailure(
        'Atlanmış mola üzerinde değişiklik yapılamaz.',
        field: 'breakBlockIndex',
      );
    }
    return target;
  }
}
