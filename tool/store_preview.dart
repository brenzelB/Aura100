// Isolated screenshot entrypoint. Release workflows use lib/main.dart.
// These illustrative, local fixtures never authenticate or write to the NAS.
import 'dart:async';
import 'package:aura_quest/core/theme/app_colors.dart';
import 'package:aura_quest/core/theme/app_theme.dart';
import 'package:aura_quest/core/widgets/app_theme_background.dart';
import 'package:aura_quest/core/widgets/theme_scope.dart';
import 'package:aura_quest/features/auth/application/auth_providers.dart';
import 'package:aura_quest/features/challenges/application/challenge_providers.dart';
import 'package:aura_quest/features/challenges/domain/challenge.dart';
import 'package:aura_quest/features/challenges/presentation/screens/challenges_screen.dart';
import 'package:aura_quest/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:aura_quest/features/friends/application/friends_providers.dart';
import 'package:aura_quest/features/home/presentation/screens/home_screen.dart';
import 'package:aura_quest/features/profile/application/profile_providers.dart';
import 'package:aura_quest/features/profile/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  if (!const bool.fromEnvironment('STORE_PREVIEW')) {
    throw StateError('Screenshot entrypoint requires STORE_PREVIEW=true.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('push_prompt_dismissed', true);
  await prefs.setInt('selected_theme', AppThemeType.neoBrutalist.index);
  await prefs.setInt('selected_theme_mode', AppThemeMode.light.index);
  await Supabase.initialize(
      url: 'https://store-preview.invalid',
      publishableKey: 'preview-only-public-key');
  final now = DateTime.now().toUtc();
  Challenge quest(String id, String title,
          {GoalType goal = GoalType.check,
          double? target,
          String? unit,
          double progress = 0,
          int members = 1,
          CheckinPeriod period = CheckinPeriod.daily,
          QuestMode mode = QuestMode.solo}) =>
      Challenge(
          id: id,
          creatorId: 'preview',
          title: title,
          description: '',
          durationDays: 56,
          auraGain: 100,
          auraPenalty: 25,
          maxStrikes: 3,
          startsOn: now.subtract(const Duration(days: 3)),
          createdAt: now,
          myAura: 400,
          goalType: goal,
          targetValue: target,
          unit: unit,
          progressInPeriod: progress,
          memberCount: members,
          mode: mode,
          checkinPeriod: period,
          checkinsPerPeriod: period == CheckinPeriod.weekly ? 3 : 1,
          balancePreset: 'classic');
  final quests = [
    quest('reading', '10 Seiten statt Doomscrolling',
        goal: GoalType.progress, target: 10, unit: 'Seiten', progress: 4),
    quest('training', 'Zusammen zum Training',
        members: 4, period: CheckinPeriod.weekly, mode: QuestMode.coop),
    quest('focus', '10 Minuten Fokus. Du schaffst das.'),
  ];
  runApp(ProviderScope(overrides: [
    currentUserProvider.overrideWithValue(null),
    currentProfileProvider.overrideWith((ref) => Profile(
        id: 'preview', username: 'mila', createdAt: now, avatarEmoji: '⚡')),
    myChallengesProvider.overrideWith((ref) => quests),
    myCheckInsProvider.overrideWith((ref) => {}),
    myInvitesProvider.overrideWith((ref) => []),
    friendRequestsProvider.overrideWith((ref) => []),
    incomingDuelsProvider.overrideWith((ref) => []),
    unseenNudgesProvider.overrideWith((ref) => []),
    targetedRoastsProvider.overrideWith((ref) => []),
    robbedNoticesProvider.overrideWith((ref) => []),
    unseenBlackoutsProvider.overrideWith((ref) => []),
    pokeBacksProvider.overrideWith((ref) => []),
    settlementEventsProvider.overrideWith((ref) => []),
    myBlackoutProvider.overrideWith((ref, id) => null),
    weeklyRecapProvider.overrideWith((ref) => null),
    trophiesProvider.overrideWith((ref) => []),
  ], child: const _Preview()));
}

class _Preview extends ConsumerStatefulWidget {
  const _Preview();
  @override
  ConsumerState<_Preview> createState() => _PreviewState();
}

class _PreviewState extends ConsumerState<_Preview> {
  late final GoRouter router;
  Timer? timer;
  int page = 0;
  @override
  void initState() {
    super.initState();
    router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            DashboardShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                builder: (_, __) =>
                    ThemeScope(builder: (_) => const HomeScreen()))
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/challenges',
                builder: (_, __) =>
                    ThemeScope(builder: (_) => const ChallengesScreen()))
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/friends', builder: (_, __) => const SizedBox())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const SizedBox())
          ]),
        ],
      ),
    ]);
    timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (page >= 3) return;
      page++;
      final theme = ref.read(themeProvider.notifier);
      if (page >= 2) theme.setTheme(AppThemeType.editorial);
      if (page == 3) theme.setMode(AppThemeMode.dark);
      router.go(page == 3 ? '/home' : '/challenges');
      ready();
    });
    ready();
  }

  void ready() => Future<void>.delayed(const Duration(seconds: 5), () {
        if (mounted) debugPrint('STORE_CAPTURE_READY_$page');
      });
  @override
  void dispose() {
    timer?.cancel();
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    return MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(theme.type, theme.mode),
        routerConfig: router,
        builder: (_, child) =>
            AppThemeBackground(themeType: theme.type, child: child!));
  }
}
