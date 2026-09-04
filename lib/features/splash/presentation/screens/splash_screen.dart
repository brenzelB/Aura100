import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';

/// First screen shown at app launch.
///
/// Shows the logo for 2 seconds, then heads for /login. If a Supabase
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
    _timer = Timer(const Duration(seconds: 2), () {
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.neonCyan, width: 2),
                boxShadow: AppColors.neonGlow(AppColors.neonCyan),
              ),
              child:  Icon(
                Icons.bolt,
                size: 64,
                color: AppColors.neonCyan,
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
