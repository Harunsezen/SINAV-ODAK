/// Süre ve sayı biçimlendiricileri.
library;

/// 8130 sn -> "2sa 15dk"
String formatDurationShort(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '${m}dk';
  if (m == 0) return '${h}sa';
  return '${h}sa ${m}dk';
}

/// 1122 sn -> "18:42" (sayaç görünümü)
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Net: 41.0 -> "41", 40.25 -> "40,25"
String formatNet(double net) {
  final rounded = (net * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(2).replaceAll('.', ',');
}
