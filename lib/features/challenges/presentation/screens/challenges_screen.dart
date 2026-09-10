import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_states.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../application/challenge_providers.dart';
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
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Extra bottom padding so the FAB never covers a card.
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  itemCount: challenges.length,
                  itemBuilder: (context, index) => StaggeredEntrance(
                    delay: StaggeredEntrance.forIndex(index),
                    child: ChallengeCard(challenge: challenges[index]),
                  ),
                ),

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
