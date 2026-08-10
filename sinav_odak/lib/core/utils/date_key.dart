/// Bir oturumun hangi "güne" yazılacağını belirleyen anahtar: 'YYYY-MM-DD'.
///
/// Kural: dateKey her zaman oturumun BAŞLANGIÇ anının YEREL gününe göre
/// hesaplanır. Gece 23:50'de başlayıp 00:40'ta biten oturum, başladığı güne
/// yazılır. Böylece kullanıcının "dün gece çalıştım" algısıyla istatistik uyar.
library;

import 'package:intl/intl.dart';


final DateFormat _fmt = DateFormat('yyyy-MM-dd');

String dateKeyOf(DateTime dt) => _fmt.format(dt);

String dateKeyOfMs(int ms) =>
    dateKeyOf(DateTime.fromMillisecondsSinceEpoch(ms));

String todayKey() => dateKeyOf(DateTime.now());

DateTime dateKeyToLocal(String key) => _fmt.parseStrict(key);

/// [from] ile [to] arasındaki (dahil) tüm gün anahtarları.
List<String> dateKeyRange(DateTime from, DateTime to) {
  final out = <String>[];
  var cur = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  while (!cur.isAfter(end)) {
    out.add(dateKeyOf(cur));
    cur = cur.add(const Duration(days: 1));
  }
  return out;
}

/// Haftanın başlangıcı (Pazartesi) — TR kullanımına uygun.
DateTime startOfWeek(DateTime dt) {
  final d = DateTime(dt.year, dt.month, dt.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

DateTime startOfMonth(DateTime dt) => DateTime(dt.year, dt.month);
