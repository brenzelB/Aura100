import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_providers.dart';
import 'core/realtime/realtime_sync.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_theme_background.dart';
import 'features/challenges/application/challenge_providers.dart';

/// Root widget: wires the theme and the router together.
class AuraQuestApp extends ConsumerWidget {
  const AuraQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(themeProvider);

    // One realtime channel for the whole app: keeps the signed-in user's
    // notifications and balances current without any screen polling.
    ref.watch(realtimeSyncProvider);

    // Hands the device's UTC offset to the server so a Blackout can be
    // scheduled in this player's own morning, noon or night.
    ref.watch(timezoneReporterProvider);

    // Registers this device for push and routes a tapped notification to
    // the quest, duel or friend it is about.
    ref.watch(pushGatewayProvider);

    // Every design system ships a light and a dark palette; the mode is
    // resolved here, so `theme` is already the right one either way.
    final data = AppTheme.build(theme.type, theme.mode);

    return MaterialApp.router(
      title: 'Aura Quest',
      debugShowCheckedModeBanner: false,
      theme: data,
      darkTheme: data,
      themeMode: theme.mode == AppThemeMode.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        return AppThemeBackground(
          themeType: theme.type,
          child: child!,
        );
      },
    );
  }
}
