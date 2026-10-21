import 'package:flutter/material.dart';
import '../../../../core/models/character.dart';
import '../../../../core/progression/class_spellcasting_profile.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/spellbook_actions_service.dart';
import '../../../../core/ui/companion_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/spell_preparation_rules_sheet.dart';

class SpellSourceSummary extends StatefulWidget {
  const SpellSourceSummary(
      {super.key, required this.hero, required this.onPrepare});
  final Character hero;
  final VoidCallback onPrepare;
  @override
  State<SpellSourceSummary> createState() => _SpellSourceSummaryState();
}

class _SpellSourceSummaryState extends State<SpellSourceSummary> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!,
        ru = Localizations.localeOf(context).languageCode == 'ru',
        t = Theme.of(context).textTheme;
    final profiles = <ClassSpellcastingProfile>[];
    for (final entry in widget.hero.classes) {
      try {
        final p = ClassSpellcastingProfile.resolve(widget.hero, entry.id);
        if (p != null) profiles.add(p);
      } catch (_) {}
    }
    if (profiles.isEmpty) return const SizedBox.shrink();
    final profile = profiles.where((p) => p.classId == _selected).firstOrNull ??
        profiles.first;
    final source = 'class:${profile.classId}',
        limit = SpellbookActionsService.preparationLimit(widget.hero, source);
    final count = SpellbookActionsService.preparedCount(widget.hero, source);
    String ability(String value) => switch (value) {
          'intelligence' => l.abilityIntAbbr,
          'wisdom' => l.abilityWisAbbr,
          'charisma' => l.abilityChaAbbr,
          'strength' => l.abilityStrAbbr,
          'dexterity' => l.abilityDexAbbr,
          'constitution' => l.abilityConAbbr,
          _ => value
        };
    Widget fact(String label, String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: t.labelSmall),
              const SizedBox(height: 4),
              Text(value,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800))
            ]);
    return CompanionSurface(
        contour: CompanionContour.focus,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (profiles.length > 1)
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final p in profiles)
                ChoiceChip(
                    label: Text(
                        '${CharacterClassContext(widget.hero, p.classId).name(ru ? 'ru' : 'en')} ${p.classLevel}'),
                    selected: profile.classId == p.classId,
                    onSelected: (_) => setState(() => _selected = p.classId))
            ])
          else
            Text(
                '${CharacterClassContext(widget.hero, profile.classId).name(ru ? 'ru' : 'en')} · ${ru ? 'ур.' : 'lv.'} ${profile.classLevel}',
                style: t.labelLarge),
          const SizedBox(height: 14),
          Wrap(spacing: 28, runSpacing: 12, children: [
            fact(l.spellAbility, ability(profile.ability)),
            fact(l.spellSaveDC, '${profile.saveDC}'),
            fact(l.spellAttack,
                '${profile.attackBonus >= 0 ? '+' : ''}${profile.attackBonus}')
          ]),
          if (CharacterClassContext(widget.hero, profile.classId)
                      .definition
                      ?.sourceId !=
                  null ||
              profile.preparation == null) ...[
            const SizedBox(height: 12),
            if (profile.preparation == null)
              Text(
                  ru
                      ? 'Уточни подготовку и ритуалы для этого класса.'
                      : 'Set preparation and ritual rules for this class.',
                  style: t.bodyMedium),
            TextButton.icon(
                icon: const Icon(Icons.auto_stories_rounded),
                label: Text(ru ? 'Правила магии' : 'Magic rules'),
                onPressed: () async {
                  final saved = await showSpellPreparationRulesSheet(
                      context, widget.hero, profile.classId);
                  if (saved == true && mounted) setState(() {});
                }),
          ],
          if (limit != null) ...[
            const SizedBox(height: 14),
            Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text('${l.preparedSpells}: $count/$limit',
                      style: t.labelLarge),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary),
                      onPressed: widget.onPrepare,
                      child: Text(
                          ru ? 'Подготовить заклинания' : 'Prepare spells'))
                ])
          ],
        ]));
  }
}
