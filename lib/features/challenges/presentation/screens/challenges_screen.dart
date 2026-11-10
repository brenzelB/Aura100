import 'package:flutter/material.dart';
import '../../../../core/widgets/editorial_cover.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_states.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../widgets/challenge_card.dart';
import '../widgets/create_challenge_sheet.dart';

/// My Challenges tab: the user's active quests.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(myChallengesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('MY QUESTS')),
      floatingActionButton: (challengesAsync.valueOrNull?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => CreateChallengeSheet.show(context),
              icon: const Icon(Icons.add),
              label: const Text(
                'NEW QUEST',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
            ),
      body: RefreshIndicator(
        color: AppColors.neonYellow,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.refresh(myChallengesProvider.future),
        child: challengesAsync.when(
          // Refreshing keeps the list on screen (no spinner flash, and
          // the entrance stagger doesn't replay every pull).
          skipLoadingOnReload: true,
          // ── Data: the quest list (or a hero empty state) ──────
          data: (challenges) => challenges.isEmpty
              ? const _EmptyState()
              : _GroupedQuestList(challenges: challenges),

          // ── Loading ───────────────────────────────────────────
          loading: () => const AppLoadingState(label: 'Loading your quests…'),

          // ── Error with retry ──────────────────────────────────
          error: (error, _) => _ErrorState(
            error: error,
            onRetry: () => ref.invalidate(myChallengesProvider),
          ),
        ),
      ),
    );
  }
}

/// Shown when the user has no active quests yet.
/// Wrapped in a ListView so pull-to-refresh keeps working.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (AppColors.activeType == AppThemeType.editorial)
          const EditorialCover(
              title: 'Your next chapter.',
              compact: true,
              chapter: 'THE QUEST EDIT',
              subtitle: 'Every great habit starts somewhere.'),
        AppStatePanel(
            title: 'Your next chapter starts here.',
            message:
                'Train, learn or break a habit. Start solo, or bring your friends along.',
            icon: Icons.flag_outlined,
            actionLabel: 'NEW QUEST',
            onAction: () => CreateChallengeSheet.show(context)),
      ],
    );
  }
}

/// Load failure with a retry button. Also scrollable for pull-to-refresh.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
        const SizedBox(height: 16),
        Text(
          'Could not load your quests. Check your connection and try again.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('RETRY'),
          ),
        ),
      ],
    );
  }
}

/// The three questions a quest list answers: what am I playing, what is
/// about to start, and what is over. One mixed list sorted by age made
/// a won quest from last month sit between two that are due today.
class _GroupedQuestList extends StatelessWidget {
  const _GroupedQuestList({required this.challenges});

  final List<Challenge> challenges;

  @override
  Widget build(BuildContext context) {
    final editorial = AppColors.activeType == AppThemeType.editorial;
    final active = <Challenge>[];
    final waiting = <Challenge>[];
    final finished = <Challenge>[];
    for (final c in challenges) {
      if (c.isOver) {
        finished.add(c);
      } else if (c.isLobby || !c.hasStarted) {
        waiting.add(c);
      } else {
        active.add(c);
      }
    }
    final sections = [
      ('ACTIVE', active),
      ('WAITING TO START', waiting),
      ('FINISHED', finished),
    ].where((s) => s.$2.isNotEmpty).toList();
    // A single group needs no heading - it would only push cards down.
    final showHeadings = sections.length > 1;

    final children = <Widget>[
      if (editorial)
        const EditorialCover(
            title: 'Make room for more.',
            chapter: 'THE QUEST EDIT',
            compact: true,
            subtitle: 'Build a habit. Break a pattern. Surprise yourself.'),
    ];
    var index = 0;
    for (final (title, quests) in sections) {
      if (showHeadings) {
        children.add(Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8, bottom: 12),
          child: Semantics(
            header: true,
            child: Text(
              '$title · ${quests.length}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.textSecondary, letterSpacing: 1),
            ),
          ),
        ));
      }
      for (final quest in quests) {
        children.add(StaggeredEntrance(
          delay: StaggeredEntrance.forIndex(index++),
          child: ChallengeCard(challenge: quest),
        ));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Extra bottom padding so the FAB never covers a card.
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: children,
    );
  }
}
