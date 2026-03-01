import 'package:flutter/material.dart';
import 'storage_service.dart';
import '../theme/app_palettes.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppColorPreset _colorPreset = AppColorPreset.qMonokai;
  bool _isHighContrast = false;

  ThemeMode get themeMode => _themeMode;
  AppColorPreset get colorPreset => _colorPreset;
  bool get isHighContrast => _isHighContrast;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load Mode
    final modeString =
        StorageService.getSetting('theme_mode', defaultValue: 'system');
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == modeString,
      orElse: () => ThemeMode.system,
    );

    // Load Preset
    final presetString =
        StorageService.getSetting('theme_preset', defaultValue: 'qMonokai');
    _colorPreset = AppColorPreset.values.firstWhere(
      (e) => e.toString() == presetString,
      orElse: () => AppColorPreset.qMonokai,
    );

    // Load High Contrast
    _isHighContrast =
        StorageService.getSetting('high_contrast', defaultValue: false);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await StorageService.saveSetting('theme_mode', mode.toString());
    notifyListeners();
  }

  Future<void> setColorPreset(AppColorPreset preset) async {
    _colorPreset = preset;
    await StorageService.saveSetting('theme_preset', preset.toString());
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    _isHighContrast = value;
    await StorageService.saveSetting('high_contrast', value);
    notifyListeners();
  }

  ThemeData get lightTheme => _createTheme(Brightness.light);
  ThemeData get darkTheme => _createTheme(Brightness.dark);

  ThemeData _createTheme(Brightness brightness) {
    final originalScheme = AppPalettes.getScheme(_colorPreset, brightness);

    // Apply High Contrast adjustments to colors if enabled
    final colorScheme =
        _isHighContrast ? _sharpenColors(originalScheme) : originalScheme;

    // Base Theme
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Roboto', // Or custom font if added
    );

    // High Contrast Border definition
    final highContrastBorder = _isHighContrast
        ? BorderSide(color: colorScheme.primary, width: 2)
        : BorderSide.none;

    final highContrastShape = _isHighContrast
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), side: highContrastBorder)
        : null; // Default shapes apply otherwise

    // Customize Components
    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        shape: _isHighContrast
            ? Border(bottom: BorderSide(color: colorScheme.primary, width: 2))
            : null,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: _isHighContrast
            ? 0
            : 2, // Remove elevation in HC mode to emphasize border
        shape: _isHighContrast
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: highContrastBorder)
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: highContrastShape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: _isHighContrast ? 0 : null,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: highContrastShape ??
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: _isHighContrast ? 0 : null,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        shape: _isHighContrast
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: highContrastBorder)
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: _isHighContrast ? 0 : 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: _isHighContrast
              ? BorderSide(color: colorScheme.primary, width: 2)
              : BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: colorScheme.primary, width: _isHighContrast ? 3 : 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color:
            _isHighContrast ? colorScheme.primary : colorScheme.outlineVariant,
        thickness: _isHighContrast ? 2 : 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: highContrastShape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: colorScheme.secondary,
        textColor: colorScheme.onSurface,
        // In HC mode, we might want ListTiles to have borders too if they are distinct blocks
      ),
      dialogTheme: DialogThemeData(
        shape: _isHighContrast
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: highContrastBorder)
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: _isHighContrast
            ? RoundedRectangleBorder(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                side: highContrastBorder)
            : const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: _isHighContrast
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: highContrastBorder)
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ColorScheme _sharpenColors(ColorScheme original) {
    // A simple implementation to "sharpen" colors could be to
    // ensure high contrast between background and foreground.
    // For now, we will just boost the primary/secondary slightly if they are muted,
    // but since our palettes are already quite specific, the main "High Contrast"
    // feature comes from the BORDERS which define boundaries clearly.

    // However, to strictly follow "sharper and saturated", we can try to saturate:
    return original.copyWith(
      primary: _saturate(original.primary),
      secondary: _saturate(original.secondary),
      tertiary: _saturate(original.tertiary),
      // Make surface darker in dark mode for better contrast against text
      surface: original.brightness == Brightness.dark
          ? const Color(0xFF000000) // Pure black for max contrast in dark mode
          : const Color(
              0xFFFFFFFF), // Pure white for max contrast in light mode
    );
  }

  Color _saturate(Color color) {
    final hsl = HSLColor.fromColor(color);
    // Increase saturation by 20%, cap at 1.0
    return hsl.withSaturation((hsl.saturation + 0.2).clamp(0.0, 1.0)).toColor();
  }
}
