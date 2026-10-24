// Mobile rendering regressions. Manual edits are tested separately.
// Real FeatureService/CharacterDataService/hydration and real AbilitiesTab are used.
// save() is a counted no-op so rendering cannot hide a write behind Hive timing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/ability_scores.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/models/spell_slots_table.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_hydration_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/features/character_sheet/widgets/abilities_tab.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart' show Pressable;
import 'package:qd_and_d/core/ui/expressive_kit.dart' show RollingNumber;
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/instrument/instrument_kit.dart'
    show StateBadge, SwitchRow;
import 'package:qd_and_d/features/combat/widgets/hp_manager_card.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/bard_inspiration_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/cleric_magic_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/druid_magic_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/fighter_combat_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/ki_tracker_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/paladin_divine_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/rage_control_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/ranger_survival_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/rogue_tools_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/sorcerer_magic_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/warlock_magic_widget.dart';
import 'package:qd_and_d/features/character_sheet/widgets/class_widgets/wizard_magic_widget.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

const modules = <String, Type>{
  'barbarian': RageControlWidget,
  'bard': BardInspirationWidget,
  'cleric': ClericMagicWidget,
  'druid': DruidMagicWidget,
  'fighter': FighterCombatWidget,
  'monk': KiTrackerWidget,
  'paladin': PaladinDivineWidget,
  'ranger': RangerSurvivalWidget,
  'rogue': RogueToolsWidget,
  'sorcerer': SorcererMagicWidget,
  'warlock': WarlockMagicWidget,
  'wizard': WizardMagicWidget,
};

class RenderCharacter extends Character {
  int saveCalls = 0;
  RenderCharacter(String cls, String subclass, List<int> slots)
      : super(
          id: 'panel-$cls',
          name: 'Panel $cls',
          race: 'human',
          characterClass: cls,
          subclass: subclass,
          level: 8,
          maxHp: 4,
          currentHp: 6,
          abilityScores: AbilityScores(
            strength: 16,
            dexterity: 14,
            constitution: 16,
            intelligence: 16,
            wisdom: 16,
            charisma: 18,
          ),
          spellSlots: List<int>.from(slots),
          maxSpellSlots: List<int>.from(slots),
        );
  @override
  Future<void> save() async {
    saveCalls++;
  }
}

CharacterFeature reserve(String id, int max) => CharacterFeature(
      id: id,
      nameEn: max == 0 ? 'Extra reserve' : 'Table reserve',
      nameRu: max == 0 ? 'Дополнительный запас' : 'Запас стола',
      descriptionEn: 'A manually adjusted table resource.',
      descriptionRu: 'Ресурс с ручным значением.',
      type: FeatureType.resourcePool,
      minLevel: 1,
      resourcePool: ResourcePool(
        currentUses: 6,
        maxUses: max,
        recoveryType: RecoveryType.manual,
      ),
    );
RenderCharacter fixture(
  String cls, {
  bool zeroMaxHp = false,
  int poolCurrent = 6,
}) {
  final data = CharacterDataService.getClassById(cls)!;
  final slots = data.spellcasting == null
      ? <int>[]
      : SpellSlotsTable.getSlots(8, data.spellcasting!.type);
  final c = RenderCharacter(cls, data.subclasses.first.getName('en'), slots);
  FeatureService.addFeaturesToCharacter(c);
  c.features = FeatureHydrationService.hydrateCharacter(c).features;
  // Inputs are already initialized before rendering. Rendering must not
  // repair/reinitialize state or save it as an incidental side effect.
  for (final f in c.features.where((f) => f.resourcePool != null)) {
    f.resourcePool!.currentUses = poolCurrent;
    f.resourcePool!.maxUses = 4;
  }
  final tableReserve = reserve('cycle-table-reserve', 4);
  tableReserve.resourcePool!.currentUses = poolCurrent;
  c.features.add(tableReserve);
  c.features.add(reserve('cycle-extra-reserve', 0));
  final firstSlot = c.maxSpellSlots.indexWhere((n) => n > 0);
  if (firstSlot >= 0) {
    c.maxSpellSlots[firstSlot] = 4;
    c.spellSlots[firstSlot] = 6;
  }
  c.channelDivinityCharges = 6;
  c.wildShapeCharges = 6;
  c.temporaryHp = 3;
  c.activeConditions = [ConditionType.poisoned];
  c.exhaustionLevel = 2;
  c.concentratingOn = 'audit-focus';
  c.isHuntersMarkActive = true;
  c.huntersMarkTarget = 'Audit target';
  c.favoredEnemies = ['beasts'];
  c.naturalExplorers = ['forest'];
  c.beastName = 'Audit beast';
  c.beastCurrentHp = 6;
  c.beastMaxHp = zeroMaxHp ? 0 : 4;
  c.isWildShaped = cls == 'druid';
  c.isRaging = cls == 'barbarian';
  c.isFrenzied = cls == 'barbarian';
  c.isReckless = cls == 'barbarian';
  c.isHidden = cls == 'rogue';
  c.isSacredWeaponActive = cls == 'paladin';
  c.armorClass = 19;
  if (zeroMaxHp) c.maxHp = 0;
  return c;
}

String snapshot(RenderCharacter c) => jsonEncode({
      'features': c.features
          .map(
            (f) => {
              'id': f.id,
              'current': f.resourcePool?.currentUses,
              'max': f.resourcePool?.maxUses,
              'recovery': f.resourcePool?.recoveryType.name,
            },
          )
          .toList(),
      'slots': c.spellSlots,
      'maxSlots': c.maxSpellSlots,
      'hp': c.currentHp,
      'maxHp': c.maxHp,
      'temp': c.temporaryHp,
      'beastHp': c.beastCurrentHp,
      'beastMax': c.beastMaxHp,
      'wildCharges': c.wildShapeCharges,
      'cd': c.channelDivinityCharges,
      'rage': c.isRaging,
      'frenzy': c.isFrenzied,
      'reckless': c.isReckless,
      'hidden': c.isHidden,
      'sacred': c.isSacredWeaponActive,
      'form': c.isWildShaped,
      'conditions': c.activeConditions.map((x) => x.name).toList(),
      'exhaustion': c.exhaustionLevel,
      'concentration': c.concentratingOn,
      'mark': c.isHuntersMarkActive,
      'target': c.huntersMarkTarget,
      'ac': c.armorClass,
      'abilities': c.abilityScores.toJson(),
    });

class PanelHost extends StatefulWidget {
  const PanelHost({super.key, required this.character, this.scale = 1});
  final RenderCharacter character;
  final double scale;
  @override
  State<PanelHost> createState() => PanelHostState();
}

class PanelHostState extends State<PanelHost> {
  int page = 0;
  bool dark = false;
  Locale locale = const Locale('en');
  void redraw() => setState(() {});
  void changePresentation() => setState(() {
        dark = !dark;
        locale = const Locale('ru');
      });
  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(widget.scale)),
          child: child!,
        ),
        home: Scaffold(
          body: IndexedStack(
            index: page,
            children: [
              AbilitiesTab(character: widget.character),
              const Center(child: Text('Away page')),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: page,
            onDestinationSelected: (i) => setState(() => page = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.person), label: 'Sheet'),
              NavigationDestination(icon: Icon(Icons.notes), label: 'Away'),
            ],
          ),
        ),
      );
}

void mobile(WidgetTester tester) {
  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint(details.toString());
    previousErrorHandler?.call(details);
  };
  addTearDown(() {
    FlutterError.onError = previousErrorHandler;
  });
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> frame(WidgetTester tester, String phase) async {
  // Active Rage/Frenzy/Sacred Weapon animations repeat. Never use pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pump(const Duration(milliseconds: 950));
  expect(tester.takeException(), isNull, reason: phase);
}

Finder ratio(int current, int max, {Finder? scope}) {
  final pattern = RegExp(
    '(^|[^0-9])$current'
    r'\s*/\s*'
    '$max'
    r'([^0-9]|$)',
  );
  final text = find.byWidgetPredicate(
    (w) =>
        w is Text &&
        pattern.hasMatch(w.data ?? w.textSpan?.toPlainText() ?? ''),
  );
  return scope == null ? text : find.descendant(of: scope, matching: text);
}

Future<void> show(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byType(AbilitiesTab),
        matching: find.byType(Scrollable),
      )
      .first;
  // Modules may now place their own resource before generic sections. Locate
  // the target from the start instead of assuming it is below the last target.
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    target,
    350,
    scrollable: scrollable,
    maxScrolls: 80,
  );
  await frame(tester, 'scroll to $target');
}

void unchanged(RenderCharacter c, String expected, String phase) {
  expect(snapshot(c), expected, reason: phase);
  expect(c.saveCalls, 0, reason: 'Rendering must not write: $phase');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('qdnd_panel_rebuild_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });
  group('12 real class panels: mobile overfill rendering is read-only', () {
    for (final cls in modules.keys) {
      testWidgets(
        '$cls retains 6/4 and 6/0 across rebuild, navigation and presentation changes',
        (tester) async {
          mobile(tester);
          final c = fixture(cls);
          final before = snapshot(c);
          final key = GlobalKey<PanelHostState>();
          await tester.pumpWidget(PanelHost(key: key, character: c));
          await frame(tester, '$cls initial');
          expect(
            find.byType(modules[cls]!),
            findsOneWidget,
            reason:
                'The actual class module must render, not a fallback/error page.',
          );
          unchanged(c, before, '$cls initial');
          await show(
            tester,
            find.byKey(const Key('abilities_section_resources')),
          );
          expect(ratio(6, 4), findsWidgets);
          expect(ratio(6, 0), findsWidgets);
          if (c.maxSpellSlots.any((n) => n > 0)) {
            // Slots live in the circle headers: a rolling remainder and its
            // maximum beside the marks.
            final count = find.byKey(ValueKey(
                cls == 'warlock' ? 'slot-count-pact' : 'slot-count-1'));
            await show(tester, count);
            expect(
              tester
                  .widget<RollingNumber>(find.descendant(
                      of: count, matching: find.byType(RollingNumber)))
                  .value,
              6,
              reason: '$cls actual slot remainder is shown',
            );
            expect(find.descendant(of: count, matching: find.text('/4')),
                findsOneWidget);
          }
          for (var i = 0; i < 3; i++) {
            key.currentState!.redraw();
            await frame(tester, '$cls rebuild $i');
            unchanged(c, before, '$cls rebuild $i');
          }
          await tester.tap(find.text('Away'));
          await frame(tester, '$cls away');
          unchanged(c, before, '$cls away');
          await tester.tap(find.text('Sheet'));
          await frame(tester, '$cls return');
          unchanged(c, before, '$cls return');
          key.currentState!.changePresentation();
          await frame(tester, '$cls theme and RU');
          unchanged(c, before, '$cls theme and RU');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pumpWidget(PanelHost(character: c));
          await frame(tester, '$cls remount');
          unchanged(c, before, '$cls remount');
        },
      );
    }
  });
  for (final cls in modules.keys) {
    testWidgets(
        '$cls remains readable at large text in EN and RU without writes',
        (tester) async {
      mobile(tester);
      final c = fixture(cls);
      final before = snapshot(c);
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c, scale: 1.6));
      await frame(tester, '$cls large EN');
      expect(find.byType(modules[cls]!), findsOneWidget);
      unchanged(c, before, '$cls large EN');
      key.currentState!.changePresentation();
      await frame(tester, '$cls large RU');
      unchanged(c, before, '$cls large RU');
      await show(tester, find.byKey(const Key('abilities_section_resources')));
      expect(ratio(6, 4), findsWidgets);
      expect(ratio(6, 0), findsWidgets);
      unchanged(c, before, '$cls large scroll');
    });
  }
  for (final cls in modules.keys) {
    testWidgets(
        '$cls late-level controls remain readable and do not alter state',
        (tester) async {
      mobile(tester);
      final c = fixture(cls);
      c.level = 20;
      c.classes.single.level = 20;
      FeatureService.addFeaturesToCharacter(c);
      c.features = FeatureHydrationService.hydrateCharacter(c).features;
      for (final feature in c.features.where((f) => f.resourcePool != null)) {
        feature.resourcePool!
          ..currentUses = 6
          ..maxUses = 0;
      }
      c.setChannelDivinityCharges(6);
      final before = snapshot(c);
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c, scale: 1.6));
      await frame(tester, '$cls 20 EN');
      expect(find.byType(modules[cls]!), findsOneWidget);
      key.currentState!.changePresentation();
      await frame(tester, '$cls 20 RU');
      unchanged(c, before, '$cls 20');
    });
  }

  testWidgets(
    'Sorcerer pre-initialized zero SP is not refilled by opening or rebuilding',
    (tester) async {
      mobile(tester);
      final c = fixture('sorcerer', poolCurrent: 0);
      final before = snapshot(c);
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c));
      await frame(tester, 'sorcerer zero');
      expect(find.byType(SorcererMagicWidget), findsOneWidget);
      unchanged(c, before, 'sorcerer zero');
      key.currentState!.redraw();
      await frame(tester, 'sorcerer zero rebuild');
      unchanged(c, before, 'sorcerer zero rebuild');
    },
  );
  testWidgets(
    'RU Cleric at text scale1.3 renders and preserves above-normal state',
    (tester) async {
      mobile(tester);
      final c = fixture('cleric');
      final before = snapshot(c);
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c, scale: 1.3));
      await frame(tester, 'scaled cleric EN');
      key.currentState!.changePresentation();
      await frame(tester, 'scaled cleric RU');
      expect(find.byType(ClericMagicWidget), findsOneWidget);
      unchanged(c, before, 'scaled cleric');
      await show(tester, find.byKey(const Key('abilities_section_resources')));
      expect(ratio(6, 4), findsWidgets);
    },
  );
  for (final cls in ['druid', 'ranger']) {
    testWidgets(
      '$cls displays a zero-normal beast HP without clipping currentHP or throwing',
      (tester) async {
        mobile(tester);
        final c = fixture(cls, zeroMaxHp: true);
        final before = snapshot(c);
        await tester.pumpWidget(PanelHost(character: c));
        await frame(tester, '$cls zero max HP');
        expect(find.byType(modules[cls]!), findsOneWidget);
        unchanged(c, before, '$cls zero max HP');
        expect(c.currentHp, 6);
        expect(c.maxHp, 0);
        expect(c.beastCurrentHp, 6);
        expect(c.beastMaxHp, 0);
      },
    );
  }
  for (final max in [4, 0]) {
    testWidgets(
      'actual HP card current6/max$max is honest and does not mutate state',
      (tester) async {
        mobile(tester);
        final c = fixture('fighter');
        c.maxHp = max;
        final before = snapshot(c);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HpManagerCard(character: c, onCharacterUpdated: () {}),
              ),
            ),
          ),
        );
        await frame(tester, 'HP card max$max');
        unchanged(c, before, 'HP card max$max');
        expect(ratio(6, max), findsWidgets);
      },
    );
  }
  testWidgets(
    'retained Rage panel reflects Character marks and external updates',
    (tester) async {
      mobile(tester);
      final c = fixture('barbarian');
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c));
      await frame(tester, 'rage true');
      bool reckless() => tester
          .widget<SwitchRow>(find.byKey(const ValueKey('barbarian-reckless')))
          .value;
      bool frenzy() => tester
          .widget<StateBadge>(find.byKey(const ValueKey('barbarian-frenzy')))
          .pressed ==
          true;
      expect(reckless(), isTrue);
      expect(frenzy(), isTrue);
      await tester.tap(find.text('Away'));
      await frame(tester, 'rage away');
      await tester.tap(find.text('Sheet'));
      await frame(tester, 'rage return');
      expect(c.isRaging, true);
      expect(c.isFrenzied, true);
      expect(c.isReckless, true);
      c.isRaging = false;
      c.isFrenzied = false;
      c.isReckless = false;
      key.currentState!.redraw();
      await frame(tester, 'rage external update');
      expect(reckless(), isFalse);
      expect(frenzy(), isFalse);
    },
  );
  testWidgets(
    'retained Rogue Hidden shows as In the shadows and follows external Character update',
    (tester) async {
      mobile(tester);
      final c = fixture('rogue');
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c));
      await frame(tester, 'hidden true');
      Finder condition(String label) => find.descendant(
          of: find.byKey(const ValueKey('rogue-advantage')),
          matching: find.text(label));
      expect(condition('Hidden'), findsOneWidget);
      await tester.tap(find.text('Away'));
      await frame(tester, 'hidden away');
      await tester.tap(find.text('Sheet'));
      await frame(tester, 'hidden return');
      expect(c.isHidden, true);
      expect(condition('Hidden'), findsOneWidget);
      c.isHidden = false;
      key.currentState!.redraw();
      await frame(tester, 'hidden external update');
      expect(condition('Advantage'), findsOneWidget);
      expect(c.saveCalls, 0);
    },
  );
  testWidgets(
    'retained Sacred Weapon visualization follows the Character active mark',
    (tester) async {
      mobile(tester);
      final c = fixture('paladin');
      final key = GlobalKey<PanelHostState>();
      await tester.pumpWidget(PanelHost(key: key, character: c));
      await frame(tester, 'sacred true');
      final control = find.byKey(
          const ValueKey('paladin-channel-channel-divinity-sacred-weapon'));
      expect(control, findsOneWidget);
      // A lit weapon counts its rounds; touching it advances or ends it.
      Finder rounds() => find.descendant(
          of: control, matching: find.textContaining('round'));
      expect(rounds(), findsOneWidget);
      await tester.tap(find.text('Away'));
      await frame(tester, 'sacred away');
      await tester.tap(find.text('Sheet'));
      await frame(tester, 'sacred return');
      expect(c.isSacredWeaponActive, true);
      expect(rounds(), findsOneWidget);
      c.channelDivinityCharges = 0;
      key.currentState!.redraw();
      await frame(tester, 'sacred with spent reserve');
      expect(
          tester
              .widget<Pressable>(find
                  .descendant(of: control, matching: find.byType(Pressable))
                  .first)
              .onTap,
          isNotNull);
      c.isSacredWeaponActive = false;
      key.currentState!.redraw();
      await frame(tester, 'sacred external update');
      expect(rounds(), findsNothing);
      expect(c.saveCalls, 0);
    },
  );
}
