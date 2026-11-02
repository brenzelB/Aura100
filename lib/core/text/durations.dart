/// Formatting for CLOCK quests, whose amounts are stored in MINUTES.
///
/// Minutes are the storage unit because they keep the target a whole
/// number for every sane goal (16h = 960) and survive `numeric(12,2)`
/// without losing seconds. They are never shown raw: "970" tells a
/// player nothing, "16h 10m" tells them everything.
library;

/// "16h 10m" / "45m" / "0m" — a span of logged time.
///
/// Hours keep counting past 24 rather than rolling into days, because
/// that is how the thing being measured is spoken about: a 36-hour
/// fast is a 36-hour fast, not "1d 12h".
String formatMinutes(num minutes) {
  final total = minutes.isFinite ? minutes.round() : 0;
  if (total <= 0) return '0m';
  final hours = total ~/ 60;
  final mins = total % 60;
  if (hours == 0) return '${mins}m';
  return '${hours}h ${mins.toString().padLeft(2, '0')}m';
}

/// "14:22:08" — the live readout while a clock is running.
///
/// Seconds are in there on purpose. A counter that only moves once a
/// minute looks frozen, and the whole point of the running state is
/// that it is visibly alive.
String formatStopwatch(Duration elapsed) {
  final d = elapsed.isNegative ? Duration.zero : elapsed;
  final hours = d.inHours;
  final mins = d.inMinutes.remainder(60);
  final secs = d.inSeconds.remainder(60);
  final mm = mins.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
}

/// "12h 30m / 16h" — a clock quest's period total against its goal.
String formatTimeProgress(num current, num target) =>
    '${formatMinutes(current)} / ${formatMinutes(target)}';

/// Splits a minute count into the hours/minutes pair the target and
/// correction pickers edit.
({int hours, int minutes}) splitMinutes(num minutes) {
  final total = minutes.isFinite && minutes > 0 ? minutes.round() : 0;
  return (hours: total ~/ 60, minutes: total % 60);
}
