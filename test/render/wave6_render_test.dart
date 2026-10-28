// "After" shots of the wave 6 screens (level-up, advancement history,
// character creation) for docs/prototypes/wave6/after, to check against the
// accepted prototype side by side.
// Opt-in: QDND_RENDER_DIR=/some/dir, one scene with QDND_RENDER_ONLY=<name>.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/progression/level_up_commit.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/locale_provider.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/theme_provider.dart';
import 'package:qd_and_d/features/character_creation/character_creation_state.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/features/character_creation/prologue.dart';
import 'package:qd_and_d/features/character_level_up/level_up_screen.dart';
import 'package:qd_and_d/features/expressive_cycle/cycle_fixture.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/shared/widgets/advancement_history_sheet.dart';

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
    dir = await Directory.systemTemp.createTemp('qdnd-w6-after-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await SpellService.loadSpells();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await ItemService.loadItems();
    await _font('Rubik',
        ['Rubik-Regular.ttf', 'Rubik-Medium.ttf', 'Rubik-SemiBold.ttf']);
    try {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    } catch (_) {}
    await _font('Inter', [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
      'Inter-Bold.ttf'
    ]);
  });
  tearDownAll(() async {
    if (_out == null) return;
    await Hive.close();
  });

  Character hero(String cls, int level) =>
      buildExpressiveCycleCharacters(levels: {cls: level}, idPrefix: 'w6-')
          .firstWhere((c) => c.characterClass == cls);

  final key = GlobalKey();
  Future<void> pump(WidgetTester tester, Widget page,
      {double height = 844}) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(390 * 2, height * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
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
        )));
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$_out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  final next = find.byKey(const ValueKey('advancement-island-next'));

  testWidgets('levelup-fighter', (tester) async {
    if (_skip('levelup-fighter')) return;
    await pump(tester, LevelUpScreen(character: hero('fighter', 3)));
    await capture(tester, '01-lv-fighter-hp');
    await tester.tap(find.byKey(const ValueKey('advancement-route-0')));
    await settle(tester);
    await capture(tester, '00-lv-fighter-class');
    await tester.drag(find.byKey(const ValueKey('advancement-scroll')), const Offset(0, -700));
    await settle(tester);
    await capture(tester, '00b-lv-fighter-class-new');
    await tester.tap(next);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('hp-method-roll')));
    await settle(tester);
    await capture(tester, '02-lv-fighter-roll');
    await tester.tap(next);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('asi-ability-strength')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('asi-ability-dexterity')));
    await settle(tester);
    await capture(tester, '03-lv-fighter-asi');
    await tester.tap(next);
    await settle(tester);
    await capture(tester, '04-lv-fighter-summary');
    await finish(tester);
  });

  testWidgets('levelup-paladin', (tester) async {
    if (_skip('levelup-paladin')) return;
    await pump(tester, LevelUpScreen(character: hero('paladin', 2)));
    await tester.tap(next);
    await settle(tester);
    await capture(tester, '05-lv-paladin-features');
    await finish(tester);
  });

  testWidgets('levelup-wizard', (tester) async {
    if (_skip('levelup-wizard')) return;
    await pump(tester, LevelUpScreen(character: hero('wizard', 4)));
    await tester.tap(next);
    await settle(tester);
    await capture(tester, '06-lv-wizard-magic');
    await finish(tester);
  });

  testWidgets('levelup-warlock', (tester) async {
    if (_skip('levelup-warlock')) return;
    await pump(tester, LevelUpScreen(character: hero('warlock', 2)));
    await tester.tap(next);
    await settle(tester);
    await capture(tester, '06b-lv-warlock-features');
    final all = find.byKey(const ValueKey('advancement-choice-all'));
    if (all.evaluate().isNotEmpty) {
      await tester.ensureVisible(all);
      await settle(tester);
      await tester.tap(all);
      await settle(tester);
      await capture(tester, '06c-lv-warlock-all-options');
      await tester.tapAt(const Offset(195, 40));
      await settle(tester);
    }
    await finish(tester);
  });

  testWidgets('levelup-wizard-spells', (tester) async {
    if (_skip('levelup-wizard-spells')) return;
    await pump(tester, LevelUpScreen(character: hero('wizard', 4)));
    await tester.tap(next);
    await settle(tester);
    final pick = find.textContaining('Коснитесь, чтобы выбрать');
    if (pick.evaluate().isNotEmpty) {
      await tester.tap(pick.first);
      await settle(tester);
      await capture(tester, '06d-lv-wizard-spell-sheet');
    }
    await finish(tester);
  });

  testWidgets('history', (tester) async {
    if (_skip('history')) return;
    final h = hero('paladin', 4);
    // Two confirmed level-ups make two rungs that can be taken back.
    await tester.runAsync(() async {
      for (var i = 0; i < 2; i++) {
        final d = LevelUpDraft.begin(h, classId: 'paladin')..chooseHealth(6);
        await LevelUpCommit.apply(h,
            baseline: d, result: d.preview, write: (_) async {});
      }
    });
    await pump(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => Center(
                    child: TextButton(
                        onPressed: () => showAdvancementHistory(context, h),
                        child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await settle(tester);
    await capture(tester, '07-history');
    await tester.tap(find.text('Уровень героя 4 → 5'));
    await settle(tester);
    await capture(tester, '07-history-rollback');
    await finish(tester);
  });

  testWidgets('create', (tester) async {
    if (_skip('create')) return;
    await pump(tester, const CharacterCreationWizard());
    final state = tester
        .element(find.byType(Prologue))
        .read<CharacterCreationState>();
    final next = find.byKey(const ValueKey('prologue-island')).last;
    Future<void> forward() async {
      await tester.tap(find.descendant(
          of: next, matching: find.byKey(const ValueKey('advancement-island-next'))));
      await settle(tester);
    }

    await capture(tester, '08-create-name-empty');
    await tester.enterText(find.byKey(const ValueKey('prologue-name')), 'Лира');
    await settle(tester);
    await capture(tester, '09-create-name');
    await forward();
    state.updateRace(CharacterDataService.shelfRaces()
        .firstWhere((r) => r.subraces.isNotEmpty));
    await settle(tester);
    await capture(tester, '10-create-race');
    state.updateSubrace(state.selectedRace!.subraces.first);
    await settle(tester);
    await forward();
    state.updateClass(CharacterDataService.getAllClasses()
        .firstWhere((c) => c.id == 'paladin'));
    await settle(tester);
    await capture(tester, '11-create-class');
    await forward();
    await capture(tester, '12-create-abilities');
    await tester.tap(find.text('Расставить по классу'));
    await settle(tester);
    await capture(tester, '13-create-abilities-placed');
    await tester.tap(find.byKey(const ValueKey('prologue-method-roll')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('prologue-roll')));
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await capture(tester, '14-create-roll-spin');
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await capture(tester, '15-create-roll-landed');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Расставить по классу'));
    await settle(tester);
    await capture(tester, '16-create-rolled');
    await forward();
    state.updateBackground(CharacterDataService.shelfBackgrounds().first);
    await settle(tester);
    await capture(tester, '17-create-background');
    await forward();
    for (final sk in state.selectedClass!.skillProficiencies.from
        .where((s) => !state.selectedBackground!.skillProficiencies.contains(s))
        .take(state.selectedClass!.skillProficiencies.choose)) {
      state.pickSkill(sk);
    }
    await settle(tester);
    await capture(tester, '18-create-skills');
    await forward();
    await capture(tester, '19-create-features');
    await forward();
    await capture(tester, '20-create-gear');
    await forward();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await capture(tester, '21-create-finale');
    await tester.drag(find.byKey(const ValueKey('prologue-scroll')), const Offset(0, -1400));
    await settle(tester);
    await capture(tester, '22-create-finale-gear');
    await finish(tester);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
