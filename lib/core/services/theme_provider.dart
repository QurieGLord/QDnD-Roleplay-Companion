import 'package:flutter/material.dart';

import '../theme/app_palettes.dart';
import 'storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  static const _themePresetKey = 'theme_preset';
  static const _basicModeStorageKey = 'high_contrast';

  ThemeMode _themeMode = ThemeMode.system;
  AppColorPreset _colorPreset = AppPalettes.fallbackPreset;
  bool _isBasicMode = false;

  ThemeMode get themeMode => _themeMode;
  AppColorPreset get colorPreset => _colorPreset;
  bool get isBasicMode => _isBasicMode;

  @Deprecated('Use isBasicMode instead.')
  bool get isHighContrast => _isBasicMode;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final modeString =
        StorageService.getSetting(_themeModeKey, defaultValue: 'system');
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == modeString,
      orElse: () => ThemeMode.system,
    );

    final presetValue = StorageService.getSetting(
      _themePresetKey,
      defaultValue: AppPalettes.fallbackPreset.toString(),
    );
    _colorPreset = AppPalettes.parsePreset(presetValue);
    if (!AppPalettes.isCanonicalStorageValue(presetValue, _colorPreset)) {
      await StorageService.saveSetting(
          _themePresetKey, _colorPreset.toString());
    }

    _isBasicMode =
        StorageService.getSetting(_basicModeStorageKey, defaultValue: false) ==
            true;

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await StorageService.saveSetting(_themeModeKey, mode.toString());
    notifyListeners();
  }

  Future<void> setColorPreset(AppColorPreset preset) async {
    _colorPreset = preset;
    await StorageService.saveSetting(_themePresetKey, preset.toString());
    notifyListeners();
  }

  Future<void> setBasicMode(bool value) async {
    _isBasicMode = value;
    await StorageService.saveSetting(_basicModeStorageKey, value);
    notifyListeners();
  }

  @Deprecated('Use setBasicMode instead.')
  Future<void> setHighContrast(bool value) => setBasicMode(value);

  ThemeData get lightTheme => _createTheme(Brightness.light);
  ThemeData get darkTheme => _createTheme(Brightness.dark);

  ThemeData _createTheme(Brightness brightness) {
    final colorScheme = _isBasicMode
        ? AppPalettes.getBasicScheme(brightness)
        : AppPalettes.getScheme(_colorPreset, brightness);

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
    );

    final rounded12 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final rounded28 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: _isBasicMode ? 1 : 2,
        shape: rounded16,
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: rounded12,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: _isBasicMode ? 1 : null,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: rounded12,
          elevation: _isBasicMode ? 1 : null,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        shape: rounded16,
        elevation: _isBasicMode ? 3 : 6,
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
          borderSide:
              BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: rounded12,
        iconColor: colorScheme.secondary,
        textColor: colorScheme.onSurface,
      ),
      dialogTheme: DialogThemeData(shape: rounded28),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(shape: rounded12),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}
