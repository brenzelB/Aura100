import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/friends_providers.dart';

/// The reasons the server accepts, with the wording players see.
const _reportReasons = <(String, String, String)>[
  ('harassment', 'Harassment or bullying', 'Targeting me to be cruel'),
  ('offensive_name', 'Offensive username', 'Their name is abusive or explicit'),
  ('cheating', 'Cheating', 'Faking check-ins or exploiting the game'),
  ('spam', 'Spam', 'Flooding me with pokes, duels or invites'),
  ('other', 'Something else', "Doesn't fit the options above"),
];

/// Report / block sheet for one player. Reachable from every place a
/// player is shown next to actions, which is what the stores require of
/// an app where users can act on each other.
Future<void> showUserSafetySheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String username,
  String? challengeId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _UserSafetySheet(
      userId: userId,
      username: username,
      challengeId: challengeId,
    ),
  );
}

class _UserSafetySheet extends ConsumerStatefulWidget {
  const _UserSafetySheet({
    required this.userId,
    required this.username,
    this.challengeId,
  });

  final String userId;
  final String username;
  final String? challengeId;

  @override
  ConsumerState<_UserSafetySheet> createState() => _UserSafetySheetState();
}

class _UserSafetySheetState extends ConsumerState<_UserSafetySheet> {
  bool _busy = false;
  bool _reporting = false;
  String? _error;

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(myFriendsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(done),
        backgroundColor: AppColors.neonGreen,
      ));
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'That did not work — try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.read(friendsRepositoryProvider);
    final blocked =
        (ref.watch(blockedUsersProvider).valueOrNull ?? const <String>{})
            .contains(widget.userId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '@${widget.username}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineMedium
                  ?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 18),

            if (_reporting) ...[
              Text(
                'What happened?',
                style: textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Reports go to the app team for review. They stay private — '
                'They are never told who reported them.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              for (final (value, label, hint) in _reportReasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Pressable(
                    onTap: _busy
                        ? null
                        : () => _run(
                              () => repo.reportUser(
                                userId: widget.userId,
                                reason: value,
                                challengeId: widget.challengeId,
                              ),
                              'Report sent. Thanks for flagging it.',
                            ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(hint,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _reporting = false),
                child: const Text('BACK'),
              ),
            ] else ...[
              // ── Report ────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _busy ? null : () => setState(() => _reporting = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warningText,
                  side: BorderSide(color: AppColors.neonYellow),
                  minimumSize: const Size(0, 50),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('REPORT PLAYER'),
              ),
              const SizedBox(height: 10),

              // ── Block / unblock ───────────────────────────
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => blocked
                        ? _run(() => repo.unblockUser(widget.userId),
                            '@${widget.username} unblocked.')
                        : _run(() => repo.blockUser(widget.userId),
                            '@${widget.username} blocked.'),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      blocked ? AppColors.successText : AppColors.danger,
                  side: BorderSide(
                      color: blocked ? AppColors.neonGreen : AppColors.danger),
                  minimumSize: const Size(0, 50),
                ),
                icon: Icon(blocked ? Icons.lock_open : Icons.block, size: 18),
                label: Text(blocked ? 'UNBLOCK PLAYER' : 'BLOCK PLAYER'),
              ),
              const SizedBox(height: 10),
              Text(
                blocked
                    ? "You've blocked @${widget.username}. Neither of you can "
                        'poke, roast, rob or duel the other.'
                    : 'Blocking stops all pokes, roasts, heists and duels '
                        'between you both ways, and ends the friendship.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary, height: 1.35),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
