import 'package:intl/intl.dart';

/// Every date and time a player reads goes through here.
///
/// The screens used to build their own strings with `padLeft(2, '0')`,
/// which produced `29.07.2026` — day-first, dot-separated, German. The
/// interface is English, so anyone outside Europe read that as the 7th
/// of September. These formats are locale-aware instead.
///
/// Not to be used for anything the SERVER sees. Day boundaries travel as
/// `yyyy-MM-dd` in UTC and are built in the repositories; those must stay
/// independent of the device's locale or check-ins land on the wrong day.
///
/// No locale is passed, so `intl` falls back to `en_US` — matching the
/// interface. The day the app speaks more languages, this is the single
/// place to hand the device locale in.

/// Calendar date, e.g. `Jul 29, 2026`. UTC date-only values must not
/// shift to the preceding day on devices west of Greenwich.
String formatDate(DateTime at) => DateFormat.yMMMd().format(at);

/// `Wednesday, Jul 29, 2026`
String formatWeekdayDate(DateTime at) {
  return '${DateFormat.EEEE().format(at)}, '
      '${DateFormat.yMMMd().format(at)}';
}

/// `10:32` — 24-hour, the same as before. Now one place to change it.
String formatTime(DateTime at) => DateFormat.Hm().format(at.toLocal());

/// When someone last put something on the board, phrased the way a
/// person would say it: `just now`, `18 min ago`, `Today, 08:14`,
/// `Yesterday, 21:43`, `Jul 28, 06:02`.
///
/// Fresh entries get a relative form because that is what you care about
/// in the moment; anything older than an hour gets a clock time, because
/// by then the habit — always logs at eight, always just before midnight
/// — is the interesting part.
String formatLastActivity(DateTime? at) {
  if (at == null) return 'never';

  final local = at.toLocal();
  final now = DateTime.now();
  final elapsed = now.difference(local);

  if (elapsed.isNegative || elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';

  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(local.year, local.month, local.day);
  final dayGap = today.difference(thatDay).inDays;

  final clock = DateFormat.Hm().format(local);
  if (dayGap == 0) return 'Today, $clock';
  if (dayGap == 1) return 'Yesterday, $clock';
  return '${DateFormat.MMMd().format(local)}, $clock';
}
