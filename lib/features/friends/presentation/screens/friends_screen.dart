import 'package:aura_quest/core/widgets/app_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../../core/widgets/spot_illustration.dart';
import '../widgets/head_to_head_sheet.dart';
import '../widgets/user_safety_sheet.dart';
import '../../application/friends_providers.dart';
import '../../domain/social_models.dart';

/// Friends tab: your friends list, incoming friend requests, pending
/// quest invites and recent pokes from quest-mates.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  /// Ask for a username and send a friend request.
  Future<void> _addFriend(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppColors.activeType == AppThemeType.auralis ? 24 : 20),
          side: BorderSide(
            color: AppColors.activeType == AppThemeType.auralis
                ? AppColors.outline
                : AppColors.neonCyan.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        title: Text(
          'ADD FRIEND',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.accentText),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Username'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('SEND'),
          ),
        ],
      ),
    );
    if (username == null || username.isEmpty || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final status = await ref
        .read(friendshipControllerProvider.notifier)
        .sendRequest(username);
    if (status == null) return; // error → ref.listen

    messenger.showSnackBar(AppSnackBar(
      content: Text(status == 'accepted'
          // They had already asked us — asking back seals it instantly.
          ? '🤝 You and @$username are now friends!'
          : '📨 Friend request sent to @$username.'),
      backgroundColor:
          status == 'accepted' ? AppColors.neonGreen : AppColors.surfaceLight,
    ));
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppColors.activeType == AppThemeType.auralis ? 24 : 20),
          side: BorderSide(
            color: AppColors.activeType == AppThemeType.auralis
                ? AppColors.outline
                : AppColors.danger.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        title: Text(
          'REMOVE FRIEND?',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.danger),
        ),
        content: Text(
          '@${friend.username} will be removed from your friends. '
          'Shared quests are not affected.',
          style: Theme.of(dialogContext)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:
                Text('CANCEL', style: TextStyle(color: AppColors.accentText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Theme.of(context).colorScheme.onError,
              minimumSize: const Size(0, 48),
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(friendshipControllerProvider.notifier)
        .remove(friend.userId);
    if (!ok) return;

    messenger.showSnackBar(AppSnackBar(
      content: Text('@${friend.username} removed.'),
      backgroundColor: AppColors.surfaceLight,
    ));
  }

  Future<void> _respondRequest(
    BuildContext context,
    WidgetRef ref,
    FriendRequest request,
    bool accept,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(friendshipControllerProvider.notifier)
        .respond(friendshipId: request.id, accept: accept);
    if (!ok) return;

    messenger.showSnackBar(AppSnackBar(
      content: Text(accept
          ? '🤝 You and @${request.fromName} are now friends!'
          : 'Request from @${request.fromName} declined.'),
      backgroundColor: accept ? AppColors.neonGreen : AppColors.surfaceLight,
    ));
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    QuestInvite invite,
    bool accept,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(respondInviteControllerProvider.notifier)
        .respond(inviteId: invite.id, accept: accept);
    if (!success) return; // error → ref.listen below

    messenger.showSnackBar(AppSnackBar(
      content: Text(accept
          ? '⚡ You joined "${invite.questTitle}"!'
          : 'Invite to "${invite.questTitle}" declined.'),
      backgroundColor: accept ? AppColors.neonGreen : AppColors.surfaceLight,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final friendsAsync = ref.watch(myFriendsProvider);
    final requestsAsync = ref.watch(friendRequestsProvider);
    final invitesAsync = ref.watch(myInvitesProvider);
    final nudgesAsync = ref.watch(myNudgesProvider);
    final responding = ref.watch(respondInviteControllerProvider).isLoading;
    final friendBusy = ref.watch(friendshipControllerProvider).isLoading;

    // Both controllers surface server rejections the same way.
    for (final provider in [
      respondInviteControllerProvider,
      friendshipControllerProvider,
    ]) {
      ref.listen(provider, (_, next) {
        final error = next.error;
        if (error == null) return;
        final message = error is PostgrestException
            ? error.message
            : 'Something went wrong - try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar(
              content: Text(message), backgroundColor: AppColors.danger),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FRIENDS'),
        actions: [
          IconButton(
            tooltip: 'Add friend',
            icon: Icon(Icons.person_add, color: AppColors.accentText),
            onPressed: friendBusy ? null : () => _addFriend(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.neonPink,
        backgroundColor: AppColors.surface,
        onRefresh: () {
          ref.invalidate(myNudgesProvider);
          ref.invalidate(unseenNudgesProvider);
          ref.invalidate(pokeBacksProvider);
          ref.invalidate(myFriendsProvider);
          ref.invalidate(friendRequestsProvider);
          return ref.refresh(myInvitesProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // ── Friend requests (only when there are any) ─────
            requestsAsync.maybeWhen(
              data: (requests) => requests.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FRIEND REQUESTS',
                          style: textTheme.headlineSmall
                              ?.copyWith(color: AppColors.successText),
                        ),
                        const SizedBox(height: 12),
                        for (final request in requests)
                          _RequestTile(
                            request: request,
                            busy: friendBusy,
                            onAccept: () =>
                                _respondRequest(context, ref, request, true),
                            onDecline: () =>
                                _respondRequest(context, ref, request, false),
                          ),
                        const SizedBox(height: 28),
                      ],
                    ),
              orElse: () => const SizedBox.shrink(),
            ),

            // ── Friends ───────────────────────────────────────
            Text(
              'MY FRIENDS',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.accentText),
            ),
            const SizedBox(height: 12),
            friendsAsync.when(
              data: (friends) => friends.isEmpty
                  ? AppStatePanel(
                      title: 'Good habits. Better company.',
                      message:
                          'Add a friend by username, then invite them to a quest.',
                      icon: Icons.group_add_outlined,
                      actionLabel: 'ADD A FRIEND',
                      onAction:
                          friendBusy ? null : () => _addFriend(context, ref))
                  : Column(
                      children: [
                        for (final friend in friends)
                          _FriendTile(
                            friend: friend,
                            busy: friendBusy,
                            onRemove: () =>
                                _confirmRemove(context, ref, friend),
                          ),
                      ],
                    ),
              loading: () => Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accentText),
                ),
              ),
              error: (error, _) => AppStatePanel(
                  title: 'Friends could not load',
                  message: 'Check your connection and try again.',
                  icon: Icons.cloud_off,
                  actionLabel: 'RETRY',
                  onAction: () => ref.invalidate(myFriendsProvider)),
            ),
            const SizedBox(height: 28),

            // ── Quest invites ─────────────────────────────────
            Text(
              'QUEST INVITES',
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.warningText),
            ),
            const SizedBox(height: 12),
            invitesAsync.when(
              data: (invites) => invites.isEmpty
                  ? const _EmptyHint(
                      icon: Icons.mail_outline,
                      motif: SpotMotif.quests,
                      title: 'No open invites',
                      text: 'Ask a friend to invite you — or invite '
                          'them from any quest.')
                  : Column(
                      children: [
                        for (final invite in invites)
                          _InviteTile(
                            invite: invite,
                            busy: responding,
                            onAccept: () =>
                                _respond(context, ref, invite, true),
                            onDecline: () =>
                                _respond(context, ref, invite, false),
                          ),
                      ],
                    ),
              loading: () => Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppColors.warningText),
                ),
              ),
              error: (error, _) => Text(
                'Could not load invites. Please try again.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
            const SizedBox(height: 28),

            // ── Pokes ─────────────────────────────────────────
            Text(
              'POKES',
              style:
                  textTheme.headlineSmall?.copyWith(color: AppColors.neonPink),
            ),
            const SizedBox(height: 12),
            nudgesAsync.when(
              data: (nudges) => nudges.isEmpty
                  ? const _EmptyHint(
                      icon: Icons.notifications_none,
                      motif: SpotMotif.inbox,
                      title: 'All quiet',
                      text: 'No pokes yet — your quest-mates are '
                          'being suspiciously calm.')
                  : Column(
                      children: [
                        for (final nudge in nudges) _NudgeTile(nudge),
                      ],
                    ),
              loading: () => Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.neonPink),
                ),
              ),
              error: (error, _) => Text(
                'Could not load pokes. Please try again.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({
    required this.friend,
    required this.busy,
    required this.onRemove,
  });

  final Friend friend;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonCyan),
      child: Row(
        children: [
          AuraAvatar(
            emoji: friend.avatarEmoji,
            username: friend.username,
            size: 38,
            color: AppColors.neonCyan,
          ),
          const SizedBox(width: 12),
          // Tapping the name opens the running score against them.
          Expanded(
            child: InkWell(
              onTap: () => showHeadToHeadSheet(
                context,
                ref,
                userId: friend.userId,
                username: friend.username,
                avatarEmoji: friend.avatarEmoji,
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${friend.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.leaderboard_outlined,
                        size: 14, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove friend',
            onPressed: busy ? null : onRemove,
            icon: Icon(Icons.person_remove_outlined,
                size: 20, color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'Report or block @${friend.username}',
            onPressed: busy
                ? null
                : () => showUserSafetySheet(
                      context,
                      ref,
                      userId: friend.userId,
                      username: friend.username,
                    ),
            icon:
                Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonGreen),
      child: Row(
        children: [
          AuraAvatar(
            emoji: request.fromAvatarEmoji,
            username: request.fromName,
            size: 38,
            color: AppColors.neonGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${request.fromName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'wants to be friends',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: busy ? null : onDecline,
            icon: Icon(Icons.close, color: AppColors.danger),
          ),
          ElevatedButton(
            onPressed: busy ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: AppColors.background,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('ACCEPT'),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final QuestInvite invite;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppColors.panelDecoration(accent: AppColors.neonYellow),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: AppColors.warningText, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.questTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'invited by @${invite.inviterName}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            onPressed: busy ? null : onDecline,
            icon: Icon(Icons.close, color: AppColors.danger),
          ),
          ElevatedButton(
            onPressed: busy ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonGreen,
              foregroundColor: AppColors.background,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }
}

class _NudgeTile extends StatelessWidget {
  const _NudgeTile(this.nudge);

  final Nudge nudge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.panelDecoration(accent: AppColors.neonPink),
      child: Row(
        children: [
          const Text('👉', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '@${nudge.fromName}',
                    style: TextStyle(
                      color: AppColors.neonPink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' poked you in '),
                  TextSpan(
                    text: nudge.questTitle,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: textTheme.bodyMedium,
            ),
          ),
          if (nudge.reaction != null) ...[
            const SizedBox(width: 8),
            Text('you ${nudge.reaction}',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(width: 8),
          Text(
            nudge.timeAgo(DateTime.now()),
            style:
                textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.text,
    this.motif,
    this.title,
  });

  final IconData icon;
  final String text;

  /// When set, renders a rich centered empty state with a theme-tinted
  /// vector spot illustration instead of the compact icon row.
  final SpotMotif? motif;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (motif == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.panelDecoration(accent: AppColors.textSecondary),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.panelDecoration(accent: AppColors.outline),
      child: Column(
        children: [
          SpotIllustration(motif: motif!, size: 44),
          const SizedBox(height: 8),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style:
                  textTheme.titleMedium?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
