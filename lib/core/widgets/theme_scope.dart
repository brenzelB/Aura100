import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

/// Rebuilds its subtree whenever the design system or light/dark mode
/// changes.
///
/// Screens read their colours from the global [AppColors] at build
/// time rather than from an InheritedWidget, so a theme switch alone
/// does not repaint them — a screen kept alive by the shell's
/// IndexedStack would keep serving the previous palette. Re-keying the
/// subtree forces a clean rebuild with the new colours.
class ThemeScope extends ConsumerWidget {
  const ThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    return KeyedSubtree(
      key: ValueKey('${theme.type.name}-${theme.mode.name}'),
      child: child,
    );
  }
}
