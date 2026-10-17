/// English loss lines, matching the rest of the app on every device locale.
/// The match stores its index; reopening cannot reroll it.
/// Tease the play, not a player's identity, appearance or personal worth.
abstract final class GameRoasts {
  static const english = [
    'Big ego. Tiny scissors.',
    'Your strategy came with a snooze button.',
    'Rock-solid confidence. Paper-thin execution.',
    'That plot twist was just you losing.',
    'Three choices. Somehow you found the fourth: regret.',
    'You brought main-character energy to a blooper reel.',
    'Your game plan is buffering.',
    'The scissors cut straight through your victory speech.',
    'Paperwork completed. Ego folded.',
    'You rocked up. You did not rock.',
    'Your confidence wrote a cheque your hand could not cash.',
    'That was less a masterplan, more a first draft.',
    'Your comeback is currently in airplane mode.',
    'Bold move. The scoreboard disagrees.',
    'A moment of silence for that victory pose.',
    'Your inner champion has asked to remain anonymous.',
    'You read the room. Your opponent read your hand.',
    'That bluff needed a little more bluff.',
    'Your ego took the scenic route to second place.',
    'The tutorial called. It has a few questions.',
    'You served confidence. They served the result.',
    'Your strategy had excellent presentation. That was it.',
    'Not your finest hand. Great material for the group chat.',
    'Even your victory playlist hit pause.',
    'You came for glory. You left with character development.',
    'Your opponent understood the assignment. You decorated it.',
    'The highlight reel politely skipped this one.',
    'All that build-up for a very small plot.',
    'Your victory speech is now a podcast nobody ordered.',
    'Your next move might be a deep breath.',
    'You folded faster than the paper.',
    'That rock had more commitment than your plan.',
    'Your scissors were apparently set to airplane mode.',
    'The scoreboard is being brutally honest today.',
    'Your ego requested a software update.',
    'You had the aura of a winner. Briefly.',
    'Your hand picked a side quest.',
    'The good news: your habits still count.',
    'Aura intact. Bragging rights temporarily unavailable.',
    'Take the roast. Keep the streak. Come back louder.',
  ];

  static String line(int key) => english[key % english.length];
}
