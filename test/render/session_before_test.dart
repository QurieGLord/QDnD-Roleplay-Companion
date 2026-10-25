// "Before" shots of the wave 3 screens (session and combat) for
// docs/prototypes/wave3/before. Opt-in: QDND_RENDER_DIR=/some/dir.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_sheet/widgets/gameplay_state_editor.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/armor_class_sheet.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/condition_chips.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/hp_keypad_sheet.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/rest_sheet.dart';
import 'package:qd_and_d/features/combat/combat_tracker_screen.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/dice_roller_modal.dart';

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

  Character veteran(String id) => buildExpressiveCycleCharacters(levels: veteranCycleLevels, idPrefix: veteranCycleIdPrefix)
      .firstWhere((h) => h.characterClass == id);

  Future<void> shoot(WidgetTester tester, String name, Character hero, {Widget? page, Future<void> Function(BuildContext)? open}) async {
    await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
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
      home: page ??
          Scaffold(
              body: Builder(
                  builder: (context) => Center(child: TextButton(onPressed: () => open!(context), child: const Text('open'))))),
    ));
    if (open != null) await tester.tap(find.text('open'));
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

  testWidgets('combat', (tester) async {
    if (_out == null) return;
    final hero = veteran('paladin')
      ..currentHp = 96
      ..temporaryHp = 8;
    hero.combatState.startCombat(14);
    hero.combatState.currentRound = 3;
    hero.activeConditions = [ConditionType.frightened, ConditionType.poisoned];
    await shoot(tester, '01-combat', hero, page: CombatTrackerScreen(character: hero));
  });

  testWidgets('combat dying', (tester) async {
    if (_out == null) return;
    final hero = veteran('rogue')..currentHp = 0;
    hero.combatState.startCombat(18);
    hero.deathSaves.successes = 1;
    hero.deathSaves.failures = 2;
    await shoot(tester, '02-combat-dying', hero, page: CombatTrackerScreen(character: hero));
  });

  testWidgets('hp keypad', (tester) async {
    if (_out == null) return;
    await shoot(tester, '03-hp-keypad', veteran('fighter'), open: (c) => showHpKeypad(c, veteran('fighter')));
  });

  testWidgets('conditions', (tester) async {
    if (_out == null) return;
    final hero = veteran('monk')..activeConditions = [ConditionType.grappled];
    await shoot(tester, '04-conditions', hero, open: (c) => showConditionPicker(c, hero));
  });

  testWidgets('short rest', (tester) async {
    if (_out == null) return;
    final hero = veteran('ranger')..currentHp = 60;
    await shoot(tester, '05-rest-short', hero, open: (c) => showRestSheet(c, hero, short: true));
  });

  testWidgets('long rest', (tester) async {
    if (_out == null) return;
    final hero = veteran('wizard')..currentHp = 40;
    await shoot(tester, '06-rest-long', hero, open: (c) => showRestSheet(c, hero, short: false));
  });


  testWidgets('armor class', (tester) async {
    if (_out == null) return;
    final hero = veteran('paladin');
    await shoot(tester, '08-armor-class', hero, open: (c) => showArmorClassBreakdown(c, hero));
  });

  testWidgets('game state editor', (tester) async {
    if (_out == null) return;
    final hero = veteran('druid');
    await shoot(tester, '09-state-editor', hero, open: (c) => showGameplayStateEditor(c, hero));
  });

  testWidgets('dice roller', (tester) async {
    if (_out == null) return;
    final hero = veteran('bard');
    await shoot(tester, '10-dice', hero, open: (c) async => showDiceRoller(c, title: 'Атака', modifier: 7));
  });
}
