import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/theme_scope.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/challenges/presentation/screens/challenge_detail_screen.dart';
import '../../features/challenges/presentation/screens/challenges_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../config/supabase_config.dart';

/// Route paths as constants — never hardcode path strings in widgets.
abstract class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String challenges = '/challenges';
  static const String friends = '/friends';

  /// The 4th tab was the Shop; the shop is per-quest now (opened from
  /// a challenge card), so this slot became the player's profile.
  static const String profile = '/profile';
}

/// The GoRouter instance, exposed through Riverpod.
///
/// Auth-aware: the router listens to Supabase auth events (via
/// [authStateChangesProvider]) and re-runs its `redirect` on every one.
/// That means sign-in and sign-out navigate automatically — no screen
/// ever has to remember to route the user after an auth change.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridge the auth event stream into a Listenable for GoRouter.
  final refreshNotifier = _AuthRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, __) => refreshNotifier.refresh());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true, // handy during development; remove for release
    refreshListenable: refreshNotifier,

    // ── Global auth guard ─────────────────────────────────────
    redirect: (context, state) {
      // Offline skeleton mode: no Supabase, no guard — everything walkable.
      if (!SupabaseConfig.isConfigured) return null;

      final location = state.matchedLocation;

      // Splash is exempt: it decides where to go itself after its delay.
      // Checked before touching Supabase so the guard never reads the auth
      // repository on the very first frame (keeps startup — and tests —
      // independent of an initialized client).
      if (location == AppRoutes.splash) return null;

      final loggedIn = ref.read(authRepositoryProvider).currentSession != null;

      // Logged out + trying to reach a protected page → login.
      if (!loggedIn && location != AppRoutes.login) return AppRoutes.login;

      // Logged in + sitting on the login page → home, with one exception:
      // a password reset holds a session from the moment the code is
      // accepted, but is only half done. Sending the user to the dashboard
      // there would skip the screen that sets the new password.
      if (loggedIn && location == AppRoutes.login) {
        if (ref.read(passwordRecoveryInProgressProvider)) return null;
        return AppRoutes.home;
      }

      return null; // no redirect needed
    },

    routes: [
      // ── Standalone (full-screen) routes ─────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => ThemeScope(builder: (_) => SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => ThemeScope(builder: (_) => LoginScreen()),
      ),

      // ── Main dashboard: 4 tabs behind a shared bottom nav ───
      // StatefulShellRoute keeps each tab's navigation stack and
      // scroll position alive when switching tabs (IndexedStack).
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ThemeScope(
          builder: (_) => DashboardShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) =>
                  ThemeScope(builder: (_) => HomeScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.challenges,
              builder: (context, state) =>
                  ThemeScope(builder: (_) => ChallengesScreen()),
              routes: [
                // Detail view: /challenges/<challenge-id>
                // Nested inside the branch, so the bottom nav stays and
                // the back button returns to the list.
                GoRoute(
                  path: ':id',
                  builder: (context, state) => ThemeScope(
                    builder: (_) => ChallengeDetailScreen(
                      challengeId: state.pathParameters['id']!,
                    ),
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.friends,
              builder: (context, state) =>
                  ThemeScope(builder: (_) => FriendsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) =>
                  ThemeScope(builder: (_) => ProfileScreen()),
            ),
          ]),
        ],
      ),
    ],

    // Simple fallback for unknown routes.
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('PAGE NOT FOUND')),
      body: Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('This page is no longer available.'),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('BACK TO HOME')),
              ]))),
    ),
  );
});

/// Tiny ChangeNotifier the router can subscribe to; we poke it whenever
/// a Supabase [AuthState] event arrives so `redirect` re-runs.
class _AuthRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
