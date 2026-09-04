import 'dart:math';

/// The app's hype engine: the celebratory counterpart to [Roasts].
/// Shown on the milestone/completion screen — same cheeky voice, but
/// pointed UP instead of down. Winning should feel loud.
abstract class Hype {
  static final _random = Random();

  static String forStreak() => _streak[_random.nextInt(_streak.length)];

  static String forCompletion() =>
      _completion[_random.nextInt(_completion.length)];

  // ── Streak milestones (7 / 30 / 100 days) ───────────────────
  static const List<String> _streak = [
    'Okay, show-off.',
    'The couch is filing a missing person report.',
    'Consistency has entered the chat.',
    'Your future self just high-fived you.',
    'Discipline: unlocked. Excuses: uninstalled.',
    'The streak gods are watching. They approve.',
    'Nobody can stop you. Some tried. They failed.',
    'This is what momentum looks like.',
    'You woke up and chose greatness. Again.',
    'Certified menace to bad habits.',
    'Your willpower called. It is flexing.',
    'That is a lot of days in a row. Show it off.',
    'Main character energy, no notes.',
    'The grind respects you now.',
    'Legends do it daily. So do you, apparently.',
    'Somewhere, a motivational poster is jealous.',
    'You are built different. Provably.',
    'The bar was high. You cleared it. Repeatedly.',
    'Keep this up and we run out of compliments.',
    'Unbothered. Consistent. Glowing.',
  ];

  // ── Quest completion ─────────────────────────────────────────
  static const List<String> _completion = [
    'Quest cleared. Take a bow.',
    'You started. You suffered. You WON.',
    'Final boss defeated: your own excuses.',
    'That is how it is done. Framed and hung.',
    'Completion unlocked. Flex accordingly.',
    'You saw it through. Most people do not.',
    'Victory lap authorized. Go slow, savor it.',
    'The aura is yours. Every last spark.',
    'From day one to done. Respect.',
    'Achievement: actually finished something.',
    'You outlasted the quest. Champion behavior.',
    'Roll credits. You are the hero.',
    'Banked, sealed, legendary.',
    'The comeback story wrote itself. You held the pen.',
    'Done and dusted. The couch never stood a chance.',
    'This one goes in the trophy room.',
  ];
}
