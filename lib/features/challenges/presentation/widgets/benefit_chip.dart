import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Icon for a shop benefit, matched by title (the seeded stock).
IconData benefitIcon(String title) => switch (title) {
      'Title Badge' => Icons.workspace_premium,
      'Streak Shield' => Icons.security,
      'Double Down' => Icons.bolt,
      'Strike Repair' => Icons.build,
      'Targeted Roast' => Icons.local_fire_department,
      'Aura Heist' => Icons.savings,
      'Aura Lord' => Icons.workspace_premium,
      _ => Icons.card_giftcard,
    };

/// The two emblems and how they read next to a name.
class _EmblemStyle {
  const _EmblemStyle(this.icon, this.color, this.label);
  final IconData icon;
  final Color color;
  final String label;
}

_EmblemStyle _emblemStyle(String title) => switch (title) {
      'Aura Lord' => _EmblemStyle(
          Icons.workspace_premium, AppColors.neonPurple, 'AURA LORD'),
      _ => _EmblemStyle(
          Icons.military_tech, AppColors.neonYellow, 'TITLE'),
    };

/// A real, compact emblem worn inline next to a player's name — a filled
/// gold/purple pill with the crest icon. Own-once titles only.
class TitleEmblem extends StatelessWidget {
  const TitleEmblem({super.key, required this.title, this.dense = false});

  final String title;

  /// Icon-only (no label) — used where space is tight.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final style = _emblemStyle(title);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 5 : 7, vertical: dense ? 3 : 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            style.color.withValues(alpha: 0.30),
            style.color.withValues(alpha: 0.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: style.color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: dense ? 12 : 13, color: style.color),
          if (!dense) ...[
            const SizedBox(width: 3),
            Text(
              style.label,
              style: TextStyle(
                color: style.color,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small purple pill showing ONE owned benefit — used on the challenge
/// card and in the detail header.
class BenefitChip extends StatelessWidget {
  const BenefitChip({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neonPurple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: AppColors.neonPurple.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(benefitIcon(title), size: 14, color: AppColors.neonPurple),
          const SizedBox(width: 4),
          Text(
            title,
            style:  TextStyle(
              color: AppColors.neonPurple,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
