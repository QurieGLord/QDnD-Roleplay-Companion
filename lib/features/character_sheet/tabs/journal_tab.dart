import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/journal_note.dart';
import '../../../core/models/quest.dart';
import '../../../core/services/storage_service.dart';
import '../../journal/widgets/adventurer_quote_card.dart';
import '../../journal/widgets/note_card.dart';
import '../../journal/widgets/quest_card.dart';
import '../../journal/dialogs/note_editor_dialog.dart';
import '../../journal/dialogs/quest_editor_dialog.dart';

class JournalTab extends StatefulWidget {
  final Character character;

  const JournalTab({super.key, required this.character});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  String _searchQuery = '';
  NoteCategory? _noteFilter;
  QuestStatus? _questFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Filter notes
    var filteredNotes = widget.character.journalNotes.where((note) {
      final matchesSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter = _noteFilter == null || note.category == _noteFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    // Sort: pinned first
    filteredNotes.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    // Filter quests
    var filteredQuests = widget.character.quests.where((quest) {
      final matchesSearch = _searchQuery.isEmpty ||
          quest.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          quest.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesFilter =
          _questFilter == null || quest.status == _questFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    // Sort: active first
    filteredQuests.sort((a, b) {
      if (a.status == QuestStatus.active && b.status != QuestStatus.active) {
        return -1;
      }
      if (a.status != QuestStatus.active && b.status == QuestStatus.active) {
        return 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return CustomScrollView(
      slivers: [
        // Adventurer's Quote
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AdventurerQuoteCard(characterName: widget.character.name),
          ),
        ),

        // Search & Filters
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: l10n.searchJournal,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
              ),
            ),
          ),
        ),

        // ================== QUESTS SECTION ==================
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.flag, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  l10n.quests,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Add Quest Button (Small)
                IconButton.filledTonal(
                  onPressed: _addQuest,
                  icon: const Icon(Icons.add, size: 18),
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  tooltip: l10n.addQuest,
                ),
              ],
            ),
          ),
        ),

        // Quests List
        if (filteredQuests.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    l10n.noActiveQuests,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final quest = filteredQuests[index];
                  return QuestCard(
                    quest: quest,
                    onTap: () => _editQuest(quest),
                    onStatusChange: (status) =>
                        _changeQuestStatus(quest, status),
                    onDelete: () => _deleteQuest(quest),
                  );
                },
                childCount: filteredQuests.length,
              ),
            ),
          ),

        // ================== NOTES SECTION ==================
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                Icon(Icons.note, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.notes,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Add Note Button (Small)
                IconButton.filledTonal(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add, size: 18),
                  constraints:
                      const BoxConstraints.tightFor(width: 32, height: 32),
                  tooltip: l10n.addNote,
                ),
              ],
            ),
          ),
        ),

        // Notes List
        if (filteredNotes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Center(
                  child: Text(
                    l10n.noNotes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                16, 0, 16, 100), // Bottom padding for safe area
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final note = filteredNotes[index];
                  return NoteCard(
                    note: note,
                    onTap: () => _editNote(note),
                    onDelete: () => _deleteNote(note),
                  );
                },
                childCount: filteredNotes.length,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addNote() async {
    final result = await showDialog<JournalNote>(
      context: context,
      builder: (context) => const NoteEditorDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        widget.character.addJournalNote(result);
        StorageService.saveCharacter(widget.character);
      });
    }
  }

  Future<void> _editNote(JournalNote note) async {
    final result = await showDialog<JournalNote>(
      context: context,
      builder: (context) => NoteEditorDialog(note: note),
    );

    if (result != null && mounted) {
      setState(() {
        widget.character.updateJournalNote(result);
        StorageService.saveCharacter(widget.character);
      });
    }
  }

  void _deleteNote(JournalNote note) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNote),
        content: Text(l10n.deleteNoteConfirmation(note.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                widget.character.deleteJournalNote(note.id);
                StorageService.saveCharacter(widget.character);
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _addQuest() async {
    final result = await showDialog<Quest>(
      context: context,
      builder: (context) => const QuestEditorDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        widget.character.addQuest(result);
        StorageService.saveCharacter(widget.character);
      });
    }
  }

  Future<void> _editQuest(Quest quest) async {
    final result = await showDialog<Quest>(
      context: context,
      builder: (context) => QuestEditorDialog(quest: quest),
    );

    if (result != null && mounted) {
      setState(() {
        widget.character.updateQuest(result);
        StorageService.saveCharacter(widget.character);
      });
    }
  }

  void _changeQuestStatus(Quest quest, QuestStatus status) {
    setState(() {
      if (status == QuestStatus.completed) {
        widget.character.completeQuest(quest.id);
      } else if (status == QuestStatus.failed) {
        widget.character.failQuest(quest.id);
      } else {
        quest.status = status;
        widget.character.updateQuest(quest);
      }
      StorageService.saveCharacter(widget.character);
    });
  }

  void _deleteQuest(Quest quest) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteQuest),
        content: Text(l10n.deleteQuestConfirmation(quest.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                widget.character.deleteQuest(quest.id);
                StorageService.saveCharacter(widget.character);
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
