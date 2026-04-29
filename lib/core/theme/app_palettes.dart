import 'package:flutter/material.dart';

enum AppColorPreset {
  monokai('Monokai', 'Classic code colors with warm surfaces'),
  gruvbox('Gruvbox', 'Retro groove colors'),
  catppuccin('Catppuccin', 'Soft pastel theme'),
  nord('Nord', 'Restrained arctic blues'),
  everforest('Everforest', 'Natural greens and warm light'),
  roseOfDune('Rose of Dune', 'Sand, spice, and muted rose');

  final String label;
  final String description;
  const AppColorPreset(this.label, this.description);
}

@immutable
class _PaletteSpec {
  const _PaletteSpec({
    required this.lightSurface,
    required this.darkSurface,
    required this.lightAccent,
    required this.darkAccent,
    required this.lightSecondary,
    required this.darkSecondary,
    required this.lightTertiary,
    required this.darkTertiary,
    this.lightOnSurface,
    this.darkOnSurface,
    this.lightSurfaceLow,
    this.darkSurfaceLow,
    this.lightSurfaceContainer,
    this.darkSurfaceContainer,
    this.lightSurfaceHigh,
    this.darkSurfaceHigh,
    this.lightSurfaceHighest,
    this.darkSurfaceHighest,
    this.lightPrimaryContainer,
    this.darkPrimaryContainer,
    this.lightSecondaryContainer,
    this.darkSecondaryContainer,
    this.lightTertiaryContainer,
    this.darkTertiaryContainer,
    this.lightOutline,
    this.darkOutline,
    this.lightError,
    this.darkError,
  });

  final Color lightSurface;
  final Color darkSurface;
  final Color lightAccent;
  final Color darkAccent;
  final Color lightSecondary;
  final Color darkSecondary;
  final Color lightTertiary;
  final Color darkTertiary;
  final Color? lightOnSurface;
  final Color? darkOnSurface;
  final Color? lightSurfaceLow;
  final Color? darkSurfaceLow;
  final Color? lightSurfaceContainer;
  final Color? darkSurfaceContainer;
  final Color? lightSurfaceHigh;
  final Color? darkSurfaceHigh;
  final Color? lightSurfaceHighest;
  final Color? darkSurfaceHighest;
  final Color? lightPrimaryContainer;
  final Color? darkPrimaryContainer;
  final Color? lightSecondaryContainer;
  final Color? darkSecondaryContainer;
  final Color? lightTertiaryContainer;
  final Color? darkTertiaryContainer;
  final Color? lightOutline;
  final Color? darkOutline;
  final Color? lightError;
  final Color? darkError;

  Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  Color accentFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccent : lightAccent;

  Color secondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSecondary : lightSecondary;

  Color tertiaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTertiary : lightTertiary;

  Color? onSurfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkOnSurface : lightOnSurface;

  Color? surfaceLowFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceLow : lightSurfaceLow;

  Color? surfaceContainerFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkSurfaceContainer
          : lightSurfaceContainer;

  Color? surfaceHighFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceHigh : lightSurfaceHigh;

  Color? surfaceHighestFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurfaceHighest : lightSurfaceHighest;

  Color? primaryContainerFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkPrimaryContainer
          : lightPrimaryContainer;

  Color? secondaryContainerFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkSecondaryContainer
          : lightSecondaryContainer;

  Color? tertiaryContainerFor(Brightness brightness) =>
      brightness == Brightness.dark
          ? darkTertiaryContainer
          : lightTertiaryContainer;

  Color? outlineFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkOutline : lightOutline;

  Color? errorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkError : lightError;
}

class AppPalettes {
  static const AppColorPreset fallbackPreset = AppColorPreset.monokai;

  static const Map<AppColorPreset, _PaletteSpec> _specs = {
    AppColorPreset.monokai: _PaletteSpec(
      lightSurface: Color(0xFFFCFAF4),
      darkSurface: Color(0xFF272822),
      lightAccent: Color(0xFFF92672),
      darkAccent: Color(0xFFF92672),
      lightSecondary: Color(0xFF008EA6),
      darkSecondary: Color(0xFF66D9EF),
      lightTertiary: Color(0xFFC26900),
      darkTertiary: Color(0xFFFD971F),
      lightOnSurface: Color(0xFF49483E),
      darkOnSurface: Color(0xFFF8F8F2),
      lightSurfaceLow: Color(0xFFF8F5EC),
      darkSurfaceLow: Color(0xFF2D2E28),
      lightSurfaceContainer: Color(0xFFF1EDE2),
      darkSurfaceContainer: Color(0xFF383930),
      lightSurfaceHigh: Color(0xFFE7E1D2),
      darkSurfaceHigh: Color(0xFF49483E),
      lightSurfaceHighest: Color(0xFFDDD5C2),
      darkSurfaceHighest: Color(0xFF5B5A4E),
      lightPrimaryContainer: Color(0xFFF6DEE4),
      darkPrimaryContainer: Color(0xFF49313C),
      lightSecondaryContainer: Color(0xFFE0F1F1),
      darkSecondaryContainer: Color(0xFF314146),
      lightTertiaryContainer: Color(0xFFF2E5CF),
      darkTertiaryContainer: Color(0xFF473B2C),
      lightOutline: Color(0xFF7F755D),
      darkOutline: Color(0xFF75715E),
      lightError: Color(0xFFF92672),
      darkError: Color(0xFFF92672),
    ),
    AppColorPreset.gruvbox: _PaletteSpec(
      lightSurface: Color(0xFFFBF1C7),
      darkSurface: Color(0xFF282828),
      lightAccent: Color(0xFFAF3A03),
      darkAccent: Color(0xFFFE8019),
      lightSecondary: Color(0xFF427B58),
      darkSecondary: Color(0xFF83A598),
      lightTertiary: Color(0xFFB57614),
      darkTertiary: Color(0xFFFABD2F),
      lightOnSurface: Color(0xFF3C3836),
      darkOnSurface: Color(0xFFEBDBB2),
      lightSurfaceLow: Color(0xFFF2E5BC),
      darkSurfaceLow: Color(0xFF32302F),
      lightSurfaceContainer: Color(0xFFEBDBB2),
      darkSurfaceContainer: Color(0xFF3C3836),
      lightSurfaceHigh: Color(0xFFD5C4A1),
      darkSurfaceHigh: Color(0xFF504945),
      lightSurfaceHighest: Color(0xFFBDAE93),
      darkSurfaceHighest: Color(0xFF665C54),
      lightPrimaryContainer: Color(0xFFF0D6B8),
      darkPrimaryContainer: Color(0xFF4A3729),
      lightSecondaryContainer: Color(0xFFDCE6D6),
      darkSecondaryContainer: Color(0xFF374243),
      lightTertiaryContainer: Color(0xFFEADDB5),
      darkTertiaryContainer: Color(0xFF47412E),
      lightOutline: Color(0xFF928374),
      darkOutline: Color(0xFF928374),
      lightError: Color(0xFF9D0006),
      darkError: Color(0xFFFB4934),
    ),
    AppColorPreset.catppuccin: _PaletteSpec(
      lightSurface: Color(0xFFEFF1F5),
      darkSurface: Color(0xFF1E1E2E),
      lightAccent: Color(0xFF8839EF),
      darkAccent: Color(0xFFCBA6F7),
      lightSecondary: Color(0xFF1E66F5),
      darkSecondary: Color(0xFF89B4FA),
      lightTertiary: Color(0xFFEA76CB),
      darkTertiary: Color(0xFFF5C2E7),
      lightOnSurface: Color(0xFF4C4F69),
      darkOnSurface: Color(0xFFCDD6F4),
      lightSurfaceLow: Color(0xFFE6E9EF),
      darkSurfaceLow: Color(0xFF181825),
      lightSurfaceContainer: Color(0xFFDCE0E8),
      darkSurfaceContainer: Color(0xFF313244),
      lightSurfaceHigh: Color(0xFFCCD0DA),
      darkSurfaceHigh: Color(0xFF45475A),
      lightSurfaceHighest: Color(0xFFBCC0CC),
      darkSurfaceHighest: Color(0xFF585B70),
      lightOutline: Color(0xFF9CA0B0),
      darkOutline: Color(0xFF6C7086),
      lightError: Color(0xFFD20F39),
      darkError: Color(0xFFF38BA8),
    ),
    AppColorPreset.nord: _PaletteSpec(
      lightSurface: Color(0xFFECEFF4),
      darkSurface: Color(0xFF2E3440),
      lightAccent: Color(0xFF5E81AC),
      darkAccent: Color(0xFF88C0D0),
      lightSecondary: Color(0xFF88C0D0),
      darkSecondary: Color(0xFF81A1C1),
      lightTertiary: Color(0xFF8FBCBB),
      darkTertiary: Color(0xFFB48EAD),
      lightOnSurface: Color(0xFF2E3440),
      darkOnSurface: Color(0xFFECEFF4),
      lightSurfaceLow: Color(0xFFE5E9F0),
      darkSurfaceLow: Color(0xFF343B49),
      lightSurfaceContainer: Color(0xFFD8DEE9),
      darkSurfaceContainer: Color(0xFF3B4252),
      lightSurfaceHigh: Color(0xFFC8D0DA),
      darkSurfaceHigh: Color(0xFF434C5E),
      lightSurfaceHighest: Color(0xFFB9C3CF),
      darkSurfaceHighest: Color(0xFF4C566A),
      lightOutline: Color(0xFF4C566A),
      darkOutline: Color(0xFF8FBCBB),
      lightError: Color(0xFFBF616A),
      darkError: Color(0xFFBF616A),
    ),
    AppColorPreset.everforest: _PaletteSpec(
      lightSurface: Color(0xFFFDF6E3),
      darkSurface: Color(0xFF2D353B),
      lightAccent: Color(0xFF8DA101),
      darkAccent: Color(0xFFA7C080),
      lightSecondary: Color(0xFFDFA000),
      darkSecondary: Color(0xFFDBBC7F),
      lightTertiary: Color(0xFF35A77C),
      darkTertiary: Color(0xFF83C092),
      lightOnSurface: Color(0xFF5C6A72),
      darkOnSurface: Color(0xFFD3C6AA),
      lightSurfaceLow: Color(0xFFF4F0D9),
      darkSurfaceLow: Color(0xFF232A2E),
      lightSurfaceContainer: Color(0xFFEFEBD4),
      darkSurfaceContainer: Color(0xFF343F44),
      lightSurfaceHigh: Color(0xFFE6E2CC),
      darkSurfaceHigh: Color(0xFF3D484D),
      lightSurfaceHighest: Color(0xFFE0DCC7),
      darkSurfaceHighest: Color(0xFF475258),
      lightOutline: Color(0xFF829181),
      darkOutline: Color(0xFF859289),
      lightError: Color(0xFFF85552),
      darkError: Color(0xFFE67E80),
    ),
    AppColorPreset.roseOfDune: _PaletteSpec(
      lightSurface: Color(0xFFFFF8EE),
      darkSurface: Color(0xFF2B2119),
      lightAccent: Color(0xFFB85C5C),
      darkAccent: Color(0xFFE8B965),
      lightSecondary: Color(0xFF8B6F61),
      darkSecondary: Color(0xFFE08F87),
      lightTertiary: Color(0xFFA97835),
      darkTertiary: Color(0xFFCFA76A),
      lightOnSurface: Color(0xFF4B3A30),
      darkOnSurface: Color(0xFFF6E4CC),
      lightSurfaceLow: Color(0xFFFAF1E4),
      darkSurfaceLow: Color(0xFF34271D),
      lightSurfaceContainer: Color(0xFFF4E8D8),
      darkSurfaceContainer: Color(0xFF463424),
      lightSurfaceHigh: Color(0xFFEDE0CF),
      darkSurfaceHigh: Color(0xFF5A4129),
      lightSurfaceHighest: Color(0xFFE6D7C4),
      darkSurfaceHighest: Color(0xFF6C4F32),
      lightPrimaryContainer: Color(0xFFF3DDD5),
      darkPrimaryContainer: Color(0xFF604128),
      lightSecondaryContainer: Color(0xFFEEE2D6),
      darkSecondaryContainer: Color(0xFF5C3B33),
      lightTertiaryContainer: Color(0xFFEFE3CF),
      darkTertiaryContainer: Color(0xFF5D432B),
      lightOutline: Color(0xFF9B806B),
      darkOutline: Color(0xFFA88958),
      lightError: Color(0xFFB85C5C),
      darkError: Color(0xFFE08F87),
    ),
  };

  static const _PaletteSpec _basicSpec = _PaletteSpec(
    lightSurface: Color(0xFFFAF3E8),
    darkSurface: Color(0xFF272822),
    lightAccent: Color(0xFF9E5261),
    darkAccent: Color(0xFFE092A2),
    lightSecondary: Color(0xFF68764A),
    darkSecondary: Color(0xFFBAC98B),
    lightTertiary: Color(0xFF8B7446),
    darkTertiary: Color(0xFFD5C27F),
  );

  /// Returns the ColorScheme for the given preset and brightness mode.
  static ColorScheme getScheme(AppColorPreset preset, Brightness brightness) {
    return _schemeFromSpec(
        _specs[preset] ?? _specs[fallbackPreset]!, brightness);
  }

  /// Returns a quieter Monokai-inspired baseline for Basic mode.
  static ColorScheme getBasicScheme(Brightness brightness) {
    return _schemeFromSpec(_basicSpec, brightness);
  }

  static AppColorPreset parsePreset(Object? value) {
    final rawValue = value?.toString();
    if (rawValue == null || rawValue.trim().isEmpty) {
      return fallbackPreset;
    }

    final normalized = rawValue
        .split('.')
        .last
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    return switch (normalized) {
      'monokai' || 'qmonokai' => AppColorPreset.monokai,
      'gruvbox' => AppColorPreset.gruvbox,
      'catppuccin' => AppColorPreset.catppuccin,
      'nord' => AppColorPreset.nord,
      'everforest' => AppColorPreset.everforest,
      'roseofdune' => AppColorPreset.roseOfDune,
      'kanagawa' || 'rosepine' => fallbackPreset,
      _ => fallbackPreset,
    };
  }

  static bool isCanonicalStorageValue(Object? value, AppColorPreset preset) {
    return value?.toString() == preset.toString();
  }

  static ColorScheme _schemeFromSpec(
    _PaletteSpec spec,
    Brightness brightness,
  ) {
    final isDark = brightness == Brightness.dark;
    final surface = spec.surfaceFor(brightness);
    final accent = spec.accentFor(brightness);
    final secondary = spec.secondaryFor(brightness);
    final tertiary = spec.tertiaryFor(brightness);
    final onSurface = spec.onSurfaceFor(brightness) ??
        (isDark ? const Color(0xFFF6F1E8) : const Color(0xFF1C1714));
    final surfaceLow = spec.surfaceLowFor(brightness) ??
        _blend(onSurface, surface, isDark ? 0.04 : 0.02);
    final surfaceContainer = spec.surfaceContainerFor(brightness) ??
        _blend(accent, surface, isDark ? 0.1 : 0.04);
    final surfaceHigh = spec.surfaceHighFor(brightness) ??
        _blend(secondary, surface, isDark ? 0.14 : 0.08);
    final surfaceHighest = spec.surfaceHighestFor(brightness) ??
        _blend(tertiary, surface, isDark ? 0.18 : 0.12);
    final primaryContainer = spec.primaryContainerFor(brightness) ??
        _blend(accent, surface, isDark ? 0.2 : 0.1);
    final secondaryContainer = spec.secondaryContainerFor(brightness) ??
        _blend(secondary, surface, isDark ? 0.16 : 0.08);
    final tertiaryContainer = spec.tertiaryContainerFor(brightness) ??
        _blend(tertiary, surface, isDark ? 0.14 : 0.08);
    final outline = spec.outlineFor(brightness) ??
        _blend(onSurface, surface, isDark ? 0.3 : 0.18);
    final danger = spec.errorFor(brightness) ??
        (isDark ? const Color(0xFFF0A2A3) : const Color(0xFFB44E4C));

    return ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      onPrimary: _foregroundFor(accent),
      primaryContainer: primaryContainer,
      onPrimaryContainer: onSurface,
      secondary: secondary,
      onSecondary: _foregroundFor(secondary),
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSurface,
      tertiary: tertiary,
      onTertiary: _foregroundFor(tertiary),
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onSurface,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: _blend(onSurface, surface, isDark ? 0.72 : 0.68),
      surfaceContainerLowest: _blend(
        onSurface,
        surface,
        isDark ? 0.02 : 0.01,
      ),
      surfaceContainerLow: surfaceLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceHigh,
      surfaceContainerHighest: surfaceHighest,
      surfaceDim: _blend(Colors.black, surface, isDark ? 0.16 : 0.05),
      surfaceBright: _blend(Colors.white, surface, isDark ? 0.08 : 0.16),
      outline: outline,
      outlineVariant: _blend(outline, surface, isDark ? 0.44 : 0.34),
      error: danger,
      onError: _foregroundFor(danger),
      errorContainer: _blend(danger, surface, isDark ? 0.18 : 0.12),
      onErrorContainer: onSurface,
      shadow: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
      scrim: Colors.black.withValues(alpha: 0.42),
      surfaceTint: accent,
    );
  }

  static Color _blend(Color foreground, Color background, double opacity) {
    return Color.alphaBlend(foreground.withValues(alpha: opacity), background);
  }

  static Color _foregroundFor(Color color) {
    return color.computeLuminance() >= 0.48
        ? const Color(0xFF191512)
        : const Color(0xFFF8F4ED);
  }
}
