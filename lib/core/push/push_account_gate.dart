import 'push_message.dart';

/// Notification payloads are wake-up hints, never proof of the recipient.
/// The authenticated server lookup and a second account check authorize display.
Future<PushMessage?> authorizePushMessage({
  required PushMessage message,
  required String? Function() currentUserId,
  required Future<PushMessage?> Function(int id) fetch,
}) async {
  final owner = currentUserId();
  if (owner == null || message.outboxId == null) return null;
  try {
    final verified = await fetch(message.outboxId!);
    return owner == currentUserId() ? verified : null;
  } catch (_) {
    return null;
  }
}
