import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';

import 'settings_test_harness.dart';

void main() {
  configureSettingsStorageHarness('qdnd_settings_theme_');

  testWidgets('SettingsScreen changes theme mode to dark', (tester) async {
    final themeProvider = ThemeProvider();
    final localeProvider = LocaleProvider();

    await pumpSettingsScreen(
      tester,
      themeProvider: themeProvider,
      localeProvider: localeProvider,
    );

    final darkFinder = find.descendant(
      of: find.byKey(const Key('settings_theme_segmented')),
      matching: find.text('Dark'),
    );
    await tester.ensureVisible(darkFinder);
    await pumpInteraction(tester);
    await tester.tap(darkFinder);
    await pumpInteraction(tester);
    await waitForSetting(
      tester,
      'theme_mode',
      ThemeMode.dark.toString(),
    );

    expect(themeProvider.themeMode, ThemeMode.dark);
  });
}
