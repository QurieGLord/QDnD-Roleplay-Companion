import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/journal/journal_graph.dart';
import 'package:qd_and_d/core/journal/journal_links.dart';

void main() {
  test('Confirmed RU names inflect and English aliases respect word boundaries',
      () {
    final elian = JournalEntity(id: 'elian', name: 'Элиан', aliases: ['Elian']);
    expect(JournalLinks.analyze('Передать Элиану письмо', [elian]).automatic,
        {'elian'});
    expect(
        JournalLinks.analyze('We met Elian by the wharf.', [elian]).automatic,
        {'elian'});
    expect(
        JournalLinks.analyze('Eliana was there', [elian]).automatic, isEmpty);
  });
  test('Same names are ambiguous; a unique full alias resolves identity', () {
    final a =
        JournalEntity(id: 'son', name: 'Элиан', aliases: ['Элиан Альдренов']);
    final b = JournalEntity(id: 'sailor', name: 'Элиан');
    final ambiguous = JournalLinks.analyze('Элиан принёс письмо', [a, b]);
    expect(ambiguous.automatic, isEmpty);
    expect(ambiguous.ambiguous.single, hasLength(2));
    expect(JournalLinks.analyze('Элиан Альдренов пришёл', [a, b]).automatic,
        {'son'});
  });
  test('Typos and synonyms are never evidence of identity', () {
    final road = JournalEntity(id: 'road', name: 'Northern road');
    expect(JournalLinks.analyze('Northern path', [road]).automatic, isEmpty);
    expect(JournalLinks.analyze('Northern raod', [road]).automatic, isEmpty);
  });
  test('Suggestions never create identities and omit service words', () {
    expect(JournalLinks.candidates('И', 'The And Мы Он Но', []), isEmpty);
    expect(
        JournalLinks.candidates('Письмо', 'Встретили Элиана у пристани.', []),
        contains('Элиана'));
    expect(
        JournalLinks.candidates(
            'Elian', 'We met Elian.', [JournalEntity(name: 'Elian')]),
        isNot(contains('Elian')));
  });
  test('Graph roundtrip preserves overrides, sessions and links by stable ID',
      () {
    final entity = JournalEntity(id: 'e', name: 'Elian');
    final graph = JournalGraph(entities: [entity]);
    graph.records['n:a'] = JournalRecordLinks(
        manual: {'e'}, excluded: {'other'}, records: {'q:b'}, session: 6);
    final copy = JournalGraph.fromJson(graph.toJson());
    expect(copy.forRecord('n:a').entities, {'e'});
    expect(copy.forRecord('n:a').records, {'q:b'});
    expect(copy.forRecord('n:a').session, 6);
    copy.removeEntity('e');
    expect(copy.forRecord('n:a').entities, isEmpty);
    copy.removeRecord('q:b');
    expect(copy.forRecord('n:a').records, isEmpty);
  });
  test('Matcher handles many known names without matching partial numbers', () {
    final names = [
      for (var i = 0; i < 500; i++) JournalEntity(id: '$i', name: 'Person $i')
    ];
    expect(
        JournalMatcher(names).analyze('We met Person 42.').automatic, {'42'});
  });

  test('Mentions mark each trusted name where it sits, endings and all', () {
    final matcher = JournalMatcher([
      JournalEntity(id: 'elian', name: 'Элиан'),
      JournalEntity(id: 'pier', name: 'Старая пристань', kind: JournalEntityKind.place),
    ]);
    const text = 'Альдрен просил найти Элиана у старой пристани.';
    final hits = matcher.mentions(text);
    expect([for (final h in hits) text.substring(h.start, h.end)],
        ['Элиана', 'старой пристани']);
    expect(hits.map((h) => h.entity.id), ['elian', 'pier']);
  });
}
