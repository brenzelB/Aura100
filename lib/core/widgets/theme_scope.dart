import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

/// Rebuilds its subtree whenever the design system or light/dark mode
/// changes.
///
/// Rebuild screens with the current palette while preserving their State,
/// scroll positions and text-field drafts when the theme changes.
class ThemeScope extends ConsumerWidget {
  const ThemeScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    return builder(context);
  }
}
