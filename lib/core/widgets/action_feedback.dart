import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/motion.dart';

/// Only pass a reward reported by the server. Pending actions never display one.
void showActionFeedback(
  ScaffoldMessengerState messenger, {
  required String message,
  int? confirmedAura,
  bool pending = false,
  bool error = false,
}) {
  if (!messenger.mounted) return;
  final color = error
      ? AppColors.danger
      : pending
          ? AppColors.warningText
          : AppColors.successText;
  if (!pending && !error) HapticFeedback.lightImpact();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color),
      ),
      content: Row(
        children: [
          Icon(
              error
                  ? Icons.error_outline
                  : pending
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_outline,
              color: color,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: AppColors.textPrimary))),
          if (!pending &&
              !error &&
              confirmedAura != null &&
              confirmedAura > 0) ...[
            const SizedBox(width: 10),
            ConfirmedAuraAmount(key: UniqueKey(), amount: confirmedAura),
          ],
        ],
      ),
    ));
}

class ConfirmedAuraAmount extends StatelessWidget {
  const ConfirmedAuraAmount({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: '+$amount Aura confirmed',
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(
              begin: reduce ? amount.toDouble() : 0, end: amount.toDouble()),
          duration: reduce ? Duration.zero : AppDurations.slow,
          curve: AppCurves.emphasizedOut,
          builder: (context, value, _) => Text(
            '+${value.round()} ⚡',
            style: TextStyle(
                color: AppColors.successText, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
