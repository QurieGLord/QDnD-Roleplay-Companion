import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_contrast_');

  testWidgets('SettingsScreen toggles high contrast mode', (tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    final highContrastFinder =
        find.byKey(const Key('settings_high_contrast_toggle'));
    await tester.ensureVisible(highContrastFinder);
    await pumpInteraction(tester);
    await tester.tap(highContrastFinder);
    await pumpInteraction(tester);
    await waitForSetting(tester, 'high_contrast', true);

    expect(themeProvider.isHighContrast, isTrue);
  });
}
