/// What the server reports after logging (or undoing) a slip on a
/// negative quest.
class SlipResult {
  const SlipResult({
    required this.count,
    required this.allowance,
    required this.over,
    required this.justFailed,
    required this.struck,
    required this.shielded,
    required this.aura,
  });

  /// Slips on the board for the current period, this one included.
  final int count;

  /// Slips permitted this period (0 = cold turkey).
  final int allowance;

  /// The period has gone past its allowance — it is lost.
  final bool over;

  /// THIS slip is the one that broke the limit (drives the hard reveal).
  final bool justFailed;

  /// A strike was booked (false when a Streak Shield absorbed it).
  final bool struck;

  /// A Streak Shield ate the strike.
  final bool shielded;

  /// The user's quest aura after any penalty.
  final int aura;

  int get left => allowance - count < 0 ? 0 : allowance - count;

  factory SlipResult.fromJson(Map<String, dynamic> json) => SlipResult(
        count: (json['count'] as num).toInt(),
        allowance: (json['allowance'] as num).toInt(),
        over: (json['over'] ?? false) as bool,
        justFailed: (json['just_failed'] ?? false) as bool,
        struck: (json['struck'] ?? false) as bool,
        shielded: (json['shielded'] ?? false) as bool,
        aura: (json['aura'] as num?)?.toInt() ?? 0,
      );
}
