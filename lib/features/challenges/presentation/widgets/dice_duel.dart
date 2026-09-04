import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException, Supabase;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/text/roasts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/duel.dart';
import '../../domain/quest_member.dart';

// ═════════════════════════════════════════════════════════════════
// DiceFace — a die drawn with real pips (no emoji), neon-framed.
// ═════════════════════════════════════════════════════════════════
class DiceFace extends StatelessWidget {
  const DiceFace({
    super.key,
    required this.value,
    required this.color,
    this.size = 56,
  });

  final int value;
  final Color color;
  final double size;

  static const _pips = <int, List<Alignment>>{
    1: [Alignment.center],
    2: [Alignment(-0.6, -0.6), Alignment(0.6, 0.6)],
    3: [Alignment(-0.6, -0.6), Alignment.center, Alignment(0.6, 0.6)],
    4: [
      Alignment(-0.6, -0.6), Alignment(0.6, -0.6),
      Alignment(-0.6, 0.6), Alignment(0.6, 0.6),
    ],
    5: [
      Alignment(-0.6, -0.6), Alignment(0.6, -0.6), Alignment.center,
      Alignment(-0.6, 0.6), Alignment(0.6, 0.6),
    ],
    6: [
      Alignment(-0.6, -0.6), Alignment(0.6, -0.6),
      Alignment(-0.6, 0.0), Alignment(0.6, 0.0),
      Alignment(-0.6, 0.6), Alignment(0.6, 0.6),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final pipSize = size * 0.16;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight,
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          for (final alignment in _pips[value.clamp(1, 6)]!)
            Align(
              alignment: alignment,
              child: Padding(
                padding: EdgeInsets.all(size * 0.1),
                child: Container(
                  width: pipSize,
                  height: pipSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A die that tumbles (random faces + jitter) until it lands on its
/// final value with a little pop.
class _RollingDie extends StatelessWidget {
  const _RollingDie({
    required this.landed,
    required this.shownValue,
    required this.finalValue,
    required this.color,
    required this.jitter,
  });

  final bool landed;
  final int shownValue;
  final int finalValue;
  final Color color;
  final double jitter; // small rotation while tumbling

  @override
  Widget build(BuildContext context) {
    if (!landed) {
      return Transform.rotate(
        angle: jitter,
        child: DiceFace(value: shownValue, color: color),
      );
    }
    // Landing pop: scale 1.35 → 1.0 with an ease-out-back feel.
    return TweenAnimationBuilder<double>(
      key: ValueKey('landed-$finalValue'),
      tween: Tween(begin: 1.35, end: 1.0),
      duration: const Duration(milliseconds: 320),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: DiceFace(value: finalValue, color: color),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// StakeDialog — pick the wager for a new duel.
// ═════════════════════════════════════════════════════════════════
class StakeDialog extends StatefulWidget {
  const StakeDialog({
    super.key,
    required this.opponent,
    required this.myAura,
  });

  final QuestMember opponent;

  /// The challenger's own quest aura — the 25% cap is derived from it.
  final int myAura;

  static Future<int?> show(
    BuildContext context, {
    required QuestMember opponent,
    required int myAura,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => StakeDialog(opponent: opponent, myAura: myAura),
    );
  }

  @override
  State<StakeDialog> createState() => _StakeDialogState();
}

class _StakeDialogState extends State<StakeDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _presets = [10, 25, 50, 100];

  /// Your cap: a quarter of your own aura (server rule).
  int get _myCap => widget.myAura ~/ 4;

  /// Their aura — they must cover the FULL stake to accept.
  int get _oppAura => widget.opponent.questAura;

  /// The most you can meaningfully bet: your cap, but never more than
  /// they can match.
  int get _effectiveMax => _myCap < _oppAura ? _myCap : _oppAura;

  bool get _canDuel => _effectiveMax >= 10;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The currently entered, valid stake — or null.
  int? get _stake {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 10 || value > _effectiveMax) return null;
    return value;
  }

  void _validate(String raw) {
    final value = int.tryParse(raw.trim());
    setState(() {
      if (raw.trim().isEmpty) {
        _error = null;
      } else if (value == null || value <= 0) {
        _error = 'Enter a number';
      } else if (value < 10) {
        _error = 'Minimum stake is 10 ⚡';
      } else if (value > _myCap) {
        _error = 'Your max is $_myCap ⚡ (25% of your aura)';
      } else if (value > _oppAura) {
        _error = '@${widget.opponent.username} only has $_oppAura ⚡ to match';
      } else {
        _error = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final stake = _stake;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            AppColors.activeType == AppThemeType.auralis ? 24 : 20),
        side: BorderSide(
          color: AppColors.activeType == AppThemeType.auralis
              ? AppColors.outline
              : AppColors.neonPink.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      title: Row(
        children: [
          const Text('🎲', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DUEL @${widget.opponent.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  textTheme.headlineSmall?.copyWith(color: AppColors.neonPink),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Both stake the same — the higher roll takes the pot.',
            style:
                textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          // Both balances, so you know how high you can go.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: AppColors.panelDecoration(
              accent: Colors.transparent,
              fill: AppColors.surfaceLight,
              radius: 12,
            ),
            child: Column(
              children: [
                _BalanceRow(
                  label: 'You',
                  aura: widget.myAura,
                  note: 'max ⚡$_myCap (25%)',
                ),
                const SizedBox(height: 8),
                _BalanceRow(
                  label: '@${widget.opponent.username}',
                  aura: _oppAura,
                  note: 'must match your stake',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!_canDuel)
            Text(
              _myCap < 10
                  ? 'You need at least 40 quest aura to duel.'
                  : '@${widget.opponent.username} needs at least 10 ⚡ to duel.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
            )
          else ...[
            // Free-form stake entry.
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: textTheme.headlineSmall
                  ?.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Your stake',
                hintText: '10 – $_effectiveMax',
                prefixText: '⚡ ',
                errorText: _error,
              ),
              onChanged: _validate,
              onSubmitted: (_) {
                if (_stake != null) Navigator.of(context).pop(_stake);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in _presets)
                  if (preset <= _effectiveMax)
                    _StakeChip(
                      label: '⚡$preset',
                      selected: stake == preset,
                      onTap: () {
                        _controller.text = '$preset';
                        _validate(_controller.text);
                      },
                    ),
                // Always offer the ceiling.
                _StakeChip(
                  label: 'Max ⚡$_effectiveMax',
                  selected: stake == _effectiveMax,
                  onTap: () {
                    _controller.text = '$_effectiveMax';
                    _validate(_controller.text);
                  },
                ),
              ],
            ),
            if (stake != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Winner takes ${stake * 2} ⚡',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton.icon(
          onPressed:
              stake == null ? null : () => Navigator.of(context).pop(stake),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonPink,
            foregroundColor: AppColors.background,
          ),
          icon: const Icon(Icons.casino, size: 18),
          label: const Text('CHALLENGE'),
        ),
      ],
    );
  }
}

/// One "name — ⚡aura — note" row in the stake dialog's balance panel.
class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.label,
    required this.aura,
    required this.note,
  });

  final String label;
  final int aura;
  final String note;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '⚡$aura',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.warningText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          note,
          style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StakeChip extends StatelessWidget {
  const _StakeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: AppColors.panelDecoration(
          accent: selected ? AppColors.neonPink : Colors.transparent,
          fill: selected
              ? AppColors.neonPink.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          radius: 8.0,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.neonPink : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// DuelSheet — offer → roll animation → result. Full-width sheet.
// ═════════════════════════════════════════════════════════════════
enum _DuelPhase { offer, rolling, result }

class DuelSheet extends ConsumerStatefulWidget {
  const DuelSheet({super.key, required this.duel});

  final IncomingDuel duel;

  static Future<void> show(BuildContext context, IncomingDuel duel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DuelSheet(duel: duel),
    );
  }

  @override
  ConsumerState<DuelSheet> createState() => _DuelSheetState();
}

class _DuelSheetState extends ConsumerState<DuelSheet> {
  final _random = Random();

  // Picked once per sheet so the burn doesn't reshuffle on rebuilds.
  final String _roast = Roasts.random();

  _DuelPhase _phase = _DuelPhase.offer;
  DuelResult? _result;

  // Tumbling state: shown faces + jitter, per die (0,1 = theirs; 2,3 = mine).
  final List<int> _shown = [1, 3, 5, 2];
  final List<double> _jitter = [0, 0, 0, 0];
  final List<bool> _landed = [false, false, false, false];
  bool _showBanner = false;
  Timer? _shuffleTimer;

  bool get _iWon {
    final myId = ref.read(currentUserProvider)?.id;
    return _result?.winnerId == myId;
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }

  Future<void> _decline() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok =
        await ref.read(duelControllerProvider.notifier).decline(widget.duel.id);
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Duel declined - @${widget.duel.challengerName} got their '
              '${widget.duel.stake} aura back.'
          : _errorText()),
      backgroundColor: ok ? AppColors.surfaceLight : AppColors.danger,
    ));
  }

  String _errorText() {
    final error = ref.read(duelControllerProvider).error;
    return error is PostgrestException
        ? error.message
        : 'Something went wrong - try again.';
  }

  Future<void> _acceptAndRoll() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(duelControllerProvider.notifier)
        .acceptAndRoll(widget.duel.id);
    if (!mounted) return;

    if (result == null) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(_errorText()),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    // The outcome is decided — now the show begins.
    setState(() {
      _result = result;
      _phase = _DuelPhase.rolling;
    });

    // Tumble: shuffle random faces + jitter every 90ms.
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 4; i++) {
          if (!_landed[i]) {
            _shown[i] = _random.nextInt(6) + 1;
            _jitter[i] = (_random.nextDouble() - 0.5) * 0.35;
          }
        }
      });
    });

    // Staggered landings: their dice first, mine last (drama!).
    for (final (index, delayMs) in const [(0, 1100), (1, 1450), (2, 1900), (3, 2350)]) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        setState(() => _landed[index] = true);
        HapticFeedback.mediumImpact();
        if (index == 3) {
          _shuffleTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 450), () {
            if (!mounted) return;
            setState(() {
              _phase = _DuelPhase.result;
              _showBanner = true;
            });
            HapticFeedback.heavyImpact();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final duel = widget.duel;
    final busy = ref.watch(duelControllerProvider).isLoading;

    // Dice values: server result once rolling, placeholders before.
    final theirDice = _result?.challengerDice ?? const [1, 1];
    final myDice = _result?.opponentDice ?? const [1, 1];

    return PopScope(
      // No slipping away mid-roll — the result deserves its moment.
      canPop: _phase != _DuelPhase.rolling,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DICE DUEL',
              style: textTheme.headlineMedium
                  ?.copyWith(color: AppColors.neonPink),
            ),
            const SizedBox(height: 6),
            Text(
              '${duel.questTitle} · ${duel.pot} ⚡ in the pot',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // ── Opponent row ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuraAvatar(
                  emoji: duel.challengerAvatar,
                  username: duel.challengerName,
                  size: 36,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Text(
                  '@${duel.challengerName}',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (_phase != _DuelPhase.offer) ...[
                  const Spacer(),
                  _DiceSum(
                    dice: theirDice,
                    landed: _landed[0] && _landed[1],
                    color: AppColors.danger,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_phase == _DuelPhase.offer)
              // The offer: two mystery dice.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 2; i++) ...[
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: AppColors.panelDecoration(
                        accent: AppColors.textSecondary,
                        fill: AppColors.surfaceLight,
                        radius: 8.0,
                      ),
                      child: Text('?',
                          style: textTheme.headlineSmall
                              ?.copyWith(color: AppColors.textSecondary)),
                    ),
                    if (i == 0) const SizedBox(width: 14),
                  ],
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RollingDie(
                    landed: _landed[0],
                    shownValue: _shown[0],
                    finalValue: theirDice[0],
                    color: AppColors.danger,
                    jitter: _jitter[0],
                  ),
                  const SizedBox(width: 14),
                  _RollingDie(
                    landed: _landed[1],
                    shownValue: _shown[1],
                    finalValue: theirDice[1],
                    color: AppColors.danger,
                    jitter: _jitter[1],
                  ),
                ],
              ),

            const SizedBox(height: 18),
            Text(
              'VS',
              style:
                  textTheme.headlineSmall?.copyWith(color: AppColors.warningText),
            ),
            const SizedBox(height: 18),

            // ── My row ───────────────────────────────────────
            if (_phase == _DuelPhase.offer)
              Text(
                'Your stake: ${duel.stake} ⚡',
                style: textTheme.bodyLarge?.copyWith(
                  color: AppColors.accentText,
                  fontWeight: FontWeight.w700,
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RollingDie(
                    landed: _landed[2],
                    shownValue: _shown[2],
                    finalValue: myDice[0],
                    color: AppColors.neonCyan,
                    jitter: _jitter[2],
                  ),
                  const SizedBox(width: 14),
                  _RollingDie(
                    landed: _landed[3],
                    shownValue: _shown[3],
                    finalValue: myDice[1],
                    color: AppColors.neonCyan,
                    jitter: _jitter[3],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('YOU',
                      style: textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  _DiceSum(
                    dice: myDice,
                    landed: _landed[2] && _landed[3],
                    color: AppColors.neonCyan,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // ── Actions / result banner ──────────────────────
            if (_phase == _DuelPhase.offer)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy ? null : _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side:
                             BorderSide(color: AppColors.surfaceLight),
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('DECLINE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : _acceptAndRoll,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.neonGreen,
                        foregroundColor: AppColors.background,
                        minimumSize: const Size(0, 48),
                      ),
                      icon: busy
                          ?  SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.background),
                            )
                          : const Icon(Icons.casino),
                      label: const Text('ROLL THE DICE'),
                    ),
                  ),
                ],
              )
            else if (_phase == _DuelPhase.rolling)
              Text(
                'Rolling…',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              )
            else ...[
              // Result banner: pop in with glow.
              AnimatedScale(
                scale: _showBanner ? 1.0 : 0.6,
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _showBanner ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: AppColors.panelDecoration(
                      accent: _iWon ? AppColors.neonGreen : AppColors.danger,
                      fill: (_iWon ? AppColors.neonGreen : AppColors.danger).withValues(alpha: 0.12),
                      isDanger: !_iWon,
                      glow: true,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _iWon
                              ? 'YOU WIN +${(_result?.pot ?? 0) - duel.stake} ⚡'
                              : 'YOU LOSE -${duel.stake} ⚡',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color:
                                _iWon ? AppColors.successText : AppColors.danger,
                          ),
                        ),
                        if (!_iWon) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _roast,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sum badge that appears once both dice of a pair landed.
class _DiceSum extends StatelessWidget {
  const _DiceSum({
    required this.dice,
    required this.landed,
    required this.color,
  });

  final List<int> dice;
  final bool landed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: landed ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: AppColors.panelDecoration(
          accent: color,
          fill: color.withValues(alpha: 0.15),
          radius: 8.0,
        ),
        child: Text(
          '${dice[0] + dice[1]}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// DuelReplaySheet — watch a RESOLVED duel unfold: same tumble, same
// staggered landings, same banner. No RPC; the outcome is history.
// ═════════════════════════════════════════════════════════════════
class DuelReplaySheet extends StatefulWidget {
  const DuelReplaySheet({
    super.key,
    required this.duel,
    required this.questTitle,
    required this.myUserId,
  });

  final QuestDuel duel;
  final String questTitle;
  final String myUserId;

  static Future<void> show(
    BuildContext context, {
    required QuestDuel duel,
    required String questTitle,
    String? myUserId,
  }) {
    final uid = myUserId ??
        (SupabaseConfig.isConfigured
            ? Supabase.instance.client.auth.currentUser?.id
            : null);
    if (uid == null || duel.status != 'resolved') return Future.value();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DuelReplaySheet(
        duel: duel,
        questTitle: questTitle,
        myUserId: uid,
      ),
    );
  }

  @override
  State<DuelReplaySheet> createState() => _DuelReplaySheetState();
}

class _DuelReplaySheetState extends State<DuelReplaySheet> {
  final _random = Random();

  // Picked once per sheet so the burn doesn't reshuffle on rebuilds.
  final String _roast = Roasts.random();

  final List<int> _shown = [1, 3, 5, 2];
  final List<double> _jitter = [0, 0, 0, 0];
  final List<bool> _landed = [false, false, false, false];
  bool _showBanner = false;
  Timer? _shuffleTimer;

  List<int> get _theirDice =>
      widget.duel.theirDice(widget.myUserId) ?? const [1, 1];
  List<int> get _myDice =>
      widget.duel.myDice(widget.myUserId) ?? const [1, 1];
  bool get _iWon => widget.duel.wonBy(widget.myUserId);

  @override
  void initState() {
    super.initState();
    // Curtain up shortly after the sheet slides in.
    Future.delayed(const Duration(milliseconds: 350), _startReplay);
  }

  void _startReplay() {
    if (!mounted) return;
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 4; i++) {
          if (!_landed[i]) {
            _shown[i] = _random.nextInt(6) + 1;
            _jitter[i] = (_random.nextDouble() - 0.5) * 0.35;
          }
        }
      });
    });

    for (final (index, delayMs)
        in const [(0, 1100), (1, 1450), (2, 1900), (3, 2350)]) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        setState(() => _landed[index] = true);
        HapticFeedback.mediumImpact();
        if (index == 3) {
          _shuffleTimer?.cancel();
          Future.delayed(const Duration(milliseconds: 450), () {
            if (!mounted) return;
            setState(() => _showBanner = true);
            HapticFeedback.heavyImpact();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final duel = widget.duel;
    final theirName = duel.otherName(widget.myUserId);
    final net = _iWon ? duel.stake : -duel.stake;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'DUEL REPLAY',
            style: textTheme.headlineMedium
                ?.copyWith(color: AppColors.neonPurple),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.questTitle} · ${duel.stake * 2} ⚡ was in the pot',
            style: textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AuraAvatar(
                emoji: duel.otherAvatar(widget.myUserId),
                username: theirName,
                size: 36,
                color: AppColors.danger,
              ),
              const SizedBox(width: 10),
              Text(
                '@$theirName',
                style: textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              _DiceSum(
                dice: _theirDice,
                landed: _landed[0] && _landed[1],
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RollingDie(
                landed: _landed[0],
                shownValue: _shown[0],
                finalValue: _theirDice[0],
                color: AppColors.danger,
                jitter: _jitter[0],
              ),
              const SizedBox(width: 14),
              _RollingDie(
                landed: _landed[1],
                shownValue: _shown[1],
                finalValue: _theirDice[1],
                color: AppColors.danger,
                jitter: _jitter[1],
              ),
            ],
          ),

          const SizedBox(height: 18),
          Text(
            'VS',
            style: textTheme.headlineSmall
                ?.copyWith(color: AppColors.warningText),
          ),
          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RollingDie(
                landed: _landed[2],
                shownValue: _shown[2],
                finalValue: _myDice[0],
                color: AppColors.neonCyan,
                jitter: _jitter[2],
              ),
              const SizedBox(width: 14),
              _RollingDie(
                landed: _landed[3],
                shownValue: _shown[3],
                finalValue: _myDice[1],
                color: AppColors.neonCyan,
                jitter: _jitter[3],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('YOU',
                  style: textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              _DiceSum(
                dice: _myDice,
                landed: _landed[2] && _landed[3],
                color: AppColors.neonCyan,
              ),
            ],
          ),

          const SizedBox(height: 24),
          AnimatedScale(
            scale: _showBanner ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 350),
            curve: Curves.elasticOut,
            child: AnimatedOpacity(
              opacity: _showBanner ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: (_iWon ? AppColors.neonGreen : AppColors.danger)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _iWon ? AppColors.neonGreen : AppColors.danger),
                  boxShadow: AppColors.neonGlow(
                      _iWon ? AppColors.neonGreen : AppColors.danger),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _iWon ? 'YOU WON +$net ⚡' : 'YOU LOST $net ⚡',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        color: _iWon ? AppColors.successText : AppColors.danger,
                      ),
                    ),
                    if (!_iWon) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _roast,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry point from the party list: pick a stake, send the challenge.
Future<void> startDuelFlow(
  BuildContext context,
  WidgetRef ref, {
  required Challenge challenge,
  required QuestMember opponent,
}) async {
  final stake = await StakeDialog.show(
    context,
    opponent: opponent,
    myAura: challenge.myAura,
  );
  if (stake == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final ok = await ref.read(duelControllerProvider.notifier).create(
        challengeId: challenge.id,
        opponentId: opponent.userId,
        stake: stake,
      );
  if (!context.mounted) return;

  if (ok) {
    messenger.showSnackBar(SnackBar(
      content: Text('🎲 Duel sent - $stake ⚡ escrowed until '
          '@${opponent.username} answers.'),
      backgroundColor: AppColors.neonPink,
    ));
  } else {
    final error = ref.read(duelControllerProvider).error;
    messenger.showSnackBar(SnackBar(
      content: Text(error is PostgrestException
          ? error.message
          : 'Could not send the duel - try again.'),
      backgroundColor: AppColors.danger,
    ));
  }
}
