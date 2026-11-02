import '../../../core/text/durations.dart';
import '../../../core/text/quantity.dart';
import '../domain/challenge.dart';

/// How a quest's amounts are written out.
///
/// A CLOCK quest stores minutes, and a raw minute count is unreadable
/// — 970 means nothing, "16h 10m" means everything. Rather than
/// teaching every widget that rule, the quest answers for itself.
///
/// This lives in presentation on purpose: the domain has no business
/// knowing how a number looks.
extension QuestAmountFormat on Challenge {
  /// The bare number: "16h 10m" on a clock quest, "72" otherwise.
  String amount(num value) =>
      isClock ? formatMinutes(value) : formatQuantity(value);

  /// The number with its unit: "16h 10m" / "72 Reps".
  ///
  /// A time already says what it is, so a clock quest never appends
  /// "min" — "970 min" is exactly the thing being avoided.
  String amountWithUnit(num value) => isClock
      ? formatMinutes(value)
      : '${formatQuantity(value)} ${unit ?? ''}'.trim();

  /// Current against target: "12h 30m / 16h" / "72 / 100 Reps".
  String progressLabel(num current, num target) => isClock
      ? formatTimeProgress(current, target)
      : formatProgress(current, target, unit ?? '');

  /// What a logged entry reads as in a feed: "+45m" / "+20 Reps".
  String addedLabel(num value) =>
      isClock ? '+${formatMinutes(value)}' : '+${amountWithUnit(value)}';
}
