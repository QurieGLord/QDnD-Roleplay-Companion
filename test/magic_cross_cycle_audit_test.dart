import 'package:qd_and_d/core/progression/spell_learning_plan.dart';
import 'package:qd_and_d/core/services/spell_eligibility_service.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/casting_constraints.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'package:qd_and_d/core/magic/spell_use.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/class_data.dart';
import 'package:qd_and_d/core/models/condition.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/progression/class_spellcasting_profile.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/progression/magic_slot_growth.dart';
import 'package:qd_and_d/core/progression/multiclass_rules.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/class_session_actions_service.dart';
import 'package:qd_and_d/core/services/fc5_parser.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/item_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_export_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_import_service.dart';
import 'package:qd_and_d/core/services/spell_cast_actions_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/spellbook_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'multiclass_magic_flow_test.dart' as flow;

const classes = [
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'fighter',
  'monk',
  'paladin',
  'ranger',
  'rogue',
  'sorcerer',
  'warlock',
  'wizard'
];
const full = {'bard', 'cleric', 'druid', 'sorcerer', 'wizard'},
    half = {'paladin', 'ranger'};
const fullSlots = [
  <int>[],
  [2],
  [3],
  [4, 2],
  [4, 3],
  [4, 3, 2],
  [4, 3, 3],
  [4, 3, 3, 1],
  [4, 3, 3, 2],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1]
];
List<int> own(String id, int level) => full.contains(id)
    ? fullSlots[level]
    : half.contains(id) && level >= 2
        ? fullSlots[(level + 1) ~/ 2]
        : [];
Map<String, dynamic> storedPrecision(Map<String, dynamic> json) {
  dynamic normalize(dynamic value) {
    if (value is List) return value.map(normalize).toList();
    if (value is Map) {
      return value.map((key, item) {
        if ({'createdAt', 'updatedAt', 'timestamp'}.contains(key) &&
            item is String) {
          final date = DateTime.tryParse(item);
          if (date != null) {
            return MapEntry(
                key,
                DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch,
                        isUtc: date.isUtc)
                    .toIso8601String());
          }
        }
        return MapEntry(key, normalize(item));
      });
    }
    return value;
  }

  return Map<String, dynamic>.from(normalize(json) as Map);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-cross-cycle-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await ItemService.loadItems();
    await SpellService.loadSpells();
    await CharacterDataService.loadAllData();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  for (final id in classes) {
    test('$id: all twenty own class levels match the 2014 capacity', () {
      for (var level = 1; level <= 20; level++) {
        final c = flow.mixed({id: level});
        final result = MulticlassRules.spellCapacity(c);
        expect(result.sharedSlots, own(id, level), reason: '$id $level');
        if (id == 'warlock') {
          expect(result.pact!.circle, math.min(5, (level + 1) ~/ 2));
          expect(
              result.pact!.count,
              level == 1
                  ? 1
                  : level < 11
                      ? 2
                      : level < 17
                          ? 3
                          : 4);
        } else {
          expect(result.pact, isNull);
        }
      }
    });
  }
  test(
      '528 ordered two-class boundary scenarios keep capacity and casting ability independent',
      () {
    var cases = 0;
    for (final a in classes) {
      for (final b in classes.where((v) => v != a)) {
        for (final levels in [(1, 1), (3, 5), (10, 10), (17, 3)]) {
          final c = flow.mixed({a: levels.$1, b: levels.$2});
          final result = MulticlassRules.spellCapacity(c);
          final ordinary =
              c.classes.where((e) => own(e.id, e.level).isNotEmpty).toList();
          final effective = ordinary.fold<int>(
              0, (n, e) => n + (full.contains(e.id) ? e.level : e.level ~/ 2));
          expect(
              result.sharedSlots,
              ordinary.isEmpty
                  ? <int>[]
                  : ordinary.length == 1
                      ? own(ordinary.single.id, ordinary.single.level)
                      : fullSlots[effective],
              reason: '$a/$b $levels');
          for (final e in c.classes) {
            final p = ClassSpellcastingProfile.resolve(c, e.id);
            if (p == null) continue;
            final expected =
                {'wizard': 4, 'cleric': 3, 'druid': 3, 'ranger': 3}[e.id] ?? 2;
            expect(p.modifier, expected);
            expect(p.saveDC, 8 + 2 + ((c.level - 1) ~/ 4) + expected);
          }
          cases++;
        }
      }
    }
    expect(cases, 528);
  });
  for (final id in [...full, ...half, 'warlock', 'fighter', 'rogue']) {
    test(
        '$id: source → cast → both rests → bundle → Hive reopen preserves actual state',
        () async {
      final c = flow.mixed({id: 6})
        ..id = 'cycle-$id'
        ..maxHp = 30
        ..currentHp = 18
        ..hitDice = [3]
        ..maxHitDice = 6;
      if (id == 'fighter' || id == 'rogue') {
        c.classes.single.subclass =
            id == 'fighter' ? 'eldritch knight' : 'arcane trickster';
      }
      FeatureService.addFeaturesToCharacter(c);
      final cap = MulticlassRules.spellCapacity(c);
      MagicSlots.allocation(
              current: cap.sharedSlots.map((v) => v + 2).toList(),
              maximum: cap.sharedSlots,
              pact: cap.pact == null
                  ? null
                  : PactSlots(
                      owner: 'warlock',
                      circle: cap.pact!.circle,
                      current: cap.pact!.count + 2,
                      maximum: cap.pact!.count))
          .applyTo(c);
      final spell = SpellService.getSpellsForClass(
              id == 'fighter' || id == 'rogue' ? 'wizard' : id)
          .firstWhere((s) => s.level == 1 && !s.concentration);
      await SpellbookActionsService.setKnown(c, spell.id, true,
          source: 'class:$id');
      if (SpellbookActionsService.preparationLimit(c, 'class:$id') != null) {
        await SpellbookActionsService.setPrepared(c, spell.id, true,
            source: 'class:$id');
      }
      c.activeConditions = [ConditionType.poisoned];
      c.concentratingOn = 'detect-magic';
      final choices = SpellUse.options(c, spell);
      expect(choices, isNotEmpty);
      final chosen = choices.firstWhere((o) =>
          o.method ==
          (id == 'warlock'
              ? SpellUseMethod.pactSlot
              : SpellUseMethod.sharedSlot));
      final before = MagicSlots.read(c);
      await SpellCastActionsService.cast(c, spell, chosen,
          locale: 'ru', expectedConcentration: 'detect-magic');
      expect(c.combatState.combatLog.last.description,
          contains(spell.getName('ru')));
      expect(c.concentratingOn, 'detect-magic');
      await GameplayActionsService.rest(c, short: true);
      await GameplayActionsService.rest(c, short: false);
      final after = MagicSlots.read(c);
      if (id == 'warlock') {
        expect(after.pact!.current, before.pact!.current - 1);
      } else {
        expect(after.current.first, before.current.first - 1);
      }
      expect(c.activeConditions, [ConditionType.poisoned]);
      expect(c.concentratingOn, 'detect-magic');
      final exported = await QdndBundleExportService.exportCharacter(c);
      final imported =
          (await QdndBundleImportService.importBytes(exported.bytes)).character;
      expect(imported.currentHp, c.currentHp);
      expect(imported.activeConditions, c.activeConditions);
      expect(imported.concentratingOn, c.concentratingOn);
      expect(MagicSlots.read(imported).current, after.current);
      expect(MagicSlots.read(imported).pact?.current, after.pact?.current);
      final saved = QdndBundleCodec.characterToJson(imported);
      await Hive.close();
      await StorageService.init();
      await CharacterDataService.reload();
      await SpellService.reload();
      expect(
          QdndBundleCodec.characterToJson(
              StorageService.getCharacter(imported.id)!),
          storedPrecision(saved));
    });
  }
  for (final condition in ConditionType.values) {
    test(
        'Recorded ${condition.name}: only incapacitating states prevent normal casting',
        () async {
      final c = flow.mixed({'wizard': 3}), s = flow.spell();
      flow.learn(c, s, 'class:wizard', prepared: true);
      c.spellSlots = [2];
      c.maxSpellSlots = [2];
      c.activeConditions = [condition];
      final blocked = {
        ConditionType.incapacitated,
        ConditionType.paralyzed,
        ConditionType.petrified,
        ConditionType.stunned,
        ConditionType.unconscious
      }.contains(condition);
      expect(SpellUse.options(c, s).isEmpty, blocked);
      if (blocked) {
        final baseline = QdndBundleCodec.characterToJson(c);
        final option = SpellUse.options(c, s, tableException: true).first;
        await expectLater(
            SpellCastActionsService.cast(c, s, option, locale: 'en'),
            throwsStateError);
        expect(QdndBundleCodec.characterToJson(c), baseline);
        await SpellCastActionsService.cast(c, s, option,
            locale: 'en',
            tableException: true,
            expectedRestrictions:
                CastingConstraints.signature(c, s, option.source.id));
        expect(c.spellSlots.first, 1);
        expect(c.activeConditions, [condition]);
        expect(c.combatState.combatLog.last.description,
            contains('table exception'));
      }
    });
  }
  test(
      'Beast Spells belongs to druid eighteen, not total level or another class source',
      () {
    for (final levels in [
      {'druid': 1, 'wizard': 19},
      {'druid': 18, 'wizard': 2},
      {'druid': 20}
    ]) {
      final c = flow.mixed(levels), s = flow.spell();
      c.isWildShaped = true;
      c.spellSlots = [2];
      c.maxSpellSlots = [2];
      flow.learn(c, s, 'class:druid', prepared: true);
      if (levels.containsKey('wizard')) {
        flow.learn(c, s, 'class:wizard', prepared: true);
      }
      final sources = SpellUse.options(c, s).map((o) => o.source.id).toSet();
      expect(sources.contains('class:druid'), levels['druid']! >= 18);
      expect(sources.contains('class:wizard'), isFalse);
      s.components = ['M'];
      s.materialComponents = 'a leaf';
      expect(SpellUse.options(c, s).isNotEmpty, levels['druid'] == 20);
      s.materialComponents = 'a diamond worth 300 gp, which is consumed';
      expect(SpellUse.options(c, s), isEmpty);
      s.materialComponents = null;
      expect(SpellUse.options(c, s), isEmpty);
    }
  });
  test(
      'A changed restriction cannot reuse approval while waiting in the save queue',
      () async {
    final c = flow.mixed({'wizard': 3}), s = flow.spell();
    flow.learn(c, s, 'class:wizard', prepared: true);
    c.spellSlots = [2];
    c.maxSpellSlots = [2];
    c.isRaging = true;
    final option = SpellUse.options(c, s, tableException: true).first,
        signature = CastingConstraints.signature(c, s, 'class:wizard');
    final gate = Completer<void>();
    final queued =
        GameplayActionsService.serializeCharacter(c, () => gate.future);
    var writes = 0;
    final action = SpellCastActionsService.cast(c, s, option,
        locale: 'en',
        tableException: true,
        expectedRestrictions: signature, write: (_) async {
      writes++;
    });
    final rejected = expectLater(action, throwsStateError);
    c.activeConditions = [ConditionType.unconscious];
    gate.complete();
    await queued;
    await rejected;
    expect(writes, 0);
    expect(c.spellSlots, [2]);
    expect(c.combatState.combatLog, isEmpty);
  });
  test(
      'Rage entry/exit is one transaction including concentration, helper flags and exhaustion',
      () async {
    final c = flow.mixed({'wizard': 17, 'barbarian': 3});
    c.classes.singleWhere((v) => v.id == 'barbarian').subclass = 'berserker';
    FeatureService.addFeaturesToCharacter(c);
    final rage = c.features.firstWhere((f) => f.id == 'rage');
    c.concentratingOn = 'detect-magic';
    rage.resourcePool!.currentUses = 2;
    final baseline = QdndBundleCodec.characterToJson(c);
    await expectLater(
        ClassSessionActionsService.rage(c, rage.id, true,
            expectedConcentration: 'detect-magic',
            write: (_) async => throw StateError('disk')),
        throwsStateError);
    expect(QdndBundleCodec.characterToJson(c), baseline);
    expect(ClassSessionActionsService.unlimitedRage(c), isFalse);
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        ClassSessionActionsService.rage(c, rage.id, true,
            expectedConcentration: 'detect-magic')
    ]);
    expect(results.where((v) => v), hasLength(1));
    expect(rage.resourcePool!.currentUses, 1);
    expect(c.concentratingOn, isNull);
    await ClassSessionActionsService.helpers(c, frenzied: true, reckless: true);
    await ClassSessionActionsService.rage(c, rage.id, false);
    await ClassSessionActionsService.rage(c, rage.id, false);
    expect(c.exhaustionLevel, 1);
    expect(c.isFrenzied, isFalse);
    expect(c.isReckless, isFalse);
  });
  test(
      'Wild Shape retains concentration and rolls back all form state on failed writes',
      () async {
    final c = flow.mixed({'druid': 2, 'wizard': 18})
      ..wildShapeCharges = 1
      ..concentratingOn = 'detect-magic';
    final baseline = QdndBundleCodec.characterToJson(c);
    await expectLater(
        ClassSessionActionsService.wildShape(c, true,
            hp: 12, name: 'Wolf', write: (_) async => throw StateError('disk')),
        throwsStateError);
    expect(QdndBundleCodec.characterToJson(c), baseline);
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        ClassSessionActionsService.wildShape(c, true, hp: 12, name: 'Wolf')
    ]);
    expect(results.where((v) => v), hasLength(1));
    expect(c.wildShapeCharges, 0);
    expect(c.concentratingOn, 'detect-magic');
    await ClassSessionActionsService.beastHealth(c, 20);
    expect(c.beastCurrentHp, 20);
    await ClassSessionActionsService.beastHealth(c, 0);
    expect(c.isWildShaped, isFalse);
    expect(c.currentHp, 10);
  });
  test(
      'Explicit review definitions apply to the previous capacity without mutating old rules',
      () async {
    final parsed = await FC5Parser.parseCompendium(
        '<compendium><class><name>Custom Mage</name><hd>6</hd><spellAbility>Intelligence</spellAbility></class></compendium>',
        sourceId: 'external');
    final data = parsed.classes.single, c = flow.mixed({'wizard': 2});
    c.classes = [
      CharacterClass(
          id: data.id, name: 'Custom Mage', level: 2, isPrimary: true)
    ];
    c.characterClass = data.id;
    CharacterClassRules.capture(data).attachTo(c.classes.single);
    c.spellSlots = [1];
    c.maxSpellSlots = [2];
    final json = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(QdndBundleCodec.classToJson(data))) as Map);
    (json['rulesMetadata'] as Map)['edition'] = '2014';
    final resolved = ClassData.fromJson(json);
    final after = LevelUpDraft.begin(c, classId: data.id).preview;
    CharacterClassRules.capture(resolved).attachTo(after.classes.single);
    MagicSlotGrowth.advance(c, after);
    expect(after.maxSpellSlots, [3, 2]);
    expect(after.spellSlots, [2, 2]);
    expect(CharacterClassRules.resolve(c.classes.single).data.rulesEdition,
        'unknown');
  });
  test(
      'Replacing an open spell definition rejects live confirmation without spending anything',
      () async {
    final real = SpellService.getSpellsForClass('wizard')
        .firstWhere((s) => s.level == 1);
    final opened = Spell.fromJson(real.toJson()), c = flow.mixed({'wizard': 3});
    flow.learn(c, opened, 'class:wizard', prepared: true);
    c.spellSlots = [2];
    c.maxSpellSlots = [2];
    final option = SpellUse.options(c, opened)
        .firstWhere((o) => o.method == SpellUseMethod.sharedSlot);
    final original = real.descriptionEn;
    final baseline = QdndBundleCodec.characterToJson(c);
    try {
      real.descriptionEn = 'Changed library rule.';
      await expectLater(
          SpellCastActionsService.cast(c, opened, option,
              locale: 'en', requireCurrentCatalog: true),
          throwsStateError);
      expect(QdndBundleCodec.characterToJson(c), baseline);
    } finally {
      real.descriptionEn = original;
    }
  });
  test(
      'Zero HP needs an explicit exception; an active beast HP pool is independent',
      () {
    final c = flow.mixed({'druid': 18}), s = flow.spell();
    flow.learn(c, s, 'class:druid', prepared: true);
    c.spellSlots = [2];
    c.maxSpellSlots = [2];
    c.currentHp = 0;
    expect(SpellUse.options(c, s), isEmpty);
    expect(SpellUse.options(c, s, tableException: true), isNotEmpty);
    c.isWildShaped = true;
    c.beastCurrentHp = 7;
    expect(SpellUse.options(c, s), isNotEmpty);
    c.beastCurrentHp = 0;
    expect(SpellUse.options(c, s), isEmpty);
  });
  test(
      'A source spell-list extension is not silently converted into a level-zero spell',
      () async {
    final result = await FC5Parser.parseCompendium(
        '<compendium><spell><name>Fireball</name><classes>Custom Mage</classes></spell></compendium>',
        sourceId: 'extension');
    expect(result.spells, isEmpty);
    expect(result.diagnostics.entries.map((d) => d.code),
        contains('spell_extension_requires_base'));
  });

  test('Imported subclass spell-list annotations stay restricted in RU and EN',
      () async {
    for (final lists in [
      'Wizard, Paladin (Oath of Conquest)',
      'Волшебник; Паладин (Клятва покорения)'
    ]) {
      final parsed = await FC5Parser.parseCompendium(
          '<compendium><spell><name>Scoped spell</name><level>1</level><classes>$lists</classes></spell></compendium>',
          sourceId: 'scoped');
      final s = parsed.spells.single, c = flow.mixed({'paladin': 3});
      c.classes.single.subclass = 'devotion';
      expect(s.availableToClasses.any((v) => v == 'paladin'), isFalse);
      expect(SpellEligibilityService.classAccess(c, s).single.state,
          SpellAccessState.conditional);
      c.classes.single.subclass = 'oath-of-conquest';
      expect(SpellEligibilityService.classAccess(c, s).single.state,
          SpellAccessState.available);
      final wizard = flow.mixed({'wizard': 1});
      expect(SpellEligibilityService.classAccess(wizard, s).single.state,
          SpellAccessState.available);
    }
  });

  test(
      'Learning includes an explicit spell-list extension owned by the third-caster subclass',
      () async {
    final scoped = flow.spell();
    scoped.id = 'scoped-ek-only';
    scoped.availableToClasses = ['Fighter (Eldritch Knight)'];
    await StorageService.saveSpells([scoped]);
    await SpellService.reload();
    try {
      final before = flow.mixed({'fighter': 2});
      final after = LevelUpDraft.begin(before, classId: 'fighter').preview;
      after.classes.single.subclass = 'eldritch knight';
      final plan = SpellLearningPlan.forAdvance(before, after, 'fighter');
      expect(plan.choices.expand((c) => c.options).map((s) => s.id),
          contains(scoped.id));
    } finally {
      await Hive.box<Spell>('spells_library').delete(scoped.id);
      await SpellService.reload();
    }
  });
}
