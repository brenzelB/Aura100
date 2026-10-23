import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/application/challenge_providers.dart';
import '../../friends/application/friends_providers.dart';
import '../../friends/domain/social_models.dart';

/// One definition of actionable activity for Home and the navigation badge.
/// Historical settlement events are deliberately not counted as new requests.
class ActivitySummary {
  const ActivitySummary({required this.count, required this.invitations});
  final int count;
  final int invitations;

  String get label => invitations > 0
      ? '$invitations quest invitation${invitations == 1 ? '' : 's'} waiting'
      : '$count update${count == 1 ? '' : 's'} to review';
}

final activitySummaryProvider = Provider<ActivitySummary>((ref) {
  final invites = ref.watch(myInvitesProvider).valueOrNull?.length ?? 0;
  return ActivitySummary(
    invitations: invites,
    count: invites +
        (ref.watch(friendRequestsProvider).valueOrNull?.length ?? 0) +
        (ref.watch(incomingDuelsProvider).valueOrNull?.length ?? 0) +
        PokeGroup.group(ref.watch(unseenNudgesProvider).valueOrNull ?? [])
            .length +
        (ref.watch(targetedRoastsProvider).valueOrNull?.length ?? 0) +
        (ref.watch(robbedNoticesProvider).valueOrNull?.length ?? 0) +
        (ref.watch(unseenBlackoutsProvider).valueOrNull?.length ?? 0) +
        (ref.watch(pokeBacksProvider).valueOrNull?.length ?? 0),
  );
});
