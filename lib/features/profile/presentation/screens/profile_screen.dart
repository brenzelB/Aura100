import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import '../../../../core/widgets/theme_components.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../challenges/application/challenge_providers.dart';
import '../../../challenges/domain/settlement.dart';
import '../../application/profile_providers.dart';
import '../../domain/profile.dart';
import '../widgets/activity_heatmap.dart';
import '../widgets/emoji_picker_sheet.dart';
import '../widgets/notification_settings_section.dart';
import '../../../../core/text/dates.dart';

/// Profile tab: identity, lifetime stats and account settings.
///
/// (This slot used to be the Shop — the shop is per-quest now and
/// lives on the challenge cards.)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static String _date(DateTime d) => formatDate(d);

  /// Tap the avatar → pick an emoji from the phone keyboard.
  Future<void> _pickAvatar(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final picked = await EmojiPickerSheet.show(
      context,
      initialEmoji: profile.avatarEmoji,
      username: profile.username,
    );
    if (picked == null || !context.mounted) return; // cancelled

    final clearing = picked == EmojiPickerSheet.clear;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .setAvatarEmoji(clearing ? null : picked);
    if (!context.mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (clearing ? 'Avatar removed.' : 'Avatar set to $picked')
          : 'Could not save the avatar - try again.'),
      backgroundColor: ok ? AppColors.neonGreen : AppColors.danger,
    ));
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final controller = TextEditingController(text: profile.username);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5)),
        ),
        title: Text(
          'CHANGE USERNAME',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.accentText),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              hintText: 'Username',
              counterText: '',
            ),
            // Mirrors the DB constraint (3-24 chars) so the round trip
            // is only spent on real problems like a taken name.
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.length < 3) return 'At least 3 characters';
              if (name.length > 24) return 'At most 24 characters';
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child:  Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (newName == null || newName == profile.username || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(profileControllerProvider.notifier).rename(newName);
    if (!context.mounted) return;

    if (ok) {
      messenger.showSnackBar(SnackBar(
        content: Text('You are now @$newName.'),
        backgroundColor: AppColors.neonGreen,
      ));
    } else {
      final error = ref.read(profileControllerProvider).error;
      // 23505 = unique violation, i.e. the name is already taken.
      final taken = error is PostgrestException && error.code == '23505';
      messenger.showSnackBar(SnackBar(
        content: Text(taken
            ? '"$newName" is already taken - pick another one.'
            : 'Could not rename - try again.'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    if (!SupabaseConfig.isConfigured) {
      context.go(AppRoutes.login); // skeleton mode: nothing to sign out of
      return;
    }
    // The router's auth listener navigates to /login automatically.
    await ref.read(authControllerProvider.notifier).signOut();
  }

  /// Reset player stats flow with confirmation dialog.
  Future<void> _resetStats(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.activeType == AppThemeType.editorial ? 24 : 20),
          side: BorderSide(
            color: AppColors.danger.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
        title: Text(
          'RESET LIFE STATS?',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(
                color: AppColors.danger,
                fontSize: 20,
              ),
        ),
        content: Text(
          'This will permanently wipe your check-in history, benefit purchases, and reset your Aura balance to 0 in all quests.\n\nAre you sure you want to reset?',
          style: Theme.of(dialogContext)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(color: AppColors.accentText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 40),
              shape: AppColors.activeType == AppThemeType.editorial
                  ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  : null,
            ),
            child: const Text('RESET STATS'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(profileControllerProvider.notifier).resetStats();
    if (!context.mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Stats reset successfully.'
          : 'Could not reset stats - try again.'),
      backgroundColor: ok ? AppColors.surfaceLight : AppColors.danger,
    ));
  }

  /// Account deletion is irreversible, so it asks twice: a warning
  /// dialog, then typing the username to confirm.
  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
        ),
        title: Text(
          'DELETE ACCOUNT?',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Everything goes: your quests, aura, gear, check-ins and '
              'friends. Quests you own are handed to another member; '
              'quests nobody else is in are deleted.\n\n'
              'Type your username to confirm.',
              style: Theme.of(dialogContext)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: profile.username),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child:  Text('KEEP MY ACCOUNT',
                style: TextStyle(color: AppColors.accentText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(
                controller.text.trim().toLowerCase() ==
                    profile.username.toLowerCase()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;

    if (confirmed == false) return; // cancelled, or the name didn't match
    if (confirmed == null) return; // dismissed

    final messenger = ScaffoldMessenger.of(context);
    final ok =
        await ref.read(profileControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Your account was deleted. Farewell, @${profile.username}.'
          : 'Could not delete the account - try again.'),
      backgroundColor: ok ? AppColors.surfaceLight : AppColors.danger,
    ));
    // On success the session is gone and the router sends us to /login.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final statsAsync = ref.watch(myStatsProvider);
    // Watched (not just read) so the controller survives its awaits.
    final busy = ref.watch(profileControllerProvider).isLoading;
    final email = ref.watch(profileRepositoryProvider).currentEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('PROFILE')),
      body: RefreshIndicator(
        color: AppColors.neonCyan,
        backgroundColor: AppColors.surface,
        onRefresh: () {
          ref.invalidate(myStatsProvider);
          ref.invalidate(trophiesProvider);
          return ref.refresh(currentProfileProvider.future);
        },
        child: profileAsync.when(
          loading: () =>  Center(
            child: CircularProgressIndicator(color: AppColors.accentText),
          ),
          error: (error, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Could not load your profile.\n$error',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          data: (profile) {
            if (profile == null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'Offline skeleton mode - no profile to show.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              );
            }

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                _IdentityCard(
                  profile: profile,
                  busy: busy,
                  onRename: () => _rename(context, ref, profile),
                  onPickAvatar: () => _pickAvatar(context, ref, profile),
                ),
                const SizedBox(height: 24),

                // ── Stats ────────────────────────────────────
                Text(
                  'PLAYER STATS',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.neonPurple),
                ),
                const SizedBox(height: 12),
                statsAsync.when(
                  data: (stats) => stats == null
                      ? const SizedBox.shrink()
                      : _StatsGrid(stats),
                  loading: () =>  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.neonPurple),
                    ),
                  ),
                  error: (error, _) => Text(
                    'Could not load stats.\n$error',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 28),

                // ── A year of habit, one square per day ──────
                const ActivityHeatmap(),
                const SizedBox(height: 28),

                // ── Trophy room (collapsed by default) ───────
                Builder(builder: (context) {
                  final trophies =
                      ref.watch(trophiesProvider).valueOrNull ?? const [];
                  if (trophies.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: _TrophyRoom(trophies: trophies),
                  );
                }),

                // ── Design Theme ─────────────────────────────
                Text(
                  'DESIGN SYSTEM',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.accentText),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.neonCyan.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose your visual universe. Alters all colors, panels, and typography.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      _ThemeSelectorRow(
                        currentTheme: ref.watch(themeProvider).type,
                        currentMode: ref.watch(themeProvider).mode,
                        onThemeChanged: (themeType) {
                          ref.read(themeProvider.notifier).setTheme(themeType);
                        },
                      ),
                      const SizedBox(height: 20),
                      Divider(
                        color: AppColors.outline,
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'APPEARANCE',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppColors.neonPurple),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Light or dark — applies to whichever design '
                        'system you picked above.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      _ModeSelectorRow(
                        currentMode: ref.watch(themeProvider).mode,
                        currentTheme: ref.watch(themeProvider).type,
                        onModeChanged: (mode) {
                          ref.read(themeProvider.notifier).setMode(mode);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Notifications ────────────────────────────
                const NotificationSettingsSection(),
                const SizedBox(height: 32),

                // ── Account ──────────────────────────────────
                Text(
                  'ACCOUNT',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.accentText),
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.mail_outline,
                  label: 'Email',
                  value: email ?? '-',
                ),
                _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Member since',
                  value: _date(profile.createdAt),
                ),
                const SizedBox(height: 4),

                // Pflicht, sobald die App an Dritte geht - und ohne
                // Verlinkung aus der App nuetzt die Seite wenig.
                _LegalLink(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy policy',
                  url: '$_legalBaseUrl#datenschutz',
                ),
                _LegalLink(
                  icon: Icons.gavel_outlined,
                  label: 'Legal notice',
                  url: '$_legalBaseUrl#impressum',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _signOut(context, ref),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('SIGN OUT'),
                ),
                const SizedBox(height: 32),

                // ── Danger zone ──────────────────────────────
                Text(
                  'DANGER ZONE',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppColors.activeType == AppThemeType.editorial ? 24 : 14),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.4),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Resetting player stats clears your check-ins, purchases and sets your Aura back to 0 in all quests.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _resetStats(context, ref, profile),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: AppColors.danger,
                            width: 1.0,
                          ),
                          minimumSize: const Size(0, 44),
                          shape: AppColors.activeType == AppThemeType.editorial
                              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              : null,
                        ),
                        icon: busy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.danger),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('RESET LIFE STATS'),
                      ),
                      const SizedBox(height: 20),
                      Divider(color: AppColors.danger.withValues(alpha: 0.2), height: 1),
                      const SizedBox(height: 20),
                      Text(
                        'Deleting your account removes every quest, '
                        'check-in and friendship for good.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _deleteAccount(context, ref, profile),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: BorderSide(
                            color: AppColors.danger,
                            width: 1.0,
                          ),
                          minimumSize: const Size(0, 44),
                          shape: AppColors.activeType == AppThemeType.editorial
                              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                              : null,
                        ),
                        icon: busy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.danger),
                              )
                            : const Icon(Icons.delete_forever, size: 18),
                        label: const Text('DELETE ACCOUNT'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Avatar + name + rename button.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.busy,
    required this.onRename,
    required this.onPickAvatar,
  });

  final Profile profile;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: AppColors.panelDecoration(accent: AppColors.neonCyan, glow: true),
      child: Column(
        children: [
          // Tap the avatar itself to change it — plus an explicit
          // hint underneath, since a tappable image isn't obvious.
          InkWell(
            onTap: busy ? null : onPickAvatar,
            customBorder: const CircleBorder(),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                AuraAvatar(
                  emoji: profile.avatarEmoji,
                  username: profile.username,
                  size: 84,
                  glow: true,
                  borderWidth: 2,
                ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration:  BoxDecoration(
                    color: AppColors.neonCyan,
                    shape: BoxShape.circle,
                  ),
                  child:  Icon(Icons.edit,
                      size: 12, color: AppColors.background),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '@${profile.username}',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: busy ? null : onRename,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentText,
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.edit, size: 14),
            label: const Text('CHANGE USERNAME'),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid(this.stats);

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.bolt, '${stats.totalAura}', 'total aura', AppColors.neonPurple),
      (Icons.emoji_events, '${stats.activeQuests}', 'active quests',
          AppColors.neonYellow),
      (Icons.flag, '${stats.questsJoined}', 'quests joined',
          AppColors.neonCyan),
      (Icons.check_circle, '${stats.totalCheckins}', 'check-ins',
          AppColors.neonGreen),
      (Icons.workspace_premium, '${stats.gearOwned}', 'gear owned',
          AppColors.neonPurple),
      (Icons.group, '${stats.friends}', 'friends', AppColors.neonPink),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: [
        for (final (icon, value, label, color) in tiles)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: AppColors.panelDecoration(accent: color),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ThemeIcon(
                  icon: icon,
                  matrixChar: switch (icon) {
                    Icons.bolt => '[A]',
                    Icons.emoji_events => '[Q]',
                    Icons.flag => '[J]',
                    Icons.check_circle => '[C]',
                    Icons.workspace_premium => '[G]',
                    Icons.group => '[F]',
                    _ => '[?]'
                  },
                  color: color,
                  size: 18,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One finished quest: golden for completed, grey for failed.
/// Perfect runs (zero missed periods) get the sparkle.
/// The trophy room, folded away by default so a long history does not
/// dominate the profile. The header alone summarises it; tapping opens
/// the list, where each entry can be removed.
class _TrophyRoom extends ConsumerStatefulWidget {
  const _TrophyRoom({required this.trophies});

  final List<Trophy> trophies;

  @override
  ConsumerState<_TrophyRoom> createState() => _TrophyRoomState();
}

class _TrophyRoomState extends ConsumerState<_TrophyRoom> {
  bool _open = false;

  Future<void> _remove(Trophy trophy) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.outline),
        ),
        title: Text(
          'REMOVE FROM ROOM?',
          style: Theme.of(dialogContext)
              .textTheme
              .headlineSmall
              ?.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          '"${trophy.questTitle}" disappears from your trophies. '
          'The quest itself and your stats stay as they are.',
          style: Theme.of(dialogContext)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('KEEP',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 40),
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok =
        await ref.read(trophyControllerProvider.notifier).hide(trophy.challengeId);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? '"${trophy.questTitle}" removed from your trophies.'
          : 'Could not remove that one - try again.'),
      backgroundColor: ok ? AppColors.surfaceLight : AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final trophies = widget.trophies;
    final won = trophies.where((t) => t.completed).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header doubles as the toggle.
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  'TROPHIES',
                  style: textTheme.headlineSmall
                      ?.copyWith(color: AppColors.warningText),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${trophies.length} finished · $won won',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more,
                      color: AppColors.textSecondary, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                for (final trophy in trophies)
                  _TrophyTile(trophy, onRemove: () => _remove(trophy)),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Swipe an entry aside, or use the ✕, to clear it out.',
                    style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }
}

class _TrophyTile extends StatelessWidget {
  const _TrophyTile(this.trophy, {this.onRemove});

  final Trophy trophy;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color =
        trophy.completed ? AppColors.neonYellow : AppColors.textSecondary;

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppColors.panelDecoration(accent: color),
      child: Row(
        children: [
          ThemeIcon(
            icon: trophy.completed ? Icons.emoji_events : Icons.heart_broken,
            matrixChar: trophy.completed ? '[T]' : '[X]',
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trophy.questTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (trophy.perfect) ...[
                      const SizedBox(width: 6),
                      const Text('✨', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                Text(
                  trophy.completed
                      ? (trophy.perfect ? 'Perfect run!' : 'Completed')
                      : 'Failed - scars still count',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          ThemeIcon(
            icon: Icons.bolt,
            matrixChar: '[A]',
            color: AppColors.neonPurple,
            size: 15,
          ),
          Text(
            '${trophy.finalAura}',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.neonPurple,
              fontWeight: FontWeight.w700,
              // Trophies stack, so these numbers form a column.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from trophies',
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(Icons.close,
                  size: 16, color: AppColors.textSecondary),
            ),
        ],
      ),
    );

    if (onRemove == null) return tile;

    // Swiping an entry aside clears it — the ✕ does the same for
    // anyone who does not think to swipe.
    return Dismissible(
      key: ValueKey('trophy-${trophy.challengeId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onRemove!();
        return false; // the dialog owns the outcome; list refreshes itself
      },
      background: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.delete_outline, color: AppColors.danger),
        ),
      ),
      child: tile,
    );
  }
}

/// Where the legal pages live. Same host family as the API, served from
/// the same NAS through the same tunnel.
const _legalBaseUrl = 'https://legal.brenzel.uk/aura-quest/';

/// A row that opens a legal page in the system browser.
///
/// Deliberately NOT an in-app web view: these pages must be readable
/// even when the app is broken or the account is gone, and a page the
/// user can share the URL of is worth more than one trapped in a modal.
class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  Future<void> _open(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (ok || !context.mounted) return;
    // No browser, or the launch was refused: show the address so it can
    // still be reached by hand. Silence would look like a dead button.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Could not open the browser. Visit $url'),
      backgroundColor: AppColors.surfaceLight,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Icon(Icons.open_in_new, size: 15, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelectorRow extends StatelessWidget {
  const _ThemeSelectorRow({
    required this.currentTheme,
    required this.currentMode,
    required this.onThemeChanged,
  });

  final AppThemeType currentTheme;

  /// Previews are painted in the active mode, so what you see in the
  /// swatch is what you get.
  final AppThemeMode currentMode;
  final ValueChanged<AppThemeType> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final type in AppThemeType.values) ...[
          if (type != AppThemeType.values.first) const SizedBox(width: 8),
          Expanded(
            child: _ThemeOptionCard(
              type: type,
              isSelected: currentTheme == type,
              onTap: () => onThemeChanged(type),
              colors: paletteFor(type, currentMode),
            ),
          ),
        ],
      ],
    );
  }
}

/// The universal light/dark switch. Independent of the design system —
/// pick a universe above, pick its lighting here.
class _ModeSelectorRow extends StatelessWidget {
  const _ModeSelectorRow({
    required this.currentMode,
    required this.currentTheme,
    required this.onModeChanged,
  });

  final AppThemeMode currentMode;
  final AppThemeType currentTheme;
  final ValueChanged<AppThemeMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in AppThemeMode.values) ...[
          if (mode != AppThemeMode.values.first) const SizedBox(width: 8),
          Expanded(
            child: _ModeOptionCard(
              mode: mode,
              isSelected: currentMode == mode,
              onTap: () => onModeChanged(mode),
              colors: paletteFor(currentTheme, mode),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  /// The palette this option would produce — the card previews itself.
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.neonPurple : colors.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              mode.icon,
              size: 20,
              color: isSelected ? colors.neonPurple : colors.textSecondary,
            ),
            const SizedBox(height: 6),
            Text(
              mode.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isSelected ? colors.neonPurple : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  const _ThemeOptionCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final AppThemeType type;
  final bool isSelected;
  final VoidCallback onTap;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final textStyle = switch (type) {
      AppThemeType.neoBrutalist => GoogleFonts.hankenGrotesk(fontSize: 10, fontWeight: FontWeight.w900, color: colors.textPrimary),
      AppThemeType.editorial => GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textPrimary),
      AppThemeType.auralis => GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: colors.textPrimary),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.neonCyan : colors.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.neonCyan.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              type.displayName,
              textAlign: TextAlign.center,
              style: textStyle,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PaletteDot(color: colors.neonCyan),
                const SizedBox(width: 4),
                _PaletteDot(color: colors.neonPink),
                const SizedBox(width: 4),
                _PaletteDot(color: colors.neonPurple),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  const _PaletteDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
