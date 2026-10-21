import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_reference_repair.dart';
import 'package:qd_and_d/core/magic/spellbook_state.dart';
import 'package:qd_and_d/core/progression/advancement_history.dart';
import 'multiclass_magic_flow_test.dart' as flow;
import 'spell_almanac_test.dart' as spells;
import 'advancement_history_test.dart' as advancement;

void main() {
  test(
      'Missing legacy spell references repair across lists, sources, arcanum and concentration; gameplay is retained',
      () async {
    final spell = spells.spell('book-a',
            en: 'Divine Favor', ru: 'Божественное благоволение', source: 'a'),
        copy = spells.spell('book-b',
            en: 'Divine Favor', ru: 'Божественное благоволение', source: 'b');
    final index = ContentCatalog(
            [ContentRecords.spell(spell), ContentRecords.spell(copy)]),
        hero = flow.mixed({'paladin': 4});
    const old = 'божественное_благоволение';
    hero.knownSpells = [old];
    hero.preparedSpells = [old];
    hero.spellMasterySpells = [old];
    hero.signatureSpells = [old];
    hero.signatureSpellsUsed = {old: true};
    hero.concentratingOn = old;
    hero.currentHp = 7;
    hero.goldPieces = 450;
    hero.spellSlots = [1];
    final book = SpellbookState.read({})
      ..setKnown('class:paladin', old, true)
      ..setPrepared('class:paladin', old, true)
      ..bindArcanum('class:paladin', 1, old);
    hero.spellbookData = book.toJson();
    var writes = 0;
    expect(
        await ContentReferenceRepair.repair(hero, catalog: index,
            write: (_) async {
          writes++;
        }),
        1);
    expect(writes, 1);
    expect(hero.knownSpells, ['book-a']);
    expect(hero.preparedSpells, ['book-a']);
    expect(hero.spellMasterySpells, ['book-a']);
    expect(hero.signatureSpellsUsed, {'book-a': true});
    expect(hero.concentratingOn, 'book-a');
    expect(
        SpellbookState.read(hero.spellbookData)
            .knows('class:paladin', 'book-a'),
        true);
    expect(hero.currentHp, 7);
    expect(hero.goldPieces, 450);
    expect(hero.spellSlots, [1]);
    expect(hero.spellbookData['contentReferences']['book-a']['originalIds'],
        [old]);
    expect(
        await ContentReferenceRepair.repair(hero, catalog: index,
            write: (_) async {
          writes++;
        }),
        0);
    expect(writes, 1);
  });
  test(
      'Different same-name definitions remain unresolved; an exact live ID never silently changes its rules',
      () async {
    final a = spells.spell('book-a',
            en: 'Thunderwave', ru: 'Волна грома', source: 'a'),
        b = spells.spell('book-b',
            en: 'Thunderwave', ru: 'Волна грома', source: 'b')
          ..descriptionEn = 'A different effect';
    final hero = flow.mixed({'wizard': 1})
      ..knownSpells = ['волна_грома', 'book-b'];
    final before = jsonEncode(hero.toJson());
    final count = await ContentReferenceRepair.repair(hero,
        catalog:
            ContentCatalog([ContentRecords.spell(a), ContentRecords.spell(b)]),
        write: (_) async {
      fail('Must not write');
    });
    expect(count, 0);
    expect(jsonEncode(hero.toJson()), before);
  });
  test(
      'Removing one source repairs to an exact surviving variant; changed replacement stays unresolved',
      () async {
    final a = spells.spell('book-a', en: 'Shield', ru: 'Щит', source: 'a'),
        b = spells.spell('book-b', en: 'Shield', ru: 'Щит', source: 'b');
    final hero = flow.mixed({'wizard': 1})..knownSpells = ['щит'];
    await ContentReferenceRepair.repair(hero,
        catalog:
            ContentCatalog([ContentRecords.spell(a), ContentRecords.spell(b)]),
        write: (_) async {});
    expect(hero.knownSpells, ['book-a']);
    await ContentReferenceRepair.repair(hero,
        catalog: ContentCatalog([ContentRecords.spell(b)]),
        write: (_) async {});
    expect(hero.knownSpells, ['book-b']);
    final changed = spells.spell('book-c', en: 'Shield', ru: 'Щит', source: 'c')
      ..descriptionEn = 'Different protection';
    expect(
        await ContentReferenceRepair.repair(hero,
            catalog: ContentCatalog([ContentRecords.spell(changed)]),
            write: (_) async {
          fail('Must not write');
        }),
        0);
    expect(hero.knownSpells, ['book-b']);
  });
  test(
      'A failed repair returns every reference, history and timestamp; later retry works',
      () async {
    final hero = flow.mixed({'wizard': 1})..knownSpells = ['щит'];
    final before = jsonEncode(hero.toJson()),
        index = ContentCatalog([
          ContentRecords.spell(spells.spell('book-a', en: 'Shield', ru: 'Щит'))
        ]);
    await expectLater(
        ContentReferenceRepair.repair(hero, catalog: index, write: (_) async {
          throw StateError('disk');
        }),
        throwsStateError);
    expect(jsonEncode(hero.toJson()), before);
    expect(
        await ContentReferenceRepair.repair(hero,
            catalog: index, write: (_) async {}),
        1);
  });
  test(
      'Historical references are mapped without replaying advancement or restoring a spent resource',
      () async {
    final hero = flow.mixed({'wizard': 1});
    await advancement.advance(hero, 'wizard', amend: (c) {
      c.knownSpells = ['щит'];
    });
    hero.spellSlots = [0];
    hero.currentHp = 3;
    final index = ContentCatalog([
      ContentRecords.spell(spells.spell('book-a', en: 'Shield', ru: 'Щит'))
    ]);
    expect(
        await ContentReferenceRepair.repair(hero,
            catalog: index, write: (_) async {}),
        1);
    expect(hero.knownSpells, ['book-a']);
    expect(hero.level, 2);
    expect(hero.spellSlots, [0]);
    expect(hero.currentHp, 3);
    final preview = AdvancementHistory.preview(
        hero, AdvancementHistory.read(hero).single.id);
    expect(preview.result.level, 1);
    expect(preview.result.knownSpells, isEmpty);
    expect(preview.result.currentHp, 3);
  });
  test(
      'Unknown spellbook/history versions are preserved and never partially repaired',
      () async {
    final hero = flow.mixed({'wizard': 1})
      ..knownSpells = ['щит']
      ..advancementData = {'version': 99, 'entries': []};
    final before = jsonEncode(hero.toJson());
    await expectLater(
        ContentReferenceRepair.repair(hero,
            catalog: ContentCatalog([
              ContentRecords.spell(
                  spells.spell('book-a', en: 'Shield', ru: 'Щит'))
            ]), write: (_) async {
          fail('Must not write');
        }),
        throwsFormatException);
    expect(jsonEncode(hero.toJson()), before);
  });
}
