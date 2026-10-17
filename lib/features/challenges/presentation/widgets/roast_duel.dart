import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/text/game_roasts.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/duel.dart';
import '../../domain/quest_member.dart';

class DuelSheet extends ConsumerWidget {
  const DuelSheet({super.key, required this.duel});
  final IncomingDuel duel;

  static Future<void> show(BuildContext context, IncomingDuel duel) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => DuelSheet(duel: duel),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(duelStateProvider(duel.id));
    final busy = ref.watch(duelControllerProvider).isLoading;
    final userId = ref.watch(currentUserProvider)?.id;
    ref.listen(duelControllerProvider, (_, next) {
      final error = next.error;
      if (error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
        content: Text(error is PostgrestException
            ? error.message
            : 'Could not save your move. Try again.'),
      ));
    });
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('EGO DUEL',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: 'Close duel',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ]),
                Text('vs @${duel.challengerName} · ${duel.questTitle}'),
                const SizedBox(height: 12),
                const Text('Rock, paper, scissors. First to three wins. '
                    'The loser gets roasted. Your Aura and XP stay yours.'),
                const SizedBox(height: 24),
                state.when(
                  skipLoadingOnRefresh: true,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Column(children: [
                    const Text('Could not load this duel.'),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(duelStateProvider(duel.id)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('TRY AGAIN'),
                    ),
                  ]),
                  data: (game) => userId == null
                      ? const Text('Sign in to see your duel.')
                      : _GameContent(
                          game: game,
                          userId: userId,
                          busy: busy,
                          onAccept: () => ref
                              .read(duelControllerProvider.notifier)
                              .accept(duel.id),
                          onDecline: () => ref
                              .read(duelControllerProvider.notifier)
                              .decline(duel.id),
                          onMove: (move) => ref
                              .read(duelControllerProvider.notifier)
                              .play(duel.id, game.round, move),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => ref.invalidate(duelStateProvider(duel.id)),
                  icon: const Icon(Icons.sync),
                  label: const Text('REFRESH'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameContent extends StatelessWidget {
  const _GameContent(
      {required this.game,
      required this.userId,
      required this.busy,
      required this.onAccept,
      required this.onDecline,
      required this.onMove});
  final DuelResult game;
  final String userId;
  final bool busy;
  final VoidCallback onAccept, onDecline;
  final ValueChanged<DuelMove> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = userId == game.challengerId;
    final lastMine = mine ? game.lastChallengerMove : game.lastOpponentMove;
    final lastTheirs = mine ? game.lastOpponentMove : game.lastChallengerMove;
    final finished = game.isFinished;
    final won = game.winnerId == userId;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label:
              'Score. You ${mine ? game.challengerScore : game.opponentScore}. '
              'Opponent ${mine ? game.opponentScore : game.challengerScore}.',
          child: ExcludeSemantics(
            child: Text(game.scoreFor(userId),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium),
          ),
        ),
        const Row(children: [
          Expanded(child: Text('YOU', textAlign: TextAlign.center)),
          Expanded(child: Text('THEM', textAlign: TextAlign.center)),
        ]),
        if (lastMine != null && lastTheirs != null) ...[
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 260),
            child: Container(
              key: ValueKey(game.round),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text('ROUND ${game.round - 1}',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Text('${lastMine.symbol}  vs  ${lastTheirs.symbol}',
                    style: const TextStyle(fontSize: 40)),
                Text(lastMine == lastTheirs
                    ? 'A draw. Same ego, next round.'
                    : lastMine.beats(lastTheirs)
                        ? 'Your point. Keep that energy.'
                        : 'Their point. Your comeback is loading.'),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (finished) ...[
          Text(won ? 'EGO INTACT.' : 'EGO: LIGHTLY TOASTED.',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(won ? 'Their roast:' : 'Your roast:',
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Semantics(
              liveRegion: true,
              child: Text(
                GameRoasts.line(game.roastKey,
                    languageCode: View.of(context)
                        .platformDispatcher
                        .locale
                        .languageCode),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              )),
          const SizedBox(height: 16),
          const Text('No Aura lost. No XP changed. Just bragging rights.',
              textAlign: TextAlign.center),
        ] else if (game.status == 'pending') ...[
          Text(
              mine
                  ? 'Invitation sent. Waiting for their courage.'
                  : 'Accept the challenge? Your points are safe.',
              textAlign: TextAlign.center),
          if (!mine) ...[
            const SizedBox(height: 16),
            FilledButton(
                onPressed: busy ? null : onAccept,
                child: const Text('LET’S PLAY')),
            TextButton(
                onPressed: busy ? null : onDecline,
                child: const Text('NOT NOW')),
          ],
        ] else if (game.status == 'active') ...[
          Text('ROUND ${game.round} · FIRST TO 3',
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(
              game.myMove == null
                  ? 'Choose in secret. Commit to the bit.'
                  : '${game.myMove!.label} locked. Waiting for their move.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final move in DuelMove.values)
                SizedBox(
                    width: 150,
                    child: OutlinedButton(
                      key: ValueKey('move-${move.name}'),
                      onPressed: busy || game.myMove != null
                          ? null
                          : () => onMove(move),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        ExcludeSemantics(
                            child: Text(move.symbol,
                                style: const TextStyle(fontSize: 32))),
                        const SizedBox(height: 8),
                        Text(move.label),
                        if (game.myMove == move)
                          const Icon(Icons.lock_outline, size: 18),
                      ]),
                    )),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
              'Both choices reveal together. A locked move cannot be changed.',
              textAlign: TextAlign.center),
        ] else
          Text(
              game.status == 'expired'
                  ? 'This duel has expired. No points changed.'
                  : 'This duel is closed. No points changed.',
              textAlign: TextAlign.center),
        if (busy)
          const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator())),
      ],
    );
  }
}

abstract final class DuelReplaySheet {
  static Future<void> show(BuildContext context,
      {required QuestDuel duel, required String questTitle}) {
    final userId = ProviderScope.containerOf(context, listen: false)
            .read(currentUserProvider)
            ?.id ??
        '';
    return DuelSheet.show(
        context,
        IncomingDuel(
          id: duel.id,
          questTitle: questTitle,
          challengerName: duel.otherName(userId),
          challengerAvatar: duel.otherAvatar(userId),
          createdAt: duel.createdAt,
          status: duel.status,
          isChallenger: duel.isChallenger(userId),
        ));
  }
}

Future<void> startDuelFlow(
  BuildContext context,
  WidgetRef ref, {
  required Challenge challenge,
  required QuestMember opponent,
}) async {
  final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('EGO DUEL'),
            content: Text(
                'Challenge @${opponent.username} to rock, paper, scissors. '
                'First to three wins. The loser gets a cheeky roast. '
                'Free to play: no Aura or XP is gained, lost or transferred.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('NOT NOW')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('CHALLENGE')),
            ],
          ));
  if (send != true || !context.mounted) return;
  final ok = await ref
      .read(duelControllerProvider.notifier)
      .create(challengeId: challenge.id, opponentId: opponent.userId);
  if (!context.mounted) return;
  final error = ref.read(duelControllerProvider).error;
  ScaffoldMessenger.of(context).showSnackBar(AppSnackBar(
      content: Text(ok
          ? 'Duel sent. Your ego is on the line. Your Aura is not.'
          : error is PostgrestException
              ? error.message
              : 'Could not send the duel. Try again.')));
}
