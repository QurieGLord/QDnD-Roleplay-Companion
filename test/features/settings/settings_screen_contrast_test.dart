import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_contrast_');

  testWidgets('SettingsScreen toggles Basic mode', (tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    final basicModeFinder = find.byKey(const Key('settings_basic_mode_toggle'));
    await tester.ensureVisible(basicModeFinder);
    await pumpInteraction(tester);
    await tester.tap(basicModeFinder);
    await pumpInteraction(tester);
    await waitForSetting(tester, 'high_contrast', true);

    expect(themeProvider.isBasicMode, isTrue);
  });
}
