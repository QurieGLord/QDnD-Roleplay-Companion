import 'package:flutter/material.dart';
import '../../../core/models/character.dart';
import '../../../core/models/class_data.dart';
import '../../../core/progression/advancement_choice_catalog.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../../../core/ui/companion_surface.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/advancement_layout.dart';
import '../../spell_almanac/spell_almanac_strings.dart';

class EntryTrainingStep extends StatelessWidget {
  const EntryTrainingStep(
      {super.key,
      required this.hero,
      required this.data,
      required this.skill,
      required this.instrument,
      required this.onSkill,
      required this.onInstrument,
      required this.onNext});
  final Character hero;
  final ClassData data;
  final String? skill, instrument;
  final ValueChanged<String> onSkill, onInstrument;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context), l = AppLocalizations.of(context)!;
    final skills = data.id == 'bard'
        ? AdvancementChoiceCatalog.skillIds
        : data.skillProficiencies.from;
    final available = skills
        .where((id) => !ProficiencyIdentity.contains(hero.proficientSkills, id))
        .toList();
    final ready = (available.isEmpty || skill != null) &&
        (data.id != 'bard' || (instrument?.trim().isNotEmpty ?? false));
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(20), children: [
        AdvancementHeading(
            title: s.t('Новые владения', 'New proficiencies'),
            subtitle: s.t(
                'При входе в новый класс ты получаешь только положенные владения.',
                'Joining a new class grants its multiclass proficiencies.')),
        if (available.isNotEmpty) ...[
          Text(s.t('Один новый навык', 'One new skill'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final id in available)
              ChoiceChip(
                  label: Text(skillLabel(l, id)),
                  selected: skill == id,
                  onSelected: (_) => onSkill(id))
          ])
        ],
        if (data.id == 'bard') ...[
          const SizedBox(height: 20),
          CompanionSurface(
              child: TextFormField(
                  initialValue: instrument,
                  autofocus: false,
                  decoration: InputDecoration(
                      labelText:
                          s.t('Музыкальный инструмент', 'Musical instrument'),
                      hintText: s.t('Например, лютня', 'For example, lute')),
                  onChanged: onInstrument))
        ],
        const SizedBox(height: 20),
        Text(s.t(
            'Начальные спасброски, снаряжение и полный набор навыков первого класса не выдаются повторно.',
            'Starting saving throws, equipment and the first-class skill package are not granted again.')),
      ])),
      AdvancementFooter(label: l.next, onPressed: ready ? onNext : null)
    ]);
  }

  static String skillLabel(AppLocalizations l, String id) =>
      switch (ProficiencyIdentity.normalize(id)) {
        'acrobatics' => l.skillAcrobatics,
        'animal-handling' => l.skillAnimalHandling,
        'arcana' => l.skillArcana,
        'athletics' => l.skillAthletics,
        'deception' => l.skillDeception,
        'history' => l.skillHistory,
        'insight' => l.skillInsight,
        'intimidation' => l.skillIntimidation,
        'investigation' => l.skillInvestigation,
        'medicine' => l.skillMedicine,
        'nature' => l.skillNature,
        'perception' => l.skillPerception,
        'performance' => l.skillPerformance,
        'persuasion' => l.skillPersuasion,
        'religion' => l.skillReligion,
        'sleight-of-hand' => l.skillSleightOfHand,
        'stealth' => l.skillStealth,
        'survival' => l.skillSurvival,
        _ => id
      };
}
