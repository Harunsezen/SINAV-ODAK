import '../entities/session_schedule.dart';

/// Kurulacak tek bir bildirim.
///
/// Saf veri: hangi anda, hangi metinle, hangi kimlikle. Platform eklentisi
/// bunu yalnızca uygular.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.atMs,
    required this.title,
    required this.body,
    required this.blockIndex,
  });

  /// Platform bildirim kimliği. Aynı oturum + blok için daima aynı değer.
  final int id;

  /// Mutlak tetiklenme anı (epoch ms).
  final int atMs;

  final String title;
  final String body;
  final int blockIndex;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.atMs == atMs &&
      other.title == title &&
      other.body == body &&
      other.blockIndex == blockIndex;

  @override
  int get hashCode => Object.hash(id, atMs, title, body, blockIndex);

  @override
  String toString() => 'PlannedNotification(#$id @$atMs "$body")';
}

/// Çizelgeden bildirim planı üretir.
///
/// **Neden ayrı bir sınıf?** `flutter_local_notifications` platform kanalı
/// kullanır ve host testlerinde `MissingPluginException` atar. Planlama
/// mantığı (hangi bildirim, ne zaman, hangi metin) burada saf Dart olarak
/// durduğu için tam test edilebilir; eklenti adaptörü yalnızca uygular.
///
/// Bu dosya saf Dart'tır: Flutter, Drift veya Riverpod import etmez ve
/// `DateTime.now()` çağırmaz.
abstract final class NotificationPlanner {
  /// Bir oturumda desteklenen en fazla blok sayısı.
  ///
  /// Bildirim kimlikleri `taban + blokIndeksi` şeklinde üretildiği için
  /// iptal ederken bu aralık taranır. 64 blok ≈ 32 çalışma + 32 mola;
  /// gerçekçi bir oturum bunun çok altındadır.
  static const int maxBlocksPerSession = 64;

  /// Çizelge için kurulacak bildirimleri üretir.
  ///
  /// [fromMs] verilirse yalnızca o andan SONRAKİ bildirimler döner —
  /// geçmişe bildirim kurmak anlamsızdır ve bazı platformlarda hata verir.
  static List<PlannedNotification> plan({
    required String sessionId,
    required SessionSchedule schedule,
    int? fromMs,
  }) {
    final base = baseIdOf(sessionId);
    final out = <PlannedNotification>[];
    final blocks = schedule.blocks;

    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      if (fromMs != null && b.endMs <= fromMs) continue;

      final isLast = i == blocks.length - 1;
      final next = isLast ? null : blocks[i + 1];

      final String title;
      final String body;

      if (isLast) {
        title = 'Oturum tamamlandı';
        body = 'Harika iş. Şimdi kaç soru çözdüğünü kaydedelim.';
      } else if (b.isStudy) {
        // Çalışma bitti, sırada mola var.
        final studyNo = schedule.studyOrdinalOf(i);
        final breakMin = (next!.seconds / 60).round();
        title = 'Mola zamanı';
        body = '$studyNo. blok bitti. $breakMin dakika molan başladı.';
      } else {
        // Mola bitti, sırada çalışma var.
        final nextStudyNo = schedule.studyOrdinalOf(i + 1);
        title = 'Mola bitti';
        body = '$nextStudyNo. blok seni bekliyor.';
      }

      out.add(
        PlannedNotification(
          id: base + i,
          atMs: b.endMs,
          title: title,
          body: body,
          blockIndex: i,
        ),
      );
    }

    return out;
  }

  /// Bir oturuma ait bildirim kimliklerinin başlangıcı.
  ///
  /// `String.hashCode` **süreçler arası kararlı değildir**; uygulama yeniden
  /// başlatıldığında eski bildirimleri iptal edemezdik. Bu yüzden içerikten
  /// deterministik FNV-1a türevi bir karma kullanılıyor.
  static int baseIdOf(String sessionId) {
    var hash = 2166136261;
    for (final unit in sessionId.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7FFFFFFF;
    }
    // Kimlik aralığı: [base, base + maxBlocksPerSession)
    // 32-bit int sınırını aşmayacak şekilde daraltılır.
    return (hash % 20000000) * maxBlocksPerSession % 0x7FFFFFFF;
  }

  /// Oturumun iptal edilmesi gereken tüm bildirim kimlikleri.
  static List<int> idsOf(String sessionId) {
    final base = baseIdOf(sessionId);
    return List<int>.generate(maxBlocksPerSession, (i) => base + i);
  }
}
