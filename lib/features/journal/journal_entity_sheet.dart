import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/journal/journal_graph.dart';
import '../../core/journal/journal_service.dart';
import '../../core/models/character.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/companion_kit.dart';
import '../../core/ui/expressive_kit.dart';
import 'journal_atlas_page.dart';
import 'journal_entry_page.dart';
import 'journal_index.dart';
import 'journal_kit.dart';
import 'journal_strings.dart';

/// A name's card over the page it was tapped on: who or what it is, how
/// often it appears, who it shares records with and where it is met. From
/// here the player follows a record, another name or opens the Atlas.
Future<void> openJournalEntity(
    BuildContext context, Character character, String id) async {
  var current = id;
  while (true) {
    if (!context.mounted) return;
    final index = JournalIndex(character);
    final entity = index.graph.entity(current);
    if (entity == null) return;
    final choice = await showCompanionSheet<String>(context,
        builder: (_) => _EntitySheet(index: index, entity: entity));
    if (choice == null || !context.mounted) return;
    if (choice.startsWith('e:')) {
      current = choice.substring(2);
      continue;
    }
    if (choice.startsWith('r:')) {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => JournalEntryPage(
                  character: character, entryKey: choice.substring(2))));
    } else if (choice.startsWith('a:')) {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => JournalAtlasPage(
                  character: character, selected: choice.substring(2))));
    }
    return;
  }
}

class _EntitySheet extends StatelessWidget {
  const _EntitySheet({required this.index, required this.entity});
  final JournalIndex index;
  final JournalEntity entity;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    final a = JournalLook.accent(context, JournalLook.kindAccent(entity.kind));
    final trail = index.trailOf(entity.id), together = index.together(entity.id);
    final mini = TextStyle(
        fontFamily: AppType.body,
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w600,
        letterSpacing: .96,
        color: c.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 0, 6),
          child: JournalSeal(
              icon: JournalLook.kindIcon(entity.kind),
              accent: a,
              size: JournalSealSize.lg),
        ),
      ),
      const SizedBox(height: 8),
      Text(
          journalUpper([
            s.kind(entity.kind),
            if (entity.aliases.isNotEmpty) entity.aliases.join(', ')
          ].join(' · ')),
          style: journalCap(context, a)),
      const SizedBox(height: 8),
      SheetHeading(entity.name),
      if (entity.description.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(entity.description,
            style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: c.onSurface.withValues(alpha: .84))),
      ],
      const SizedBox(height: 14),
      JournalStats(
          records: trail.length, together: together.length, strings: s),
      if (together.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(journalUpper(s.t('Вместе в записях', 'Together in entries')),
            style: mini),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final (e, _) in together.take(6))
            JournalToken(
                entity: e, onTap: () => Navigator.pop(context, 'e:${e.id}')),
        ]),
      ],
      const SizedBox(height: 14),
      Text(journalUpper(s.t('Где встречается', 'Where it appears')),
          style: mini),
      const SizedBox(height: 6),
      JournalTrail(
          index: index,
          records: trail,
          ring: c.surfaceContainer,
          brief: true,
          onOpen: (key) => Navigator.pop(context, 'r:$key')),
      const SizedBox(height: 14),
      ToneButton(
          key: const ValueKey('journal-entity-atlas'),
          label: s.t('Открыть в Атласе', 'Open in the Atlas'),
          icon: const LineIcon('grid', size: 20),
          kind: ToneKind.primary,
          height: 52,
          expand: true,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context, 'a:${entity.id}');
          }),
    ]);
  }
}

/// «4 записи · 6 пересечений» in rolling numbers.
class JournalStats extends StatelessWidget {
  const JournalStats(
      {super.key,
      required this.records,
      required this.together,
      required this.strings,
      this.trailing});
  final int records, together;
  final JournalStrings strings;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget stat(int n, String word) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              RollingNumber(n,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                      color: c.onSurface)),
              const SizedBox(width: 6),
              Text(word,
                  style: TextStyle(fontSize: 13, color: c.onSurfaceVariant)),
            ]);
    String word(String full) => full.substring(full.indexOf(' ') + 1);
    return Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          stat(records, word(strings.records(records))),
          stat(
              together,
              word(strings.plural(
                  together,
                  const ['пересечение', 'пересечения', 'пересечений'],
                  const ['crossing', 'crossings']))),
          if (trailing != null) trailing!,
        ]);
  }
}

/// Records along a thread of numbered beads: a name's story, session by
/// session.
class JournalTrail extends StatelessWidget {
  const JournalTrail(
      {super.key,
      required this.index,
      required this.records,
      required this.onOpen,
      this.ring,
      this.brief = false});
  final JournalIndex index;
  final List<JournalEntry> records;
  final ValueChanged<String> onOpen;
  final Color? ring;

  /// The kind of record under its title instead of its first lines.
  final bool brief;
  @override
  Widget build(BuildContext context) {
    final s = JournalStrings(context), c = Theme.of(context).colorScheme;
    return Stack(children: [
      if (records.length > 1)
        Positioned(
            left: 27,
            top: 24,
            bottom: 24,
            child: Container(
                width: 2, color: c.onSurface.withValues(alpha: .1))),
      Column(children: [
        for (final r in records)
          Pressable(
            key: ValueKey('journal-trail-${r.key}'),
            onTap: () => onOpen(r.key),
            haptic: true,
            scale: .98,
            semanticLabel: r.title,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                JournalBead('${index.session(r.key) ?? '—'}',
                    ring: ring),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title,
                            style: TextStyle(
                                fontFamily: AppType.body,
                                fontSize: 15,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: c.onSurface)),
                        const SizedBox(height: 3),
                        Text(
                            brief
                                ? (r.quest != null
                                    ? s.t('Задание', 'Quest')
                                    : JournalLook.categoryLabel(
                                        s, r.note!.category))
                                : r.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: c.onSurfaceVariant)),
                      ]),
                ),
                LineIcon('forward', size: 18, color: c.onSurfaceVariant),
              ]),
            ),
          ),
      ]),
    ]);
  }
}
