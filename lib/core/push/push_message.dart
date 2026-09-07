/// One push notification, however it arrived.
///
/// The two delivery routes hand over very different things:
///
///  * **UnifiedPush** carries a content-free wake-up ping.
///  * **Firebase** carries only a category and the row id. The text is
///    fetched from our own server afterwards — Google never sees who
///    attacked whom, in which quest, or with what.
///
/// Both end up here, so everything downstream stops caring which route
/// a message took.
class PushMessage {
  const PushMessage({
    required this.category,
    required this.title,
    required this.body,
    this.refId,
    this.outboxId,
  });

  /// 'attack' | 'duel' | 'social' | 'quest'
  final String category;
  final String title;
  final String body;

  /// The row that caused this — a quest id for most categories, the
  /// duel or friendship id for the rest. Used to open the right screen.
  final String? refId;

  /// Row id in `notification_outbox`; the key for fetching the text.
  final int? outboxId;

  /// What to show when the text could not be fetched.
  ///
  /// The wake-up ping always carries the category, so even offline the
  /// notification can say something truer than "New message". It stays
  /// deliberately vague about people and quests: this text is composed
  /// without ever having seen the real one.
  factory PushMessage.fallback({
    required String category,
    String? refId,
    int? outboxId,
  }) {
    final (title, body) = switch (category) {
      'attack' => ('You are under attack', 'Someone hit you in a quest.'),
      'duel' => ('Duel', 'Something happened in one of your duels.'),
      'social' => ('Aura Quest', 'Someone is trying to reach you.'),
      'quest' => ('Quest update', 'One of your quests moved on.'),
      _ => ('Aura Quest', 'Open the app to see what happened.'),
    };
    return PushMessage(
      category: category,
      title: title,
      body: body,
      refId: refId,
      outboxId: outboxId,
    );
  }

  /// Parses whatever the transport handed over.
  ///
  /// Firebase delivers a `Map<String, String>`; UnifiedPush delivers the
  /// JSON our own delivery function posted. The keys are the same in
  /// both because the server writes them that way, so one parser does.
  static PushMessage? tryParse(Map<String, dynamic> data) {
    final category = data['category'];
    if (category is! String) return null;

    final rawId = data['id'];
    final outboxId = rawId is int ? rawId : int.tryParse('${rawId ?? ''}');
    final refId = data['refId'] is String ? data['refId'] as String : null;

    // Legacy text is parsed for compatibility, but never trusted for display.
    final title = data['title'];
    final body = data['message'] ?? data['body'];
    if (title is! String || body is! String) {
      return PushMessage.fallback(
        category: category,
        refId: refId,
        outboxId: outboxId,
      );
    }
    return PushMessage(
      category: category,
      title: title,
      body: body,
      refId: refId,
      outboxId: outboxId,
    );
  }

  /// True when the text still has to be fetched from our server.
  bool get needsFetch =>
      outboxId != null && body == PushMessage.fallback(category: category).body;

  PushMessage withText({required String title, required String body}) =>
      PushMessage(
        category: category,
        title: title,
        body: body,
        refId: refId,
        outboxId: outboxId,
      );
}
