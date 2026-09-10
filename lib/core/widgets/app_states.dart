import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/design_tokens.dart';

/// Messages retain readable text, regardless of the supplied status colour.
class AppSnackBar extends SnackBar {
  AppSnackBar(
      {super.key,
      required Widget content,
      Color? backgroundColor,
      super.duration,
      SnackBarAction? action,
      super.behavior})
      : super(
          backgroundColor: backgroundColor ?? AppColors.surface,
          shape: AppShapes.panel,
          elevation: 0,
          action: action == null
              ? null
              : SnackBarAction(
                  label: action.label,
                  onPressed: action.onPressed,
                  textColor: readableOn(backgroundColor ?? AppColors.surface)),
          content: Semantics(
              liveRegion: true,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                    color: readableOn(backgroundColor ?? AppColors.surface),
                    fontSize: 15,
                    height: 1.4),
                child: content,
              )),
        );
}

class AppStatePanel extends StatelessWidget {
  const AppStatePanel(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.auto_awesome_outlined,
      this.actionLabel,
      this.onAction});
  final String title, message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration:
            AppColors.panelDecoration(accent: AppColors.neonCyan, glow: true),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.neonCyan,
                  border: Border.all(color: AppColors.outline, width: 2),
                  borderRadius: BorderRadius.circular(6)),
              child:
                  Icon(icon, size: 28, color: readableOn(AppColors.neonCyan))),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward),
                label: Text(actionLabel!)),
          ],
        ]),
      );
}

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.label = 'Loading…'});
  final String label;
  @override
  Widget build(BuildContext context) => Center(
          child: Semantics(
        liveRegion: true,
        label: label,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 16),
          Text(label),
        ]),
      ));
}

/// Scrollable at large type sizes and above the keyboard, with shared geometry.
class AppDialog extends AlertDialog {
  AppDialog({
    super.key,
    super.title,
    super.content,
    super.actions,
    super.backgroundColor,
    ShapeBorder? shape,
    super.insetPadding,
    super.contentPadding,
    super.actionsPadding,
    super.titlePadding,
    super.scrollable = true,
    super.actionsAlignment,
  }) : super(shape: AppShapes.dialog);
}
