import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/settings/settings_screen.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

void configureSettingsStorageHarness(String tempPrefix) {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(tempPrefix);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => tempDir.path,
    );
    await StorageService.init();
  });

  setUp(() async {
    await StorageService.clearAll();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });
}

Future<void> pumpSettingsScreen(
  WidgetTester tester, {
  required ThemeProvider themeProvider,
  required LocaleProvider localeProvider,
  bool disableAnimations = false,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 120));
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: _SettingsTestApp(disableAnimations: disableAnimations),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> pumpInteraction(
  WidgetTester tester, [
  Duration duration = const Duration(milliseconds: 260),
]) async {
  await tester.pump();
  await tester.pump(duration);
}

Future<void> waitForSetting(
  WidgetTester tester,
  String key,
  dynamic expected,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));

  while (StorageService.getSetting(key) != expected &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 40));
  }

  expect(StorageService.getSetting(key), expected);
}

class _SettingsTestApp extends StatelessWidget {
  const _SettingsTestApp({
    required this.disableAnimations,
  });

  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) {
        return MaterialApp(
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: disableAnimations,
              ),
              child: child!,
            );
          },
          home: const SettingsScreen(),
        );
      },
    );
  }
}
