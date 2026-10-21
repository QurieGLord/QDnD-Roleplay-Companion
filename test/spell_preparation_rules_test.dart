import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/magic/spell_preparation_rules.dart';
import 'package:qd_and_d/core/magic/spell_use.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/progression/character_class_rules.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/spell_eligibility_service.dart';
import 'package:qd_and_d/core/services/spell_preparation_rules_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/services/spellbook_actions_service.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'multiclass_magic_flow_test.dart' as flow;

Character foreign({SpellPreparationRules? preparation, Object? raw}) {
  final c = flow.mixed({'library:moon-mage': 3});
  final json =
      QdndBundleCodec.classToJson(CharacterDataService.getClassById('wizard')!);
  json['id'] = c.classes.single.id;
  json['name'] = {'en': 'Moon Mage', 'ru': 'Лунный маг'};
  json['sourceId'] = 'moon';
  json['rulesMetadata'] = {
    'edition': '2014',
    'declaredFields': ['hitDie', 'spellcasting'],
    if (preparation != null || raw != null)
      'spellPreparation': raw ?? preparation!.toJson()
  };
  CharacterClassRules.capture(QdndBundleCodec.classFromJson(json))
      .attachTo(c.classes.single);
  c.spellSlots = [2, 1];
  c.maxSpellSlots = [4, 2];
  return c;
}

Future<void> declare(Character c, SpellPreparationRules rules,
    {Future<void> Function(Character)? write}) {
  final entry = c.classes.single,
      owned = CharacterClassRules.resolve(c.classes.single);
  return SpellPreparationRulesService.save(c, entry.id, rules,
      expectedDigest: owned.snapshot['digest'],
      expectedLevel: entry.level,
      expectedSubclass: entry.subclass,
      write: write ?? (_) async {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-preparation-');
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
      'A foreign class needs a declaration; known mode casts without preparation and retains its own ability',
      () async {
    final c = foreign(), s = SpellService.getSpellById('detect-magic')!;
    flow.learn(c, s, 'class:${c.classes.single.id}');
    expect(SpellUse.options(c, s), isEmpty);
    await declare(c, const SpellPreparationRules(SpellPreparationMode.known));
    final options = SpellUse.options(c, s);
    expect(options, isNotEmpty);
    expect(options.every((o) => o.source.ability == 'intelligence'), true);
    expect(options.any((o) => o.method == SpellUseMethod.ritual), false);
  });
  test(
      'List preparation learns directly, book preparation requires a copied spell, and allowance uses own level',
      () async {
    final s = flow.spell()..availableToClasses = ['Moon Mage'];
    await StorageService.saveSpells([s]);
    await SpellService.reload();
    final list = foreign(
        preparation: const SpellPreparationRules(SpellPreparationMode.prepared,
            divisor: 2));
    expect(
        SpellbookActionsService.preparationLimit(
            list, 'class:library:moon-mage'),
        5);
    expect(SpellEligibilityService.classAccess(list, s).single.state,
        SpellAccessState.available);
    await SpellbookActionsService.setPrepared(list, s.id, true,
        source: 'class:library:moon-mage', write: (_) async {});
    expect(SpellUse.ready(list, s), true);
    final book = foreign(
        preparation: const SpellPreparationRules(SpellPreparationMode.book));
    await expectLater(
        SpellbookActionsService.setPrepared(book, s.id, true,
            source: 'class:library:moon-mage', write: (_) async {}),
        throwsStateError);
    await SpellbookActionsService.setKnown(book, s.id, true,
        source: 'class:library:moon-mage', write: (_) async {});
    await SpellbookActionsService.setPrepared(book, s.id, true,
        source: 'class:library:moon-mage', write: (_) async {});
    expect(SpellUse.ready(book, s), true);
  });
  test('Ritual modes are independent of namespace and slot progression', () {
    final s = flow.spell(ritual: true);
    for (final mode in RitualPreparationMode.values) {
      final c = foreign(
          preparation:
              SpellPreparationRules(SpellPreparationMode.book, ritual: mode));
      flow.learn(c, s, 'class:library:moon-mage');
      expect(
          SpellUse.options(c, s).any((o) => o.method == SpellUseMethod.ritual),
          mode == RitualPreparationMode.book);
      flow.learn(c, s, 'class:library:moon-mage', prepared: true);
      expect(
          SpellUse.options(c, s).any((o) => o.method == SpellUseMethod.ritual),
          mode != RitualPreparationMode.none);
    }
  });
  test(
      'Failed declaration restores every hero value and future declarations are preserved',
      () async {
    final c = foreign(), before = jsonEncode(c.toJson());
    await expectLater(
        declare(c, const SpellPreparationRules(SpellPreparationMode.known),
            write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    final future = foreign(raw: {'version': 2, 'mode': 'unknown'}),
        futureBefore = jsonEncode(future.toJson());
    await expectLater(
        declare(
            future, const SpellPreparationRules(SpellPreparationMode.known)),
        throwsUnsupportedError);
    expect(jsonEncode(future.toJson()), futureBefore);
  });
  test('Stale open declaration cannot overwrite a later level or rule choice',
      () async {
    final c = foreign(),
        entry = c.classes.single,
        owned = CharacterClassRules.resolve(c.classes.single);
    await declare(c, const SpellPreparationRules(SpellPreparationMode.book));
    final before = jsonEncode(c.toJson());
    await expectLater(
        SpellPreparationRulesService.save(c, entry.id,
            const SpellPreparationRules(SpellPreparationMode.known),
            expectedDigest: owned.snapshot['digest'],
            expectedLevel: entry.level,
            expectedSubclass: entry.subclass,
            write: (_) async {}),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Only metadata changes; declaration survives native codec and a real store restart',
      () async {
    final c = foreign(),
        original = CharacterClassRules.resolve(c.classes.single).snapshot;
    final slots = List<int>.from(c.spellSlots);
    await declare(
        c,
        const SpellPreparationRules(SpellPreparationMode.prepared,
            divisor: 2, ritual: RitualPreparationMode.prepared),
        write: StorageService.saveCharacter);
    final now = CharacterClassRules.resolve(c.classes.single).snapshot;
    expect(now['features'], original['features']);
    final a = Map.of(now['definition'] as Map)..remove('rulesMetadata');
    final b = Map.of(original['definition'] as Map)..remove('rulesMetadata');
    expect(a, b);
    expect(c.spellSlots, slots);
    final transferred =
        QdndBundleCodec.characterFromJson(QdndBundleCodec.characterToJson(c));
    expect(
        CharacterClassRules.resolve(transferred.classes.single)
            .data
            .rulesMetadata,
        CharacterClassRules.resolve(c.classes.single).data.rulesMetadata);
    await Hive.close();
    await StorageService.init();
    final restored =
        StorageService.getAllCharacters().singleWhere((v) => v.id == c.id);
    expect(
        SpellbookActionsService.preparationLimit(
            restored, 'class:library:moon-mage'),
        5);
    expect(restored.spellSlots, slots);
  });
}
