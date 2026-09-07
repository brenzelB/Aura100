import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../../core/widgets/theme_components.dart';

import '../../../../core/realtime/realtime_sync.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/text/dates.dart';
import '../../../../core/text/quantity.dart';
import '../../../../core/text/roasts.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/challenge_timeline.dart';
import '../../domain/progress_entry.dart';
import '../../domain/quest_member.dart';
import '../widgets/benefit_chip.dart';
import '../widgets/challenge_shop_sheet.dart';
import '../widgets/progress_widgets.dart';
import '../widgets/quest_activity_section.dart';
import '../widgets/quest_duels_section.dart';
import '../widgets/quest_party_section.dart';
import '../widgets/quest_reminder_row.dart';
import '../widgets/slip_widgets.dart';
import '../../../home/presentation/widgets/robbed_notice_gate.dart';
import '../../../home/presentation/widgets/targeted_roast_gate.dart';

/// Detail view of one quest: header info, stats and the day-by-day
/// timeline. Reached by tapping a challenge card.
///
/// The timeline is rendered as a SliverGrid inside a CustomScrollView —
/// cells are built lazily, so even a 365-day quest scrolls smoothly.
class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  /// Guards the roast lock dialog against stacking on rebuilds.
  bool _roastLockShowing = false;

  /// Roast ids already faced this session. The server ack is async, so
  /// the provider can still hand us a just-dismissed roast for a moment
  /// (a refresh racing the ack) — this stops a second dialog.
  final Set<String> _handledRoastIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  /// Safety net only. RealtimeSync pushes check-ins, progress, slips and
  /// duels for this quest as they land, so this timer exists purely to
  /// recover from a dropped socket — hence the long interval.
  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(RealtimeSync.fallbackInterval, (_) => _refreshData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshData();
      _startTimer();
    } else {
      _refreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    if (!mounted) return;
    // The tab shell is an IndexedStack, so this screen stays alive (and
    // its timer running) while the user is on another tab. TickerMode is
    // false for the hidden branches — use it to stay quiet until we are
    // actually on screen again.
    if (!TickerMode.valuesOf(context).enabled) return;
    ref.invalidate(myChallengesProvider);
    ref.invalidate(checkInsProvider(widget.challengeId));
    ref.invalidate(questMembersProvider(widget.challengeId));
    ref.invalidate(questDuelsProvider(widget.challengeId));
    ref.invalidate(progressEntriesProvider(widget.challengeId));
    ref.invalidate(questActivityProvider(widget.challengeId));
    ref.invalidate(targetedRoastsProvider);
  }

  /// Tells owners up front that leaving passes the crown on — the
  /// successor is the longest-standing member (same rule as the RPC).
  String _ownerHint(List<QuestMember> members) {
    final iAmOwner = members.any((m) => m.isMe && m.isOwner);
    if (!iAmOwner) return '';
    final others = members.where((m) => !m.isMe).toList();
    if (others.isEmpty) return '';
    return '\n\nYou own this quest — @${others.first.username} '
        'will take it over.';
  }

  /// Safety gate: abandoning is destructive (quest aura + gear are
  /// lost), so it always asks first.
  Future<void> _confirmAbandon(
    BuildContext context,
    Challenge challenge,
    List<QuestMember> members,
  ) async {
    // The roast is picked once so it doesn't change on dialog rebuilds.
    final roast = Roasts.random();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.5)),
        ),
        // Someone who is already out isn't giving up — they lost a while
        // ago and are only closing the tab. No roast, no guilt trip.
        title: Text(
          challenge.amIOut ? 'STOP WATCHING?' : 'GIVING UP?',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!challenge.amIOut) ...[
              Text(
                '"$roast"',
                style: Theme.of(dialogContext)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              challenge.amIOut
                  ? '"${challenge.title}" disappears from your quests and '
                      'you stop seeing how the others finish. You are '
                      'already out, so there is nothing left to lose.'
                      '${_ownerHint(members)}'
                  : '"${challenge.title}" disappears from your quests. '
                      'Your ${challenge.myAura} quest aura'
                      '${challenge.ownedBenefits.isEmpty ? '' : ' and your gear'} '
                      'will be lost. This cannot be undone.'
                      '${_ownerHint(members)}',
              style: Theme.of(dialogContext)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              challenge.amIOut ? 'KEEP WATCHING' : 'KEEP FIGHTING',
              style: TextStyle(color: AppColors.accentText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 40),
            ),
            child: Text(
                challenge.amIOut ? 'LEAVE QUEST' : "YES, I'M A LOSER"),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(abandonControllerProvider(challenge.id).notifier)
        .abandon();
    if (!context.mounted) return;

    if (result.ok) {
      context.pop(); // back to the (now shorter) quest list
      messenger.showSnackBar(SnackBar(
        content: Text(result.newOwner == null
            ? 'Quest "${challenge.title}" abandoned. ${Roasts.random()}'
            : 'Quest abandoned — @${result.newOwner} owns '
                '"${challenge.title}" now. ${Roasts.random()}'),
        backgroundColor: AppColors.surfaceLight,
      ));
    } else {
      final error = ref.read(abandonControllerProvider(challenge.id)).error;
      messenger.showSnackBar(SnackBar(
        content: Text(error is PostgrestException
            ? error.message
            : 'Could not abandon the quest - try again.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final challengesAsync = ref.watch(myChallengesProvider);
    final checkInsAsync = ref.watch(checkInsProvider(widget.challengeId));

    final roasts = ref.watch(targetedRoastsProvider).valueOrNull ?? [];
    final pendingRoast = roasts
        .where((r) => r.challengeId == widget.challengeId)
        .firstOrNull;

    // Entering the roasted quest's page triggers the lock — once per
    // roast. The id is marked handled BEFORE the (async) dismissal so a
    // racing refresh can't surface the same roast for a second dialog.
    if (pendingRoast != null &&
        !_roastLockShowing &&
        !_handledRoastIds.contains(pendingRoast.id)) {
      _roastLockShowing = true;
      _handledRoastIds.add(pendingRoast.id);
      final roast = pendingRoast;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _roastLockShowing = false;
          return;
        }
        await showTargetedRoastLockDialog(context, ref, roast);
        _roastLockShowing = false;
      });
    }

    final abandoning =
        ref.watch(abandonControllerProvider(widget.challengeId)).isLoading;

    final challenge = challengesAsync.valueOrNull
        ?.where((c) => c.id == widget.challengeId)
        .firstOrNull;
    final members = ref.watch(questMembersProvider(widget.challengeId)).valueOrNull ??
        const <QuestMember>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUEST DETAILS'),
        actions: [
          if (challenge != null)
            abandoning
                ?  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.danger),
                    ),
                  )
                : IconButton(
                    tooltip: 'Abandon quest',
                    icon:
                         Icon(Icons.flag_outlined, color: AppColors.danger),
                    onPressed: () =>
                        _confirmAbandon(context, challenge, members),
                  ),
        ],
      ),
      body: challengesAsync.when(
        // The 8-second auto-refresh reloads these providers; keep the
        // current content on screen during a reload so it never flashes
        // back to a spinner. Only the very first load shows one.
        skipLoadingOnReload: true,
        loading: () =>  Center(
          child: CircularProgressIndicator(color: AppColors.warningText),
        ),
        error: (error, _) => _CenteredMessage('Could not load quest.\n$error'),
        data: (challenges) {
          final challenge =
              challenges.where((c) => c.id == widget.challengeId).firstOrNull;
          if (challenge == null) {
            return const _CenteredMessage(
                'Quest not found - maybe it ended or you left it.');
          }
          return checkInsAsync.when(
            skipLoadingOnReload: true,
            loading: () =>  Center(
              child: CircularProgressIndicator(color: AppColors.warningText),
            ),
            error: (error, _) =>
                _CenteredMessage('Could not load check-ins.\n$error'),
            data: (checkIns) => RefreshIndicator(
              color: AppColors.neonCyan,
              backgroundColor: AppColors.surface,
              onRefresh: () async {
                _refreshData();
                try {
                  await ref.read(myChallengesProvider.future);
                  await ref.read(checkInsProvider(widget.challengeId).future);
                  await ref.read(questMembersProvider(widget.challengeId).future);
                  await ref.read(questDuelsProvider(widget.challengeId).future);
                } catch (_) {}
              },
              child: _DetailBody(
                challenge: challenge,
                timeline: ChallengeTimeline.build(
                  challenge: challenge,
                  checkIns: checkIns,
                  today: DateTime.now().toUtc(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.challenge, required this.timeline});

  final Challenge challenge;
  final ChallengeTimeline timeline;

  @override
  Widget build(BuildContext context) {
    // Soft entrance: content fades in and slides up slightly.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppDurations.base,
      curve: AppCurves.emphasizedOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: child),
      ),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(child: _HeaderCard(challenge)),
          ),
          // Knocked out but still here: say so once, at the top, instead
          // of leaving the player to wonder why every button is dead.
          if (challenge.amIOut)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _SpectatorCard(challenge)),
            ),
          // Someone bought two hours of silence on you.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(child: _BlackoutCard(challenge)),
          ),
          // A lobby waits here with the roster and the START button.
          if (challenge.isLobby)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _LobbyCard(challenge)),
            ),
          // The day-by-day stats are meaningless before a quest starts.
          if (!challenge.isLobby)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _StatsRow(timeline.stats)),
            ),
          // Progress quests lead with their bar and the log button.
          if (challenge.isProgress)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _ProgressSection(challenge: challenge),
              ),
            ),
          // Negative quests lead with their slip budget.
          if (challenge.isAvoid && !challenge.isLobby)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _AvoidSection(challenge: challenge),
              ),
            ),
          if (!challenge.isLobby)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(child: _StakesSection(challenge)),
            ),
          if (!challenge.isLobby)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: QuestReminderRow(challenge: challenge),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: QuestPartySection(challenge: challenge),
            ),
          ),
          if (!challenge.isLobby) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: QuestDuelsSection(challenge: challenge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: QuestActivitySection(challenge: challenge),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIMELINE',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: AppColors.accentText),
                    ),
                    const SizedBox(height: 12),
                    const _Legend(),
                  ],
                ),
              ),
            ),
            // Virtualized 7-column day grid (calendar weeks).
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 56, // grows column count on tablets
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _DayCell(
                    day: timeline.days[index],
                    challenge: challenge,
                  ),
                  childCount: timeline.days.length,
                ),
              ),
            ),
          ],
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 32),
            sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Header: title, description, schedule, progress
// ─────────────────────────────────────────────────────────────────
/// The lockout banner: shown only while a Blackout is actually running
/// on the logged-in player, and it counts itself down.
///
/// Renders nothing the rest of the time — including while one is armed
/// but not yet started. Being able to see a Blackout coming would defeat
/// the whole point of buying one, so the server never hands out anyone
/// else's row and this card never announces the future.
class _BlackoutCard extends ConsumerStatefulWidget {
  const _BlackoutCard(this.challenge);

  final Challenge challenge;

  @override
  ConsumerState<_BlackoutCard> createState() => _BlackoutCardState();
}

class _BlackoutCardState extends ConsumerState<_BlackoutCard> {
  Timer? _ticker;
  bool _acked = false;

  @override
  void initState() {
    super.initState();
    // Half a minute is plenty for an "1h 12m left" label and costs
    // nothing; a per-second countdown on a two-hour window would just
    // be noise.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final blackout =
        ref.watch(myBlackoutProvider(widget.challenge.id)).valueOrNull;

    if (blackout == null || !blackout.isRunning) return const SizedBox.shrink();

    // Mark it seen once, so the same lockout doesn't feel like news
    // every time the screen is opened.
    if (!_acked) {
      _acked = true;
      ref
          .read(challengeRepositoryProvider)
          .ackBlackouts(widget.challenge.id);
    }

    final blocked =
        widget.challenge.isProgress ? 'log any reps' : 'check in';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.panelDecoration(accent: AppColors.neonPurple),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌑', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'BLACKOUT',
                        style: textTheme.headlineSmall?.copyWith(
                          color: AppColors.neonPurple,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      '${blackout.remainingLabel} left',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  blackout.attackerName == null
                      ? 'Someone locked you out of this quest — you cannot '
                          '$blocked until it lifts.'
                      : '@${blackout.attackerName} locked you out of this '
                          'quest — you cannot $blocked until it lifts.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown to a player who is out of the running but still in the quest.
///
/// Losing no longer kicks anyone out — the seat, the party list and the
/// whole history stay. This card is the one place that says so, so the
/// dead buttons further down read as a rule rather than a bug.
class _SpectatorCard extends StatelessWidget {
  const _SpectatorCard(this.challenge);

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.panelDecoration(accent: AppColors.danger),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('☠️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "YOU'RE OUT",
                  style: textTheme.headlineSmall?.copyWith(
                    color: AppColors.danger,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  challenge.isLastManStanding
                      ? 'Eliminated — but you keep your seat. Watch the '
                          'survivors fight it out to the end.'
                      : 'Out of strikes — but you keep your seat. Follow '
                          'the rest of the party to the finish.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No more check-ins, shop or duels. Leave whenever you '
                  'like with the flag up top.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard(this.challenge);

  final Challenge challenge;

  static String _date(DateTime d) => formatDate(d);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final today = DateTime.now().toUtc();
    final ended = !challenge.isEndless && !today.isBefore(challenge.endsAt);
    final lastDay = challenge.endsAt.subtract(const Duration(days: 1));
    // "Day X of Y" — clamped so pre-start shows 0 and post-end shows Y.
    final dayNumber = (today.difference(challenge.startsOn).inDays + 1)
        .clamp(0, challenge.durationDays);
    final progress = dayNumber / challenge.durationDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.panelDecoration(
        accent: ended ? AppColors.textSecondary : AppColors.neonYellow,
        glow: !ended,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ended) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppColors.panelDecoration(
                accent: AppColors.danger,
                fill: AppColors.danger.withValues(alpha: 0.15),
                radius: 8.0,
                isDanger: true,
              ),
              child: Text(
                'QUEST ENDED',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            challenge.title,
            style: textTheme.headlineMedium
                ?.copyWith(color: AppColors.warningText),
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              challenge.description,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          // Owned gear is shown down with the shop, where it belongs.
          const SizedBox(height: 16),

          // Schedule row: endless quests show a start + running-days
          // pill; fixed quests show the start → end range.
          Row(
            children: [
               Icon(challenge.isEndless
                      ? Icons.all_inclusive
                      : Icons.calendar_month,
                  size: 16, color: AppColors.neonCyan),
              const SizedBox(width: 6),
              Text(
                challenge.isEndless
                    ? 'Since ${_date(challenge.startsOn)}'
                    : '${_date(challenge.startsOn)}  →  ${_date(lastDay)}',
                style: textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                ended ? 'over' : challenge.timeLeftLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: ended ? AppColors.textSecondary : AppColors.accentText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (challenge.checkinPeriod != CheckinPeriod.daily) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                 Icon(Icons.repeat, size: 16, color: AppColors.neonPink),
                const SizedBox(width: 6),
                Text(
                  '${challenge.checkinsPerPeriod}x per '
                  '${challenge.checkinPeriod == CheckinPeriod.weekly ? 'week' : 'month'}',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.neonPink),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Endless quests have no finish line — they just count up.
          if (challenge.isEndless)
            Row(
              children: [
                Icon(Icons.local_fire_department,
                    size: 16, color: AppColors.warningText),
                const SizedBox(width: 6),
                Text(
                  'Running for ${challenge.runningDays} '
                  'day${challenge.runningDays == 1 ? '' : 's'}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else ...[
            // Progress: Day X of Y with an animated bar.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PROGRESS',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                Text(
                  'Day $dayNumber of ${challenge.durationDays}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AppDurations.slow,
              curve: AppCurves.emphasizedOut,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  color:
                      ended ? AppColors.textSecondary : AppColors.neonYellow,
                  backgroundColor: AppColors.surfaceLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Lobby: the roster gathers, the creator kicks it off
// ─────────────────────────────────────────────────────────────────
class _LobbyCard extends ConsumerWidget {
  const _LobbyCard(this.challenge);

  final Challenge challenge;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(startQuestControllerProvider(challenge.id).notifier)
        .start();
    if (!context.mounted) return;
    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text('🏁 "${challenge.title}" is on — good luck.'),
        backgroundColor: AppColors.neonGreen,
      ));
    } else {
      final error =
          ref.read(startQuestControllerProvider(challenge.id)).error;
      messenger.showSnackBar(SnackBar(
        content: Text(error is PostgrestException
            ? error.message
            : 'Could not start the quest — try again.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final myId = ref.watch(currentUserProvider)?.id;
    final iAmCreator = myId == challenge.creatorId;
    final starting =
        ref.watch(startQuestControllerProvider(challenge.id)).isLoading;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.panelDecoration(accent: AppColors.neonYellow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, size: 18, color: AppColors.warningText),
              const SizedBox(width: 8),
              Text('WAITING TO START',
                  style: textTheme.headlineSmall
                      ?.copyWith(color: AppColors.warningText)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            iAmCreator
                ? (challenge.isLastManStanding
                    ? 'Invite players below. When everyone is in, hit START — '
                        'the roster locks and the elimination begins. Needs '
                        'at least 2 players.'
                    : 'Invite players below, then start the quest when ready.')
                : 'The creator starts this quest once everyone has joined. '
                    'Hang tight.',
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          if (iAmCreator) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: starting ? null : () => _start(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size(0, 48),
                ),
                icon: starting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.background),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('START QUEST'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Progress: the bar, the log button and the full history
// ─────────────────────────────────────────────────────────────────
class _ProgressSection extends ConsumerWidget {
  const _ProgressSection({required this.challenge});

  final Challenge challenge;

  static String _periodLabel(Challenge challenge, DateTime periodStart) {
    final date = formatDate(periodStart);
    return switch (challenge.checkinPeriod) {
      CheckinPeriod.daily => date,
      CheckinPeriod.weekly => 'Week of $date',
      CheckinPeriod.monthly => 'Month from $date',
    };
  }

  static String _time(DateTime at) => formatTime(at);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final entriesAsync = ref.watch(progressEntriesProvider(challenge.id));
    final target = challenge.targetValue ?? 0;
    final done = challenge.progressInPeriod >= target && target > 0;
    final ended = challenge.isFinished ||
        (!challenge.isEndless && !DateTime.now().toUtc().isBefore(challenge.endsAt));
    // A running lockout — null whenever nothing is blocking right now.
    final running = ref.watch(myBlackoutProvider(challenge.id)).valueOrNull;
    final blackout = (running != null && running.isRunning) ? running : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: AppColors.panelDecoration(
            accent: done ? AppColors.neonGreen : AppColors.neonPurple,
            glow: done,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'THIS ${challenge.checkinPeriod.name.toUpperCase()}',
                    style: textTheme.headlineSmall?.copyWith(
                      color: done
                          ? AppColors.successText
                          : AppColors.neonPurple,
                    ),
                  ),
                  const Spacer(),
                  if (!done)
                    Text(
                      '${formatQuantity(challenge.progressRemaining)} to go',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
              // Reached-and-beyond banner.
              if (done) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.successText),
                    const SizedBox(width: 6),
                    Text(
                      challenge.overshoot > 0
                          ? 'Target reached · +${formatQuantity(challenge.overshoot)} '
                              '${challenge.unit ?? ''} beyond'
                          : 'Target reached — keep going for bonus',
                      style: textTheme.bodySmall?.copyWith(
                          color: AppColors.successText,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              QuestProgressBar(challenge: challenge),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                // You can always log more — bonus reps past the goal are
                // documented (they feed the totals below). Unless you are
                // out (read-only for good) or blacked out (read-only for
                // the next couple of hours).
                child: (ended || challenge.amIOut || blackout != null)
                    ? OutlinedButton.icon(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          disabledForegroundColor: blackout != null
                              ? AppColors.neonPurple
                              : (challenge.amIOut
                                  ? AppColors.danger
                                  : (done
                                      ? AppColors.successText
                                      : AppColors.textSecondary)),
                          side: BorderSide(
                              color: blackout != null
                                  ? AppColors.neonPurple
                                  : (challenge.amIOut
                                      ? AppColors.danger
                                      : (done
                                          ? AppColors.neonGreen
                                          : AppColors.textSecondary))),
                        ),
                        icon: Icon(
                            blackout != null
                                ? Icons.block
                                : (challenge.amIOut
                                    ? Icons.visibility_outlined
                                    : (done ? Icons.check_circle : Icons.lock)),
                            size: 18),
                        label: Text(blackout != null
                            ? 'BLACKED OUT · ${blackout.remainingLabel} LEFT'
                            : (challenge.amIOut
                                ? 'WATCHING ONLY'
                                : (done ? 'TARGET REACHED' : 'QUEST OVER'))),
                      )
                    : ElevatedButton.icon(
                        onPressed: () =>
                            showAddProgressSheet(context, ref, challenge),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: done
                              ? AppColors.neonGreen
                              : AppColors.neonPurple,
                          foregroundColor: AppColors.background,
                          minimumSize: const Size(0, 46),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(done ? 'LOG MORE REPS' : 'ADD PROGRESS'),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Cumulative totals ────────────────────────────
        _CumulativeTotals(
          challenge: challenge,
          entries: entriesAsync.valueOrNull ?? const [],
        ),
        const SizedBox(height: 24),

        // ── History ──────────────────────────────────────
        Text(
          'HISTORY',
          style: textTheme.headlineSmall
              ?.copyWith(color: AppColors.neonPurple),
        ),
        const SizedBox(height: 12),
        entriesAsync.when(
          skipLoadingOnReload: true,
          loading: () => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.neonPurple),
            ),
          ),
          error: (error, _) => Text(
            'Could not load the history.\n$error',
            style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Text(
                'Nothing logged yet — your first entry starts the story.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              );
            }
            final periods = ProgressPeriod.group(entries, target);
            return Column(
              children: [
                for (final period in periods)
                  _PeriodHistoryTile(
                    challenge: challenge,
                    label: _periodLabel(challenge, period.periodStart),
                    period: period,
                    unit: challenge.unit ?? '',
                    time: _time,
                    // Only the running period can be corrected; the rest
                    // are settled and locked by the server.
                    editable:
                        period.periodStart == challenge.currentPeriodStart,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One period of the history: the totals, the verdict and every entry
/// that got it there.
class _PeriodHistoryTile extends ConsumerWidget {
  const _PeriodHistoryTile({
    required this.challenge,
    required this.label,
    required this.period,
    required this.unit,
    required this.time,
    required this.editable,
  });

  final Challenge challenge;
  final String label;
  final ProgressPeriod period;
  final String unit;
  final String Function(DateTime) time;

  /// Whether these entries can be corrected (current period only).
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    // Two shades of the same idea: the bright one draws the panel edge,
    // the readable one carries the text sitting on it.
    final accent = period.reached ? AppColors.neonGreen : AppColors.danger;
    final color = period.reached ? AppColors.successText : AppColors.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(accent: accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(period.reached ? Icons.check_circle : Icons.cancel,
                  size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${formatProgress(period.total, period.target, unit)}'
                ' · ${period.percent}%',
                style: textTheme.bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (editable)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Tap an entry to correct a mistyped value',
                style: textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          // Every single entry, newest first, with its time.
          for (final entry in period.entries)
            InkWell(
              onTap: editable
                  ? () =>
                      showCorrectEntrySheet(context, ref, challenge, entry)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  children: [
                    Text(
                      '+${formatQuantity(entry.amount)}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.neonPurple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      unit,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      time(entry.createdAt),
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    if (editable) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.edit_outlined,
                          size: 14, color: AppColors.textSecondary),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A negative quest's headline: how much rope is left this period, the
/// slip button, and what a clean run is worth.
class _AvoidSection extends ConsumerWidget {
  const _AvoidSection({required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final color = slipColor(challenge);
    final broken = challenge.slipLimitBroken;
    final busy = ref.watch(slipControllerProvider(challenge.id)).isLoading;
    final periodWord = switch (challenge.checkinPeriod) {
      CheckinPeriod.daily => 'today',
      CheckinPeriod.weekly => 'this week',
      CheckinPeriod.monthly => 'this month',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration:
          AppColors.panelDecoration(accent: color, glow: !broken && !challenge.slipNearLimit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THIS ${challenge.checkinPeriod.name.toUpperCase()}',
                style: textTheme.headlineSmall?.copyWith(color: color),
              ),
              const Spacer(),
              if (!broken && challenge.dailyAllowance > 0)
                Text(
                  '${challenge.slipsLeft} left',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SlipMeter(challenge: challenge),
          const SizedBox(height: 14),
          Text(
            broken
                ? 'The limit broke $periodWord — the strike is already on the '
                    'board. Your streak still stands; the next period starts clean.'
                : challenge.dailyAllowance == 0
                    ? 'Do nothing and $periodWord pays out in full. There is no '
                        'button to press — that is the whole point.'
                    : 'Stay at or under ${challenge.dailyAllowance} and '
                        '$periodWord still counts. The fewer you use, the more '
                        'aura you keep.',
            style: textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                // Out of the running: the budget stays on screen so the
                // player can follow it, but nothing can be booked. Not
                // via `busy` — that would spin forever.
                child: challenge.amIOut
                    ? OutlinedButton.icon(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          disabledForegroundColor: AppColors.danger,
                          side: BorderSide(color: AppColors.danger),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('WATCHING ONLY'),
                      )
                    : SlipButton(
                        challenge: challenge,
                        busy: busy,
                        onPressed: () =>
                            logSlipAndReveal(context, ref, challenge),
                      ),
              ),
              // A mis-tap can be taken back — a consequence cannot.
              if (!broken &&
                  !challenge.amIOut &&
                  challenge.slipsInPeriod > 0) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final undone = await ref
                              .read(slipControllerProvider(challenge.id).notifier)
                              .undo();
                          if (undone == null) return;
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                                'Taken back — ${undone.count} on the board.'),
                            backgroundColor: AppColors.neonGreen,
                          ));
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: BorderSide(color: AppColors.outline),
                    minimumSize: const Size(0, 46),
                  ),
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('UNDO'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Lifetime / month / week reps across every period — bonus reps
/// included. This is where overshoot lands: it never moves the goal,
/// but every rep you ever did is counted here.
class _CumulativeTotals extends StatelessWidget {
  const _CumulativeTotals({required this.challenge, required this.entries});

  final Challenge challenge;
  final List<ProgressEntry> entries;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unit = challenge.unit ?? '';
    final totals = ProgressTotals.from(entries, DateTime.now());

    Widget tile(String label, double value, {bool lead = false}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatQuantity(value),
                style: textTheme.headlineSmall?.copyWith(
                  color: lead ? AppColors.successText : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 2),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.panelDecoration(accent: AppColors.neonGreen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, size: 16, color: AppColors.successText),
              const SizedBox(width: 6),
              Text(
                'TOTAL REPS',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.successText,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile('ALL-TIME', totals.lifetime, lead: true),
              tile('THIS MONTH', totals.thisMonth),
              tile('THIS WEEK', totals.thisWeek),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Stakes & rules — the economy at a glance
// ─────────────────────────────────────────────────────────────────
class _StakesSection extends StatelessWidget {
  const _StakesSection(this.challenge);

  final Challenge challenge;

  // The stored values stay 'solo' and 'versus'; only what players read
  // changed. "Solo" was wrong the moment someone else joined, and
  // "Versus" never said that this one is fought in teams.
  String get _modeLabel => switch (challenge.mode) {
        QuestMode.coop => 'Co-op · one for all',
        QuestMode.versus =>
          'Team battle · team ${challenge.myTeam == 'blue' ? 'blue' : 'red'}',
        QuestMode.lastManStanding => 'Last Man Standing',
        QuestMode.solo => 'Free for all',
      };

  IconData get _modeIcon => switch (challenge.mode) {
        QuestMode.coop => Icons.handshake,
        QuestMode.versus => Icons.sports_kabaddi,
        QuestMode.lastManStanding => Icons.military_tech,
        QuestMode.solo => Icons.person,
      };

  Color get _modeColor => switch (challenge.mode) {
        QuestMode.coop => AppColors.neonPurple,
        QuestMode.versus =>
          challenge.myTeam == 'blue' ? AppColors.neonCyan : AppColors.danger,
        QuestMode.lastManStanding => AppColors.neonYellow,
        QuestMode.solo => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // A quest narrowed to certain weekdays says so instead of "Every
    // day" — that is the single most load-bearing fact about when it
    // is due, and the stakes row is where players look for it.
    final frequency = challenge.checkinPeriod == CheckinPeriod.daily
        ? challenge.weekdayLabel
        : '${challenge.checkinsPerPeriod}x per '
            '${challenge.checkinPeriod == CheckinPeriod.weekly ? 'week' : 'month'}'
            '${challenge.hasRestDays ? ' · ${challenge.weekdayLabel}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAKES',
          style: textTheme.headlineSmall
              ?.copyWith(color: AppColors.warningText),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.bolt,
              label: '+${challenge.auraGain} / check-in',
              color: AppColors.neonGreen,
            ),
            _InfoChip(
              icon: Icons.heart_broken,
              label: '-${challenge.auraPenalty} / miss',
              color: AppColors.danger,
            ),
            _InfoChip(
              icon: Icons.shield_outlined,
              label: challenge.maxStrikes == 0
                  ? 'Hardcore · 0 strikes'
                  : '${challenge.strikesUsed}/${challenge.maxStrikes} strikes',
              color: challenge.strikesUsed >= challenge.maxStrikes
                  ? AppColors.danger
                  : AppColors.textSecondary,
            ),
            if (challenge.isProgress)
              _InfoChip(
                icon: Icons.trending_up,
                label: '${formatQuantity(challenge.targetValue ?? 0)} '
                    '${challenge.unit ?? ''} per '
                    '${challenge.checkinPeriod.name.replaceAll('daily', 'day').replaceAll('weekly', 'week').replaceAll('monthly', 'month')}',
                color: AppColors.neonPurple,
              ),
            _InfoChip(
              icon: Icons.repeat,
              label: frequency,
              color: AppColors.neonPink,
            ),
            _InfoChip(icon: _modeIcon, label: _modeLabel, color: _modeColor),
          ],
        ),
        // The shop belongs to the economy, so it sits with the stakes:
        // balance on the left, a medium-emphasis way in on the right.
        const SizedBox(height: 16),
        _GearShopRow(challenge),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Gear & shop — your spendable aura, what you own, and the way in.
// Sits inside STAKES: same topic, one block instead of two.
// ─────────────────────────────────────────────────────────────────
class _GearShopRow extends StatelessWidget {
  const _GearShopRow(this.challenge);

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, size: 20, color: AppColors.neonPurple),
            const SizedBox(width: 2),
            Text(
              '${challenge.myAura}',
              style: textTheme.titleLarge
                  ?.copyWith(color: AppColors.neonPurple),
            ),
            const SizedBox(width: 6),
            Text(
              'to spend',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const Spacer(),
            OutlinedButton.icon(
              // The balance stays readable; spending it does not.
              onPressed: challenge.amIOut
                  ? null
                  : () => ChallengeShopSheet.show(context, challenge),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.neonPurple,
                disabledForegroundColor: AppColors.textSecondary,
                side: BorderSide(
                    color: challenge.amIOut
                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                        : AppColors.neonPurple.withValues(alpha: 0.6)),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 16),
              label: const Text('SHOP'),
            ),
          ],
        ),
        // What this quest's aura already bought.
        if (challenge.ownedBenefits.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final title in challenge.ownedBenefits)
                BenefitChip(title: title),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Stats: success rate, streaks, missed days
// ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow(this.stats);

  final ChallengeStats stats;

  @override
  Widget build(BuildContext context) {
    final rate = stats.successRate;
    return Row(
      children: [
        _StatTile(
          label: 'SUCCESS',
          value: rate == null ? '-' : '${(rate * 100).round()}%',
          detail: '${stats.doneCount}/${stats.accountableCount} ${stats.unit}',
          accent: AppColors.neonGreen,
          color: AppColors.successText,
          icon: Icons.percent,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'STREAK',
          value: '${stats.currentStreak}',
          detail: 'current',
          accent: AppColors.neonCyan,
          color: AppColors.accentText,
          icon: Icons.local_fire_department,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'BEST',
          value: '${stats.longestStreak}',
          detail: 'longest',
          accent: AppColors.neonYellow,
          color: AppColors.warningText,
          icon: Icons.emoji_events,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'MISSED',
          value: '${stats.missedCount}',
          detail: stats.unit,
          accent: AppColors.danger,
          color: AppColors.danger,
          icon: Icons.heart_broken,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;

  /// Bright — draws the tile's edge.
  final Color accent;

  /// Readable — the icon and the number sitting inside it.
  final Color color;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: AppColors.panelDecoration(accent: accent),
        child: Column(
          children: [
            ThemeIcon(icon: icon, matrixChar: '[S]', color: color, size: 16),
            const SizedBox(height: 6),
            Text(
              value,
              style: textTheme.titleLarge?.copyWith(
                color: color,
                // Four tiles side by side — tabular digits keep them
                // from shifting as the numbers grow.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Timeline grid
// ─────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children:  [
        _LegendItem(color: AppColors.neonGreen, label: 'done'),
        _LegendItem(color: AppColors.danger, label: 'missed'),
        _LegendItem(color: AppColors.neonCyan, label: 'today'),
        _LegendItem(color: AppColors.surfaceLight, label: 'upcoming'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.challenge});

  final TimelineDay day;
  final Challenge challenge;

  (Color, Color, IconData?) get _style => switch (day.status) {
        DayStatus.done => (
            AppColors.neonGreen.withValues(alpha: 0.18),
            AppColors.neonGreen,
            Icons.check,
          ),
        DayStatus.missed => (
            AppColors.danger.withValues(alpha: 0.15),
            AppColors.danger,
            Icons.close,
          ),
        DayStatus.today => (
            AppColors.neonCyan.withValues(alpha: 0.15),
            AppColors.neonCyan,
            Icons.hourglass_bottom,
          ),
        DayStatus.future => (
            AppColors.surfaceLight,
            AppColors.textSecondary,
            null,
          ),
        DayStatus.notJoined => (
            AppColors.surface,
            AppColors.textSecondary,
            null,
          ),
        DayStatus.rest => (
            AppColors.surface,
            AppColors.textSecondary,
            null,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, accent, icon) = _style;

    return GestureDetector(
      onTap: () => _DayDetailsSheet.show(context, day, challenge),
      child: Container(
        decoration: AppColors.panelDecoration(
          accent: day.isToday ? AppColors.neonCyan : accent,
          fill: bg,
          radius: 10.0,
          glow: day.isToday,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.date.day}',
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (icon != null) Icon(icon, size: 12, color: accent),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Day details bottom sheet
// ─────────────────────────────────────────────────────────────────
class _DayDetailsSheet extends ConsumerStatefulWidget {
  const _DayDetailsSheet({required this.day, required this.challenge});

  final TimelineDay day;
  final Challenge challenge;

  static Future<void> show(
    BuildContext context,
    TimelineDay day,
    Challenge challenge,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DayDetailsSheet(day: day, challenge: challenge),
    );
  }

  @override
  ConsumerState<_DayDetailsSheet> createState() => _DayDetailsSheetState();
}

class _DayDetailsSheetState extends ConsumerState<_DayDetailsSheet> {
  TimelineDay get day => widget.day;

  /// Check in straight from the timeline: pop the sheet on success —
  /// the invalidated providers flip the cell to green and update the
  /// stats and the card outside.
  Future<void> _checkIn() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final result = await ref
        .read(checkInControllerProvider(widget.challenge.id).notifier)
        .checkIn(questTitle: widget.challenge.title);
    if (!mounted) return;

    if (result.isQueuedOffline) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: const Text(
            '⚡ Offline erledigt! Wird synchronisiert, sobald wieder Netz da ist.'),
        backgroundColor: AppColors.neonYellow,
      ));
      return;
    }

    if (!result.isSuccess) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.errorMessage ?? 'Check-in failed - try again.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    final gained = result.auraGained ?? 0;

    // A heist may have swiped this payout — reveal it over the sheet,
    // then close and skip the "+aura" toast (gained is 0 when robbed).
    final robbed = await revealRobbedIfAny(context, ref, widget.challenge.id);
    navigator.pop();
    if (robbed != null) return;
    messenger.showSnackBar(SnackBar(
      content: Text('⚡ +$gained Aura! Quest checked in.'),
      backgroundColor: AppColors.neonGreen,
    ));
  }

  (String, Color, IconData) get _statusInfo => switch (day.status) {
        DayStatus.done => ('Done', AppColors.neonGreen, Icons.check_circle),
        DayStatus.missed => ('Missed', AppColors.danger, Icons.cancel),
        DayStatus.today => (
            'Today - check-in pending',
            AppColors.neonCyan,
            Icons.hourglass_bottom,
          ),
        DayStatus.future => (
            'Upcoming',
            AppColors.textSecondary,
            Icons.radio_button_unchecked,
          ),
        DayStatus.notJoined => (
            'Before you joined',
            AppColors.textSecondary,
            Icons.remove_circle_outline,
          ),
        DayStatus.rest => (
            'Free day - target is per period',
            AppColors.textSecondary,
            Icons.self_improvement,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (label, color, icon) = _statusInfo;
    final isLoading =
        ref.watch(checkInControllerProvider(widget.challenge.id)).isLoading;
    final running =
        ref.watch(myBlackoutProvider(widget.challenge.id)).valueOrNull;
    final blackout = (running != null && running.isRunning) ? running : null;

    final dateLabel = formatWeekdayDate(day.date);

    final checkedAtLocal = day.checkedAt?.toLocal();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: color),
          const SizedBox(height: 14),
          Text(dateLabel, style: textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            label,
            style: textTheme.bodyLarge
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          if (checkedAtLocal != null) ...[
            const SizedBox(height: 8),
            Text(
              'Checked in at ${formatTime(checkedAtLocal)}',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          // Progress quests are satisfied by logging amounts, never by
          // a manual tick — point at the bar instead.
          if (day.status == DayStatus.today && widget.challenge.isProgress) ...[
            const SizedBox(height: 16),
            Text(
              'Log your progress above — the day ticks itself off once '
              'you reach the target.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ]
          // Out of the running: the day sheet still opens and still shows
          // what happened, it just no longer offers a way to score.
          else if (widget.challenge.amIOut) ...[
            const SizedBox(height: 20),
            Text(
              "You're out of this quest — following along only.",
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ]
          // Someone bought two hours of silence on you.
          else if (blackout != null) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌑', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'Blacked out — ${blackout.remainingLabel} left',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ]
          // Today, still pending → check in right from the timeline.
          else if (day.status == DayStatus.today) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _checkIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonGreen,
                  foregroundColor: AppColors.background,
                ),
                icon: isLoading
                    ?  SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.background),
                      )
                    : const Icon(Icons.bolt),
                label: Text('CHECK IN NOW  (+${widget.challenge.auraGain})'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
