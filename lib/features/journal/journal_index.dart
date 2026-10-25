import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_links.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';

/// One read of a hero's journal for a frame: records, names and the ties
/// between them, as the journal screens ask for them.
class JournalIndex {
  JournalIndex(this.character)
      : graph = JournalService.graph(character),
        entries = JournalService.entries(character) {
    // Names written before a record was last saved are found on reading too;
    // this works on the read copy and never writes.
    JournalService.reconcile(character, graph);
    matcher = JournalMatcher(graph.entities);
  }
  final Character character;
  final JournalGraph graph;
  final List<JournalEntry> entries;
  late final JournalMatcher matcher;

  JournalEntry? entry(String key) {
    for (final e in entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  int? session(String key) => graph.records[key]?.session;

  /// Names linked with a record, in the order they are first met.
  List<JournalEntity> entitiesOf(String key) => [
        for (final id in graph.forRecord(key).entities)
          if (graph.entity(id) case final e?) e
      ];

  List<JournalEntry> recordsOf(String id) => [
        for (final e in entries)
          if (graph.forRecord(e.key).entities.contains(id)) e
      ];

  /// Records of a name in story order: by session, the unnumbered last.
  List<JournalEntry> trailOf(String id) => recordsOf(id)
    ..sort((a, b) {
      final x = session(a.key), y = session(b.key);
      if (x != y) return (x ?? 1 << 20).compareTo(y ?? 1 << 20);
      return a.date.compareTo(b.date);
    });

  /// Names met in the same records, the most shared first.
  List<(JournalEntity, int)> together(String id) {
    final counts = <String, int>{};
    for (final r in recordsOf(id)) {
      for (final other in graph.forRecord(r.key).entities) {
        if (other != id) counts.update(other, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return [
      for (final e in counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
        if (graph.entity(e.key) case final entity?) (entity, e.value)
    ];
  }

  /// Threads of a record: the ones it points to, then those pointing at it.
  List<(JournalEntry, bool)> threadsOf(String key) {
    final seen = <String>{};
    return [
      for (final k in graph.forRecord(key).records)
        if (entry(k) case final e? when seen.add(k)) (e, true),
      for (final e in entries)
        if (e.key != key &&
            graph.forRecord(e.key).records.contains(key) &&
            seen.add(e.key))
          (e, false),
    ];
  }

  List<JournalMention> mentions(String text) => matcher.mentions(text);
}
