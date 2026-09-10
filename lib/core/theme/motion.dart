import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// The app's motion language — one place for every curve and duration,
/// so movement feels like one hand drew it.
///
/// Curves are the *strong* custom variants Emil Kowalski recommends,
/// not Flutter's built-ins: the standard ones lack the punch that makes
/// motion feel intentional. Durations stay under ~300ms for anything
/// the user triggers, because ease-out at 200ms feels faster than the
/// same move at 400ms — perceived speed is the point.
abstract class AppCurves {
  /// Strong ease-out — for things ENTERING or responding to a press.
  /// Starts fast, so the UI feels instantly alive. cubic(0.23,1,0.32,1).
  static const Cubic emphasizedOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out — for things MOVING/morphing on screen.
  static const Cubic movement = Cubic(0.77, 0.0, 0.175, 1.0);

  /// iOS-like sheet curve (Ionic) — for drawers/bottom sheets.
  static const Cubic drawer = Cubic(0.32, 0.72, 0.0, 1.0);
}

abstract class AppDurations {
  /// Button/card press feedback.
  static const Duration press = Duration(milliseconds: 130);

  /// Tooltips, small popovers, chips.
  static const Duration quick = Duration(milliseconds: 190);

  /// The default for most UI entrances.
  static const Duration base = Duration(milliseconds: 260);

  /// Progress fills, larger reveals.
  static const Duration slow = Duration(milliseconds: 280);
}

/// Wraps any tappable surface with a subtle scale-down on press
/// (Emil: "buttons must feel responsive"). Honours the OS reduce-motion
/// setting — no scale then, just the tap.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Subtle by design — 0.95–0.98 reads as "pressed", not "shrunk".
  final double pressedScale;

  @override
  State<Pressable> createState() => _PressableState();
}

/// A one-shot entrance: the child fades and rises a few pixels into
/// place after [delay]. Give list items an index-scaled delay to get a
/// gentle cascade (Emil: 30–80ms between items, decorative, never
/// blocking). Honours reduce-motion.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  /// index → capped delay, so a long list never crawls in.
  static Duration forIndex(int index, {int step = 30, int maxItems = 4}) =>
      Duration(milliseconds: (index.clamp(0, maxItems)) * step);

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      // Next frame, so the transition has a "from" state to animate.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _shown = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shown = _shown || reduce;
    return AnimatedSlide(
      offset: shown ? Offset.zero : const Offset(0, 0.06),
      duration: reduce ? Duration.zero : AppDurations.base,
      curve: AppCurves.emphasizedOut,
      child: AnimatedOpacity(
        opacity: shown ? 1 : 0,
        duration: reduce ? Duration.zero : AppDurations.base,
        curve: AppCurves.emphasizedOut,
        child: widget.child,
      ),
    );
  }
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _focused = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final scale =
        (_down && _interactive && !reduce) ? widget.pressedScale : 1.0;

    return FocusableActionDetector(
        enabled: _interactive,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          })
        },
        child: DecoratedBox(
            decoration: BoxDecoration(
                border: _focused
                    ? Border.all(color: AppColors.neonPurple, width: 3)
                    : null),
            child: GestureDetector(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              onTapDown: _interactive ? (_) => _set(true) : null,
              onTapUp: _interactive ? (_) => _set(false) : null,
              onTapCancel: _interactive ? () => _set(false) : null,
              child: AnimatedScale(
                scale: scale,
                duration: reduce ? Duration.zero : AppDurations.press,
                curve: AppCurves.emphasizedOut,
                child: widget.child,
              ),
            )));
  }
}
