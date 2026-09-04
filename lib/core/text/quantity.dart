/// Formatting and parsing for freely defined progress amounts.
///
/// Targets are whatever the player types — 100, 7500, 2.5, 13 — so the
/// display must not force decimals onto whole numbers, and the input
/// must accept a comma as well as a dot.
library;

/// 100.0 -> "100", 2.5 -> "2.5", 2.50 -> "2.5", 0.25 -> "0.25"
String formatQuantity(num value) {
  final v = value.toDouble();
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// Parses user input, accepting "2,5" as well as "2.5".
/// Returns null when the text is not a usable positive amount.
double? parseQuantity(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

/// "72 / 100 Reps"
String formatProgress(num current, num target, String unit) =>
    '${formatQuantity(current)} / ${formatQuantity(target)} $unit';
