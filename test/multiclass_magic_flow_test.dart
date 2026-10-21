import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'package:qd_and_d/core/magic/spell_use.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/character_class.dart';
import 'package:qd_and_d/core/models/spell.dart';
import 'package:qd_and_d/core/progression/magic_slot_growth.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/progression/level_up_commit.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/spell_cast_actions_service.dart';
import 'journal_service_test.dart' as fixtures;

Character mixed(Map<String, int> levels) {
  final c = fixtures.hero();
  c.characterClass = levels.keys.first;
  c.level = levels.values.reduce((a, b) => a + b);
  c.classes = levels.entries
      .map((e) => CharacterClass(
          id: e.key,
          name: e.key,
          level: e.value,
          isPrimary: e.key == levels.keys.first))
      .toList();
  c.abilityScores =
      c.abilityScores.copyWith(intelligence: 18, wisdom: 16, charisma: 14);
  return c;
}

Spell spell(
        {int circle = 1, bool ritual = false, bool concentration = false}) =>
    Spell(
        id: 'flow-spell-$circle',
        nameEn: 'Flow',
        nameRu: 'Чары',
        level: circle,
        school: 'Abjuration',
        castingTime: '1 action',
        range: 'Self',
        duration: '1 minute',
        concentration: concentration,
        ritual: ritual,
        components: ['V'],
        descriptionEn: 'Test',
        descriptionRu: 'Тест',
        availableToClasses: ['wizard', 'cleric', 'warlock']);
void learn(Character c, Spell s, String source, {bool prepared = false}) {
  final b = SpellbookState.read(c.spellbookData);
  b.setKnown(source, s.id, true);
  if (prepared) b.setPrepared(source, s.id, true);
  c.spellbookData = b.toJson();
  c.knownSpells = b.allKnown.toList();
  c.preparedSpells = b.allPrepared.toList();
}

void slots(Character c,
        {int shared = 2,
        int pact = 2,
        int circle = 2,
        int? maxShared,
        int? maxPact}) =>
    MagicSlots.allocation(
            current: [shared],
            maximum: [maxShared ?? shared],
            pact: PactSlots(
                owner: 'warlock',
                circle: circle,
                current: pact,
                maximum: maxPact ?? pact))
        .applyTo(c);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-multiclass-magic-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
    await StorageService.init();
    await FeatureService.init();
    await CharacterDataService.loadAllData();
    await SpellService.loadSpells();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  test(
      'Read-only pools split a single legacy Pact caster without writing or granting a refill',
      () {
    final c = mixed({'warlock': 3})
      ..spellSlots = [0, 1]
      ..maxSpellSlots = [0, 2];
    final before = jsonEncode(c.toJson());
    final view = MagicSlots.read(c);
    expect(view.pact!.current, 1);
    expect(view.pact!.circle, 2);
    expect(view.current, [0, 0]);
    expect(jsonEncode(c.toJson()), before);
  });
  test('Ambiguous legacy mixed pool is rejected without losing its values', () {
    final c = mixed({'wizard': 3, 'warlock': 2})
      ..spellSlots = [6, 3]
      ..maxSpellSlots = [4, 2];
    final before = jsonEncode(c.toJson());
    expect(() => MagicSlots.read(c), throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'One spell from two classes offers two independent casting abilities and both payments',
      () {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell();
    slots(c);
    learn(c, s, 'class:wizard', prepared: true);
    learn(c, s, 'class:warlock');
    final choices = SpellUse.options(c, s);
    expect(choices, hasLength(4));
    expect(
        choices
            .where((o) => o.source.id == 'class:wizard')
            .first
            .source
            .modifier,
        4);
    expect(
        choices
            .where((o) => o.source.id == 'class:warlock')
            .first
            .source
            .modifier,
        2);
    expect(
        choices
            .where((o) => o.method == SpellUseMethod.pactSlot)
            .every((o) => o.circle == 2),
        true);
  });
  test(
      'A wizard using Pact slots keeps Intelligence and spends only the chosen pool',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell();
    slots(c);
    learn(c, s, 'class:wizard', prepared: true);
    final option = SpellUse.options(c, s)
        .firstWhere((o) => o.method == SpellUseMethod.pactSlot);
    final cast = await SpellCastActionsService.cast(c, s, option, locale: 'ru');
    expect(c.spellSlots, [2]);
    expect(MagicSlots.read(c).pact!.current, 1);
    expect(cast.option.source.modifier, 4);
    expect(c.combatState.combatLog, hasLength(1));
  });
  test('A warlock can pay with a shared slot without spending Pact slots',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell();
    slots(c);
    learn(c, s, 'class:warlock');
    await SpellCastActionsService.cast(
        c,
        s,
        SpellUse.options(c, s)
            .firstWhere((o) => o.method == SpellUseMethod.sharedSlot),
        locale: 'en');
    expect(c.spellSlots, [1]);
    expect(MagicSlots.read(c).pact!.current, 2);
  });
  test(
      'Unprepared wizard has a ritual but no paid cast; the ritual costs neither pool',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell(ritual: true);
    slots(c);
    learn(c, s, 'class:wizard');
    final options = SpellUse.options(c, s);
    expect(options.single.method, SpellUseMethod.ritual);
    await SpellCastActionsService.cast(c, s, options.single, locale: 'en');
    expect(c.spellSlots, [2]);
    expect(MagicSlots.read(c).pact!.current, 2);
  });
  test('A nonritual unprepared spell has no available casting method', () {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell();
    slots(c);
    learn(c, s, 'class:wizard');
    expect(SpellUse.options(c, s), isEmpty);
  });
  test('A failed cast restores cost, concentration, log and timestamp together',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}),
        s = spell(concentration: true);
    slots(c);
    learn(c, s, 'class:wizard', prepared: true);
    c.concentratingOn = 'old';
    final before = jsonEncode(c.toJson());
    await expectLater(
        SpellCastActionsService.cast(c, s, SpellUse.options(c, s).first,
            locale: 'ru', expectedConcentration: 'old', write: (hero) async {
          hero.updatedAt = DateTime(2050);
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test('Concentration changed after the choice causes no cost or log',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}),
        s = spell(concentration: true);
    slots(c);
    learn(c, s, 'class:wizard', prepared: true);
    c.concentratingOn = 'new';
    final before = jsonEncode(c.toJson());
    await expectLater(
        SpellCastActionsService.cast(c, s, SpellUse.options(c, s).first,
            locale: 'ru', expectedConcentration: 'old'),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test('Concurrent uses of the last shared slot succeed exactly once',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3}), s = spell();
    slots(c, shared: 1, pact: 0);
    learn(c, s, 'class:wizard', prepared: true);
    final option = SpellUse.options(c, s).single;
    final attempts = await Future.wait([
      for (var i = 0; i < 2; i++)
        SpellCastActionsService.cast(c, s, option, locale: 'en')
            .then((_) => true, onError: (_) => false)
    ]);
    expect(attempts.where((ok) => ok), hasLength(1));
    expect(c.spellSlots, [0]);
    expect(c.combatState.combatLog, hasLength(1));
  });
  test(
      'Short rest restores only Pact, and both rests preserve overfilled pools',
      () async {
    final c = mixed({'wizard': 3, 'warlock': 3});
    slots(c, shared: 1, pact: 0, maxShared: 4, maxPact: 2);
    await GameplayActionsService.rest(c, short: true);
    expect(c.spellSlots, [1]);
    expect(MagicSlots.read(c).pact!.current, 2);
    slots(c, shared: 6, pact: 6, maxShared: 4, maxPact: 2);
    await GameplayActionsService.rest(c, short: true);
    await GameplayActionsService.rest(c, short: false);
    expect(c.spellSlots, [6]);
    expect(MagicSlots.read(c).pact!.current, 6);
  });
  test(
      'Advancing a new Pact class preserves shared spending and initializes only its own resource',
      () {
    final c = mixed({'wizard': 3})
      ..spellSlots = [1, 0]
      ..maxSpellSlots = [4, 2];
    final d =
        LevelUpDraft.begin(c, classId: 'warlock', newClassName: 'Warlock');
    final next = d.preview;
    MagicSlotGrowth.advance(c, next);
    expect(next.spellSlots, [1, 0]);
    expect(MagicSlots.read(next).pact!.current, 1);
    expect(c.magicData, isEmpty);
    expect(c.spellSlots, [1, 0]);
  });
  test(
      'Advancing Pact circle carries its actual remainder without refilling or duplicating the old circle',
      () {
    final c = mixed({'wizard': 3, 'warlock': 2});
    slots(c, shared: 1, pact: 6, circle: 1, maxPact: 2);
    final d = LevelUpDraft.begin(c, classId: 'warlock');
    final next = d.preview;
    MagicSlotGrowth.advance(c, next);
    expect(next.spellSlots, [1]);
    expect(MagicSlots.read(next).pact!.circle, 2);
    expect(MagicSlots.read(next).pact!.current, 6);
  });
  test(
      'Advancing the shared caster grants only capacity growth while retaining independent Pact spending',
      () {
    final c = mixed({'wizard': 2, 'warlock': 3});
    slots(c, shared: 1, pact: 1, maxShared: 3, maxPact: 2);
    final next = LevelUpDraft.begin(c, classId: 'wizard').preview;
    MagicSlotGrowth.advance(c, next);
    expect(next.spellSlots, [2, 2]);
    expect(next.maxSpellSlots, [4, 2]);
    expect(MagicSlots.read(next).pact!.current, 1);
  });
  test(
      'Owned lists and split pools survive commit, Hive restart and isolated copy',
      () async {
    final c = mixed({'wizard': 3})
      ..spellSlots = [1, 0]
      ..maxSpellSlots = [4, 2];
    final s = spell();
    learn(c, s, 'class:wizard', prepared: true);
    final d =
        LevelUpDraft.begin(c, classId: 'warlock', newClassName: 'Warlock');
    d.chooseHealth(4);
    final next = d.preview;
    MagicSlotGrowth.advance(c, next);
    next.hitDice = [3, 1];
    await LevelUpCommit.apply(c, baseline: d, result: next);
    await Hive.close();
    await StorageService.init();
    final restored = StorageService.getCharacter(c.id)!;
    expect(MagicSlots.read(restored).pact!.current, 1);
    expect(
        SpellbookState.read(restored.spellbookData)
            .ids('class:wizard', 'prepared'),
        {s.id});
    final copy = QdndBundleCodec.cloneCharacter(restored);
    MagicSlots.read(copy).spend(MagicPool.pact, 1).applyTo(copy);
    expect(MagicSlots.read(restored).pact!.current, 1);
  });
}
