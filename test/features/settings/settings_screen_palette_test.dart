import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';

import 'settings_test_harness.dart';

void main() {
  test('AppPalettes resolves legacy palette values', () {
    for (final legacyValue in [
      'qMonokai',
      'AppColorPreset.qMonokai',
      'AppColorPreset.kanagawa',
      'AppColorPreset.rosePine',
    ]) {
      expect(AppPalettes.parsePreset(legacyValue), AppColorPreset.monokai);
    }
  });

  test('AppPalettes keeps canonical anchor colors', () {
    final monokaiDark = AppPalettes.getScheme(
      AppColorPreset.monokai,
      Brightness.dark,
    );
    expect(monokaiDark.surface, const Color(0xFF272822));
    expect(monokaiDark.primary, const Color(0xFFF92672));
    expect(monokaiDark.secondary, const Color(0xFF66D9EF));
    expect(monokaiDark.tertiary, const Color(0xFFFD971F));
    expect(monokaiDark.onSurface, const Color(0xFFF8F8F2));

    final monokaiLight = AppPalettes.getScheme(
      AppColorPreset.monokai,
      Brightness.light,
    );
    expect(monokaiLight.primary, const Color(0xFFF92672));
    expect(monokaiLight.secondary, const Color(0xFF008EA6));
    expect(monokaiLight.tertiary, const Color(0xFFC26900));

    final gruvboxLight = AppPalettes.getScheme(
      AppColorPreset.gruvbox,
      Brightness.light,
    );
    expect(gruvboxLight.surface, const Color(0xFFFBF1C7));
    expect(gruvboxLight.primary, const Color(0xFFAF3A03));
    expect(gruvboxLight.secondary, const Color(0xFF427B58));
    expect(gruvboxLight.tertiary, const Color(0xFFB57614));

    final gruvboxDark = AppPalettes.getScheme(
      AppColorPreset.gruvbox,
      Brightness.dark,
    );
    expect(gruvboxDark.surface, const Color(0xFF282828));
    expect(gruvboxDark.primary, const Color(0xFFFE8019));
    expect(gruvboxDark.secondary, const Color(0xFF83A598));
    expect(gruvboxDark.tertiary, const Color(0xFFFABD2F));
    expect(gruvboxDark.onSurface, const Color(0xFFEBDBB2));
    expect(gruvboxDark.surfaceContainerHigh, const Color(0xFF504945));

    final catppuccinLight = AppPalettes.getScheme(
      AppColorPreset.catppuccin,
      Brightness.light,
    );
    expect(catppuccinLight.primary, const Color(0xFF8839EF));
    expect(catppuccinLight.secondary, const Color(0xFF1E66F5));
    expect(catppuccinLight.tertiary, const Color(0xFFEA76CB));

    final catppuccinDark = AppPalettes.getScheme(
      AppColorPreset.catppuccin,
      Brightness.dark,
    );
    expect(catppuccinDark.primary, const Color(0xFFCBA6F7));
    expect(catppuccinDark.secondary, const Color(0xFF89B4FA));
    expect(catppuccinDark.tertiary, const Color(0xFFF5C2E7));

    final nordLight = AppPalettes.getScheme(
      AppColorPreset.nord,
      Brightness.light,
    );
    expect(nordLight.surface, const Color(0xFFECEFF4));
    expect(nordLight.primary, const Color(0xFF5E81AC));
    expect(nordLight.secondary, const Color(0xFF88C0D0));
    expect(nordLight.tertiary, const Color(0xFF8FBCBB));
    expect(nordLight.onSurface, const Color(0xFF2E3440));

    final everforestDark = AppPalettes.getScheme(
      AppColorPreset.everforest,
      Brightness.dark,
    );
    expect(everforestDark.primary, const Color(0xFFA7C080));
    expect(everforestDark.secondary, const Color(0xFFDBBC7F));
    expect(everforestDark.tertiary, const Color(0xFF83C092));

    final roseOfDuneDark = AppPalettes.getScheme(
      AppColorPreset.roseOfDune,
      Brightness.dark,
    );
    expect(roseOfDuneDark.primary, const Color(0xFFE8B965));
    expect(roseOfDuneDark.secondary, const Color(0xFFE08F87));
    expect(roseOfDuneDark.tertiary, const Color(0xFFCFA76A));
  });

  test('AppPalettes keeps large surfaces quiet for expressive palettes', () {
    const monokaiGreen = Color(0xFFA6E22E);
    final monokaiDark = AppPalettes.getScheme(
      AppColorPreset.monokai,
      Brightness.dark,
    );
    expect(monokaiDark.secondary, isNot(monokaiGreen));
    expect(monokaiDark.secondaryContainer, isNot(monokaiGreen));
    expect(monokaiDark.surfaceContainerHigh, isNot(monokaiGreen));
    expect(monokaiDark.surfaceContainerHigh, const Color(0xFF49483E));
    expect(_isCyanish(monokaiDark.secondary), isTrue);

    final monokaiLight = AppPalettes.getScheme(
      AppColorPreset.monokai,
      Brightness.light,
    );
    expect(_isCyanish(monokaiLight.secondary), isTrue);
    expect(_isGreenish(monokaiLight.surfaceContainerHigh), isFalse);

    final gruvboxDark = AppPalettes.getScheme(
      AppColorPreset.gruvbox,
      Brightness.dark,
    );
    expect(gruvboxDark.surfaceContainerHigh, const Color(0xFF504945));
    expect(_isGreenish(gruvboxDark.surfaceContainerHigh), isFalse);

    final roseLight = AppPalettes.getScheme(
      AppColorPreset.roseOfDune,
      Brightness.light,
    );
    expect(roseLight.surface, const Color(0xFFFFF8EE));
    expect(roseLight.surfaceContainerHigh, const Color(0xFFEDE0CF));
    expect(
        _channelRange(roseLight.surfaceContainerHigh), lessThanOrEqualTo(31));
    expect(_green(roseLight.surfaceContainerHigh),
        greaterThanOrEqualTo(_red(roseLight.surfaceContainerHigh) - 16));
  });

  group('SettingsScreen palettes', () {
    configureSettingsStorageHarness('qdnd_settings_palette_');

    testWidgets('SettingsScreen exposes only imported palettes', (
      tester,
    ) async {
      expect(
        AppColorPreset.values,
        orderedEquals([
          AppColorPreset.monokai,
          AppColorPreset.gruvbox,
          AppColorPreset.catppuccin,
          AppColorPreset.nord,
          AppColorPreset.everforest,
          AppColorPreset.roseOfDune,
        ]),
      );

      final themeProvider = ThemeProvider();
      final localeProvider = LocaleProvider();

      await pumpSettingsScreen(
        tester,
        themeProvider: themeProvider,
        localeProvider: localeProvider,
      );

      for (final preset in AppColorPreset.values) {
        expect(
          find.byKey(Key('settings_palette_${preset.name}')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('settings_palette_kanagawa')), findsNothing);
      expect(find.byKey(const Key('settings_palette_rosePine')), findsNothing);
    });

    testWidgets('SettingsScreen changes color preset', (tester) async {
      final themeProvider = ThemeProvider();
      final localeProvider = LocaleProvider();

      await pumpSettingsScreen(
        tester,
        themeProvider: themeProvider,
        localeProvider: localeProvider,
      );

      final gruvboxFinder = find.byKey(const Key('settings_palette_gruvbox'));
      await tester.ensureVisible(gruvboxFinder);
      await pumpInteraction(tester);
      await tester.tap(gruvboxFinder);
      await pumpInteraction(tester);
      await waitForSetting(
        tester,
        'theme_preset',
        AppColorPreset.gruvbox.toString(),
      );

      expect(themeProvider.colorPreset, AppColorPreset.gruvbox);
    });
  });
}

bool _isCyanish(Color color) {
  return _blue(color) > _red(color) && _green(color) > _red(color);
}

bool _isGreenish(Color color) {
  return _green(color) > _red(color) && _green(color) > _blue(color);
}

int _channelRange(Color color) {
  final channels = [_red(color), _green(color), _blue(color)]..sort();
  return channels.last - channels.first;
}

int _red(Color color) => _colorChannel(color.r);

int _green(Color color) => _colorChannel(color.g);

int _blue(Color color) => _colorChannel(color.b);

int _colorChannel(double value) {
  return (value * 255).round().clamp(0, 255).toInt();
}
