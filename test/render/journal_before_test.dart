// "Before" shots of the wave 4 screens (the journal) for
// docs/prototypes/wave4/before. Opt-in: QDND_RENDER_DIR=/some/dir.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_sheet/tabs/journal_tab.dart';
import 'package:qd_and_d/features/journal/cycle_fixture.dart';
import 'package:qd_and_d/core/journal/journal_service.dart';
import 'package:qd_and_d/features/journal/journal_atlas_page.dart';
import 'package:qd_and_d/features/journal/journal_entry_editor.dart';
import 'package:qd_and_d/features/journal/journal_entry_page.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

final _out = Platform.environment['QDND_RENDER_DIR'];

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(rootBundle.load('assets/fonts/$f'));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    if (_out == null) return;
    dir = await Directory.systemTemp.createTemp('qdnd-before-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    await _font('Rubik', ['Rubik-Regular.ttf', 'Rubik-Medium.ttf', 'Rubik-SemiBold.ttf']);
    try {
      await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    } catch (_) {}
    await _font('Inter', ['Inter-Regular.ttf', 'Inter-Medium.ttf', 'Inter-SemiBold.ttf', 'Inter-Bold.ttf']);
  });
  tearDownAll(() async {
    if (_out == null) return;
    await Hive.close();
  });

  Future<Character> hero(WidgetTester tester) async {
    await tester.runAsync(seedJournalCycle);
    return StorageService.getCharacter('cycle-journal-working-20261008')!;
  }

  Future<void> shoot(WidgetTester tester, String name, Widget page, {double height = 844}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider().darkTheme,
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => RepaintBoundary(key: key, child: child),
      home: page,
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    addTearDown(tester.view.reset);
  }

  testWidgets('journal tab', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    await shoot(tester, '01-journal', Scaffold(body: JournalTab(character: c)), height: 1600);
  });

  testWidgets('note page', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    await shoot(tester, '02-note', JournalEntryPage(character: c, entryKey: 'n:cycle-last'), height: 1400);
  });

  testWidgets('quest page', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    await shoot(tester, '03-quest', JournalEntryPage(character: c, entryKey: 'q:cycle-find'), height: 1400);
  });

  testWidgets('note editor', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    final entry = JournalService.entries(c).firstWhere((e) => e.key == 'n:cycle-last');
    await shoot(tester, '04-editor', JournalEntryEditor(character: c, entry: entry), height: 1600);
  });

  testWidgets('quest editor', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    await shoot(tester, '05-quest-editor', JournalEntryEditor(character: c, quest: true), height: 1400);
  });

  testWidgets('atlas', (tester) async {
    if (_out == null) return;
    final c = await hero(tester);
    await shoot(tester, '06-atlas', JournalAtlasPage(character: c), height: 1400);
  });
}
