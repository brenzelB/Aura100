/// Target-scaled shortcuts shared by the amount sheet and today's cards.
List<double> progressPresets(double target) {
  if (!target.isFinite || target <= 0) return const [];
  final values = <double>{};
  for (final value in [target * 0.1, target * 0.25, target * 0.5]) {
    final rounded = value >= 100
        ? (value / 10).round() * 10.0
        : value >= 10
            ? value.roundToDouble()
            : value >= 1
                ? (value * 2).round() / 2
                : (value * 100).round() / 100;
    if (rounded > 0) values.add(rounded);
  }
  return values.toList();
}
