/// Durata di un brano: 3:07, e 1:02:11 solo quando serve davvero.
String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final seconds = d.inSeconds.abs();
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

/// Durata complessiva di un album o della libreria: "48 min", "3 h 12 min".
String formatTotal(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return m > 0 ? '$h h $m min' : '$h h';
  if (d.inMinutes > 0) return '${d.inMinutes} min';
  return '${d.inSeconds} s';
}

String plural(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';
