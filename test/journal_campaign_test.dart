import 'package:flutter_test/flutter_test.dart';
import 'package:qd_and_d/core/journal/journal_service.dart';
import 'package:qd_and_d/features/journal/journal_campaign.dart';
import 'journal_service_test.dart' as fixtures;

/// Every Cycle hero's journal is a story of its own: each name of its Atlas
/// is met in a record, and the records reach back across sessions.
void main() {
  const classes = [
    'barbarian', 'bard', 'cleric', 'druid', 'fighter', 'monk',
    'paladin', 'ranger', 'rogue', 'sorcerer', 'warlock', 'wizard'
  ];
  for (final id in classes) {
    test('The $id campaign ties every name to a record', () {
      final hero = fixtures.hero()..characterClass = id;
      writeJournalCampaign(hero);
      final g = JournalService.graph(hero);
      for (final e in g.entities) {
        expect(
            g.records.values.any((r) => r.entities.contains(e.id)), isTrue,
            reason: '$id: ${e.name}');
      }
      expect(g.records.values.where((r) => r.records.isNotEmpty), isNotEmpty);
      expect(hero.journalNotes.where((n) => n.isPinned), isNotEmpty);
      expect(g.currentSession, g.sessions);
    });
  }
}
