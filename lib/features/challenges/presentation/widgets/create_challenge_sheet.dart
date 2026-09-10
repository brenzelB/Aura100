import 'package:aura_quest/core/widgets/app_states.dart';
import '../../domain/quest_balance.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/config/supabase_config.dart';
import '../../../../core/text/quantity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/aura_avatar.dart';
import '../../../friends/application/friends_providers.dart';
import '../../../friends/domain/social_models.dart';
import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../../../core/text/dates.dart';

/// Bottom-sheet form for forging a new challenge: title, flexible
/// schedule (custom duration + start date), stakes and strikes.
class CreateChallengeSheet extends ConsumerStatefulWidget {
  const CreateChallengeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true, // let the sheet rise above the keyboard
      backgroundColor: AppColors.surface,
      shape: AppShapes.sheet,
      builder: (_) => const CreateChallengeSheet(),
    );
  }

  @override
  ConsumerState<CreateChallengeSheet> createState() =>
      _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends ConsumerState<CreateChallengeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _auraGainController = TextEditingController(text: '100');
  final _auraPenaltyController = TextEditingController(text: '25');
  static DateTime _initialStartDate() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  int _maxStrikes = 3;
  QuestPreset _preset = QuestPreset.classic;
  bool _customBalance = false;
  bool _attacksEnabled = true;

  void _selectPreset(QuestPreset preset) => setState(() {
        _preset = preset;
        _customBalance = false;
        _auraGainController.text = '${preset.reward}';
        _auraPenaltyController.text = '${preset.penalty}';
        _maxStrikes = preset.misses;
        _attacksEnabled = preset.attacks;
      });
  late DateTime _startsOn = _initialStartDate();
  late DateTime _endsOn = _initialStartDate().add(const Duration(days: 6));
  CheckinPeriod _period = CheckinPeriod.daily;
  int _perPeriod = 3;
  QuestMode _mode = QuestMode.solo;
  GoalType _goalType = GoalType.check;
  bool _isEndless = false;
  final _invitees = <String>{};
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();

  /// Slips permitted per period on an avoid quest (0 = cold turkey).
  int _allowance = 0;

  /// ISO weekdays the quest runs on (1 = Monday … 7 = Sunday).
  ///
  /// All seven by default, so leaving this alone gives exactly the
  /// behaviour the app had before rest days existed.
  final Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};

  bool get _isProgress => _goalType == GoalType.progress;

  /// Negative quest: the win is not doing the thing.
  bool get _isAvoid => _goalType == GoalType.avoid;
  bool get _isLms => _mode == QuestMode.lastManStanding;

  /// LMS is always endless; the checkbox is otherwise the user's call.
  bool get _endless => _isEndless || _isLms;

  /// Common units offered as one-tap chips — the field stays free text,
  /// so anything else works too.
  static const _unitSuggestions = [
    'Reps',
    'Minutes',
    'Hours',
    'Kilometers',
    'Meters',
    'Liters',
    'Milliliters',
    'Pages',
    'Steps',
  ];

  // The names players read. The stored values are still 'solo' and
  // 'versus' — renaming those would be a data migration for nothing.
  static const _modeInfo = {
    QuestMode.solo: (
      'FREE FOR ALL',
      Icons.groups_2,
      'No teams. Everyone is scored on their own — run it alone, or '
          'invite friends and race them up the aura board.',
    ),
    QuestMode.coop: (
      'CO-OP',
      Icons.handshake,
      'One for all: if anyone misses, the WHOLE party pays the '
          'penalty and takes the strike. One Streak Shield protects '
          'everyone. If one falls, all fall.',
    ),
    QuestMode.versus: (
      'TEAM BATTLE',
      Icons.sports_kabaddi,
      'Two teams, red and blue: joiners fill the smaller side. At the '
          'end the team with the most check-ins per member wins - losers '
          'pay 25% of their aura to the winners.',
    ),
    QuestMode.lastManStanding: (
      'LAST STANDING',
      Icons.military_tech,
      'Elimination: bust your strikes and you are OUT. You invite '
          'players, then hit START; the last one still in wins a bonus '
          'for every rival outlasted. Endless by nature.',
    ),
  };

  /// Both dates are inclusive: start == end is a 1-day quest.
  int get _durationDays => _endsOn.difference(_startsOn).inDays + 1;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _auraGainController.dispose();
    _auraPenaltyController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  String? _validateAura(String? value) {
    final n = int.tryParse(value ?? '');
    if (n == null || n < 0) return 'Enter a number ≥ 0';
    if (n > 10000) return 'Keep it under 10 000';
    return null;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startsOn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _startsOn = DateTime.utc(picked.year, picked.month, picked.day);
      // Keep the end date valid: never before start, max 365 days.
      if (_endsOn.isBefore(_startsOn)) _endsOn = _startsOn;
      final maxEnd = _startsOn.add(const Duration(days: 364));
      if (_endsOn.isAfter(maxEnd)) _endsOn = maxEnd;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsOn.isBefore(_startsOn) ? _startsOn : _endsOn,
      // The pickers enforce the 1-365 day window — no validator needed.
      firstDate: _startsOn,
      lastDate: _startsOn.add(const Duration(days: 364)),
    );
    if (picked != null) {
      setState(
          () => _endsOn = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  String _dateLabel(DateTime d, {required bool todayAllowed}) {
    final now = DateTime.now().toUtc();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (isToday && todayAllowed) return 'Today';
    return formatDate(d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);

    if (!SupabaseConfig.isConfigured) {
      messenger.showSnackBar(AppSnackBar(
        content: Text('Supabase not configured — skeleton mode.'),
        backgroundColor: AppColors.surfaceLight,
      ));
      return;
    }

    final success =
        await ref.read(createChallengeControllerProvider.notifier).create(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              durationDays: _durationDays,
              balancePreset: _customBalance ? 'custom' : _preset.name,
              attacksEnabled: _attacksEnabled,
              auraGain: int.parse(_auraGainController.text),
              auraPenalty: int.parse(_auraPenaltyController.text),
              maxStrikes: _maxStrikes,
              startsOn: _startsOn,
              checkinPeriod: _period,
              // Progress and avoid quests resolve once per period.
              checkinsPerPeriod:
                  (_isProgress || _isAvoid || _period == CheckinPeriod.daily)
                      ? 1
                      : _perPeriod,
              mode: _mode,
              goalType: _goalType,
              targetValue:
                  _isProgress ? parseQuantity(_targetController.text) : null,
              unit: _isProgress ? _unitController.text.trim() : null,
              isEndless: _endless,
              dailyAllowance: _isAvoid ? _allowance : 0,
              activeWeekdays: _weekdays.toList()..sort(),
              invitees: _invitees.toList(),
            );

    if (!mounted || !success) return;

    Navigator.of(context).pop();
    final invited = _invitees.length;
    messenger.showSnackBar(AppSnackBar(
      content: Text(_isLms
          ? '🏆 Lobby "${_titleController.text.trim()}" created'
              '${invited == 0 ? '' : ' · $invited invited'} — open it and '
              'hit START when everyone is in.'
          : '⚡ Quest "${_titleController.text.trim()}" created!'
              '${invited == 0 ? '' : ' · $invited invited'}'),
      backgroundColor: AppColors.neonGreen,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final createState = ref.watch(createChallengeControllerProvider);
    final isLoading = createState.isLoading;

    ref.listen(createChallengeControllerProvider, (_, next) {
      final error = next.error;
      if (error == null) return;
      final message = error is PostgrestException
          ? error.message
          : 'Could not create the challenge.';
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(content: Text(message), backgroundColor: AppColors.danger),
      );
    });

    final media = MediaQuery.of(context);
    return ConstrainedBox(
      // Cap the height so a barrier stays above the sheet (tap to
      // dismiss) and the grab handle below is always a drag-to-close
      // zone — even when every optional field is showing.
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 12,
                bottom: 24 + media.viewInsets.bottom,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'NEW QUEST',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium
                          ?.copyWith(color: AppColors.warningText),
                    ),
                    const SizedBox(height: 24),

                    // ── Title ────────────────────────────────────────
                    TextFormField(
                      controller: _titleController,
                      maxLength: 80,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Quest name',
                        hintText: 'e.g. Gym every day',
                        counterText: '',
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Give your quest a name'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Description (optional) ───────────────────────
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 500,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'What are the rules?',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Goal type: tick it off, collect a target, or avoid ──
                    Row(
                      children: [
                        Expanded(
                          child: _GoalTypeCard(
                            label: 'CHECK OFF',
                            detail: 'Done once per period',
                            icon: Icons.check_circle_outline,
                            selected: _goalType == GoalType.check,
                            onTap: isLoading
                                ? null
                                : () =>
                                    setState(() => _goalType = GoalType.check),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GoalTypeCard(
                            label: 'PROGRESS',
                            detail: 'Collect up to a target',
                            icon: Icons.trending_up,
                            selected: _isProgress,
                            onTap: isLoading
                                ? null
                                : () => setState(
                                    () => _goalType = GoalType.progress),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GoalTypeCard(
                            label: 'AVOID',
                            detail: 'Win by not doing it',
                            icon: Icons.block,
                            selected: _isAvoid,
                            onTap: isLoading
                                ? null
                                : () =>
                                    setState(() => _goalType = GoalType.avoid),
                          ),
                        ),
                      ],
                    ),

                    // ── Daily allowance (avoid quests only) ──────────
                    if (_isAvoid) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppColors.panelDecoration(
                            accent: AppColors.neonPurple),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.block,
                                    size: 16, color: AppColors.neonPurple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Doing nothing wins the day.',
                                    style: textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Every slip gets logged with a tap. Stay inside your '
                              'budget and the period still counts — go over it and '
                              'the period is lost on the spot.',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Allowed per ${_period.name == 'daily' ? 'day' : _period.name == 'weekly' ? 'week' : 'month'}',
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                _StepperButton(
                                  icon: Icons.remove,
                                  onTap: isLoading || _allowance == 0
                                      ? null
                                      : () => setState(() => _allowance--),
                                ),
                                SizedBox(
                                  width: 54,
                                  child: Text(
                                    '$_allowance',
                                    textAlign: TextAlign.center,
                                    style: textTheme.displaySmall?.copyWith(
                                      color: _allowance == 0
                                          ? AppColors.successText
                                          : AppColors.neonYellow,
                                    ),
                                  ),
                                ),
                                _StepperButton(
                                  icon: Icons.add,
                                  onTap: isLoading || _allowance >= 100
                                      ? null
                                      : () => setState(() => _allowance++),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _allowance == 0
                                  ? 'Cold turkey — a single slip loses the period.'
                                  : 'Taper mode — up to $_allowance slip'
                                      '${_allowance == 1 ? '' : 's'} allowed. '
                                      'The fewer you use, the more aura you keep.',
                              style: textTheme.bodySmall?.copyWith(
                                color: _allowance == 0
                                    ? AppColors.successText
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Target + unit (progress quests only) ─────────
                    if (_isProgress) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _targetController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Target',
                                hintText: 'e.g. 100',
                                labelStyle:
                                    TextStyle(color: AppColors.neonPurple),
                              ),
                              validator: (value) {
                                if (!_isProgress) return null;
                                final parsed = parseQuantity(value ?? '');
                                if (parsed == null || parsed <= 0) {
                                  return 'Enter a target > 0';
                                }
                                if (parsed > 1000000) {
                                  return 'Keep it under 1 000 000';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _unitController,
                              maxLength: 24,
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                hintText: 'e.g. Reps',
                                counterText: '',
                                labelStyle:
                                    TextStyle(color: AppColors.neonPurple),
                              ),
                              validator: (value) {
                                if (!_isProgress) return null;
                                return (value?.trim().isEmpty ?? true)
                                    ? 'Name the unit'
                                    : null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final unit in _unitSuggestions)
                            _UnitChip(
                              label: unit,
                              selected: _unitController.text.trim() == unit,
                              onTap: isLoading
                                  ? null
                                  : () => setState(() {
                                        _unitController.text = unit;
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Anything works — type your own unit if none fits.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // ── Quest mode: solo / co-op / versus / last standing ─
                    // Four options wrap into a 2×2 grid so each stays legible.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 8.0;
                        final w = (constraints.maxWidth - gap) / 2;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final mode in QuestMode.values)
                              SizedBox(
                                width: w,
                                child: _ModeChip(
                                  label: _modeInfo[mode]!.$1,
                                  icon: _modeInfo[mode]!.$2,
                                  selected: _mode == mode,
                                  onTap: isLoading
                                      ? null
                                      : () => setState(() => _mode = mode),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _modeInfo[_mode]!.$3,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),

                    // ── Invite friends (optional, fires on create) ──
                    const SizedBox(height: 16),
                    _InviteRow(
                      invitees: _invitees,
                      enabled: !isLoading,
                      onChanged: () => setState(() {}),
                    ),

                    // ── Endless toggle (forced on for Last Standing) ─
                    const SizedBox(height: 8),
                    _EndlessTile(
                      value: _endless,
                      locked: _isLms,
                      enabled: !isLoading,
                      onChanged: (v) => setState(() => _isEndless = v),
                    ),
                    const SizedBox(height: 16),

                    // ── Schedule: start always; end only for fixed quests ─
                    // Last Man Standing has no start date either — it starts
                    // when the creator hits START in the lobby.
                    if (!_isLms) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isLoading ? null : _pickStartDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Starts',
                                  labelStyle:
                                      TextStyle(color: AppColors.textSecondary),
                                  suffixIcon: Icon(Icons.calendar_month,
                                      size: 20, color: AppColors.accentText),
                                ),
                                child: Text(
                                  _dateLabel(_startsOn, todayAllowed: true),
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                          if (!_endless) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: isLoading ? null : _pickEndDate,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Ends',
                                    labelStyle: TextStyle(
                                        color: AppColors.textSecondary),
                                    suffixIcon: Icon(Icons.event,
                                        size: 20, color: AppColors.neonPink),
                                  ),
                                  child: Text(
                                    _dateLabel(_endsOn, todayAllowed: false),
                                    style: textTheme.bodyLarge,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _endless
                            ? 'Runs forever — no end date.'
                            : '$_durationDays day${_durationDays == 1 ? '' : 's'} total',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Check-in frequency ───────────────────────────
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<CheckinPeriod>(
                            isExpanded: true,
                            initialValue: _period,
                            dropdownColor: AppColors.surfaceLight,
                            decoration: InputDecoration(
                              labelText: 'Check-in frequency',
                              labelStyle:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: CheckinPeriod.daily,
                                child: Text('Every day'),
                              ),
                              DropdownMenuItem(
                                value: CheckinPeriod.weekly,
                                child: Text('Per week'),
                              ),
                              DropdownMenuItem(
                                value: CheckinPeriod.monthly,
                                child: Text('Per month'),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _period = value ?? CheckinPeriod.daily;
                              // Clamp the count to the new period's maximum.
                              final max =
                                  _period == CheckinPeriod.weekly ? 7 : 30;
                              if (_perPeriod > max) _perPeriod = max;
                            }),
                          ),
                        ),
                        // Progress quests always have exactly one target per
                        // period, so the "how often" picker is meaningless.
                        if (_period != CheckinPeriod.daily && !_isProgress) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _perPeriod,
                              dropdownColor: AppColors.surfaceLight,
                              decoration: InputDecoration(
                                labelText: 'How often?',
                                labelStyle:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                              items: [
                                for (var n = 1;
                                    n <=
                                        (_period == CheckinPeriod.weekly
                                            ? 7
                                            : 30);
                                    n++)
                                  DropdownMenuItem(
                                      value: n, child: Text('${n}x')),
                              ],
                              onChanged: (value) =>
                                  setState(() => _perPeriod = value ?? 1),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Which days does it run on? ───────────────────
                    // All seven by default. Switching one off makes that day
                    // a rest day: nothing due, no strike, not counted as
                    // missed. The server enforces it.
                    Row(
                      children: [
                        Icon(Icons.event_repeat,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text('ACTIVE DAYS',
                                style: textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ))),
                        Text(
                          _weekdays.length == 7
                              ? 'every day'
                              : '${_weekdays.length} of 7',
                          style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          Semantics(
                            button: true,
                            selected: _weekdays.contains(day),
                            label: const [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday'
                            ][day - 1],
                            child: SizedBox(
                                width: 48,
                                height: 48,
                                child: _WeekdayChip(
                                  label: const [
                                    'M',
                                    'T',
                                    'W',
                                    'T',
                                    'F',
                                    'S',
                                    'S'
                                  ][day - 1],
                                  selected: _weekdays.contains(day),
                                  onTap: () => setState(() {
                                    if (_weekdays.contains(day)) {
                                      // Never let the last day go — a quest with no
                                      // active day could never be won or lost.
                                      if (_weekdays.length > 1) {
                                        _weekdays.remove(day);
                                      }
                                    } else {
                                      _weekdays.add(day);
                                    }
                                  }),
                                )),
                          ),
                      ],
                    ),
                    if (_weekdays.length < 7) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Days you switch off are rest days: nothing is due, and '
                        'they never cost you a strike.',
                        style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Text('BALANCE', style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      for (final preset in QuestPreset.values)
                        ChoiceChip(
                            label: Text(preset.label),
                            selected: !_customBalance && _preset == preset,
                            onSelected: (_) => _selectPreset(preset)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_customBalance
                        ? 'Custom balance'
                        : _preset.description),
                    Text(
                        '+${_auraGainController.text} Aura per unit · −${_auraPenaltyController.text} per missed period · $_maxStrikes misses allowed. The next miss ends your run.'),
                    const SizedBox(height: 8),
                    const Text(
                        '100 permanent XP per confirmed unit, up to 500 per UTC day. Shopping and attacks never lower your level.'),
                    if (_mode != QuestMode.lastManStanding)
                      const Text(
                          'If the run fails, you keep 25% of its remaining Aura. Permanent XP stays.'),
                    ExpansionTile(
                        title: const Text('Advanced'),
                        tilePadding: EdgeInsets.zero,
                        children: [
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Use custom balance'),
                              value: _customBalance,
                              onChanged: (value) {
                                if (value) {
                                  setState(() => _customBalance = true);
                                } else {
                                  _selectPreset(_preset);
                                }
                              }),
                          if (_customBalance) ...[
                            DropdownButtonFormField<int>(
                                key: ValueKey(_maxStrikes),
                                initialValue: _maxStrikes,
                                decoration: const InputDecoration(
                                    labelText: 'Allowed missed periods'),
                                items: [
                                  for (var n = 0; n <= 10; n++)
                                    DropdownMenuItem(
                                        value: n, child: Text('$n allowed'))
                                ],
                                onChanged: (value) =>
                                    setState(() => _maxStrikes = value ?? 3)),
                            TextFormField(
                                controller: _auraGainController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Aura per successful unit'),
                                validator: _validateAura,
                                onChanged: (_) => setState(() {})),
                            TextFormField(
                                controller: _auraPenaltyController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText:
                                        'Aura penalty per missed period'),
                                validator: _validateAura,
                                onChanged: (_) => setState(() {})),
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Allow attacks'),
                                subtitle: const Text(
                                    '3 outgoing attacks per account and UTC day. One successful incoming heist per day.'),
                                value: _attacksEnabled,
                                onChanged: (value) =>
                                    setState(() => _attacksEnabled = value)),
                          ],
                        ]),
                    const SizedBox(height: 28),

                    // ── Submit ───────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: isLoading ? null : _submit,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt),
                      label: const Text('CREATE'),
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

/// Endless on/off. Locked (always on) for Last Man Standing.
class _EndlessTile extends StatelessWidget {
  const _EndlessTile({
    required this.value,
    required this.locked,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool locked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: (!enabled || locked) ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.all_inclusive,
                size: 20,
                color: value ? AppColors.neonPurple : AppColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Endless quest',
                      style: textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    locked
                        ? 'Always on for Last Man Standing.'
                        : 'No end date — tracks how long you keep it up.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (!enabled || locked) ? null : onChanged,
              activeTrackColor: AppColors.neonPurple,
            ),
          ],
        ),
      ),
    );
  }
}

/// Invite friends while creating. Fires the invites on save.
class _InviteRow extends ConsumerWidget {
  const _InviteRow({
    required this.invitees,
    required this.enabled,
    required this.onChanged,
  });

  final Set<String> invitees;
  final bool enabled;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    // Make sure the friend list is loaded before opening the picker.
    List<Friend> friends;
    try {
      friends = await ref.read(myFriendsProvider.future);
    } catch (_) {
      friends = const [];
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.sheet,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INVITE FRIENDS',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: AppColors.warningText)),
              const SizedBox(height: 12),
              if (friends.isEmpty)
                Text('No friends yet — add them on the Friends tab.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final friend in friends)
                        CheckboxListTile(
                          value: invitees.contains(friend.username),
                          activeColor: AppColors.neonPurple,
                          contentPadding: EdgeInsets.zero,
                          secondary: AuraAvatar(
                            emoji: friend.avatarEmoji,
                            username: friend.username,
                            size: 32,
                            borderWidth: 1,
                          ),
                          title: Text('@${friend.username}'),
                          onChanged: (on) {
                            if (on ?? false) {
                              invitees.add(friend.username);
                            } else {
                              invitees.remove(friend.username);
                            }
                            setSheet(() {});
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('DONE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled ? () => _pick(context, ref) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.person_add, size: 20, color: AppColors.warningText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite friends',
                      style: textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    invitees.isEmpty
                        ? 'They get an invite the moment you create it.'
                        : invitees.map((u) => '@$u').join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                        color: invitees.isEmpty
                            ? AppColors.textSecondary
                            : AppColors.neonYellow),
                  ),
                ],
              ),
            ),
            if (invitees.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.neonYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${invitees.length}',
                    style: TextStyle(
                        color: AppColors.warningText,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Check-off vs progress — the two ways a period can be satisfied.
class _GoalTypeCard extends StatelessWidget {
  const _GoalTypeCard({
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.neonPurple : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonPurple.withValues(alpha: 0.10)
              : AppColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.neonPurple : AppColors.outline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square +/- control for the avoid quest's allowance.
class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? AppColors.neonPurple.withValues(alpha: 0.5)
                : AppColors.outline,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.neonPurple : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// One-tap suggestion for the (still free-text) unit field.
class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.neonPurple : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonPurple.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.neonPurple : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// One selectable quest-mode option (solo / co-op / versus).
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Only the icon and the label use this — the chip's own fill and
    // border keep the bright yellow a few lines below.
    final color = selected ? AppColors.warningText : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonYellow.withValues(alpha: 0.10)
              : AppColors.surfaceLight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.neonYellow : AppColors.surfaceLight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day-of-week toggle. Deliberately the same shape as the other
/// pick-one-of-many chips in the app: filled and outlined when on,
/// muted surface when off.
class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        // 44 keeps the row inside a comfortable tap target even on a
        // narrow phone, where seven chips get tight.
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.neonPurple.withValues(alpha: 0.15)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.neonPurple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: selected ? AppColors.neonPurple : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
