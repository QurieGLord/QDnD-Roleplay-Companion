// Wave 3 renders of the native port, compared side by side with the
// prototype (docs/prototypes/wave3). Opt-in: QDND_RENDER_DIR=/some/dir,
// QDND_RENDER_ONLY=<name> renders one scene.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/combat_state.dart';
import 'package:qd_and_d/core/models/combat_turn.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/game_console.dart';
import 'package:qd_and_d/features/character_sheet/widgets/overview_tab.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/armor_class_sheet.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/condition_chips.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/hp_keypad_sheet.dart';
import 'package:qd_and_d/features/character_sheet/widgets/session/rest_sheet.dart';
import 'package:qd_and_d/features/combat/arsenal.dart';
import 'package:qd_and_d/features/combat/combat_tracker_screen.dart';
import 'package:qd_and_d/features/combat/turn_panel.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/dice_roller_modal.dart';

final _out = Platform.environment['QDND_RENDER_DIR'];
final _only = Platform.environment['QDND_RENDER_ONLY'];
bool _skip(String name) => _out == null || (_only != null && _only != name);

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

  Future<void> shoot(WidgetTester tester, String name, Character hero, {Widget? page, Future<void> Function(BuildContext)? open, double height = 844}) async {
    await tester.runAsync(() => Hive.box<Character>('characters').put(hero.id, hero));
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

  testWidgets('overview', (tester) async {
    if (_skip('overview')) return;
    final hero = veteran('paladin')
      ..currentHp = 100
      ..temporaryHp = 8
      ..activeConditions = [ConditionType.frightened, ConditionType.poisoned];
    await shoot(tester, 'w3-overview', hero,
        page: Scaffold(body: OverviewTab(character: hero, onCharacterUpdated: () {})));
  });

  testWidgets('brink', (tester) async {
    if (_skip('brink')) return;
    final hero = veteran('rogue')..currentHp = 0;
    hero.deathSaves.successes = 1;
    hero.deathSaves.failures = 2;
    await shoot(tester, 'w3-brink', hero,
        page: Scaffold(body: OverviewTab(character: hero, onCharacterUpdated: () {})));
  });

  testWidgets('hp sheet', (tester) async {
    if (_skip('hp')) return;
    final hero = veteran('barbarian')..isRaging = true;
    await shoot(tester, 'w3-hp', hero, open: (c) => showHpKeypad(c, hero));
  });

  testWidgets('conditions sheet', (tester) async {
    if (_skip('conditions')) return;
    final hero = veteran('monk')
      ..activeConditions = [ConditionType.grappled]
      ..exhaustionLevel = 3;
    await shoot(tester, 'w3-conditions', hero, open: (c) => showConditionPicker(c, hero), height: 1900);
  });

  testWidgets('rest sheet', (tester) async {
    if (_skip('rest')) return;
    final hero = veteran('ranger')..currentHp = 60;
    await shoot(tester, 'w3-rest-short', hero, open: (c) => showRestSheet(c, hero, short: true));
  });

  testWidgets('long rest sheet', (tester) async {
    if (_skip('rest-long')) return;
    final hero = veteran('wizard')..currentHp = 40;
    await shoot(tester, 'w3-rest-long', hero, open: (c) => showRestSheet(c, hero, short: false));
  });

  testWidgets('armor class', (tester) async {
    if (_skip('ac')) return;
    final hero = veteran('paladin');
    await shoot(tester, 'w3-ac', hero, open: (c) => showArmorClassBreakdown(c, hero));
  });

  testWidgets('console', (tester) async {
    if (_skip('console')) return;
    final hero = veteran('druid');
    await shoot(tester, 'w3-console', hero, open: (c) => showGameConsole(c, hero));
  });

  testWidgets('dice', (tester) async {
    if (_skip('dice')) return;
    final hero = veteran('bard');
    await shoot(tester, 'w3-dice', hero, open: (c) async => showDiceRoller(c, title: 'Атака', modifier: 7));
  });

  testWidgets('combat', (tester) async {
    if (_skip('combat')) return;
    final hero = veteran('paladin')
      ..currentHp = 96
      ..temporaryHp = 8;
    hero.combatState.startCombat(14);
    hero.combatState.currentRound = 3;
    hero.isSacredWeaponActive = true;
    CombatTurn(hero.combatState)
      ..setUsed(TurnCost.bonus, true)
      ..moved = 10
      ..addEffect(const CombatEffect(
          key: 'sacred', name: 'Священное оружие', icon: 'sword', accent: 2, left: 8, max: 10));
    hero.combatState.addLogEntry(CombatLogEntry(
        id: 'a', timestamp: DateTime(2026), type: CombatLogType.roundStart, description: 'Раунд 3', round: 3));
    await shoot(tester, 'w3-combat', hero, page: CombatTrackerScreen(character: hero), height: 1500);
  });

  testWidgets('arsenal spells', (tester) async {
    if (_skip('arsenal')) return;
    final hero = veteran('wizard');
    hero.combatState.startCombat(14);
    await shoot(tester, 'w3-arsenal', hero, open: (c) => showArsenalSheet(c, hero, ArsenalTab.spells), height: 1400);
  });

  testWidgets('arsenal features', (tester) async {
    if (_skip('feats')) return;
    final hero = veteran('paladin');
    hero.combatState.startCombat(14);
    await shoot(tester, 'w3-feats', hero, open: (c) => showArsenalSheet(c, hero, ArsenalTab.feats), height: 1000);
  });

  testWidgets('attack', (tester) async {
    if (_skip('attack')) return;
    final hero = veteran('paladin');
    hero.combatState.startCombat(14);
    final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
    await shoot(tester, 'w3-attack', hero,
        open: (c) => showAttackSheet(c, hero, weaponAttacks(hero, l10n, 'ru').first));
  });

  testWidgets('lay on hands', (tester) async {
    if (_skip('lay')) return;
    final hero = veteran('paladin')..currentHp = 100;
    hero.combatState.startCombat(14);
    final lay = hero.features.firstWhere((f) => f.id.contains('lay-on-hands') || f.id.contains('lay_on_hands'));
    await shoot(tester, 'w3-lay', hero, open: (c) => showFeatureInstrument(c, hero, lay));
  });

  testWidgets('movement', (tester) async {
    if (_skip('move')) return;
    final hero = veteran('monk');
    await shoot(tester, 'w3-move', hero,
        open: (c) => showMovementSheet(c, kicker: hero.name, speed: hero.speed, moved: 15, dash: false));
  });
}
