import 'package:flutter/material.dart';

import '../theme/app_palettes.dart';
import '../theme/app_tokens.dart';
import '../ui/app_menu_style.dart';
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
    final paletteScheme = AppPalettes.getScheme(_colorPreset, brightness);
    final colorScheme =
        _isBasicMode ? AppPalettes.calmScheme(paletteScheme) : paletteScheme;
    final accents = AppPalettes.accents(_colorPreset, brightness);

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: AppType.body,
    );

    RoundedRectangleBorder rounded(double radius) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    // A plain button has no state to show: it stays a capsule and answers a
    // press with its tone (the Material state layer), not with its shape.
    const buttonShape = WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());
    const buttonMotion = Duration(milliseconds: 220);

    return baseTheme.copyWith(
      extensions: [
        _isBasicMode ? AppPalettes.calmAccents(accents) : accents,
        AppCalm(_isBasicMode ? 1 : 0),
      ],
      textTheme: AppType.textTheme(baseTheme.textTheme),
      primaryTextTheme: AppType.textTheme(baseTheme.primaryTextTheme),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: _isBasicMode ? 1 : 2,
        shape: rounded(AppRadii.xl),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          elevation: _isBasicMode ? 1 : null,
          animationDuration: buttonMotion,
        ).copyWith(shape: buttonShape),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: _isBasicMode ? 1 : null,
          animationDuration: buttonMotion,
        ).copyWith(shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(animationDuration: buttonMotion)
            .copyWith(shape: buttonShape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(animationDuration: buttonMotion)
            .copyWith(shape: buttonShape),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiaryContainer,
        foregroundColor: colorScheme.onTertiaryContainer,
        shape: rounded(AppRadii.lgPlus),
        elevation: _isBasicMode ? 3 : 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          borderSide: _isBasicMode
              ? BorderSide(color: colorScheme.outline)
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          borderSide: _isBasicMode
              ? BorderSide(color: colorScheme.outline.withValues(alpha: .5))
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
          borderSide: BorderSide(
              color: colorScheme.secondary, width: _isBasicMode ? 2 : 1.2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: rounded(AppRadii.lgPlus),
        iconColor: colorScheme.secondary,
        textColor: colorScheme.onSurface,
      ),
      dialogTheme: DialogThemeData(shape: rounded(AppRadii.xl)),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
      ),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      popupMenuTheme: PopupMenuThemeData(
          shape: AppMenuStyle.shape,
          color: colorScheme.surfaceContainerHigh,
          surfaceTintColor: Colors.transparent,
          elevation: 4),
      dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
              shape: const WidgetStatePropertyAll(AppMenuStyle.shape),
              backgroundColor:
                  WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
              surfaceTintColor:
                  const WidgetStatePropertyAll(Colors.transparent),
              elevation: const WidgetStatePropertyAll(4))),
      menuTheme: MenuThemeData(
          style: MenuStyle(
              shape: const WidgetStatePropertyAll(AppMenuStyle.shape),
              backgroundColor:
                  WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
              elevation: const WidgetStatePropertyAll(4))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        backgroundColor: colorScheme.surfaceContainerHigh,
        contentTextStyle:
            TextStyle(fontFamily: AppType.body, color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
      ),
    );
  }
}
