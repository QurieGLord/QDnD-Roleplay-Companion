import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:qd_and_d/core/models/character.dart';
import 'package:qd_and_d/core/models/journal_note.dart';
import 'package:qd_and_d/core/progression/advancement_history.dart';
import 'package:qd_and_d/core/progression/level_up_commit.dart';
import 'package:qd_and_d/core/progression/level_up_draft.dart';
import 'package:qd_and_d/core/progression/feature_evolution.dart';
import 'package:qd_and_d/core/services/feature_service.dart';
import 'package:qd_and_d/core/services/character_data_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/services/storage_service.dart';
import 'package:qd_and_d/core/services/gameplay_actions_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_export_service.dart';
import 'package:qd_and_d/core/services/qdnd_bundle_import_service.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/magic/magic_slots.dart';
import 'multiclass_magic_flow_test.dart' as flow;

Future<void> advance(Character c, String id,
    {int hp = 6, void Function(Character)? amend}) async {
  final d = LevelUpDraft.begin(c,
      classId: id, newClassName: c.classes.any((v) => v.id == id) ? null : id)
    ..chooseHealth(hp);
  final result = d.preview;
  amend?.call(result);
  await LevelUpCommit.apply(c,
      baseline: d, result: result, write: (_) async {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('qdnd-rollback-');
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
      'Rollback removes only development and retains later HP, journal, money and manual adjustments',
      () async {
    final c = flow.mixed({'fighter': 1})
      ..maxHp = 20
      ..currentHp = 12;
    await advance(c, 'fighter');
    expect(c.maxHp, 20 + 6 + c.abilityScores.constitutionModifier);
    expect(AdvancementHistory.read(c), hasLength(1));
    c.currentHp = 4;
    c.temporaryHp = 7;
    c.goldPieces = 450;
    c.maxHp += 3;
    c.armorClass = 19;
    c.journalNotes.add(JournalNote(id: 'story', title: 'After the level-up'));
    final preview =
        AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id);
    expect(preview.result.maxHp, 23);
    expect(c.level, 2);
    await AdvancementHistory.apply(c, preview, write: (_) async {});
    expect(c.level, 1);
    expect(c.currentHp, 4);
    expect(c.maxHp, 23);
    expect(c.temporaryHp, 7);
    expect(c.goldPieces, 450);
    expect(c.armorClass, 19);
    expect(c.journalNotes.single.title, 'After the level-up');
    expect(AdvancementHistory.read(c), isEmpty);
  });
  test('A rollback can cancel several recent levels including adding a class',
      () async {
    final c = flow.mixed({'fighter': 1});
    await advance(c, 'wizard');
    await advance(c, 'wizard');
    await advance(c, 'fighter');
    final records = AdvancementHistory.read(c);
    final p = AdvancementHistory.preview(c, records.first.id);
    expect(p.count, 3);
    await AdvancementHistory.apply(c, p, write: (_) async {});
    expect(c.level, 1);
    expect(c.classes.single.id, 'fighter');
    expect(c.classes.single.level, 1);
  });
  test(
      'Resource growth is reversed after spending/rest and excesses survive; evolved features keep their consumption',
      () async {
    final c = flow.mixed({'fighter': 16});
    final old =
        FeatureService.getFeatureById('action-surge-1-use')!.copyForCharacter();
    old.resourcePool!.currentUses = 1;
    c.features = [old];
    c.spellSlots = [6];
    c.maxSpellSlots = [4];
    await advance(c, 'fighter', amend: (p) {
      FeatureEvolution.acquire(
          p.features, FeatureService.getFeatureById('action-surge-2-uses')!);
      p.features.single.resourcePool!.currentUses = 2;
      p.spellSlots = [7];
      p.maxSpellSlots = [5];
    });
    c.features.single.resourcePool!.currentUses = 1;
    c.spellSlots = [5];
    final p = AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id);
    expect(p.result.spellSlots, [4]);
    expect(p.result.maxSpellSlots, [4]);
    expect(p.result.features.single.id, 'action-surge-1-use');
    expect(p.result.features.single.resourcePool!.currentUses, 0);
  });
  test(
      'An old sheet has no invented history; future/corrupt records are preserved and cannot be overwritten',
      () async {
    final c = flow.mixed({'fighter': 14});
    expect(AdvancementHistory.read(c), isEmpty);
    c.advancementData = {'version': 2, 'entries': []};
    final before = jsonEncode(c.toJson());
    await expectLater(advance(c, 'fighter'), throwsFormatException);
    expect(jsonEncode(c.toJson()), before);
  });
  test(
      'Failed rollback and stale confirmation leave the live hero and history intact',
      () async {
    final c = flow.mixed({'fighter': 1});
    await advance(c, 'fighter');
    final p = AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id),
        before = jsonEncode(c.toJson());
    await expectLater(
        AdvancementHistory.apply(c, p, write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(c.toJson()), before);
    c.goldPieces = 10;
    final changed = jsonEncode(c.toJson());
    await expectLater(
        AdvancementHistory.apply(c, p, write: (_) async {}), throwsStateError);
    expect(jsonEncode(c.toJson()), changed);
  });
  test(
      'History survives native clone and a real Hive restart and does not grow recursively',
      () async {
    final c = flow.mixed({'fighter': 1});
    await advance(c, 'fighter');
    await advance(c, 'fighter');
    await StorageService.saveCharacter(c);
    final clone = QdndBundleCodec.cloneCharacter(c);
    expect(AdvancementHistory.read(clone), hasLength(2));
    expect(jsonEncode(clone.advancementData), isNot(contains('journalNotes')));
    await Hive.close();
    await StorageService.init();
    final loaded = StorageService.getCharacter(c.id)!;
    expect(AdvancementHistory.read(loaded), hasLength(2));
    await AdvancementHistory.apply(
        loaded,
        AdvancementHistory.preview(
            loaded, AdvancementHistory.read(loaded).last.id));
    expect(loaded.level, 2);
  });
  test(
      'Native bundle retains rollback history and its historical spell references',
      () async {
    final c = flow.mixed({'wizard': 1});
    await advance(c, 'wizard', amend: (p) {
      final book = SpellbookState.read(p.spellbookData)
        ..setKnown('class:wizard', 'shield', true);
      p.spellbookData = book.toJson();
      p.knownSpells = ['shield'];
    });
    c.goldPieces = 77;
    final exported = await QdndBundleExportService.exportCharacter(c);
    expect(exported.manifest['schemaVersion'], 5);
    final imported =
        (await QdndBundleImportService.importBytes(exported.bytes)).character;
    expect(AdvancementHistory.read(imported), hasLength(1));
    await AdvancementHistory.apply(
        imported,
        AdvancementHistory.preview(
            imported, AdvancementHistory.read(imported).last.id),
        write: (_) async {});
    expect(imported.level, 1);
    expect(imported.goldPieces, 77);
    expect(imported.knownSpells, isNot(contains('shield')));
  });
  test(
      'A removed class loses later source-owned spells while a shared spell from another source remains',
      () async {
    final c = flow.mixed({'fighter': 1});
    await advance(c, 'wizard', amend: (p) {
      final b = SpellbookState.read(p.spellbookData)
        ..setKnown('class:wizard', 'shield', true);
      p.spellbookData = b.toJson();
      p.knownSpells = ['shield'];
    });
    final b = SpellbookState.read(c.spellbookData)
      ..setKnown('class:wizard', 'detect-magic', true)
      ..setKnown('manual', 'shield', true);
    c.spellbookData = b.toJson();
    c.knownSpells = ['shield', 'detect-magic'];
    final p = AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id);
    expect(p.result.classes.single.id, 'fighter');
    expect(p.result.knownSpells, contains('shield'));
    expect(p.result.knownSpells, isNot(contains('detect-magic')));
    expect(SpellbookState.read(p.result.spellbookData).ownersOf('shield'),
        ['manual']);
  });

  test('Removing a newly acquired Pact class works after spending its slot',
      () async {
    final c = flow.mixed({'fighter': 1});
    await advance(c, 'warlock', amend: (p) {
      MagicSlots.allocation(
              current: [],
              maximum: [],
              pact: const PactSlots(
                  owner: 'warlock', circle: 1, current: 1, maximum: 1))
          .applyTo(p);
    });
    MagicSlots.spendOn(c, MagicPool.pact, 1);
    final p = AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id);
    expect(p.result.classes.single.id, 'fighter');
    expect(MagicSlots.read(p.result).pact, isNull);
  });
  test(
      'Legacy cleric feature versions remain exportable and rollback keeps the shared spent reserve',
      () async {
    final c = flow.mixed({'cleric': 6});
    FeatureService.addFeaturesToCharacter(c);
    c.setChannelDivinityCharges(2);
    await advance(c, 'cleric');
    await GameplayActionsService.spendChannelDivinity(c);
    final p = AdvancementHistory.preview(c, AdvancementHistory.read(c).last.id);
    expect(p.result.channelDivinityCharges, 1);
    expect(
        p.result.channelDivinityResources
            .every((f) => f.resourcePool!.currentUses == 1),
        true);
    final exported = await QdndBundleExportService.exportCharacter(c);
    expect(exported.bytes, isNotEmpty);
  });
}
