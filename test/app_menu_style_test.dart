import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/ui/app_menu_style.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/models/quest.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'journal_service_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-menu-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  testWidgets('The quest state is a segment that saves in one tap',
      (tester) async {
    final c = fixtures.hero()
      ..quests.add(Quest(id: 'q', title: 'Find the keeper'));
    await tester.runAsync(() => StorageService.saveCharacter(c));
    final provider = ThemeProvider();
    await tester.pumpWidget(MaterialApp(
        theme: provider.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: JournalEntryPage(character: c, entryKey: 'q:q')));
    await tester.pumpAndSettle();
    final completed = find.byKey(const ValueKey('journal-status-1'));
    await tester.scrollUntilVisible(completed, 140,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Completed'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(completed);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(c.quests.single.status, QuestStatus.completed);
    expect(tester.takeException(), isNull);
    provider.dispose();
  });
  test(
      'Material menus share the same shape and palette in light and dark themes',
      () {
    final provider = ThemeProvider();
    for (final theme in [provider.lightTheme, provider.darkTheme]) {
      expect(theme.popupMenuTheme.shape, AppMenuStyle.shape);
      expect(theme.dropdownMenuTheme.menuStyle!.shape!.resolve({}),
          AppMenuStyle.shape);
      expect(
          theme.popupMenuTheme.color, theme.colorScheme.surfaceContainerHigh);
    }
    provider.dispose();
  });
}
