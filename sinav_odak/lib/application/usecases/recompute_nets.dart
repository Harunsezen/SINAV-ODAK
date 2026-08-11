import 'package:drift/drift.dart';

import '../../data/local/database.dart';
import '../../domain/entities/enums.dart';
import '../../domain/services/net_calculator.dart';

/// Net katsayısı değiştiğinde GEÇMİŞ oturumların netini yeniden hesaplar.
///
/// **Neden gerekli:** `study_sessions.net` denormalize bir alan — oturum
/// kaydedilirken o anki katsayıyla hesaplanıp yazılıyor. Kullanıcı ayarlardan
/// katsayıyı 4'ten 3'e çektiğinde bu alan olduğu gibi kalıyordu; istatistik
/// ekranı eski katsayıyla hesaplanmış netleri yeni katsayıymış gibi
/// gösteriyordu. Toplam net **sessizce yanlış** oluyordu.
///
/// Akış: her oturumun netini yeni katsayıyla yeniden hesapla → yaz →
/// etkilenen GÜNLERİN `daily_stats` özetini yeniden üret. İkinci adım
/// olmadan oturum satırları düzelir ama grafikleri besleyen günlük özet
/// eski değerde kalırdı.
class RecomputeNetsUseCase {
  RecomputeNetsUseCase(this._db);

  final AppDatabase _db;

  /// [coefficient] ile tüm tamamlanmış oturumları yeniden hesaplar.
  ///
  /// Dönen değer güncellenen oturum sayısıdır (kullanıcıya "142 oturum
  /// güncellendi" demek için).
  ///
  /// Tek transaction: yarıda kalırsa bazı oturumlar yeni, bazıları eski
  /// katsayıyla kalır ve toplam net hiçbir katsayıya karşılık gelmez.
  Future<int> call({required double coefficient}) async {
    return _db.transaction(() async {
      final sessions = await (_db.select(_db.studySessions)
            ..where((t) => t.status.equalsValue(SessionStatus.running).not()))
          .get();

      if (sessions.isEmpty) return 0;

      final touchedDays = <String>{};
      var updated = 0;

      for (final s in sessions) {
        // Soru girilmemiş oturumun neti zaten 0; hesaplamaya sokmak
        // `NetCalculator`'ın doğrulamalarını gereksiz yere tetikler.
        if (s.questionCount == 0) continue;

        final result = NetCalculator.calculate(
          questionCount: s.questionCount,
          correctCount: s.correctCount,
          wrongCount: s.wrongCount,
          emptyCount: s.emptyCount,
          coefficient: coefficient,
          actualDurationS: s.actualDurationS,
        );

        if (result.net == s.net) continue;

        await (_db.update(_db.studySessions)..where((t) => t.id.equals(s.id)))
            .write(StudySessionsCompanion(net: Value(result.net)));
        touchedDays.add(s.dateKey);
        updated++;
      }

      for (final day in touchedDays) {
        await _db.statsDao.recomputeDay(day);
      }

      return updated;
    });
  }
}
