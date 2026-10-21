import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/content/content_catalog.dart';

ContentRecord<String> record(String id, String source,
        {List<String> names = const ['Thunderwave', 'Волна грома'],
        String effect = '2d8',
        String edition = '2014',
        ContentKind kind = ContentKind.spell}) =>
    ContentRecord(
        kind: kind,
        id: id,
        sourceId: source,
        entity: id,
        names: names,
        edition: edition,
        definition: {'id': id, 'sourceId': source, 'effect': effect});
void main() {
  test(
      'Identical records from independent books retain provenance in one variant',
      () {
    final index = ContentCatalog([
      record('a', 'book'),
      record('b', 'collection'),
      record('c', 'module')
    ]);
    expect(index.families, hasLength(1));
    expect(index.families.single.variants, hasLength(1));
    expect(index.families.single.sources, {'book', 'collection', 'module'});
    expect(index.records, hasLength(3));
  });
  test('Same title never collapses different mechanics or rules editions', () {
    final index = ContentCatalog([
      record('a', 'book'),
      record('b', 'homebrew', effect: '3d8'),
      record('c', 'revision', edition: '2024')
    ]);
    expect(index.families, hasLength(1));
    expect(index.families.single.variants, hasLength(3));
    expect(index.unambiguousDefinition('Волна грома'), isNull);
    expect(index.unambiguousDefinition('b')!.records.single.entity, 'b');
  });
  test(
      'Translation bridge groups families without equating translated definitions',
      () {
    final index = ContentCatalog([
      record('a', 'en', names: ['Thunderwave']),
      record('b', 'ru', names: ['Волна грома']),
      record('c', 'bridge')
    ]);
    expect(index.families, hasLength(1));
    expect(index.records.map((r) => r.id), ['a', 'b', 'c']);
  });
  test(
      'Removal of one source preserves the other original identity and definition',
      () {
    final a = record('a', 'book'), b = record('b', 'collection');
    final both = ContentCatalog([a, b]), remaining = ContentCatalog([b]);
    expect(both.unambiguousDefinition('Thunderwave')!.records, hasLength(2));
    expect(remaining.unambiguousDefinition('Thunderwave')!.key,
        both.unambiguousDefinition('Thunderwave')!.key);
    expect(remaining.candidates('b').single.recordKey, b.recordKey);
  });
  test(
      'Kinds and unknown fields are significant; reading does not mutate input',
      () {
    final data = {'id': 'a', 'x': 3, 'sourceId': 'book'},
        copy = Map<String, dynamic>.of(data);
    final a = ContentRecord(
        kind: ContentKind.spell,
        id: 'a',
        sourceId: 'book',
        entity: 'a',
        names: ['Shield'],
        definition: data);
    final b = record('b', 'book', names: ['Shield'], kind: ContentKind.item);
    final c = ContentRecord(
        kind: ContentKind.spell,
        id: 'c',
        sourceId: 'book',
        entity: 'c',
        names: ['Shield'],
        definition: {...data, 'x': 4});
    final index = ContentCatalog([a, b, c]);
    expect(index.families, hasLength(2));
    expect(
        index.unambiguousDefinition('Shield', kind: ContentKind.spell), isNull);
    expect(data, copy);
  });
  test(
      'Same external ID in different books stays ambiguous; duplicate source record is rejected',
      () {
    final a = record('same', 'book'),
        b = record('same', 'homebrew', effect: '8d8');
    final index = ContentCatalog([a, b]);
    expect(index.candidates('same'), hasLength(2));
    expect(index.unambiguousDefinition('same'), isNull);
    expect(() => ContentCatalog([a, a]), throwsArgumentError);
  });
  test('Import order changes no family partition or variant definitions', () {
    final list = [
      record('a', 'book'),
      record('b', 'book2'),
      record('c', 'home', effect: '5d8'),
      record('d', 'other', names: ['Mage hand'])
    ];
    Set<String> probe(ContentCatalog<String> i) => i.families
        .map((f) =>
            (f.records.map((r) => r.recordKey).toList()..sort()).join('|'))
        .toSet();
    expect(probe(ContentCatalog(list)), probe(ContentCatalog(list.reversed)));
  });
}
