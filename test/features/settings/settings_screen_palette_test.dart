import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_palette_');

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
}
