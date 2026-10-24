// Renders the Magic tab of every Cycle hero to PNG for a side-by-side check
// against docs/prototypes/wave2. Opt-in: QDND_RENDER_DIR=/some/dir.
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
import 'package:qd_and_d/features/character_level_up/cycle_fixture.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/features/expressive_cycle/custom_class_fixture.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/spell_cast_sheet.dart';

final _out = Platform.environment['QDND_RENDER_DIR'];

/// Puts a hero into its "in use" state for the second render pass.
void _activate(Character hero) {
  final id = hero.characterClass.toLowerCase();
  if (id.contains('barbarian')) {
    hero.isRaging = true;
    hero.isReckless = true;
    hero.exhaustionLevel = 1;
  }
  if (id.contains('druid')) {
    hero.isWildShaped = true;
    hero.beastName = 'Волк';
    hero.beastMaxHp = 11;
    hero.beastCurrentHp = 8;
  }
  if (id.contains('ranger')) {
    hero.isHuntersMarkActive = true;
    hero.huntersMarkTarget = 'Гнилой упырь';
  }
}

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
    dir = await Directory.systemTemp.createTemp('qdnd-render-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    stdout.writeln('R init');
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    stdout.writeln('R data');
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

  final only = Platform.environment['QDND_RENDER_ONLY'];
  testWidgets('render Magic tab of the Cycle roster', (tester) async {
    if (_out == null) return;
    final roster = Platform.environment['QDND_RENDER_VETERAN'] != null
        ? [...buildExpressiveCycleCharacters(levels: veteranCycleLevels), buildCustomClassCycleCharacter()]
        : Platform.environment['QDND_RENDER_HIGH'] != null
        ? [...buildExpressiveCycleCharacters(), buildCustomClassCycleCharacter()]
        : [...buildLevelUpCycleCharacters(), buildCustomClassCycleCharacter()];
    for (final hero in roster) {
      if (only != null && !hero.characterClass.toLowerCase().contains(only)) continue;
      if (Platform.environment['QDND_RENDER_ACTIVE'] != null) _activate(hero);
      await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390 * 2, 2600 * 2);
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
        home: RepaintBoundary(
          key: key,
          child: Scaffold(body: AbilitiesTab(key: ValueKey(hero.id), character: hero)),
        ),
      ));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      stdout.writeln('R pumped ${hero.characterClass}');
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = hero.characterClass.toLowerCase().replaceAll(' ', '_');
        stdout.writeln('R image');
        await File('$_out/magic-$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
    }
    addTearDown(tester.view.reset);
  });

  // QDND_RENDER_CAST=<spell id>: the cast sheet of that spell for the hero
  // picked by QDND_RENDER_ONLY, at phone size.
  final castId = Platform.environment['QDND_RENDER_CAST'];
  testWidgets('render the cast sheet', (tester) async {
    if (_out == null || castId == null) return;
    final hero = buildExpressiveCycleCharacters()
        .firstWhere((h) => only == null || h.characterClass.contains(only));
    final spell = SpellService.getSpellById(castId)!;
    await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    // A Pixel gesture bar: the sheet's button must stay above it.
    tester.view.viewPadding = const FakeViewPadding(bottom: 48 * 2);
    tester.view.padding = const FakeViewPadding(bottom: 48 * 2);
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
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showSpellCastSheet(context, hero, spell),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/cast-$castId.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
    addTearDown(tester.view.reset);
  });
}
