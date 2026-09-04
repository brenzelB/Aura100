import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType {
  neoBrutalist,
  editorial,
  auralis;

  String get displayName => switch (this) {
        neoBrutalist => 'Kinetic Neo-Brutalist',
        editorial => 'Editorial Growth',
        auralis => 'Auralis',
      };
}

/// Light or dark — a universal setting that applies to whichever
/// design system is active. Every theme ships both.
enum AppThemeMode {
  light,
  dark;

  String get displayName => switch (this) {
        light => 'Light',
        dark => 'Dark',
      };

  IconData get icon => switch (this) {
        light => Icons.light_mode,
        dark => Icons.dark_mode,
      };
}

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color neonCyan;
  final Color neonPink;
  final Color neonPurple;
  final Color neonGreen;
  final Color neonYellow;
  final Color textPrimary;
  final Color textSecondary;
  final Color danger;

  /// Border colour for cards, panels and dialogs.
  final Color outline;

  /// Border colour for text fields (some systems draw these stronger).
  final Color inputOutline;

  /// Panel shadow colour — a hard offset for Neo-Brutalist, a soft
  /// ambient tint for the others.
  final Color shadow;

  /// Foreground on primary/accent buttons.
  final Color onAccent;

  // ── Readable twins of the accents ────────────────────────────────
  //
  // A colour that works as a BUTTON FILL rarely works as TEXT on a pale
  // surface. Neo-Brutalist's #FFC700 is the clearest case: unbeatable as
  // a yellow button with ink on top (11.2:1), but only 1.56:1 when the
  // same yellow is used for a heading on white — far under the 4.5:1
  // that WCAG asks for body text.
  //
  // So the accents keep their job as fills, borders and glows, and these
  // three carry the same meaning where the colour has to be READ. In
  // every palette that already passed the check they are simply the same
  // value, which is why swapping a call site over is safe in all six
  // themes at once.

  /// Primary accent where it must be read (headings, links, icons).
  final Color accentText;

  /// Success/"done" where it must be read.
  final Color successText;

  /// Warning/gold where it must be read.
  final Color warningText;

  final bool isDark;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.neonCyan,
    required this.neonPink,
    required this.neonPurple,
    required this.neonGreen,
    required this.neonYellow,
    required this.textPrimary,
    required this.textSecondary,
    required this.danger,
    required this.outline,
    required this.inputOutline,
    required this.shadow,
    required this.onAccent,
    required this.accentText,
    required this.successText,
    required this.warningText,
    required this.isDark,
  });
}

// ── Kinetic Neo-Brutalist ───────────────────────────────────────
const neoBrutalistColors = AppThemeColors(
  background: Color(0xFFFDEFE7),    // Tertiary warm off-white background
  surface: Color(0xFFFFFFFF),       // Pure white card base
  surfaceLight: Color(0xFFF0EDED),  // Surface container grey
  neonCyan: Color(0xFFFFC700),      // Primary Yellow
  neonPink: Color(0xFF0057FF),      // Secondary Blue
  neonPurple: Color(0xFF7C3AED),    // Kinetic Purple accent
  neonGreen: Color(0xFF00C853),     // Earthy Green success state
  neonYellow: Color(0xFFFFC700),    // Warning Gold
  textPrimary: Color(0xFF191919),    // Ink black primary text
  textSecondary: Color(0xFF4F4632),  // Warm muted brown secondary text
  danger: Color(0xFFBA1A1A),        // Clean red error
  outline: Color(0xFF191919),       // Thick solid ink border
  inputOutline: Color(0xFF191919),
  shadow: Color(0xFF191919),        // Hard black offset shadow
  onAccent: Color(0xFF191919),      // Ink text on the yellow button
  // The yellow reaches only 1.4:1 on white — fine as a button, illegible
  // as a heading. Same hue, darkened until it clears 4.5:1.
  accentText: Color(0xFF876900),
  successText: Color(0xFF008035),
  warningText: Color(0xFF876900),
  isDark: false,
);

const neoBrutalistDarkColors = AppThemeColors(
  background: Color(0xFF14120F),    // Warm near-black canvas
  surface: Color(0xFF1E1B17),
  surfaceLight: Color(0xFF2A2620),
  neonCyan: Color(0xFFFFC700),      // The yellow carries straight over
  neonPink: Color(0xFF5B8CFF),      // Blue lifted for dark contrast
  neonPurple: Color(0xFFC084FC),    // Kinetic Purple accent (Dark mode)
  neonGreen: Color(0xFF00E676),
  neonYellow: Color(0xFFFFC700),
  textPrimary: Color(0xFFF7F5F2),
  textSecondary: Color(0xFFB5AC9B),
  danger: Color(0xFFFF6B5E),
  outline: Color(0xFFF7F5F2),       // Brutalist border, inverted to white
  inputOutline: Color(0xFFF7F5F2),
  shadow: Color(0xFFF7F5F2),        // High contrast offset matching the outline
  onAccent: Color(0xFF191919),      // Ink text on the yellow button
  // On the dark canvas the accents already read at 10:1 and up — the
  // readable twins are simply the accents themselves.
  accentText: Color(0xFFFFC700),
  successText: Color(0xFF00E676),
  warningText: Color(0xFFFFC700),
  isDark: true,
);

// ── Editorial Growth ────────────────────────────────────────────
const editorialColors = AppThemeColors(
  background: Color(0xFFFFF8F2),    // Cream base background
  surface: Color(0xFFFFFFFF),       // White card floating tier
  surfaceLight: Color(0xFFF5F2ED),  // Cream/off-white neutral base
  neonCyan: Color(0xFFE65C4F),      // Primary Terracotta
  neonPink: Color(0xFF2D2D2D),      // Secondary Dark Slate
  neonPurple: Color(0xFFA93027),    // Accent Dark Terracotta
  neonGreen: Color(0xFF4A7C59),     // Earthy Sage Green for success
  neonYellow: Color(0xFFD4A373),    // Earthy Ochre/Gold
  textPrimary: Color(0xFF1E1B16),    // Dark brown/slate primary text
  textSecondary: Color(0xFF58413E),  // Warm muted brown secondary text
  danger: Color(0xFFBA1A1A),        // Clean red error
  outline: Color(0xFFE0BFBB),       // outline-variant grey-red
  inputOutline: Color(0xFF8C716D),  // Stronger slate/brown field border
  shadow: Color(0xFFE65C4F),        // Soft terracotta ambient shadow
  onAccent: Color(0xFFFFF8F2),      // Cream text on the dark slate button
  // Terracotta reads 3.5:1 on white and the ochre only 2.2:1 — both
  // deepened just enough, hue untouched. The sage green already passed.
  accentText: Color(0xFFD72F1F),
  successText: Color(0xFF4A7C59),
  warningText: Color(0xFF9C6530),
  isDark: false,
);

const editorialDarkColors = AppThemeColors(
  background: Color(0xFF17120F),    // Warm dark paper
  surface: Color(0xFF201A16),
  surfaceLight: Color(0xFF2B231E),
  neonCyan: Color(0xFFFF8672),      // Terracotta lifted for dark
  neonPink: Color(0xFFEDE4DA),      // Slate inverts to warm light
  neonPurple: Color(0xFFD9695B),
  neonGreen: Color(0xFF7FB08D),
  neonYellow: Color(0xFFE0B183),
  textPrimary: Color(0xFFF4EBE3),
  textSecondary: Color(0xFFC2AC9F),
  danger: Color(0xFFFF6B5E),
  outline: Color(0xFF4A3A33),
  inputOutline: Color(0xFF6E5A51),
  shadow: Color(0xFFFF8672),        // Warm terracotta glow
  onAccent: Color(0xFF17120F),      // Dark text on the light button
  accentText: Color(0xFFFF8672),
  successText: Color(0xFF7FB08D),
  warningText: Color(0xFFE0B183),
  isDark: true,
);

// ── Auralis ─────────────────────────────────────────────────────
const auralisColors = AppThemeColors(
  background: Color(0xFFF9F9F9),   // Soft cool white background
  surface: Color(0xFFFFFFFF),      // Pure white container
  surfaceLight: Color(0xFFEEEEEE), // Light grey divider/scaffolding
  neonCyan: Color(0xFF1A1C1C),     // Deep charcoal primary
  neonPink: Color(0xFF5E5E5E),     // Slate grey secondary
  neonPurple: Color(0xFF5457E8),   // Indigo accent for Aura, more decisive
  neonGreen: Color(0xFF0F5132),    // Restrained dark green for success
  neonYellow: Color(0xFFB85C00),   // Restrained amber warning
  textPrimary: Color(0xFF1A1C1C),  // Deep charcoal text
  textSecondary: Color(0xFF5F5E5E), // Muted grey text
  danger: Color(0xFFBA1A1A),       // Clean red error
  outline: Color(0xFFE3E5E9),      // Crisper hairline; depth via shadow
  inputOutline: Color(0xFFDDE0E5),
  shadow: Color(0xFF0B1220),       // Cool ambient shadow
  onAccent: Color(0xFFFFFFFF),     // White text on the charcoal button
  // Auralis was built restrained enough to pass on its own; only the
  // amber needed a hair of depth to clear 4.5:1 on the tinted canvas.
  accentText: Color(0xFF1A1C1C),
  successText: Color(0xFF0F5132),
  warningText: Color(0xFFB55A00),
  isDark: false,
);

const auralisDarkColors = AppThemeColors(
  background: Color(0xFF0C0E0F),   // Deeper base so lifted cards read
  surface: Color(0xFF1A1F22),      // Lifted so cards float off the canvas
  surfaceLight: Color(0xFF262C30),
  neonCyan: Color(0xFFF1F3F3),     // Charcoal primary inverts to near-white
  neonPink: Color(0xFF9AA1A5),
  neonPurple: Color(0xFF8B93FF),   // Indigo, a touch more vivid on dark
  neonGreen: Color(0xFF34D399),
  neonYellow: Color(0xFFFBBF24),
  textPrimary: Color(0xFFF1F3F3),
  textSecondary: Color(0xFF9AA1A5),
  danger: Color(0xFFFF6B5E),
  outline: Color(0xFF343B41),      // Visible hairline for card edges
  inputOutline: Color(0xFF343B41),
  shadow: Color(0xFF000000),
  onAccent: Color(0xFF0C0E0F),     // Dark text on the near-white button
  accentText: Color(0xFFF1F3F3),
  successText: Color(0xFF34D399),
  warningText: Color(0xFFFBBF24),
  isDark: true,
);

/// The palette for one design system in one mode.
AppThemeColors paletteFor(AppThemeType type, AppThemeMode mode) {
  final dark = mode == AppThemeMode.dark;
  return switch (type) {
    AppThemeType.neoBrutalist =>
      dark ? neoBrutalistDarkColors : neoBrutalistColors,
    AppThemeType.editorial => dark ? editorialDarkColors : editorialColors,
    AppThemeType.auralis => dark ? auralisDarkColors : auralisColors,
  };
}

abstract class AppColors {
  static AppThemeColors current = neoBrutalistColors;

  /// Which design system and mode `current` came from. Tracked
  /// explicitly so lookups never depend on comparing palettes.
  static AppThemeType currentType = AppThemeType.neoBrutalist;
  static AppThemeMode currentMode = AppThemeMode.light;

  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get surfaceLight => current.surfaceLight;
  static Color get neonCyan => current.neonCyan;
  static Color get neonPink => current.neonPink;
  static Color get neonPurple => current.neonPurple;
  static Color get neonGreen => current.neonGreen;
  static Color get neonYellow => current.neonYellow;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get danger => current.danger;
  static Color get outline => current.outline;
  static Color get inputOutline => current.inputOutline;
  static Color get shadow => current.shadow;
  static Color get onAccent => current.onAccent;

  /// Use these three wherever the colour has to be READ — headings,
  /// labels, status text, icons on a plain surface. The neon* accents
  /// stay for fills, borders and glows.
  static Color get accentText => current.accentText;
  static Color get successText => current.successText;
  static Color get warningText => current.warningText;

  static bool get isDark => current.isDark;

  static List<BoxShadow> neonGlow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.45),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ];

  static AppThemeType get activeType => currentType;

  /// Applies a design system + mode to the global palette.
  static void apply(AppThemeType type, AppThemeMode mode) {
    current = paletteFor(type, mode);
    currentType = type;
    currentMode = mode;
  }

  /// Dynamically computes card/panel decorations based on the active theme
  static BoxDecoration panelDecoration({
    required Color accent,
    Color? fill,
    double? radius,
    bool isDanger = false,
    bool glow = false,
  }) {
    final type = activeType;
    final effectiveFill = fill != null ? Color.alphaBlend(fill, surface) : surface;
    switch (type) {
      case AppThemeType.neoBrutalist:
        return BoxDecoration(
          color: effectiveFill,
          borderRadius: BorderRadius.circular(radius ?? 8.0), // Rounded 8px corners
          border: Border.all(
            color: isDanger ? danger : outline, // Thick solid border
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: shadow, // Hard offset shadow
              offset: const Offset(4, 4),
              blurRadius: 0,
              spreadRadius: 0,
            )
          ],
        );
      case AppThemeType.editorial:
        return BoxDecoration(
          color: effectiveFill,
          borderRadius: BorderRadius.circular(radius ?? 24.0), // Rounded modern/tactile corners
          border: Border.all(
            color: isDanger ? danger : outline, // outline-variant
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: 0.08), // Soft ambient shadow
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            )
          ],
        );
      case AppThemeType.auralis:
        // Real, directional depth. On light, a soft cast shadow lets
        // cards float off the near-white canvas; on near-black, depth
        // comes from the lifted surface + hairline (a black shadow would
        // be invisible), with a faint cast only to seat stacked cards.
        return BoxDecoration(
          color: effectiveFill,
          borderRadius: BorderRadius.circular(radius ?? 22.0),
          border: Border.all(
            color: isDanger ? danger : outline,
            width: 1.0,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                    spreadRadius: -8,
                  ),
                ]
              : [
                  BoxShadow(
                    color: shadow.withValues(alpha: 0.10),
                    offset: const Offset(0, 10),
                    blurRadius: 30,
                    spreadRadius: -12,
                  ),
                  BoxShadow(
                    color: shadow.withValues(alpha: 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                    spreadRadius: -2,
                  ),
                ],
        );
    }
  }
}

/// The active design system plus its light/dark mode.
class AppThemeSettings {
  const AppThemeSettings({required this.type, required this.mode});

  final AppThemeType type;
  final AppThemeMode mode;

  AppThemeSettings copyWith({AppThemeType? type, AppThemeMode? mode}) =>
      AppThemeSettings(type: type ?? this.type, mode: mode ?? this.mode);
}

/// Riverpod provider to manage the active theme (design system + mode).
final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeSettings>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeSettings> {
  ThemeNotifier()
      : super(const AppThemeSettings(
          type: AppThemeType.neoBrutalist,
          mode: AppThemeMode.light,
        )) {
    _loadTheme();
  }

  static const _themeKey = 'selected_theme';
  static const _modeKey = 'selected_theme_mode';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var type = state.type;
      var mode = state.mode;

      final themeIndex = prefs.getInt(_themeKey);
      if (themeIndex != null &&
          themeIndex >= 0 &&
          themeIndex < AppThemeType.values.length) {
        type = AppThemeType.values[themeIndex];
      }
      final modeIndex = prefs.getInt(_modeKey);
      if (modeIndex != null &&
          modeIndex >= 0 &&
          modeIndex < AppThemeMode.values.length) {
        mode = AppThemeMode.values[modeIndex];
      }

      _apply(type, mode);
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  void _apply(AppThemeType type, AppThemeMode mode) {
    AppColors.apply(type, mode);
    state = AppThemeSettings(type: type, mode: mode);
  }

  void setTheme(AppThemeType type) {
    _apply(type, state.mode);
    _persist(_themeKey, type.index);
  }

  /// Universal light/dark switch — keeps the chosen design system.
  void setMode(AppThemeMode mode) {
    _apply(state.type, mode);
    _persist(_modeKey, mode.index);
  }

  Future<void> _persist(String key, int value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, value);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}
