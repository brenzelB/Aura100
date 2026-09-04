import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Temporary placeholder body used by the four dashboard tabs during
/// Phase 1. Will be deleted as each feature gets its real UI.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    this.actions,
    this.subtitle,
    this.floatingActionButton,
  });

  final String title;
  final IconData icon;
  final Color accent;

  /// Optional app bar actions (e.g. the logout button on the Home tab).
  final List<Widget>? actions;

  /// Optional line under the "coming soon" text (e.g. the user's email).
  final String? subtitle;

  /// Optional FAB (e.g. "new quest" on the Challenges tab).
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title.toUpperCase()), actions: actions),
      floatingActionButton: floatingActionButton,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing icon badge in the feature's accent color.
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
                boxShadow: AppColors.neonGlow(accent),
              ),
              child: Icon(icon, size: 48, color: accent),
            ),
            const SizedBox(height: 24),
            Text(
              'COMING SOON',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: accent),
            ),
            const SizedBox(height: 12),
            Text(
              'This quest is still being forged…',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: accent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
