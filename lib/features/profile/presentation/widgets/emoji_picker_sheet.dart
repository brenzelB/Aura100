import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../domain/emoji.dart';

/// Lets the player pick an avatar emoji straight from their phone
/// keyboard: the text field opens it, and whatever emoji they tap
/// lands in the live preview above.
///
/// Pops the chosen emoji, or the sentinel [EmojiPickerSheet.clear] when
/// they want the plain initial back. Popping null = cancelled.
class EmojiPickerSheet extends StatefulWidget {
  const EmojiPickerSheet({
    super.key,
    required this.initialEmoji,
    required this.username,
  });

  final String? initialEmoji;
  final String username;

  /// Distinguishes "remove my avatar" from "cancelled" on pop.
  static const String clear = '__clear__';

  static Future<String?> show(
    BuildContext context, {
    required String? initialEmoji,
    required String username,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // rise above the keyboard
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EmojiPickerSheet(
        initialEmoji: initialEmoji,
        username: username,
      ),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _preview;

  /// A few on-brand picks so the sheet is useful even before opening
  /// the emoji keyboard.
  static const _suggestions = [
    '⚡', '🔥', '💪', '🏆', '🎮', '🚀', '🧠', '🥷', '👑', '🐉', '🎯', '💎',
  ];

  static const _icons = [
    'face', 'game', 'rocket', 'trophy', 'fire', 'shield', 'pets', 'run',
    'gym', 'heart', 'star', 'bolt', 'user', 'brain', 'shapes', 'puzzle',
  ];

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
  void initState() {
    super.initState();
    _preview = widget.initialEmoji;
    // Straight to the keyboard — the emoji key is one tap away there.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// The keyboard may deliver letters or several emojis at once; keep
  /// the last emoji and drop everything else.
  void _onChanged(String value) {
    final emoji = EmojiUtils.extractLast(value);
    if (emoji == null) {
      // Typed text isn't an avatar — wipe it, keep the preview.
      _controller.clear();
      return;
    }
    setState(() => _preview = emoji);
    // Mirror just the emoji back into the field.
    _controller.value = TextEditingValue(
      text: emoji,
      selection: TextSelection.collapsed(offset: emoji.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'PICK YOUR AVATAR',
            style: textTheme.headlineSmall
                ?.copyWith(color: AppColors.accentText),
          ),
          const SizedBox(height: 20),

          // Live preview in the real frame.
          AuraAvatar(
            emoji: _preview,
            username: widget.username,
            size: 84,
            glow: true,
          ),
          const SizedBox(height: 20),

          // The keyboard entry point.
          TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            decoration:  InputDecoration(
              hintText: 'Tap 😀 on your keyboard',
              helperText: 'Any emoji from your keyboard works',
              helperStyle: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),

          // Quick picks.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final emoji in _suggestions)
                InkWell(
                  onTap: () => setState(() => _preview = emoji),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _preview == emoji
                          ? AppColors.neonCyan.withValues(alpha: 0.18)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _preview == emoji
                            ? AppColors.neonCyan
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            'FLAT AVATAR ICONS',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final iconName in _icons)
                InkWell(
                  onTap: () => setState(() => _preview = '❖$iconName'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _preview == '❖$iconName'
                          ? AppColors.neonCyan.withValues(alpha: 0.18)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _preview == '❖$iconName'
                            ? AppColors.neonCyan
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      _getIconData(iconName) ?? Icons.face,
                      size: 22,
                      color: _preview == '❖$iconName'
                          ? AppColors.neonCyan
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              if (widget.initialEmoji != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pop(EmojiPickerSheet.clear),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side:  BorderSide(color: AppColors.surfaceLight),
                    ),
                    child: const Text('REMOVE'),
                  ),
                ),
              if (widget.initialEmoji != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _preview == null
                      ? null
                      : () => Navigator.of(context).pop(_preview),
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
