import 'package:flutter/material.dart';
import '../../../../core/widgets/app_states.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../challenges/presentation/widgets/create_challenge_sheet.dart';
import '../../../../core/text/roasts.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/challenge.dart';
import '../../../challenges/domain/settlement.dart';
import '../../../challenges/presentation/widgets/dice_duel.dart';
import '../../../challenges/presentation/widgets/progress_widgets.dart';
import '../../../challenges/presentation/widgets/quick_progress_actions.dart';
import '../../../challenges/presentation/widgets/slip_widgets.dart';
import '../../../friends/application/friends_providers.dart';
import '../../../friends/domain/social_models.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/home_providers.dart';
import '../../domain/home_agenda.dart';
import '../widgets/celebration_gate.dart';
import '../widgets/blackout_notice_gate.dart';
import '../widgets/push_permission_card.dart';
import '../widgets/weekly_recap_card.dart';
import '../widgets/robbed_notice_gate.dart';
import '../widgets/targeted_roast_gate.dart';
import '../../../../core/widgets/theme_components.dart';

/// Home tab — the daily cockpit. It answers three questions at a
/// glance: what's due today, what is about to be lost, and who wants
/// something from me.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agendaAsync = ref.watch(homeAgendaProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final comebacks =
        (ref.watch(myChallengesProvider).valueOrNull ?? <Challenge>[])
            .where((c) => c.comebackNeeded && !c.isFinished)
            .toList();
    final syncNotice = ref.watch(offlineSyncNoticeProvider);
    final pendingIds = ref
        .watch(pendingCheckInsProvider)
        .where((p) => DateUtils.isSameDay(p.date, DateTime.now().toUtc()))
        .map((p) => p.challengeId)
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('HOME'), actions: [
        IconButton(
            tooltip: 'Create a quest',
            icon: const Icon(Icons.add),
            onPressed: () => CreateChallengeSheet.show(context)),
      ]),
      body: RefreshIndicator(
        color: AppColors.neonCyan,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          final owner = ref.read(currentUserProvider)?.id;
          // Trigger offline sync if any pending check-ins exist
          final result = await ref
              .read(offlineSyncServiceProvider)
              .syncPendingCheckIns(ref.read(challengeRepositoryProvider));
          if (!context.mounted || ref.read(currentUserProvider)?.id != owner) {
            return;
          }
          if (result.discardedCount > 0) {
            ref.read(offlineSyncNoticeProvider.notifier).state =
                '${result.discardedCount} saved check-in(s) could not be applied. Open the quest to review its status.';
          }
          await ref.read(pendingCheckInsProvider.notifier).load();
          ref.invalidate(myInvitesProvider);
          ref.invalidate(friendRequestsProvider);
          ref.invalidate(robbedNoticesProvider);
          ref.invalidate(unseenBlackoutsProvider);
          ref.invalidate(myNudgesProvider);
          ref.invalidate(myCheckInsProvider);
          ref.invalidate(settlementEventsProvider);
          ref.invalidate(incomingDuelsProvider);
          ref.invalidate(targetedRoastsProvider);
          ref.invalidate(unseenNudgesProvider);
          ref.invalidate(pokeBacksProvider);
          return ref.refresh(myChallengesProvider.future);
        },
        child: agendaAsync.when(
          // Pull-to-refresh reloads the agenda; keep it on screen so it
          // updates in place instead of blanking to a spinner.
          skipLoadingOnReload: true,
          skipError: true,
          loading: () => const AppLoadingState(label: 'Loading your day…'),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppStatePanel(
                  title: 'Your day is taking a moment',
                  message: 'Check your connection, then try again.',
                  icon: Icons.cloud_off_outlined,
                  actionLabel: 'TRY AGAIN',
                  onAction: () => ref.invalidate(myChallengesProvider)),
            ],
          ),
          data: (loadedAgenda) {
            final agenda = loadedAgenda.withPendingCheckIns(pendingIds);
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                const TargetedRoastRefresher(),
                _TodayHeader(
                    agenda: agenda,
                    username: profile?.username,
                    pendingCount: agenda.done
                        .where((i) => pendingIds.contains(i.challenge.id))
                        .length),
                const SizedBox(height: 16),
                if (syncNotice != null)
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(syncNotice),
                    trailing: IconButton(
                      tooltip: 'Dismiss',
                      icon: const Icon(Icons.close),
                      onPressed: () => ref
                          .read(offlineSyncNoticeProvider.notifier)
                          .state = null,
                    ),
                  ),
                // ── Open today ────────────────────────────────
                if (comebacks.isNotEmpty) ...[
                  _SectionTitle('COMEBACK', color: AppColors.neonGreen),
                  for (final quest in comebacks)
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.replay),
                      title: Text(quest.title),
                      subtitle: Text(_comebackMessage(quest)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('${AppRoutes.challenges}/${quest.id}'),
                    )),
                  const SizedBox(height: 12),
                ],
                _SectionTitle(
                  'TODAY',
                  color: AppColors.accentText,
                ),
                const SizedBox(height: 12),
                if (agenda.open.every((i) => i.isDoomed))
                  _AllDoneCard(
                      hasQuests: agenda.totalRunning > 0,
                      hasLostQuests: agenda.doomed.isNotEmpty,
                      waitingForSync: agenda.done
                          .any((i) => pendingIds.contains(i.challenge.id)))
                else
                  for (final item in agenda.open)
                    if (!item.isDoomed)
                      if (item.isCritical)
                        _RiskCard(key: ValueKey(item.challenge.id), item: item)
                      else
                        _AgendaCard(
                            key: ValueKey(item.challenge.id), item: item),

                // ── Done ──────────────────────────────────────
                if (agenda.done.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('DONE FOR TODAY', color: AppColors.successText),
                  const SizedBox(height: 12),
                  for (final item in agenda.done) _DoneRow(item: item),
                ],

                if (agenda.doomed.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _SectionTitle('FINISHED', color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  for (final item in agenda.doomed) _DoomedCard(item: item),
                ],

                const SizedBox(height: 20),
                _ActivitySection(key: ValueKey(profile?.id)),
                const SizedBox(height: 12),
                const WeeklyRecapCard(compact: true),
                const PushPermissionCard(),

                // ── Upcoming ──────────────────────────────────
                if (agenda.upcoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionTitle('UPCOMING', color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  for (final challenge in agenda.upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              challenge.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            challenge.timeLeftLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _comebackMessage(Challenge quest) {
  if (quest.amIOut) {
    return 'This run has ended. Start a new quest — your XP stays.';
  }
  final next = quest.nextComebackDate(DateTime.now().toUtc());
  if (next == null) {
    return 'Start a new quest for your comeback. Your XP stays.';
  }
  final today = DateTime.now().toUtc();
  final when = DateUtils.isSameDay(next, today)
      ? 'today'
      : '${next.day}.${next.month}.${next.year}';
  return quest.isAvoid
      ? 'Comeback goal: finish the next planned period within your allowance · $when'
      : 'Comeback goal: complete the next planned unit · $when';
}

/// Events stay discoverable without pushing today's tasks below the fold.
class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myInvitesProvider);
    final requests = ref.watch(friendRequestsProvider);
    final duels = ref.watch(incomingDuelsProvider);
    final nudges = ref.watch(unseenNudgesProvider);
    final roasts = ref.watch(targetedRoastsProvider);
    final robbed = ref.watch(robbedNoticesProvider);
    final blackouts = ref.watch(unseenBlackoutsProvider);
    final backs = ref.watch(pokeBacksProvider);
    final events = ref.watch(settlementEventsProvider);
    final count = (invites.valueOrNull?.length ?? 0) +
        (requests.valueOrNull?.length ?? 0) +
        (duels.valueOrNull?.length ?? 0) +
        PokeGroup.group(nudges.valueOrNull ?? []).length +
        (roasts.valueOrNull?.length ?? 0) +
        (robbed.valueOrNull?.length ?? 0) +
        (blackouts.valueOrNull?.length ?? 0) +
        (backs.valueOrNull?.length ?? 0);
    final states = [
      invites,
      requests,
      duels,
      nudges,
      roasts,
      robbed,
      blackouts,
      backs,
      events
    ];
    final summary = states.any((s) => s.hasError)
        ? 'Some updates could not load · pull to retry'
        : states.any((s) => s.isLoading && !s.hasValue)
            ? 'Checking for updates…'
            : count > 0
                ? '$count to review · invites, friends and quest events'
                : 'All caught up · ${events.valueOrNull?.length ?? 0} recent events';
    final hasUnread = count > 0;
    final activityAccent = hasUnread ? AppColors.danger : AppColors.neonPurple;
    return Container(
      decoration: AppColors.panelDecoration(
        accent: activityAccent,
        fill: hasUnread ? AppColors.danger.withValues(alpha: 0.06) : null,
        isDanger: hasUnread,
        glow: hasUnread,
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              hasUnread ? Icons.notifications_active : Icons.notifications_none,
              color: hasUnread ? AppColors.danger : AppColors.accentText,
            ),
            if (hasUnread)
              Positioned(
                right: -18,
                top: -13,
                child: _ActivityBadge(count: count),
              ),
          ],
        ),
        title: const Text('ACTIVITY'),
        subtitle: Text(summary),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          const _InboxSection(),
          const RobbedAlertSection(),
          const BlackoutAlertSection(),
          const _RoastAlertSection(),
          const _PokeBackBanner(),
          const _EventsSection(),
          if (count == 0 && (events.valueOrNull?.isEmpty ?? true))
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nothing waiting. Your next move is on Today.')),
        ],
      ),
    );
  }
}

/// A compact, high-contrast count that stays visible while the inbox is
/// collapsed. The label is announced as one useful piece of information by
/// screen readers instead of exposing the decorative number separately.
class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 99 ? '99+' : '$count';
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$count new activities',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('activity-unread-badge'),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outline, width: 1.5),
          ),
          child: Text(
            displayCount,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: readableOn(AppColors.danger),
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

/// "You got roasted" alert — always visible on Home while a roast is
/// pending, no matter which section the quest sits in. Tapping it faces
/// the roast (countdown lock), which is also unavoidable when checking
/// in or opening that quest.
class _RoastAlertSection extends ConsumerWidget {
  const _RoastAlertSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roasts = ref.watch(targetedRoastsProvider).valueOrNull ?? [];
    if (roasts.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final challenges = ref.watch(myChallengesProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final roast in roasts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => showTargetedRoastLockDialog(context, ref, roast),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: AppColors.panelDecoration(
                  accent: AppColors.neonPurple,
                  glow: true,
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ROAST INCOMING!',
                            style: textTheme.headlineSmall
                                ?.copyWith(color: AppColors.neonPurple),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${roast.senderUsername} roasted you in '
                            '"${challenges.where((c) => c.id == roast.challengeId).firstOrNull?.title ?? 'a quest'}"'
                            ' — tap to face it (${roast.durationSeconds}s lock).',
                            style: textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.neonPurple),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
    );
  }
}

/// Progress ring + greeting.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader(
      {required this.agenda,
      required this.username,
      required this.pendingCount});

  final HomeAgenda agenda;
  final String? username;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final confirmed =
        (agenda.done.length - pendingCount).clamp(0, agenda.totalRunning);
    final completion =
        agenda.totalRunning == 0 ? null : confirmed / agenda.totalRunning;
    final allDone = completion == 1.0;
    final accent = allDone ? AppColors.neonGreen : AppColors.neonCyan;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.panelDecoration(
          accent: accent, glow: true, fill: accent.withValues(alpha: .1)),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Semantics(
              label:
                  '$confirmed of ${agenda.totalRunning} quests confirmed today',
              child: Stack(alignment: Alignment.center, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: completion ?? 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppDurations.base,
                  curve: AppCurves.emphasizedOut,
                  builder: (context, value, _) => SizedBox.expand(
                      child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 4,
                    color:
                        allDone ? AppColors.successText : AppColors.accentText,
                    backgroundColor: AppColors.surfaceLight,
                  )),
                ),
                ExcludeSemantics(
                    child: Text('$confirmed/${agenda.totalRunning}',
                        style: textTheme.labelSmall
                            ?.copyWith(fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The day's anchor — a real hero greeting, not an eyebrow.
                Text(
                  username == null ? 'Hey' : 'Hey @$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color:
                        allDone ? AppColors.successText : AppColors.textPrimary,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pendingCount > 0
                      ? '$pendingCount saved on this device · waiting to sync'
                      : switch (agenda) {
                          _ when agenda.totalRunning == 0 =>
                            'No running quests. Time to forge one.',
                          _ when agenda.open.isEmpty =>
                            'Everything done today. Legend.',
                          _ when agenda.open.every((i) => i.isDoomed) =>
                            'No actions left today. Review your finished quests.',
                          _ => '${agenda.open.length} quest'
                              '${agenda.open.length == 1 ? '' : 's'} waiting for you.',
                        },
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending invites + fresh pokes. Without push notifications this is
/// the only place these ever surface, so they live on Home.
class _InboxSection extends ConsumerWidget {
  const _InboxSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(myInvitesProvider).valueOrNull ?? const [];
    final unseen = ref.watch(unseenNudgesProvider).valueOrNull ?? const [];
    final duels = ref.watch(incomingDuelsProvider).valueOrNull ?? const [];
    // Friend requests belong here for the same reason quest invites do:
    // somebody is waiting on an answer. Living only in the Friends tab
    // meant they went unnoticed until that tab happened to be opened.
    final requests = ref.watch(friendRequestsProvider).valueOrNull ?? const [];
    // Unseen pokes, one card per quest — they drop off the moment you
    // dismiss, react, or check in on that quest.
    final pokeGroups = PokeGroup.group(unseen);

    if (invites.isEmpty &&
        pokeGroups.isEmpty &&
        duels.isEmpty &&
        requests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('INBOX', color: AppColors.neonYellow),
        const SizedBox(height: 12),
        // Open duels come first — there is aura on the table.
        for (final duel in duels)
          _InboxRow(
            icon: Icons.casino,
            color: AppColors.neonPink,
            text: '🎲 @${duel.challengerName} challenges you — '
                '${duel.pot} ⚡ pot',
            detail: '${duel.questTitle} · stake ${duel.stake}',
            onTap: () => DuelSheet.show(context, duel),
          ),
        if (invites.isNotEmpty)
          _InboxRow(
            icon: Icons.mail,
            color: AppColors.neonYellow,
            text: '${invites.length} quest invite'
                '${invites.length == 1 ? '' : 's'} waiting',
            detail: invites.first.questTitle,
            onTap: () => context.go(AppRoutes.friends),
          ),
        // Named while there is one name to name — "@bra wants to be quest
        // mates" is answerable at a glance; "2 friend requests" needs a
        // trip to the Friends tab before you even know who is asking.
        if (requests.isNotEmpty)
          _InboxRow(
            icon: Icons.person_add_alt_1,
            color: AppColors.neonCyan,
            text: requests.length == 1
                ? '@${requests.first.fromName} wants to be quest mates'
                : '${requests.length} friend requests waiting',
            detail: requests.length == 1
                ? 'Tap to accept or decline'
                : 'From @${requests.map((r) => r.fromName).join(', @')}',
            onTap: () => context.go(AppRoutes.friends),
          ),
        for (final group in pokeGroups) _PokeInboxCard(group: group),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// One quest's unseen pokes: who poked you, plus a one-tap emoji to fire
/// back at all of them and a plain dismiss. Both clear the card; neither
/// creates a new notification for anyone (no ping-pong).
class _PokeInboxCard extends ConsumerStatefulWidget {
  const _PokeInboxCard({required this.group});

  final PokeGroup group;

  @override
  ConsumerState<_PokeInboxCard> createState() => _PokeInboxCardState();
}

class _PokeInboxCardState extends ConsumerState<_PokeInboxCard> {
  static const _reactions = ['💪', '🔥', '👍', '😤', '🙏'];
  bool _busy = false;

  Future<void> _dismiss() async {
    await _run((repo) => repo.dismissQuestPokes(widget.group.challengeId));
  }

  Future<void> _react(String emoji) async {
    await _run(
        (repo) => repo.reactToQuestPokes(widget.group.challengeId, emoji));
  }

  Future<void> _run(Future<void> Function(dynamic repo) action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(friendsRepositoryProvider));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
            content:
                const Text('Could not save your response. Please try again.'),
            backgroundColor: AppColors.danger));
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(unseenNudgesProvider);
    ref.invalidate(myNudgesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final group = widget.group;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(accent: AppColors.neonPink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active,
                  size: 18, color: AppColors.neonPink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${group.who} poked you',
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _dismiss,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Got it'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'in ${group.questTitle} — time to move.',
            style:
                textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          // One tap fires this emoji back to every poker (and clears).
          Row(
            children: [
              for (final emoji in _reactions) ...[
                _ReactionButton(
                  emoji: emoji,
                  enabled: !_busy,
                  onTap: () => _react(emoji),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.enabled,
    required this.onTap,
  });

  final String emoji;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.neonPink.withValues(alpha: 0.25)),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Passive feed: reactions to pokes you sent. Informational, dismissible,
/// never actionable — tapping just marks them seen.
class _PokeBackBanner extends ConsumerWidget {
  const _PokeBackBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backs = ref.watch(pokeBacksProvider).valueOrNull ?? const [];
    if (backs.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    Future<void> ack() async {
      await ref.read(friendsRepositoryProvider).ackPokeBacks();
      ref.invalidate(pokeBacksProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: ack,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppColors.panelDecoration(accent: AppColors.neonCyan),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(backs.first.reaction, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  backs.length == 1
                      ? '@${backs.first.reactorName} reacted to your poke '
                          'in ${backs.first.questTitle}'
                      : '@${backs.first.reactorName} and ${backs.length - 1} '
                          'other${backs.length - 1 == 1 ? '' : 's'} reacted '
                          'to your pokes',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppColors.panelDecoration(accent: color),
          child: Row(
            children: [
              ThemeIcon(icon: icon, matrixChar: '[I]', color: color, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text,
                        style: textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the settlement engine did while the player was away —
/// penalties, strikes, shield saves, completions. The same rows the
/// future FCM pushes will be built from.
class _EventsSection extends ConsumerWidget {
  const _EventsSection();

  void _openEvent(BuildContext context, SettlementEvent event) {
    if (event.kind == 'completed' || event.kind == 'milestone') {
      CelebrationGate.show(context, event);
      return;
    }
    final (icon, color, text) = _describe(event);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
          child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (event.kind == 'failed') ...[
            const SizedBox(height: 12),
            Text(Roasts.random(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),
          if (event.canOpenQuest)
            TextButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  context.push('${AppRoutes.challenges}/${event.challengeId}');
                },
                child: const Text('OPEN QUEST'))
          else
            const Text('This quest is no longer available to you.',
                textAlign: TextAlign.center),
        ]),
      )),
    );
  }

  (IconData, Color, String) _describe(SettlementEvent event) {
    return switch (event.kind) {
      'penalty' => (
          Icons.heart_broken,
          AppColors.danger,
          '${event.amount} aura · ${event.questTitle}',
        ),
      'strike' => (
          Icons.close,
          AppColors.danger,
          'Strike ${event.amount} · ${event.questTitle}',
        ),
      'shield_saved' => (
          Icons.security,
          AppColors.neonPurple,
          'Streak Shield saved you · ${event.questTitle}',
        ),
      'failed' => (
          Icons.flag,
          AppColors.danger,
          'Quest failed · ${event.questTitle} '
              '(${event.amount} aura salvaged)',
        ),
      'bonus' => (
          Icons.stars,
          AppColors.neonYellow,
          '+${event.amount} completion bonus · ${event.questTitle}',
        ),
      'completed' => (
          Icons.emoji_events,
          AppColors.neonGreen,
          'Quest completed · ${event.questTitle} '
              '(${event.amount} aura banked)',
        ),
      'duel_won' => (
          Icons.casino,
          AppColors.neonGreen,
          '🎲 Duel won: +${event.amount} · ${event.questTitle}',
        ),
      'duel_lost' => (
          Icons.casino,
          AppColors.danger,
          '🎲 Duel lost: ${event.amount} · ${event.questTitle}',
        ),
      'versus_won' => (
          Icons.sports_kabaddi,
          AppColors.neonGreen,
          '🏆 Your team won: +${event.amount} tribute · '
              '${event.questTitle}',
        ),
      'versus_lost' => (
          Icons.sports_kabaddi,
          AppColors.danger,
          '🏳 Your team lost: ${event.amount} tribute · '
              '${event.questTitle}',
        ),
      'milestone' => (
          Icons.local_fire_department,
          AppColors.neonYellow,
          '🔥 ${event.amount}-day streak · ${event.questTitle}',
        ),
      'strike_repaired' => (
          Icons.build,
          AppColors.neonGreen,
          '🔧 Strike repaired · ${event.questTitle}',
        ),
      'eliminated' => (
          Icons.dangerous,
          AppColors.danger,
          '💀 Eliminated · ${event.questTitle}',
        ),
      'lms_finished' => (
          Icons.flag,
          AppColors.textSecondary,
          '🏁 Last Man Standing over · ${event.questTitle}',
        ),
      'heist_robbed' => (
          Icons.money_off,
          AppColors.danger,
          '💸 Robbed: ${event.amount} aura · ${event.questTitle}',
        ),
      'heist_blocked' => (
          Icons.shield,
          AppColors.neonGreen,
          'Aura Ward blocked a heist · ${event.questTitle}'
        ),
      'heist_expired' => (
          Icons.timer_off,
          AppColors.textSecondary,
          'Heist ended without a payout · ${event.questTitle}'
        ),
      'heist_hit' => (
          Icons.savings,
          AppColors.neonGreen,
          '💰 Heist paid off: +${event.amount} · ${event.questTitle}',
        ),
      'avoided' => (
          Icons.shield_moon,
          AppColors.neonGreen,
          '🚫 Stayed clean: +${event.amount} · ${event.questTitle}',
        ),
      'slip_over' => (
          Icons.block,
          AppColors.danger,
          '🚫 Slipped past the limit · ${event.questTitle}',
        ),
      _ => (Icons.info_outline, AppColors.textSecondary, event.questTitle),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(settlementEventsProvider).valueOrNull ?? const [];
    if (events.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('LATEST', color: AppColors.neonPurple),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: AppColors.panelDecoration(accent: AppColors.neonPurple),
          child: Column(
            children: [
              for (final event in events.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Builder(builder: (context) {
                    final (icon, color, text) = _describe(event);
                    return InkWell(
                      onTap: () => _openEvent(context, event),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              ThemeIcon(
                                  icon: icon,
                                  matrixChar: '[A]',
                                  color: color,
                                  size: 15),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall
                                      ?.copyWith(color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right,
                                  size: 18, color: AppColors.textSecondary),
                            ],
                          )),
                    );
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Shared check-in button used by the agenda + risk cards.
class _CheckInButton extends ConsumerStatefulWidget {
  const _CheckInButton({required this.item, required this.color});

  final AgendaItem item;
  final Color color;

  @override
  ConsumerState<_CheckInButton> createState() => _CheckInButtonState();
}

class _CheckInButtonState extends ConsumerState<_CheckInButton> {
  bool _submitting = false;
  AgendaItem get item => widget.item;
  Color get color => widget.color;

  Future<void> _checkIn(BuildContext context, WidgetRef ref) async {
    if (_submitting ||
        ref.read(checkInControllerProvider(item.challenge.id)).isLoading) {
      return;
    }
    final owner = ref.read(currentUserProvider)?.id;
    setState(() => _submitting = true);
    try {
      await _performCheckIn(context, ref);
    } catch (error, stack) {
      debugPrint('Home check-in action failed: $error');
      debugPrintStack(stackTrace: stack);
      if (context.mounted && ref.read(currentUserProvider)?.id == owner) {
        showActionFeedback(ScaffoldMessenger.of(context),
            error: true,
            message: 'Could not complete this check-in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _performCheckIn(BuildContext context, WidgetRef ref) async {
    final owner = ref.read(currentUserProvider)?.id;
    if (owner == null) return;
    final roasts = ref.read(targetedRoastsProvider).valueOrNull ?? [];
    final pendingRoast =
        roasts.where((r) => r.challengeId == item.challenge.id).firstOrNull;

    if (pendingRoast != null) {
      await showTargetedRoastLockDialog(context, ref, pendingRoast);
      if (!context.mounted) return;
    }
    if (ref.read(currentUserProvider)?.id != owner) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(checkInControllerProvider(item.challenge.id).notifier)
        .checkIn(questTitle: item.challenge.title);
    if (!context.mounted || ref.read(currentUserProvider)?.id != owner) return;

    if (result.isQueuedOffline) {
      showActionFeedback(messenger,
          pending: true, message: 'Saved on this device · waiting to sync');
      return;
    }

    if (!result.isSuccess) {
      showActionFeedback(messenger,
          error: true,
          message: result.errorMessage ?? 'Check-in failed. Try again.');
      return;
    }

    final gained = result.auraGained ?? 0;

    // Checking in clears this quest's pokes (server-side trigger) —
    // refresh the inbox so they drop off Home immediately.
    ref.invalidate(unseenNudgesProvider);

    // No extra round trip or blocking reveal before confirming the user's action.
    // Heist details remain available in Activity; zero payout displays no reward.
    showActionFeedback(messenger,
        message: '${item.challenge.title} · check-in confirmed',
        confirmedAura: gained);
  }

  @override
  Widget build(BuildContext context) {
    // A running lockout reaches the agenda too. Without this the button
    // here still invites a tap the server is going to refuse.
    final running =
        ref.watch(myBlackoutProvider(item.challenge.id)).valueOrNull;
    if (running != null && running.isRunning) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: AppColors.neonPurple,
          side: BorderSide(color: AppColors.neonPurple.withValues(alpha: 0.6)),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.block, size: 15),
        label: Text(running.remainingLabel),
      );
    }

    // Progress quests are never ticked off — they collect amounts.
    if (item.challenge.isProgress) {
      final progressBusy =
          ref.watch(progressControllerProvider(item.challenge.id)).isLoading;
      return ElevatedButton.icon(
        onPressed: progressBusy
            ? null
            : () async {
                final roasts =
                    ref.read(targetedRoastsProvider).valueOrNull ?? [];
                final pendingRoast = roasts
                    .where((r) => r.challengeId == item.challenge.id)
                    .firstOrNull;
                if (pendingRoast != null) {
                  await showTargetedRoastLockDialog(context, ref, pendingRoast);
                }
                if (context.mounted) {
                  showAddProgressSheet(context, ref, item.challenge);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neonPurple,
          foregroundColor: AppColors.background,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('ADD'),
      );
    }

    // Negative quests are won by inaction — nothing to tick off, only a
    // slip to own up to.
    if (item.challenge.isAvoid) {
      return SlipButton(
        challenge: item.challenge,
        compact: true,
        busy: ref.watch(slipControllerProvider(item.challenge.id)).isLoading,
        onPressed: () => logSlipAndReveal(context, ref, item.challenge),
      );
    }

    final isLoading = _submitting ||
        ref.watch(checkInControllerProvider(item.challenge.id)).isLoading;

    return ElevatedButton(
      onPressed: isLoading ? null : () => _checkIn(context, ref),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.background,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.background),
            )
          : const Text('CHECK-IN'),
    );
  }
}

/// A quest that still needs a check-in in the current period.
class _AgendaCard extends ConsumerWidget {
  const _AgendaCard({super.key, required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final roasts = ref.watch(targetedRoastsProvider).valueOrNull ?? [];
    final pendingRoast =
        roasts.where((r) => r.challengeId == item.challenge.id).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(
        accent:
            pendingRoast != null ? AppColors.neonPurple : AppColors.neonCyan,
        glow: pendingRoast != null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingRoast != null)
            GestureDetector(
              onTap: () =>
                  showTargetedRoastLockDialog(context, ref, pendingRoast),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neonPurple, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGETED ROAST RECEIVED!',
                            style: TextStyle(
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'From @${pendingRoast.senderUsername} — tap to unlock screen (${pendingRoast.durationSeconds}s lock)',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_clock,
                        color: AppColors.neonPurple, size: 20),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    if (pendingRoast != null) {
                      await showTargetedRoastLockDialog(
                          context, ref, pendingRoast);
                    }
                    if (context.mounted) {
                      context
                          .push('${AppRoutes.challenges}/${item.challenge.id}');
                    }
                  },
                  child: Text(
                    item.challenge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _CheckInButton(item: item, color: AppColors.neonGreen),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(item.demandLabel,
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.accentText)),
              Text('+${item.challenge.auraGain} ⚡',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.successText)),
            ],
          ),
          if (item.challenge.isProgress) ...[
            const SizedBox(height: 8),
            QuestProgressBar(challenge: item.challenge, compact: true),
            QuickProgressActions(challenge: item.challenge),
          ],
        ],
      ),
    );
  }
}

/// A quest that dies on the next miss — loud on purpose.
class _RiskCard extends ConsumerWidget {
  const _RiskCard({super.key, required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final strikes = item.challenge.maxStrikes;
    final roasts = ref.watch(targetedRoastsProvider).valueOrNull ?? [];
    final pendingRoast =
        roasts.where((r) => r.challengeId == item.challenge.id).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(
          accent:
              pendingRoast != null ? AppColors.neonPurple : AppColors.danger,
          isDanger: pendingRoast == null,
          glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingRoast != null)
            GestureDetector(
              onTap: () =>
                  showTargetedRoastLockDialog(context, ref, pendingRoast),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.neonPurple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neonPurple, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TARGETED ROAST RECEIVED!',
                            style: TextStyle(
                              color: AppColors.neonPurple,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'From @${pendingRoast.senderUsername} — tap to unlock screen (${pendingRoast.durationSeconds}s lock)',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_clock,
                        color: AppColors.neonPurple, size: 20),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              ThemeIcon(
                icon: Icons.warning_amber_rounded,
                matrixChar: '[!]',
                size: 18,
                color: AppColors.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    if (pendingRoast != null) {
                      await showTargetedRoastLockDialog(
                          context, ref, pendingRoast);
                    }
                    if (context.mounted) {
                      context
                          .push('${AppRoutes.challenges}/${item.challenge.id}');
                    }
                  },
                  child: Text(
                    item.challenge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              _CheckInButton(item: item, color: AppColors.danger),
            ],
          ),
          if (item.challenge.isProgress) ...[
            const SizedBox(height: 8),
            QuestProgressBar(challenge: item.challenge, compact: true),
            QuickProgressActions(challenge: item.challenge),
          ],
          const SizedBox(height: 10),
          Text(
            item.deadlineToday
                ? 'Miss today and the quest is lost '
                    '($strikes strike${strikes == 1 ? '' : 's'} used up).'
                : 'Fail this period and the quest is lost — '
                    '${item.demandLabel}.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

/// A quest whose strike budget is spent: it's over, the server just
/// hasn't been asked yet. No check-in button — it would only error.
class _DoomedCard extends StatelessWidget {
  const _DoomedCard({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final allowed = item.challenge.maxStrikes;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(accent: AppColors.textSecondary),
      child: InkWell(
        onTap: () =>
            context.push('${AppRoutes.challenges}/${item.challenge.id}'),
        child: Row(
          children: [
            ThemeIcon(
              icon: Icons.heart_broken,
              matrixChar: '[☠]',
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.challenge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lost — ${item.strikesUsed} missed, '
                    'only $allowed allowed. Time to let it go.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            ThemeIcon(
              icon: Icons.chevron_right,
              matrixChar: '>',
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// One line per quest already satisfied this period.
class _DoneRow extends ConsumerWidget {
  const _DoneRow({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPending = ref.watch(pendingCheckInsProvider).any((p) =>
        p.challengeId == item.challenge.id &&
        DateUtils.isSameDay(p.date, DateTime.now().toUtc()));

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          ThemeIcon(
            icon: isPending ? Icons.hourglass_top : Icons.check_circle,
            matrixChar: isPending ? '[~]' : '[X]',
            size: 14,
            color: isPending ? AppColors.neonYellow : AppColors.neonGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.challenge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          if (isPending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.neonYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppColors.neonYellow.withValues(alpha: 0.5),
                    width: 1),
              ),
              child: Text(
                'Waiting to sync',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warningText,
                ),
              ),
            )
          else if (item.challenge.checkinPeriod != CheckinPeriod.daily)
            Text(
              '${item.doneInPeriod}/${item.target}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.successText),
            ),
        ],
      ),
    );
  }
}

/// Nothing open: either everything is checked in, or there are no
/// quests at all.
class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard(
      {required this.hasQuests,
      this.waitingForSync = false,
      this.hasLostQuests = false});

  final bool hasQuests;
  final bool waitingForSync;
  final bool hasLostQuests;

  @override
  Widget build(BuildContext context) {
    if (!hasQuests && !waitingForSync && !hasLostQuests) {
      return AppStatePanel(
          title: 'Small habit. Big energy.',
          message:
              'Pick something you want to do more often. Make it your first quest.',
          actionLabel: 'CREATE A QUEST',
          onAction: () => CreateChallengeSheet.show(context));
    }
    final textTheme = Theme.of(context).textTheme;
    final color = waitingForSync || hasLostQuests || !hasQuests
        ? AppColors.warningText
        : AppColors.successText;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.panelDecoration(accent: color),
      child: Row(
        children: [
          ThemeIcon(
            icon: waitingForSync
                ? Icons.cloud_upload_outlined
                : hasLostQuests
                    ? Icons.info_outline
                    : hasQuests
                        ? Icons.emoji_events
                        : Icons.add_circle_outline,
            matrixChar: hasQuests ? '[★]' : '[+]',
            size: 28,
            color: color,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              waitingForSync
                  ? 'Saved on this device. We will sync when you are back online.'
                  : hasLostQuests
                      ? 'No check-ins available. Review your finished quests below.'
                      : hasQuests
                          ? 'All check-ins done. Come back tomorrow.'
                          : 'No running quests — head to Quests and '
                              'forge your first one.',
              style: textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
