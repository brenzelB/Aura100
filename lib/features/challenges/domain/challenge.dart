/// How often a quest expects check-ins. Weekly/monthly periods are
/// 7/30-day blocks anchored to the quest's start date.
enum CheckinPeriod {
  daily,
  weekly,
  monthly;

  static CheckinPeriod fromDb(String? value) => switch (value) {
        'weekly' => weekly,
        'monthly' => monthly,
        _ => daily,
      };

  int get lengthDays => switch (this) {
        daily => 1,
        weekly => 7,
        monthly => 30,
      };

  /// Caption for stats tiles ("7/8 days" vs "3/4 weeks").
  String get unitLabel => switch (this) {
        daily => 'days',
        weekly => 'weeks',
        monthly => 'months',
      };
}

/// Who fights whom in a quest — fixed at creation.
enum QuestMode {
  /// Everyone plays for themselves (the classic).
  solo,

  /// ONE FOR ALL: a single missed period hits the whole party.
  coop,

  /// RED vs BLUE: two teams, the busier one (check-ins per member)
  /// takes a 25% tribute from the losers at the end.
  versus,

  /// Elimination: bust your strikes and you are OUT. Last one standing
  /// wins. Inherently endless, and starts from a lobby.
  lastManStanding;

  static QuestMode fromDb(String? value) => switch (value) {
        'coop' => coop,
        'versus' => versus,
        'last_man_standing' => lastManStanding,
        _ => solo,
      };

  String get dbValue => this == lastManStanding ? 'last_man_standing' : name;
}

/// A quest's lifecycle: waiting in a lobby, running, or over.
enum QuestLifecycle {
  lobby,
  active,
  finished;

  static QuestLifecycle fromDb(String? value) => switch (value) {
        'lobby' => lobby,
        'finished' => finished,
        _ => active,
      };
}

/// How a period is satisfied.
enum GoalType {
  /// Tick it off once per period ("10 minutes of meditation").
  check,

  /// Collect partial amounts until a freely defined target is hit
  /// ("100 push-ups", "2.5 litres", "7500 steps").
  progress,

  /// Win by NOT doing something ("don't smoke"). Every slip is logged;
  /// staying inside the period's allowance still counts as a success.
  avoid;

  static GoalType fromDb(String? value) => switch (value) {
        'progress' => progress,
        'avoid' => avoid,
        _ => check,
      };

  String get dbValue => name;
}

/// One habit challenge — mirrors a row of the `challenges` table plus
/// the logged-in user's participant state (aura, checked-in flag).
class Challenge {
  const Challenge({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.auraGain,
    required this.auraPenalty,
    required this.maxStrikes,
    required this.startsOn,
    required this.createdAt,
    this.checkinPeriod = CheckinPeriod.daily,
    this.checkinsPerPeriod = 1,
    this.mode = QuestMode.solo,
    this.myTeam,
    this.lifecycle = QuestLifecycle.active,
    this.isEndless = false,
    this.startedAt,
    this.goalType = GoalType.check,
    this.targetValue,
    this.unit,
    this.dailyAllowance = 0,
    this.slipsInPeriod = 0,
    this.progressInPeriod = 0,
    this.checkedInToday = false,
    this.myAura = 0,
    this.strikesUsed = 0,
    this.periodsMissed = 0,
    this.memberCount = 1,
    this.joinedOn,
    this.ownedBenefits = const [],
    this.myStatus = 'active',
    this.balancePreset = 'custom',
    this.attacksEnabled = true,
    this.comebackNeeded = false,
    this.activeWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final int durationDays;
  final int auraGain;
  final int auraPenalty;

  /// Allowed missed check-ins/periods before the participant is excluded.
  final int maxStrikes;
  final String balancePreset;
  final bool attacksEnabled;
  final bool comebackNeeded;

  /// How often check-ins are expected (daily / weekly / monthly).
  final CheckinPeriod checkinPeriod;

  /// Check-ins required per period (always 1 for daily).
  final int checkinsPerPeriod;

  /// Solo, co-op (one for all) or versus (red vs blue).
  final QuestMode mode;

  /// The logged-in user's team in a versus quest ('red'/'blue');
  /// null in solo and co-op quests.
  final String? myTeam;

  /// Waiting in a lobby, running, or finished.
  final QuestLifecycle lifecycle;

  /// No fixed end — runs until everyone's gone / abandoned / (LMS) won.
  final bool isEndless;

  /// When the quest actually went live (for "running X days").
  final DateTime? startedAt;

  bool get isLobby => lifecycle == QuestLifecycle.lobby;
  bool get isFinished => lifecycle == QuestLifecycle.finished;
  bool get isLastManStanding => mode == QuestMode.lastManStanding;

  /// Whole days the quest has been running (endless display).
  int get runningDays {
    final from = startedAt?.toUtc() ??
        DateTime.utc(startsOn.year, startsOn.month, startsOn.day);
    final days = DateTime.now().toUtc().difference(from).inDays;
    return days < 0 ? 0 : days + 1; // day 1 on the first day
  }

  /// Checked off, or collected towards a target.
  final GoalType goalType;

  /// The amount to reach per period — progress quests only.
  final double? targetValue;

  /// The freely chosen unit of [targetValue] ("Reps", "km").
  final String? unit;

  /// Slips permitted per period on an avoid quest (0 = cold turkey).
  final int dailyAllowance;

  /// Slips the user logged in the CURRENT period (avoid quests).
  final int slipsInPeriod;

  /// How much the user has logged in the CURRENT period.
  final double progressInPeriod;

  bool get isProgress => goalType == GoalType.progress;

  /// A negative quest: the win condition is not doing the thing.
  bool get isAvoid => goalType == GoalType.avoid;

  /// Slips left before the period is lost (never negative).
  int get slipsLeft {
    final left = dailyAllowance - slipsInPeriod;
    return left < 0 ? 0 : left;
  }

  /// The period is blown — the limit was already exceeded.
  bool get slipLimitBroken => isAvoid && slipsInPeriod > dailyAllowance;

  /// One slip away from losing the period (or already at a zero budget).
  bool get slipNearLimit => isAvoid && !slipLimitBroken && slipsLeft <= 1;

  /// 0.0 – 1.0, clamped. Meaningless for check-off quests.
  double get progressRatio {
    final target = targetValue;
    if (target == null || target <= 0) return 0;
    return (progressInPeriod / target).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressRatio * 100).round();

  /// What is still missing this period (never negative).
  double get progressRemaining {
    final target = targetValue;
    if (target == null) return 0;
    final left = target - progressInPeriod;
    return left <= 0 ? 0 : left;
  }

  /// This period's goal is met (or beaten).
  bool get goalReached {
    final target = targetValue;
    return isProgress &&
        target != null &&
        target > 0 &&
        progressInPeriod >= target;
  }

  /// Reps logged BEYOND the goal this period (bonus, never negative).
  double get overshoot {
    final target = targetValue;
    if (target == null) return 0;
    final extra = progressInPeriod - target;
    return extra > 0 ? extra : 0;
  }

  /// First day of the challenge (UTC date).
  final DateTime startsOn;

  final DateTime createdAt;

  /// Whether the logged-in user already checked in today (UTC day).
  final bool checkedInToday;

  /// The logged-in user's aura earned INSIDE this challenge
  /// (challenge_participants.challenge_aura) — the shop currency.
  final int myAura;

  /// Strikes burnt so far — settled by the hourly engine, so this is
  /// the authoritative figure (shield-absorbed misses don't count).
  final int strikesUsed;

  /// Periods missed so far (settled figure; includes shielded ones).
  final int periodsMissed;

  /// Active party size (including the user themselves).
  final int memberCount;

  /// UTC date the logged-in user joined (participant created_at).
  /// Days before this don't count against them. Falls back to
  /// [startsOn] when unknown.
  final DateTime? joinedOn;

  /// Titles of the shop benefits the user owns in THIS quest
  /// (deduplicated) — shown on the card icon and in the detail header.
  final List<String> ownedBenefits;

  /// The logged-in player's own participation status in this quest:
  /// `active` / `failed` / `eliminated` / `completed`.
  ///
  /// Losing does NOT remove anyone from a quest. The player keeps their
  /// seat, keeps seeing the party and the history, and can leave when
  /// they feel like it — they just can't score any more.
  final String myStatus;

  /// Out of the running: the quest is still visible, but every action
  /// that would touch the competition is closed off. The server enforces
  /// the same rule; this is only what the interface goes by.
  bool get amIOut => myStatus == 'failed' || myStatus == 'eliminated';

  /// The days of the week this quest actually runs on, as ISO numbers
  /// (1 = Monday … 7 = Sunday). All seven unless the creator narrowed it.
  ///
  /// A day that is not in here demands nothing: no check-in, no reps, no
  /// strike, and it does not count as a missed day. The server enforces
  /// that; everything here only makes it visible.
  final List<int> activeWeekdays;

  /// Narrowed to fewer than seven days — worth showing as a badge.
  bool get hasRestDays => activeWeekdays.length < 7;

  /// Does this quest run on [day]?
  bool runsOn(DateTime day) => activeWeekdays.contains(day.weekday);

  /// Next possible comeback date, including rest days and a lost avoid period.
  DateTime? nextComebackDate(DateTime now) {
    if (amIOut || isFinished || isLobby) return null;
    final utc = now.toUtc();
    var day = DateTime.utc(utc.year, utc.month, utc.day);
    if (day.isBefore(startsOn)) day = startsOn;
    if (slipLimitBroken) {
      day = periodStartFor(day).add(Duration(days: checkinPeriod.lengthDays));
    } else if (checkedInToday) {
      day = day.add(const Duration(days: 1));
    }
    for (var i = 0; i < 7; i++) {
      if (!isEndless && !day.isBefore(endsAt)) return null;
      if (runsOn(day)) return day;
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  /// Does it run today (UTC, the same day the server settles on)?
  bool get runsToday => runsOn(DateTime.now().toUtc());

  /// `Mon–Fri` / `Mon, Wed, Fri` / `Every day` — the short label the
  /// stakes row and the quest card use.
  String get weekdayLabel {
    if (!hasRestDays) return 'Every day';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final sorted = [...activeWeekdays]..sort();
    // A single unbroken run reads better as a range.
    final isRun =
        sorted.length > 2 && sorted.last - sorted.first == sorted.length - 1;
    if (isRun) return '${names[sorted.first - 1]}–${names[sorted.last - 1]}';
    return sorted.map((d) => names[d - 1]).join(', ');
  }

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        balancePreset: json['balance_preset'] as String? ?? 'custom',
        attacksEnabled: json['attacks_enabled'] as bool? ?? true,
        comebackNeeded: json['comeback_needed'] as bool? ?? false,
        id: json['id'] as String,
        creatorId: json['creator_id'] as String,
        title: json['title'] as String,
        description: (json['description'] ?? '') as String,
        durationDays: json['duration_days'] as int,
        auraGain: json['aura_gain'] as int,
        auraPenalty: json['aura_penalty'] as int,
        maxStrikes: json['max_strikes'] as int,
        checkinPeriod: CheckinPeriod.fromDb(json['checkin_period'] as String?),
        checkinsPerPeriod: (json['checkins_per_period'] ?? 1) as int,
        mode: QuestMode.fromDb(json['mode'] as String?),
        lifecycle: QuestLifecycle.fromDb(json['lifecycle'] as String?),
        isEndless: (json['is_endless'] ?? false) as bool,
        startedAt: json['started_at'] == null
            ? null
            : DateTime.parse(json['started_at'] as String),
        goalType: GoalType.fromDb(json['goal_type'] as String?),
        targetValue: (json['target_value'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        dailyAllowance: (json['daily_allowance'] ?? 0) as int,
        // Older rows predate the column; they simply run every day.
        activeWeekdays: (json['active_weekdays'] as List?)
                ?.map((d) => (d as num).toInt())
                .toList() ??
            const [1, 2, 3, 4, 5, 6, 7],
        // Date-only string → pin to UTC midnight to match the DB's UTC days.
        startsOn: DateTime.parse('${json['starts_on']}T00:00:00Z'),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Challenge copyWith({
    bool? checkedInToday,
    int? myAura,
    bool? comebackNeeded,
    int? strikesUsed,
    int? periodsMissed,
    int? memberCount,
    DateTime? joinedOn,
    List<String>? ownedBenefits,
    String? myTeam,
    double? progressInPeriod,
    int? slipsInPeriod,
    String? myStatus,
    List<int>? activeWeekdays,
  }) =>
      Challenge(
        balancePreset: balancePreset,
        attacksEnabled: attacksEnabled,
        comebackNeeded: comebackNeeded ?? this.comebackNeeded,
        id: id,
        creatorId: creatorId,
        title: title,
        description: description,
        durationDays: durationDays,
        auraGain: auraGain,
        auraPenalty: auraPenalty,
        maxStrikes: maxStrikes,
        startsOn: startsOn,
        createdAt: createdAt,
        checkinPeriod: checkinPeriod,
        checkinsPerPeriod: checkinsPerPeriod,
        mode: mode,
        myTeam: myTeam ?? this.myTeam,
        lifecycle: lifecycle,
        isEndless: isEndless,
        startedAt: startedAt,
        goalType: goalType,
        targetValue: targetValue,
        unit: unit,
        dailyAllowance: dailyAllowance,
        slipsInPeriod: slipsInPeriod ?? this.slipsInPeriod,
        progressInPeriod: progressInPeriod ?? this.progressInPeriod,
        checkedInToday: checkedInToday ?? this.checkedInToday,
        myAura: myAura ?? this.myAura,
        strikesUsed: strikesUsed ?? this.strikesUsed,
        periodsMissed: periodsMissed ?? this.periodsMissed,
        memberCount: memberCount ?? this.memberCount,
        joinedOn: joinedOn ?? this.joinedOn,
        ownedBenefits: ownedBenefits ?? this.ownedBenefits,
        myStatus: myStatus ?? this.myStatus,
        activeWeekdays: activeWeekdays ?? this.activeWeekdays,
      );

  /// Day AFTER the last challenge day (exclusive end, UTC midnight).
  DateTime get endsAt => startsOn.add(Duration(days: durationDays));

  /// First day of the period containing [day] — 7/30-day blocks
  /// anchored to [startsOn], mirroring the server's rule exactly.
  DateTime periodStartFor(DateTime day) {
    final start = DateTime.utc(startsOn.year, startsOn.month, startsOn.day);
    final target = DateTime.utc(day.year, day.month, day.day);
    final len = checkinPeriod.lengthDays;
    final daysIn = target.difference(start).inDays;
    if (daysIn <= 0) return start;
    return start.add(Duration(days: (daysIn ~/ len) * len));
  }

  /// The period the user is currently in (UTC).
  DateTime get currentPeriodStart => periodStartFor(DateTime.now().toUtc());

  bool get hasStarted => !DateTime.now().toUtc().isBefore(startsOn);

  /// Whole days left, rounded UP and never negative.
  int get daysLeft {
    final hours = endsAt.difference(DateTime.now().toUtc()).inHours;
    return hours <= 0 ? 0 : (hours / 24).ceil();
  }

  /// Chip label: "in lobby" / "running 5d" / "starts in 3d" /
  /// "12d left" / "ends today".
  String get timeLeftLabel {
    if (isLobby) return 'in lobby';
    if (isEndless) return 'running ${runningDays}d';
    if (!hasStarted) {
      final hours = startsOn.difference(DateTime.now().toUtc()).inHours;
      final days = hours <= 0 ? 1 : (hours / 24).ceil();
      return 'starts in ${days}d';
    }
    return daysLeft <= 1 ? 'ends today' : '${daysLeft}d left';
  }
}
