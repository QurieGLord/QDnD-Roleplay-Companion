import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';
import 'package:qd_and_d/core/content/content_identity.dart';

ContentRecord<String> spell(String id, String? source, List<String> names,
        {Map<String, dynamic>? definition}) =>
    ContentRecord(
        kind: ContentKind.spell,
        id: id,
        sourceId: source,
        entity: id,
        names: names,
        definition: definition ?? {'names': names, 'id': id});

List<ContentFamily> families(Iterable<ContentRecord<String>> records) =>
    ContentCatalog<String>(records).families;

void main() {
  var n = 0;
  String mint() => 'id${n++}';
  setUp(() => n = 0);

  test('a family keeps its ID across rebuilds and import order', () {
    final a = spell('fireball', null, ['Fireball', 'Огненный шар']);
    final b = spell('fireball', 'book', ['Fireball', 'Огненный шар'],
        definition: {'other': 1});
    final c = spell('shield', null, ['Shield', 'Щит']);
    final registry = ContentIdentityRegistry.empty();
    registry.reconcile(ContentKind.spell, families([a, b, c]), newId: mint);
    final fire = registry.familyOfRecord(ContentKind.spell, null, 'fireball');
    final shield = registry.familyOfRecord(ContentKind.spell, null, 'shield');
    expect(fire, isNotNull);
    expect(fire, isNot(shield));
    // The book's variant joined the same family, with its own variant ID.
    expect(registry.familyOfRecord(ContentKind.spell, 'book', 'fireball'), fire);
    expect(registry.variantsOfFamily(fire!), hasLength(2));
    // Rebuilt in another order: nothing new, the same IDs.
    final changed = registry.reconcile(ContentKind.spell, families([c, b, a]), newId: mint);
    expect(changed, isFalse);
    expect(registry.familyOfRecord(ContentKind.spell, null, 'fireball'), fire);
    expect(registry.familyOfRecord(ContentKind.spell, null, 'shield'), shield);
  });

  test('the variant ID follows the exact definition, not the record', () {
    final a = spell('fireball', null, ['Fireball']);
    final copy = spell('fireball', 'other-book', ['Fireball']);
    expect(ContentIdentityRegistry.variantIdOf(a),
        ContentIdentityRegistry.variantIdOf(copy));
    final registry = ContentIdentityRegistry.empty()
      ..reconcile(ContentKind.spell, families([a, copy]), newId: mint);
    expect(registry.variantOfRecord(ContentKind.spell, null, 'fireball'),
        registry.variantOfRecord(ContentKind.spell, 'other-book', 'fireball'));
  });

  test('a bridging book merges two families; the older one survives', () {
    final registry = ContentIdentityRegistry.empty();
    final ru = spell('a', 'ru-book', ['Огненный шар']);
    final en = spell('b', 'en-book', ['Fireball']);
    registry.reconcile(ContentKind.spell, families([ru]),
        newId: mint, now: DateTime.utc(2026, 1, 1));
    registry.reconcile(ContentKind.spell, families([ru, en]),
        newId: mint, now: DateTime.utc(2026, 1, 2));
    final older = registry.familyOfRecord(ContentKind.spell, 'ru-book', 'a')!;
    final younger = registry.familyOfRecord(ContentKind.spell, 'en-book', 'b')!;
    expect(older, isNot(younger));
    final bridge = spell('c', 'srd', ['Fireball', 'Огненный шар']);
    registry.reconcile(ContentKind.spell, families([ru, en, bridge]),
        newId: mint, now: DateTime.utc(2026, 1, 3));
    expect(registry.familyOfRecord(ContentKind.spell, 'en-book', 'b'), older);
    // A reference made with the younger ID still lands in the same family.
    expect(registry.resolveFamily(younger), older);
    expect(registry.journal.map((j) => j['op']), contains('merge'));
  });

  test('when the bridge goes, the family splits and remembers its origin', () {
    final registry = ContentIdentityRegistry.empty();
    final a = spell('a', 'x', ['Alpha']);
    final a2 = spell('a2', 'x', ['Alpha'], definition: {'v': 2});
    final b = spell('b', 'y', ['Beta']);
    final bridge = spell('c', 'z', ['Alpha', 'Beta']);
    registry.reconcile(ContentKind.spell, families([a, a2, b, bridge]), newId: mint);
    final joined = registry.familyOfRecord(ContentKind.spell, 'x', 'a')!;
    expect(registry.familyOfRecord(ContentKind.spell, 'y', 'b'), joined);
    registry.reconcile(ContentKind.spell, families([a, a2, b]), newId: mint);
    // Alpha holds more of the old family and keeps its ID.
    expect(registry.familyOfRecord(ContentKind.spell, 'x', 'a'), joined);
    final beta = registry.familyOfRecord(ContentKind.spell, 'y', 'b')!;
    expect(beta, isNot(joined));
    final split = registry.journal.lastWhere((j) => j['op'] == 'split');
    expect(split['family'], beta);
    expect(split['from'], [joined]);
  });

  test('a variant whose book was removed still resolves to its family', () {
    final registry = ContentIdentityRegistry.empty();
    final base = spell('fireball', null, ['Fireball']);
    final homebrew = spell('fireball-hb', 'hb', ['Fireball'], definition: {'hb': 1});
    registry.reconcile(ContentKind.spell, families([base, homebrew]), newId: mint);
    final fire = registry.familyOfRecord(ContentKind.spell, 'hb', 'fireball-hb');
    registry.reconcile(ContentKind.spell, families([base]), newId: mint);
    expect(registry.familyOfRecord(ContentKind.spell, 'hb', 'fireball-hb'), fire);
    expect(registry.variantsOfFamily(fire!), hasLength(2));
  });

  test('the registry survives storage; a newer shape is left alone', () {
    final registry = ContentIdentityRegistry.empty()
      ..reconcile(ContentKind.spell,
          families([spell('fireball', null, ['Fireball'])]), newId: mint);
    final stored = jsonDecode(jsonEncode(registry.toJson()));
    final back = ContentIdentityRegistry.fromJson(stored)!;
    expect(back.familyOfRecord(ContentKind.spell, null, 'fireball'),
        registry.familyOfRecord(ContentKind.spell, null, 'fireball'));
    expect(back.reconcile(ContentKind.spell,
        families([spell('fireball', null, ['Fireball'])]), newId: mint), isFalse);
    expect(ContentIdentityRegistry.fromJson({'version': 99}), isNull);
  });

  test('a whole library arriving at once is one seed entry', () {
    final registry = ContentIdentityRegistry.empty()
      ..reconcile(ContentKind.spell, families([
        for (var i = 0; i < 500; i++) spell('s$i', null, ['Spell $i'])
      ]), newId: mint);
    expect(registry.liveFamiliesOf(ContentKind.spell), 500);
    expect(registry.journal, hasLength(1));
    expect(registry.journal.single['op'], 'seed');
    expect(registry.journal.single['families'], 500);
    // Later arrivals are journaled one by one.
    registry.reconcile(ContentKind.spell, families([
      for (var i = 0; i < 501; i++) spell('s$i', null, ['Spell $i'])
    ]), newId: mint);
    expect(registry.journal.last['op'], 'create');
  });
}
