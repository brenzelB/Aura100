// Pure Dart, no Docker or network. Uses the same prices as the app.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:aura_quest/features/challenges/domain/quest_balance.dart';

void main() {
  final random = Random(20260908);
  const trials = 100000;
  final heists = <Map<String, Object>>[];
  for (final reward in [1, 10, 100, 1000]) {
    for (var tier = 1; tier <= 3; tier++) {
      final price = QuestBalance.price(reward, 'Aura Heist', tier: tier);
      final chance = tier * .25;
      var net = 0;
      for (var i = 0; i < trials; i++) {
        net += (random.nextDouble() < chance ? reward : 0) - price;
      }
      heists.add({
        'reward': reward,
        'tier': tier,
        'price': price,
        'expectedNet': chance * reward - price,
        'simulatedNet': net / trials
      });
    }
  }
  final runs = <Map<String, Object>>[];
  for (final preset in QuestPreset.values) {
    for (final consistency in [.8, .9, .95]) {
      var finished = 0;
      for (var i = 0; i < trials; i++) {
        var misses = 0;
        for (var day = 0; day < 30; day++) {
          if (random.nextDouble() >= consistency) misses++;
        }
        if (misses <= preset.misses) finished++;
      }
      runs.add({
        'preset': preset.name,
        'unitSuccessProbability': consistency,
        'completion30Days': finished / trials
      });
    }
  }
  final result = {
    'seed': 20260908,
    'trialsPerScenario': trials,
    'assumptions':
        'Independent daily outcomes; no gear, defense, expiry, rest days, or bonus rewards. Heist results are before defense/expiry. Not a player-retention forecast.',
    'oldClassicHeistExpectedNet': .25 * 100 - 150,
    'heists': heists,
    'runs': runs
  };
  Directory('build/balance').createSync(recursive: true);
  final json = const JsonEncoder.withIndent('  ').convert(result);
  File('build/balance/simulation.json').writeAsStringSync(json);
  stdout.writeln(json);
}
