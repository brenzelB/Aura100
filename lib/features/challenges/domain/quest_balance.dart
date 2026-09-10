/// Trial balance rules. Integer prices round up, with a one-Aura minimum.
enum QuestPreset {
  chill('Chill', 100, 10, 5, false,
      'Room to learn. Five misses allowed. No attacks.'),
  classic('Classic', 100, 25, 3, true,
      'Steady progress. Three misses allowed. Limited attacks.'),
  chaos('Chaos', 100, 50, 1, true,
      'Higher stakes. One miss allowed. Limited attacks.');

  const QuestPreset(this.label, this.reward, this.penalty, this.misses,
      this.attacks, this.description);
  final String label;
  final int reward, penalty, misses;
  final bool attacks;
  final String description;
}

abstract final class QuestBalance {
  static int price(int reward, String item, {int tier = 1}) {
    final percent = switch (item) {
      'Title Badge' => 200,
      'Double Down' => 80,
      'Streak Shield' => 100,
      'Strike Repair' => 200,
      'Aura Lord' => 1000,
      'Aura Ward' => 25,
      'Aura Heist' => switch (tier) {
          1 => 20,
          2 => 40,
          3 => 60,
          _ => throw ArgumentError('Invalid heist tier')
        },
      'Targeted Roast' => tier == 1 ? 50 : 75,
      'Blackout' => 150,
      _ => throw ArgumentError('Unknown shop item: $item'),
    };
    final rounded = (reward * percent / 100).ceil();
    return rounded < 1 ? 1 : rounded;
  }

  static const xpPerUnit = 100;
  static const dailyXpLimit = 500;
  static const xpPerLevel = 500;
  static const outgoingAttacksPerDay = 3;
}
