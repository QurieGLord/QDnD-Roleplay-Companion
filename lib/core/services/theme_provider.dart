import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'storage_service.dart';
import '../theme/app_palettes.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  AppColorPreset _colorPreset = AppColorPreset.qMonokai;

  ThemeMode get themeMode => _themeMode;
  AppColorPreset get colorPreset => _colorPreset;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Load Mode
    final modeString = StorageService.getSetting('theme_mode', defaultValue: 'system');
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == modeString,
      orElse: () => ThemeMode.system,
    );

    // Load Preset
    final presetString = StorageService.getSetting('theme_preset', defaultValue: 'qMonokai');
    _colorPreset = AppColorPreset.values.firstWhere(
      (e) => e.toString() == presetString,
      orElse: () => AppColorPreset.qMonokai,
    );

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

  ThemeData get lightTheme => _createTheme(Brightness.light);
  ThemeData get darkTheme => _createTheme(Brightness.dark);

  ThemeData _createTheme(Brightness brightness) {
    final colorScheme = AppPalettes.getScheme(_colorPreset, brightness);
    
    // Base Theme
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Roboto', // Or custom font if added
    );

    // Customize Components
    return baseTheme.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      
      /*
      cardTheme: CardTheme(
        color: colorScheme.surfaceContainerLow,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      */
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: colorScheme.secondary,
        textColor: colorScheme.onSurface,
      ),
    );
  }
}
