import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

/// First screen shown at app launch.
///
/// Briefly shows the logo, then heads for /login. If a Supabase
/// session already exists, the router's auth guard (see app_router.dart)
/// intercepts that navigation and lands on the dashboard instead — so
/// this screen never needs to know about auth.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 350), () {
      // Router redirect rewrites this to /home when a session exists.
      if (mounted) context.go(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // never navigate from a disposed widget
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder logo mark — swap for real branding later.
            Container(
              padding: const EdgeInsets.all(28),
              decoration: AppColors.panelDecoration(
                  accent: AppColors.neonCyan,
                  fill: AppColors.neonCyan,
                  glow: true),
              child: Icon(
                Icons.bolt,
                size: 64,
                color: AppColors.onAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'AURA QUEST',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(color: AppColors.accentText),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: AppColors.neonPink,
                backgroundColor: AppColors.surface,
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
