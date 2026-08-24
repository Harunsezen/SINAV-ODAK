import 'package:drift/drift.dart';

import '../../../domain/entities/enums.dart';

/// KİTAP OKUMA OTURUMU (v1.3).
///
/// ## Neden `study_sessions`'a eklenmedi, AYRI tablo
///
/// Çalışma oturumunun üç zorunlu alanı var: **ders**, **çalışma türü** ve
/// **çizelge (`schedule_json`)**. Kitap okumanın üçü de yok.
///
/// Aynı tabloya sığdırmak için "Kitap Okuma" diye sahte bir ders ve sahte
/// bir çalışma türü uydurmak gerekirdi. O sahte ders **ders seçicide**,
/// **istatistikteki pasta grafiğinde**, **CSV'de** ve **"gelişim gereken
/// konular"da** görünürdü: roman okuyan öğrenci, ders dağılımında
/// "Kitap Okuma %40" satırı bulurdu. Sayfa hedefi modunda ise çizelge
/// hiç yok — sayaç ileri sayıyor ve planlanmış bir bitişi yok; uydurma
/// bir `schedule_json` yazmak, çizelgeyi tek doğruluk kaynağı sayan
/// kurtarma akışını yalan bir veriyle beslerdi.
///
/// Ayrı tablonun bedeli: `daily_stats`, seri ve PDF yollarının kitap
/// oturumunu **ayrıca** okuması gerekiyor. Bu bedel görünür ve testle
/// kilitli; sahte ders satırının bedeli görünmez olurdu.
///
/// ## Doğru/yanlış/net YOK
///
/// Metrik yalnızca **süre + sayfa + kitap adı**. Net hesabı, odak skoru
/// ve yanlış defteri bu tabloya hiç dokunmuyor.
///
/// ## Süre çalışma süresine EKLENMİYOR
///
/// `daily_stats.total_study_s` yalnızca çalışma oturumlarını sayıyor;
/// okuma süresi `daily_stats.reading_s` içinde ayrı duruyor. Aksi halde
/// bir saat roman okuyan öğrencinin **günlük çalışma hedefi** kendiliğinden
/// dolardı. Grafik ikisini birlikte gösteriyor ama ayrı renklerle: kullanıcı
/// hem toplamı hem kırılımı görüyor (bkz. `stats_charts.dart`).
///
/// **Seri (streak) buna DAHİL:** o gün yalnızca kitap okuyan öğrencinin
/// zinciri kırılmıyor (koordinatör kuralı). Bkz.
/// `SessionRepository.saveBookSession`.
@TableIndex(name: 'idx_book_date', columns: {#dateKey})
@TableIndex(name: 'idx_book_status', columns: {#status})
class BookSessions extends Table {
  TextColumn get id => text()();

  /// 'YYYY-MM-DD' — okumanın BAŞLADIĞI yerel gün. Gece yarısını aşan
  /// oturum başladığı güne yazılıyor; çalışma oturumuyla aynı kural.
  TextColumn get dateKey => text()();

  TextColumn get mode => textEnum<BookMode>()();

  IntColumn get startedAt => integer()();
  IntColumn get endedAt => integer().nullable()();

  /// MOD A'da belirlenen süre (saniye). Sayfa hedefi modunda `null` —
  /// o modda planlanmış bir süre YOK, uydurulmuyor.
  IntColumn get plannedDurationS => integer().nullable()();

  /// MOD B'de belirlenen sayfa hedefi. Süre modunda `null`.
  IntColumn get pageTarget => integer().nullable()();

  /// Gerçekleşen okuma süresi (saniye). `BookInput.maxReadingS` ile
  /// tavanlı: sayacı açık unutulan oturum 23 saat okuma yazmasın.
  IntColumn get actualDurationS => integer().withDefault(const Constant(0))();

  /// Kullanıcının bildirdiği okunan sayfa. Ölçülmüyor, SORULUYOR.
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();

  /// **Boş bırakılabilir** (koordinatör kuralı). Boşsa `null` saklanıyor;
  /// istatistik ve PDF yerine geçen etiketi ("Kitap") gösteriyor.
  TextColumn get bookTitle => text().nullable().withLength(min: 1, max: 80)();

  TextColumn get status => textEnum<SessionStatus>()();

  @override
  Set<Column> get primaryKey => {id};
}
