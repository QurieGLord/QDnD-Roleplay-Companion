import 'package:flutter/material.dart';

enum AppColorPreset {
  qMonokai('QMonokai', 'Code-inspired contrast'),
  gruvbox('Gruvbox', 'Retro groove colors'),
  catppuccin('Catppuccin', 'Soothing pastel theme'),
  kanagawa('Kanagawa', 'Colors of a wave'),
  rosePine('Rosé Pine', 'All natural pine, faux fur and a bit of soho'),
  roseOfDune('Rose of Dune', 'Arid sands and spice');

  final String label;
  final String description;
  const AppColorPreset(this.label, this.description);
}

class AppPalettes {
  /// Returns the ColorScheme for the given preset and brightness mode
  static ColorScheme getScheme(AppColorPreset preset, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    switch (preset) {
      case AppColorPreset.qMonokai:
        return isDark ? _qMonokaiDark : _qMonokaiLight;
      case AppColorPreset.gruvbox:
        return isDark ? _gruvboxDark : _gruvboxLight;
      case AppColorPreset.catppuccin:
        return isDark ? _catppuccinMocha : _catppuccinLatte;
      case AppColorPreset.kanagawa:
        return isDark ? _kanagawaWave : _kanagawaLotus;
      case AppColorPreset.rosePine:
        return isDark ? _rosePineDark : _rosePineDawn;
      case AppColorPreset.roseOfDune:
        return isDark ? _duneDark : _duneLight;
    }
  }

  // ===========================================================================
  // 1. QMonokai (The Original Warmth)
  // ===========================================================================
  static const _qMonokaiDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFF5C5C), // Vibrant Warm Coral
    onPrimary: Color(0xFF330000),
    primaryContainer: Color(0xFF9E1A34), // Deep Berry
    onPrimaryContainer: Color(0xFFFFD9DE),
    secondary: Color(0xFFA6E22E), // The Classic Monokai Lime (Warm & Acidic)
    onSecondary: Color(0xFF1E2905),
    secondaryContainer: Color(0xFF526615),
    onSecondaryContainer: Color(0xFFE8F7C8),
    tertiary: Color(0xFF66D9EF), // Cyan (Classic)
    onTertiary: Color(0xFF002830),
    tertiaryContainer: Color(0xFF004F5E),
    onTertiaryContainer: Color(0xFFC4F3FF),
    error: Color(0xFFFD971F), // Orange
    onError: Color(0xFF381E00),
    surface: Color(0xFF2E2B29), // Warm Dark Chocolate/Grey
    onSurface: Color(0xFFF8F8F2), // Off-white
    surfaceContainerHighest: Color(0xFF46423F), // Lighter chocolate
    outline: Color(0xFF968B83),
  );

  static const _qMonokaiLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFD41C60), // Deep Pink
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFD4E2),
    onPrimaryContainer: Color(0xFF4D1025),
    secondary: Color(0xFF6E9615), // Darker Green
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE2F5C8),
    onSecondaryContainer: Color(0xFF263608),
    tertiary: Color(0xFF1E9CB0), // Darker Blue
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD1F4FA),
    onTertiaryContainer: Color(0xFF00363D),
    error: Color(0xFFD67608), // Darker Orange
    onError: Colors.white,
    surface: Color(0xFFFDF9F3), // Creamy White
    onSurface: Color(0xFF272822), // Dark Text
    surfaceContainerHighest: Color(0xFFECE8E1),
    outline: Color(0xFFA5A296),
  );

  // ===========================================================================
  // 2. Gruvbox (True Warm Retro)
  // ===========================================================================
  static const _gruvboxDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFE8019), // Bright Orange
    onPrimary: Color(0xFF281700),
    primaryContainer: Color(0xFFA65000), // Deep Orange
    onPrimaryContainer: Color(0xFFFFDBC2),
    secondary: Color(0xFFB8BB26), // Retro Green
    onSecondary: Color(0xFF262900),
    secondaryContainer: Color(0xFF5F6305),
    onSecondaryContainer: Color(0xFFE9ECA8),
    tertiary: Color(0xFFFABD2F), // Yellow
    onTertiary: Color(0xFF302200),
    tertiaryContainer: Color(0xFF876200),
    onTertiaryContainer: Color(0xFFFFEFBF),
    error: Color(0xFFCC241D),
    onError: Color(0xFFFBF1C7),
    surface: Color(0xFF322C29), // Deep Peat / Warm Brown-Grey (No Blue!)
    onSurface: Color(0xFFEBDBB2), // Off-white
    surfaceContainerHighest: Color(0xFF504640), // Lighter Peat
    outline: Color(0xFFA89984),
  );

  static const _gruvboxLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF9D0006), // Dark Red
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDAD4),
    onPrimaryContainer: Color(0xFF410001),
    secondary: Color(0xFF79740E), // Dark Green
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE8EDAB),
    onSecondaryContainer: Color(0xFF1F1F00),
    tertiary: Color(0xFFB57614), // Dark Yellow
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE087),
    onTertiaryContainer: Color(0xFF291800),
    error: Color(0xFFCC241D),
    onError: Colors.white,
    surface: Color(0xFFFBF1C7), // Light Bg
    onSurface: Color(0xFF3C3836), // Dark Fg
    surfaceContainerHighest: Color(0xFFEBDBB2),
    outline: Color(0xFFA89984),
  );

  // ===========================================================================
  // 3. Catppuccin
  // ===========================================================================
  static const _catppuccinMocha = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFCBA6F7), // Mauve
    onPrimary: Color(0xFF1E1E2E),
    primaryContainer: Color(0xFF483275),
    onPrimaryContainer: Color(0xFFEADCF9),
    secondary: Color(0xFFA6E3A1), // Green
    onSecondary: Color(0xFF1E1E2E),
    secondaryContainer: Color(0xFF2F542D),
    onSecondaryContainer: Color(0xFFD5F2D3),
    tertiary: Color(0xFF89B4FA), // Blue
    onTertiary: Color(0xFF1E1E2E),
    tertiaryContainer: Color(0xFF26406E),
    onTertiaryContainer: Color(0xFFD3E2FD),
    error: Color(0xFFF38BA8), // Red
    onError: Color(0xFF1E1E2E),
    surface: Color(0xFF1E1E2E), // Base
    onSurface: Color(0xFFCDD6F4), // Text
    surfaceContainerHighest: Color(0xFF313244), // Surface0
    outline: Color(0xFF6C7086), // Overlay0
  );

  static const _catppuccinLatte = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF8839EF), // Mauve
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFEADCF9),
    onPrimaryContainer: Color(0xFF33096D),
    secondary: Color(0xFF40A02B), // Green
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD5F2D3),
    onSecondaryContainer: Color(0xFF0D2B06),
    tertiary: Color(0xFF1E66F5), // Blue
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFD3E2FD),
    onTertiaryContainer: Color(0xFF001946),
    error: Color(0xFFD20F39), // Red
    onError: Colors.white,
    surface: Color(0xFFEFF1F5), // Base
    onSurface: Color(0xFF4C4F69), // Text
    surfaceContainerHighest: Color(0xFFE6E9EF), // Surface0
    outline: Color(0xFF9CA0B0), // Overlay0
  );

  // ===========================================================================
  // 4. Kanagawa
  // ===========================================================================
  static const _kanagawaWave = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF7E9CD8), // Crystal Blue
    onPrimary: Color(0xFF16161D),
    primaryContainer: Color(0xFF2D4F67),
    onPrimaryContainer: Color(0xFFDCE4F6),
    secondary: Color(0xFF98BB6C), // Spring Green
    onSecondary: Color(0xFF16161D),
    secondaryContainer: Color(0xFF475C28),
    onSecondaryContainer: Color(0xFFE6F0DA),
    tertiary: Color(0xFFD27E99), // Sakura Pink
    onTertiary: Color(0xFF16161D),
    tertiaryContainer: Color(0xFF5F283B),
    onTertiaryContainer: Color(0xFFF4DDE4),
    error: Color(0xFFC34043), // Samurai Red
    onError: Color(0xFFDCD7BA),
    surface: Color(0xFF1F1F28), // Sumi Ink
    onSurface: Color(0xFFDCD7BA), // Fuji White
    surfaceContainerHighest: Color(0xFF2A2A37),
    outline: Color(0xFF727169),
  );

  static const _kanagawaLotus = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF43557A), // Darker Blue
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFC5D3F0),
    onPrimaryContainer: Color(0xFF121928),
    secondary: Color(0xFF59703B), // Darker Green
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD6E6C2),
    onSecondaryContainer: Color(0xFF1A230F),
    tertiary: Color(0xFF8C4B5F), // Darker Pink
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFF0CDDA),
    onTertiaryContainer: Color(0xFF33121D),
    error: Color(0xFFC84053),
    onError: Colors.white,
    surface: Color(0xFFF2F4F8), // Lotus White
    onSurface: Color(0xFF43436C), // Ink
    surfaceContainerHighest: Color(0xFFE6E8EC),
    outline: Color(0xFF8A8A9E),
  );

  // ===========================================================================
  // 5. Rosé Pine
  // ===========================================================================
  static const _rosePineDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFEBBCBA), // Rose
    onPrimary: Color(0xFF191724),
    primaryContainer: Color(0xFF754D4C),
    onPrimaryContainer: Color(0xFFFAF4F4),
    secondary: Color(0xFF31748F), // Pine
    onSecondary: Color(0xFFE0DEF4),
    secondaryContainer: Color(0xFF15323E),
    onSecondaryContainer: Color(0xFFCBE3EC),
    tertiary: Color(0xFFF6C177), // Gold
    onTertiary: Color(0xFF191724),
    tertiaryContainer: Color(0xFF634525),
    onTertiaryContainer: Color(0xFFFDF5E8),
    error: Color(0xFFEB6F92), // Love
    onError: Color(0xFF191724),
    surface: Color(0xFF191724), // Base
    onSurface: Color(0xFFE0DEF4), // Text
    surfaceContainerHighest: Color(0xFF26233A), // Surface
    outline: Color(0xFF908CAA), // Muted
  );

  static const _rosePineDawn = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFD7827E), // Rose (darker)
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFE6E4),
    onPrimaryContainer: Color(0xFF572321),
    secondary: Color(0xFF286983), // Pine (darker)
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD3ECF5),
    onSecondaryContainer: Color(0xFF092633),
    tertiary: Color(0xFFEA9D34), // Gold (darker)
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFF3D9),
    onTertiaryContainer: Color(0xFF5C3A0B),
    error: Color(0xFFB4637A),
    onError: Colors.white,
    surface: Color(0xFFFAF4F4), // Base
    onSurface: Color(0xFF575279), // Text
    surfaceContainerHighest: Color(0xFFF2E9E1),
    outline: Color(0xFF9893A5),
  );

  // ===========================================================================
  // 6. Rose of Dune (Golden Warmth)
  // ===========================================================================
  static const _duneDark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFE09F3E), // Golden Sand
    onPrimary: Color(0xFF291C0A),
    primaryContainer: Color(0xFF754C18), // Deep Gold Brown
    onPrimaryContainer: Color(0xFFFFE7C9),
    secondary: Color(0xFFB85C00), // Muted Spice
    onSecondary: Color(0xFF3E1F00),
    secondaryContainer: Color(0xFF6E3600),
    onSecondaryContainer: Color(0xFFFFDCC2),
    tertiary: Color(0xFF5C8DA3), // Grey-Blue (Sky)
    onTertiary: Color(0xFF002C3B),
    tertiaryContainer: Color(0xFF0E475C),
    onTertiaryContainer: Color(0xFFC7E8FF),
    error: Color(0xFFC0392B),
    onError: Color(0xFFFFFFFF),
    surface: Color(0xFF241E19), // Dark Umber (No Red)
    onSurface: Color(0xFFEBE0D6), // Pale Sand
    surfaceContainerHighest: Color(0xFF3D342E), // Lighter Umber
    outline: Color(0xFF8F7F73),
  );

  static const _duneLight = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFBA4A00), // Darker Spice
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFDCC2),
    onPrimaryContainer: Color(0xFF3E1600),
    secondary: Color(0xFFA04000), // Darker Red
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFD6C2),
    onSecondaryContainer: Color(0xFF381200),
    tertiary: Color(0xFF2980B9), // Water Blue
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFC2E5FF),
    onTertiaryContainer: Color(0xFF002642),
    error: Color(0xFFA93226),
    onError: Colors.white,
    surface: Color(0xFFFDEBD0), // Light Sand
    onSurface: Color(0xFF5D4037), // Dark Brown
    surfaceContainerHighest: Color(0xFFF6DDC7),
    outline: Color(0xFFB9770E),
  );
}
