import 'package:flutter/material.dart';

import '../../../../core/widgets/action_feedback.dart';
import '../../domain/challenge.dart';
import '../../domain/progress_entry.dart';
import '../quest_amount.dart';

void showProgressFeedback(
  ScaffoldMessengerState messenger, {
  required ProgressResult result,
  required double added,
  required Challenge challenge,
}) {
  // The quest knows whether its amounts are reps or minutes; a clock
  // quest reads "+45m", never "+45 min".
  final message = result.overshoot
      ? '${challenge.addedLabel(added)} bonus logged · '
          '${challenge.amountWithUnit(result.total)} total'
      : result.completed
          ? 'Goal reached · ${challenge.amountWithUnit(result.total)}'
          : '${challenge.addedLabel(added)} logged · '
              '${challenge.progressLabel(result.total, result.target)}';
  showActionFeedback(messenger, message: message, confirmedAura: result.gained);
}
