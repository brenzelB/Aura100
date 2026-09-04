import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The one avatar of the app: an emoji (or the username's initial as a
/// fallback) framed in Cyber-Pixel style.
///
/// Emojis are full-colour glyphs that would look pasted-on against the
/// dark UI, so the FRAME does the styling: a dark disc, a neon ring in
/// the caller's accent colour and a soft radial glow behind the glyph,
/// which ties it into the app's look without touching the emoji itself.
class AuraAvatar extends StatelessWidget {
  const AuraAvatar({
    super.key,
    required this.emoji,
    required this.username,
    this.size = 40,
    this.color,
    this.glow = false,
    this.borderWidth = 1.5,
  });

  /// The player's chosen emoji; null → initial letter.
  final String? emoji;

  final String username;
  final double size;

  /// Ring + glow colour (e.g. gold for a quest owner).
  final Color? color;

  /// Outer neon halo — for hero spots like the profile card.
  final bool glow;

  final double borderWidth;

  static IconData? _getIconData(String name) {
    return switch (name) {
      'face' => Icons.face,
      'game' => Icons.sports_esports,
      'rocket' => Icons.rocket_launch,
      'trophy' => Icons.emoji_events,
      'fire' => Icons.local_fire_department,
      'shield' => Icons.shield,
      'pets' => Icons.pets,
      'run' => Icons.directions_run,
      'gym' => Icons.fitness_center,
      'heart' => Icons.favorite,
      'star' => Icons.star,
      'bolt' => Icons.flash_on,
      'user' => Icons.account_circle,
      'brain' => Icons.psychology,
      'shapes' => Icons.category,
      'puzzle' => Icons.extension,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasEmoji = emoji != null && emoji!.isNotEmpty;
    final resolvedColor = color ?? AppColors.neonCyan;

    // Use textPrimary for high contrast readability of initials/icons inside the avatar
    final contentColor = AppColors.textPrimary;

    Widget? avatarContent;
    if (hasEmoji) {
      if (emoji!.startsWith('❖')) {
        final iconName = emoji!.substring(1);
        final iconData = _getIconData(iconName);
        if (iconData != null) {
          avatarContent = Icon(
            iconData,
            size: size * 0.5,
            color: contentColor,
          );
        }
      }
      
      avatarContent ??= Text(
        emoji!,
        style: TextStyle(fontSize: size * 0.5),
        textAlign: TextAlign.center,
      );
    } else {
      avatarContent = Text(
        username.isEmpty ? '?' : username[0].toUpperCase(),
        style: TextStyle(
          color: contentColor,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final isAuralis = AppColors.activeType == AppThemeType.auralis;
    final isNeoBrutalist = AppColors.activeType == AppThemeType.neoBrutalist;
    final isEditorial = AppColors.activeType == AppThemeType.editorial;

    // Resolve contrast-safe background fills and gradients for each theme type:
    Color? bgColor;
    Gradient? bgGradient;

    if (isAuralis || isEditorial) {
      bgColor = AppColors.surfaceLight; // Cream in Editorial, Light grey in Auralis (and dark-mode variations)
    } else if (isNeoBrutalist) {
      bgColor = AppColors.surface; // White in light mode, Dark surface in dark mode
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        gradient: bgGradient,
        border: Border.all(color: resolvedColor, width: borderWidth),
        boxShadow: null,
      ),
      child: avatarContent,
    );
  }
}
