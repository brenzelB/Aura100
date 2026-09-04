import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/dates.dart';
import '../../../../core/text/quantity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../friends/application/friends_providers.dart';
import '../../../friends/presentation/widgets/user_safety_sheet.dart';
import '../../application/challenge_providers.dart';
import '../../domain/benefit.dart';
import '../../domain/challenge.dart';
import '../../domain/quest_member.dart';
import 'benefit_chip.dart';
import 'dice_duel.dart';

/// The PARTY block on the quest detail screen: every member with
/// owner crown, current check-in status, quest aura, owned gear and a
/// poke button — plus the invite entry point.
class QuestPartySection extends ConsumerStatefulWidget {
  const QuestPartySection({super.key, required this.challenge});

  final Challenge challenge;

  @override
  ConsumerState<QuestPartySection> createState() =>
      _QuestPartySectionState();
}

class _QuestPartySectionState extends ConsumerState<QuestPartySection> {
  /// Which member is currently being poked (their button spins).
  String? _nudgingUserId;

  Future<void> _nudge(QuestMember member) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _nudgingUserId = member.userId);

    final success = await ref
        .read(nudgeControllerProvider(widget.challenge.id).notifier)
        .nudge(member.userId);

    if (mounted) setState(() => _nudgingUserId = null);
    if (!success) return; // error → surfaced by ref.listen below

    messenger.showSnackBar(SnackBar(
      content: Text('👉 @${member.username} got poked!'),
      backgroundColor: AppColors.neonPink,
    ));
  }

  Future<void> _showInviteDialog(List<QuestMember> members) async {
    // Friends already in the quest can't be invited again — the picker
    // greys them out instead of letting the server reject the tap.
    final memberNames =
        members.map((m) => m.username.toLowerCase()).toSet();

    final username = await showDialog<String>(
      context: context,
      builder: (_) => _InviteDialog(memberNames: memberNames),
    );
    if (username == null || username.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(inviteControllerProvider(widget.challenge.id).notifier)
        .invite(username);
    if (!success) return; // error → ref.listen

    messenger.showSnackBar(SnackBar(
      content: Text('📨 Invite sent to @$username!'),
      backgroundColor: AppColors.neonGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final membersAsync = ref.watch(questMembersProvider(widget.challenge.id));

    // Server rejections from poking or inviting → red SnackBars.
    void listenErrors(ProviderListenable<AsyncValue<void>> provider) {
      ref.listen(provider, (_, next) {
        final error = next.error;
        if (error == null) return;
        final message = error is PostgrestException
            ? error.message
            : 'Something went wrong - try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.danger),
        );
      });
    }

    listenErrors(nudgeControllerProvider(widget.challenge.id));
    listenErrors(inviteControllerProvider(widget.challenge.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PARTY',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.neonPink),
            ),
            const Spacer(),
            OutlinedButton.icon(
              // Out of the running: no bringing in reinforcements either.
              onPressed: widget.challenge.amIOut
                  ? null
                  : () =>
                      _showInviteDialog(membersAsync.valueOrNull ?? const []),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warningText,
                disabledForegroundColor: AppColors.textSecondary,
                side: BorderSide(
                    color: widget.challenge.amIOut
                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                        : AppColors.neonYellow.withValues(alpha: 0.6)),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('INVITE'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        membersAsync.when(
          // Keep the party on screen through the 8s auto-refresh.
          skipLoadingOnReload: true,
          data: (members) {
            Widget tile(QuestMember member, {Color? teamColor}) =>
                _MemberTile(
                  member: member,
                  challenge: widget.challenge,
                  teamColor: teamColor,
                  isNudging: _nudgingUserId == member.userId,
                  onNudge: () => _nudge(member),
                  onDuel: () => startDuelFlow(
                    context,
                    ref,
                    challenge: widget.challenge,
                    opponent: member,
                  ),
                );

            if (widget.challenge.mode == QuestMode.versus) {
              final red =
                  members.where((m) => m.team == 'red').toList();
              final blue =
                  members.where((m) => m.team == 'blue').toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VersusScoreboard(red: red, blue: blue),
                  const SizedBox(height: 14),
                  _TeamLabel('TEAM RED', color: AppColors.danger),
                  const SizedBox(height: 8),
                  for (final member in red)
                    tile(member, teamColor: AppColors.danger),
                  const SizedBox(height: 6),
                  _TeamLabel('TEAM BLUE', color: AppColors.neonCyan),
                  const SizedBox(height: 8),
                  for (final member in blue)
                    tile(member, teamColor: AppColors.neonCyan),
                ],
              );
            }

            return Column(
              children: [
                if (widget.challenge.mode == QuestMode.coop)
                  const _CoopBanner(),
                for (final member in members) tile(member),
              ],
            );
          },
          loading: () =>  Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.neonPink),
            ),
          ),
          error: (error, _) => Text(
            'Could not load the party.\n$error',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
          ),
        ),
      ],
    );
  }
}

/// The co-op covenant, spelled out where the party can see it.
class _CoopBanner extends StatelessWidget {
  const _CoopBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonPurple),
      child: Row(
        children: [
          Icon(Icons.handshake, size: 18, color: AppColors.neonPurple),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ONE FOR ALL — if anyone misses, the whole party pays. '
              'A Streak Shield saves everyone. If one falls, all fall.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// RED vs BLUE tally: total check-ins and the per-member average that
/// actually decides the match (mirrors the server's scoring).
class _VersusScoreboard extends StatelessWidget {
  const _VersusScoreboard({required this.red, required this.blue});

  final List<QuestMember> red;
  final List<QuestMember> blue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final redTotal =
        red.fold<int>(0, (sum, m) => sum + m.totalCheckins);
    final blueTotal =
        blue.fold<int>(0, (sum, m) => sum + m.totalCheckins);
    final redAvg = red.isEmpty ? 0.0 : redTotal / red.length;
    final blueAvg = blue.isEmpty ? 0.0 : blueTotal / blue.length;

    Widget side(String name, Color color, int total, double avg,
        int memberCount, bool leading, CrossAxisAlignment align) {
      return Column(
        crossAxisAlignment: align,
        children: [
          Text(
            name,
            style: textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$total',
            style: textTheme.headlineSmall?.copyWith(
              color: leading ? color : AppColors.textSecondary,
            ),
          ),
          Text(
            memberCount == 0
                ? 'no players'
                : '${avg.toStringAsFixed(1)} / member',
            style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary, fontSize: 10),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonYellow),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          side('RED', AppColors.danger, redTotal, redAvg, red.length,
              redAvg >= blueAvg, CrossAxisAlignment.start),
          Text(
            'VS',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.warningText,
              fontWeight: FontWeight.w800,
            ),
          ),
          side('BLUE', AppColors.neonCyan, blueTotal, blueAvg,
              blue.length, blueAvg >= redAvg, CrossAxisAlignment.end),
        ],
      ),
    );
  }
}

class _TeamLabel extends StatelessWidget {
  const _TeamLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
        ),
      ],
    );
  }
}

/// Slim bar under a party member's name — their share of this
/// period's target.
class _MemberProgressBar extends StatelessWidget {
  const _MemberProgressBar({required this.value, required this.done});

  final double value;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: AppDurations.slow,
      curve: AppCurves.emphasizedOut,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: v,
          minHeight: 5,
          color: done ? AppColors.neonGreen : AppColors.neonPurple,
          backgroundColor: AppColors.surfaceLight,
        ),
      ),
    );
  }
}

/// Invite picker: tap a friend, or type any username for non-friends.
/// Pops the chosen username.
class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog({required this.memberNames});

  /// Lowercased usernames already in the quest.
  final Set<String> memberNames;

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final friendsAsync = ref.watch(myFriendsProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.neonYellow.withValues(alpha: 0.5)),
      ),
      title: Text(
        'INVITE A FRIEND',
        style: textTheme.headlineSmall
            ?.copyWith(color: AppColors.warningText),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            friendsAsync.when(
              data: (friends) => friends.isEmpty
                  ? Text(
                      'No friends yet - add them on the Friends tab, '
                      'or type a username below.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    )
                  : ConstrainedBox(
                      // Keeps long friend lists inside the dialog.
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final friend in friends)
                            _FriendPickTile(
                              username: friend.username,
                              avatarEmoji: friend.avatarEmoji,
                              alreadyIn: widget.memberNames
                                  .contains(friend.username.toLowerCase()),
                              onTap: () =>
                                  Navigator.of(context).pop(friend.username),
                            ),
                        ],
                      ),
                    ),
              loading: () =>  Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.warningText),
                ),
              ),
              error: (_, __) => Text(
                'Could not load friends - type a username below.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
             Divider(color: AppColors.surfaceLight),
            const SizedBox(height: 8),
            Text(
              'OR BY USERNAME',
              style: textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Username'),
              onSubmitted: (value) =>
                  Navigator.of(context).pop(value.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child:  Text('CANCEL',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('INVITE'),
        ),
      ],
    );
  }
}

class _FriendPickTile extends StatelessWidget {
  const _FriendPickTile({
    required this.username,
    required this.avatarEmoji,
    required this.alreadyIn,
    required this.onTap,
  });

  final String username;
  final String? avatarEmoji;
  final bool alreadyIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color =
        alreadyIn ? AppColors.textSecondary : AppColors.textPrimary;

    return InkWell(
      onTap: alreadyIn ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            AuraAvatar(
              emoji: avatarEmoji,
              username: username,
              size: 32,
              color: color,
              borderWidth: 1,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
            if (alreadyIn)
              Text(
                'in quest',
                style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary, fontSize: 10),
              )
            else
               Icon(Icons.add_circle_outline,
                  size: 18, color: AppColors.warningText),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.challenge,
    required this.isNudging,
    required this.onNudge,
    required this.onDuel,
    this.teamColor,
  });

  final QuestMember member;
  final Challenge challenge;
  final bool isNudging;
  final VoidCallback onNudge;
  final VoidCallback onDuel;

  /// Versus quests colour the avatar ring by team (owner crown stays).
  final Color? teamColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor =
        member.doneThisPeriod ? AppColors.neonGreen : AppColors.textSecondary;

    // Eliminated players (Last Man Standing) fade out and lose their
    // action buttons; the winner keeps a golden glow.
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: member.isWinner
              ? AppColors.neonYellow
              : (member.isMe
                  ? AppColors.neonCyan.withValues(alpha: 0.5)
                  : AppColors.surfaceLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar; team colour wins, otherwise gold for the owner.
              AuraAvatar(
                emoji: member.avatarEmoji,
                username: member.username,
                size: 40,
                color: teamColor ??
                    (member.isOwner
                        ? AppColors.neonYellow
                        : AppColors.textSecondary),
              ),
              const SizedBox(width: 12),

              // Only the NAME shares the top row with the buttons. The
              // status line and the bar sit on their own full-width rows
              // below — otherwise 48dp touch targets would squeeze this
              // column so hard that even a 7-letter name gets clipped.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${member.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (member.isOwner) ...[
                      const SizedBox(width: 6),
                      const Text('👑', style: TextStyle(fontSize: 13)),
                    ],
                    // Owned emblems (Title Badge, Aura Lord) — the real
                    // visual badge, right by the name.
                    for (final title
                        in Benefit.ownedTitles(member.gear)) ...[
                      const SizedBox(width: 5),
                      TitleEmblem(title: title, dense: true),
                    ],
                    if (member.isMe) ...[
                      const SizedBox(width: 6),
                      Text(
                        'YOU',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.accentText,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    // Out of the running — still on the roster, still
                    // watching, but no longer a rival.
                    if (member.isOut) ...[
                      const SizedBox(width: 6),
                      const Text('☠️', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 3),
                      Text('OUT',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          )),
                    ],
                    if (member.isWinner) ...[
                      const SizedBox(width: 6),
                      const Text('🏆', style: TextStyle(fontSize: 13)),
                    ],
                  ],
                ),
              ),

              // Actions only. The aura value moved down to the status
              // row: three 48dp targets and a four-digit number left the
              // name barely 70px, which clipped even "@brenzel".
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // No poking or duelling the fallen.
                  // Nothing to duel or poke about once someone is out —
                  // whether that someone is them or me. Report/block
                  // below stays reachable either way.
                  if (!member.isMe &&
                      !member.isOut &&
                      !member.isWinner &&
                      !challenge.amIOut) ...[
                    IconButton(
                      tooltip: 'Duel @${member.username}',
                      onPressed: onDuel,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(Icons.casino_outlined,
                          size: 20, color: AppColors.warningText),
                    ),
                    isNudging
                        // 16 padding keeps the spinner on the same 48dp
                        // footprint as the button it replaces, so the row
                        // doesn't jump while a poke is in flight.
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.neonPink),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Poke @${member.username}',
                            onPressed: onNudge,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 48, minHeight: 48),
                            icon: Icon(Icons.notifications_active_outlined,
                                size: 20, color: AppColors.neonPink),
                          ),
                  ],
                  // Report / block. Quiet on purpose, but always
                  // reachable wherever one player can act on another.
                  if (!member.isMe)
                    IconButton(
                      tooltip: 'Report or block @${member.username}',
                      onPressed: () => showUserSafetySheet(
                        context,
                        ref,
                        userId: member.userId,
                        username: member.username,
                        challengeId: challenge.id,
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: Icon(Icons.more_vert,
                          size: 18, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ),

          // Status on its own row, indented to line up under the name
          // (40 avatar + 12 gap). It gets the full tile width here, so
          // "100 / 100 Reps" and the gear icons always fit.
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Check-in status for the current period.
                      Icon(
                        member.doneThisPeriod
                            ? Icons.check_circle
                            : Icons.hourglass_bottom,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          // Progress quests show the real numbers, so the
                          // party sees exactly where everyone stands.
                          challenge.isProgress
                              ? formatProgress(
                                  member.progressInPeriod,
                                  challenge.targetValue ?? 0,
                                  challenge.unit ?? '',
                                )
                              : (member.doneThisPeriod
                                  ? 'checked in'
                                  : '${member.checkinsThisPeriod} so far'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall
                              ?.copyWith(color: statusColor, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Owned DEFENSIVE gear as mini icons. Emblems show
                      // as their badge by the name; PvP attack items stay
                      // hidden so a pending roast or heist can't be
                      // scouted.
                      for (final title in member.gear)
                        if (!Benefit.titles.contains(title) &&
                            title != 'Targeted Roast' &&
                            title != 'Aura Heist') ...[
                          Icon(benefitIcon(title),
                              size: 13, color: AppColors.neonPurple),
                          const SizedBox(width: 3),
                        ],
                    ],
                  ),
                ),
                // Quest aura (mini leaderboard), pinned to the right edge
                // so the values form a clean column down the party list.
                Icon(Icons.bolt, size: 15, color: AppColors.neonPurple),
                Text(
                  '${member.questAura}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.neonPurple,
                    fontWeight: FontWeight.w700,
                    // Members sit one under the other, so their aura forms
                    // a column. Proportional digits make it jitter on every
                    // refresh; tabular ones line up.
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          // When they last put something on the board. Reads as a habit
          // once you have watched it a few days — "always around eight"
          // — which is exactly the intelligence a Blackout runs on.
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Row(
              children: [
                Icon(Icons.schedule,
                    size: 11, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${challenge.isProgress ? 'Last progress' : 'Last check-in'}: '
                    '${formatLastActivity(member.lastActivityAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),

          // The bar spans the whole tile instead of only the middle
          // column. Every member's bar then starts and ends at the same
          // place, however many action buttons their row carries — a
          // 30/100 next to a 100/100 is finally comparable at a glance.
          if (challenge.isProgress) ...[
            const SizedBox(height: 8),
            _MemberProgressBar(
              value: challenge.targetValue == null ||
                      challenge.targetValue! <= 0
                  ? 0
                  : (member.progressInPeriod / challenge.targetValue!)
                      .clamp(0.0, 1.0),
              done: member.doneThisPeriod,
            ),
          ],
        ],
      ),
    );

    return member.isOut ? Opacity(opacity: 0.5, child: tile) : tile;
  }
}
