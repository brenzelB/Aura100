import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/push/push_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Asks for notification permission — but explains itself first.
///
/// The system prompt is a one-shot on Android 13+: after two refusals it
/// can only be undone in the system settings, which nobody does. Firing
/// it at app start, before the player has any idea why this app wants
/// it, spends that one shot on a coin flip.
///
/// So the card makes the case in the app's own words and only summons
/// the system prompt when the player has already said yes once. Whoever
/// taps "Not now" is not asked again — the card stays gone, and the
/// switch lives in the profile from then on.
class PushPermissionCard extends ConsumerStatefulWidget {
  const PushPermissionCard({super.key});

  @override
  ConsumerState<PushPermissionCard> createState() => _PushPermissionCardState();
}

class _PushPermissionCardState extends ConsumerState<PushPermissionCard> {
  static const _dismissedKey = 'push_prompt_dismissed';

  /// null = still deciding whether to show anything at all.
  bool? _show;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final status = await PushService.instance.permissionStatus();

    // Granted already — nothing to ask, nothing to show.
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      if (mounted) setState(() => _show = false);
      return;
    }

    // Everything else means "not granted", and on Android that is ALSO
    // what a never-asked permission reports — there is no separate
    // "not determined" there. So the system status cannot tell us
    // whether asking is still possible; only our own record can.
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_dismissedKey) ?? false;
    if (mounted) setState(() => _show = !dismissed);
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await PushService.instance.askPermission();
    if (!mounted) return;

    // Asked once, either way: the card does not come back. A refusal
    // that keeps being re-asked is nagging, and on Android the second
    // refusal is final anyway.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _show = false;
    });
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'No notifications, then. You can turn them on in Profile.'),
        backgroundColor: AppColors.surfaceLight,
      ));
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (mounted) setState(() => _show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_show != true) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppColors.panelDecoration(accent: AppColors.accentText),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    size: 20, color: AppColors.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('DON\'T GET AMBUSHED',
                      style: textTheme.headlineSmall
                          ?.copyWith(color: AppColors.accentText, fontSize: 17)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A blackout locks you out for two hours. A heist takes your '
              'next check-in. A duel runs out after 48. Without '
              'notifications you find out when it is already over.',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _enable,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: const Text('TURN ON NOTIFICATIONS'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : _dismiss,
              child: Text('Not now',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
