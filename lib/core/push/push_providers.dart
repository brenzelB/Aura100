import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import '../config/supabase_config.dart';
import '../router/app_router.dart';
import 'push_message.dart';
import 'push_service.dart';

/// Keeps push registration in step with who is signed in, and turns a
/// tapped notification into a screen.
///
/// Watched once at the root, like the realtime channel: registration has
/// to survive every screen, and re-registering per screen would hammer
/// the server on every navigation.
final pushGatewayProvider = Provider<void>((ref) {
  if (!SupabaseConfig.isConfigured) return;

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    PushService.instance.clearAccountContext();
    return;
  }

  final service = PushService.instance;
  var active = true;
  ref.onDispose(() {
    active = false;
    service.onOpened = null;
  });
  service.onOpened = (message) {
    if (active) _open(ref, message);
  };
  // start() is idempotent; on later sign-ins only the re-registration
  // below actually does anything.
  service.start().then((_) {
    if (active) return service.refreshRegistration();
  });
});

/// Sends the player where the notification came from.
///
/// A notification that only opens the app makes the player hunt for what
/// it was about — which defeats the point of telling them at all.
void _open(Ref ref, PushMessage message) {
  final router = ref.read(appRouterProvider);
  final refId = message.refId;

  switch (message.category) {
    // For attacks and quest results refId is the quest itself.
    case 'attack':
    case 'quest':
      if (refId != null) {
        router.push('${AppRoutes.challenges}/$refId');
      } else {
        router.go(AppRoutes.challenges);
      }
    // Duels are answered from Home, where the inbox row sits.
    case 'duel':
      router.go(AppRoutes.home);
    // Invites, friend requests and pokes all live under Friends.
    case 'social':
      router.go(AppRoutes.friends);
    default:
      router.go(AppRoutes.home);
  }
}
