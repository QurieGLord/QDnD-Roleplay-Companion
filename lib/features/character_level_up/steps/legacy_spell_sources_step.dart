import '../../../core/content/content_reference_repair.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/character.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/progression/character_class_context.dart';
import '../../../core/progression/class_spellcasting_profile.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../../spell_almanac/spell_almanac_strings.dart';
import '../widgets/advancement_layout.dart';

/// Only ambiguous old records reach this page. The newly acquired class cannot
/// retroactively own spells already on the sheet.
class LegacySpellSourcesStep extends StatelessWidget {
  const LegacySpellSourcesStep(
      {super.key,
      required this.before,
      required this.preview,
      required this.ids,
      required this.selected,
      required this.onChanged,
      required this.onNext});
  final Character before, preview;
  final List<String> ids;
  final Map<String, String> selected;
  final ValueChanged<Map<String, String>> onChanged;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context), l = AppLocalizations.of(context)!;
    final theme = Theme.of(context), c = theme.colorScheme;
    final casters = before.classes.where((entry) {
      try {
        return ClassSpellcastingProfile.resolve(before, entry.id) != null;
      } catch (_) {
        return false;
      }
    }).toList();
    final assigned = ids.where(selected.containsKey).length;
    void choose(String id, String source) {
      HapticFeedback.selectionClick();
      onChanged({...selected, id: source});
    }

    return Column(children: [
      AdvancementStepList(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, 20 + AdvancementDockScope.inset(context)),
              children: [
        AdvancementHeading(
            title: s.t(
                'Откуда эти заклинания?', 'Where did these spells come from?'),
            subtitle: s.t(
                'Для этих записей класс ещё не указан. Выбери, какой класс дал заклинание: от этого зависят его характеристика и подготовка. Выбор сохранится вместе с повышением.',
                'These spells have no class recorded. Choose the class that granted each spell: it determines its ability and preparation. Your choices are saved with the level-up.')),
        CompanionSurface(
            contour: CompanionContour.focus,
            quiet: true,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.auto_stories_rounded, color: c.secondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        s.t('Подготовка и запасы сохранятся',
                            'Preparation and resources are preserved'),
                        style: theme.textTheme.titleSmall))
              ]),
              const SizedBox(height: 12),
              Text(
                  s.t('Если это дар, черта или особое правило мастера, выбери «Дар или правило стола».',
                      'For a gift, feat, or special GM ruling, choose “Gift or table ruling”.'),
                  style: theme.textTheme.bodyMedium),
              if (casters.isNotEmpty && ids.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                    s.t('Все заклинания одного класса?',
                        'All from the same class?'),
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in casters)
                    ActionChip(
                        avatar: const Icon(Icons.done_all_rounded, size: 18),
                        label: Text(CharacterClassContext(before, entry.id)
                            .name(s.ru ? 'ru' : 'en')),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          onChanged({
                            ...selected,
                            for (final id in ids) id: 'class:${entry.id}'
                          });
                        })
                ]),
              ],
            ])),
        const SizedBox(height: 20),
        Text(
            s.t('Выбрано: $assigned из ${ids.length}',
                'Assigned: $assigned of ${ids.length}'),
            style: theme.textTheme.labelLarge?.copyWith(color: c.secondary)),
        const SizedBox(height: 12),
        for (final id in ids)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: CompanionSurface(
                  contour: CompanionContour.soft,
                  quiet: !selected.containsKey(id),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(
                                      SpellService.getSpellById(id)
                                              ?.getName(s.ru ? 'ru' : 'en') ??
                                          ContentReferenceRepair.retainedName(
                                              before, id, s.ru ? 'ru' : 'en') ??
                                          s.t('Заклинание из неподключённой книги',
                                              'Spell from a missing book'),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800))),
                              if (selected.containsKey(id)) ...[
                                const SizedBox(width: 12),
                                Icon(Icons.check_circle_rounded,
                                    size: 20, color: c.secondary)
                              ],
                            ]),
                        if (before.preparedSpells.contains(id)) ...[
                          const SizedBox(height: 6),
                          Text(s.t('Сейчас подготовлено', 'Currently prepared'),
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: c.onSurfaceVariant))
                        ],
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final entry in casters)
                            ChoiceChip(
                                label: Text(
                                    CharacterClassContext(before, entry.id)
                                        .name(s.ru ? 'ru' : 'en')),
                                selected: selected[id] == 'class:${entry.id}',
                                showCheckmark: false,
                                onSelected: (_) =>
                                    choose(id, 'class:${entry.id}')),
                          ChoiceChip(
                              label: Text(s.t('Дар или правило стола',
                                  'Gift or table ruling')),
                              selected: selected[id] == 'manual',
                              showCheckmark: false,
                              onSelected: (_) => choose(id, 'manual')),
                        ]),
                      ]))),
      ]),
      AdvancementFooter(
          label: l.next,
          hint: assigned == ids.length
              ? null
              : s.t('Выбери вариант для каждой записи',
                  'Choose an origin for each spell'),
          onPressed: assigned == ids.length ? onNext : null),
    ]);
  }
}
