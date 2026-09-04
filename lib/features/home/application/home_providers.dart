import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/application/challenge_providers.dart';
import '../domain/home_agenda.dart';

/// Today's agenda: what's still open, what's done, what's at risk.
///
/// Derived from the quest list + check-ins, so it recomputes only when
/// those actually change (a check-in invalidates both).
final homeAgendaProvider = FutureProvider.autoDispose<HomeAgenda>((ref) async {
  final challenges = await ref.watch(myChallengesProvider.future);
  final checkIns = await ref.watch(myCheckInsProvider.future);
  return HomeAgenda.build(
    challenges: challenges,
    checkInsByQuest: checkIns,
    today: DateTime.now().toUtc(),
  );
});
