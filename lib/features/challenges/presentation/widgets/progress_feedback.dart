import 'package:flutter/material.dart';

import '../../../../core/text/quantity.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../domain/progress_entry.dart';

void showProgressFeedback(
  ScaffoldMessengerState messenger, {
  required ProgressResult result,
  required double added,
  required String unit,
}) {
  final message = result.overshoot
      ? '+${formatQuantity(added)} bonus logged · ${formatQuantity(result.total)} $unit total'
      : result.completed
          ? 'Goal reached · ${formatQuantity(result.total)} $unit'
          : '+${formatQuantity(added)} $unit logged · ${formatQuantity(result.total)} / ${formatQuantity(result.target)}';
  showActionFeedback(messenger, message: message, confirmedAura: result.gained);
}
