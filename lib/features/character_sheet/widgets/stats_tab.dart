import '../../../core/progression/character_training.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/progression/skill_check.dart';
import '../../../core/progression/proficiency_identity.dart';
import '../../../shared/widgets/dice_roller_modal.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/companion_kit.dart';

class StatsTab extends StatelessWidget {
  final Character character;

  const StatsTab({super.key, required this.character});

  String _getAbilityName(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength':
        return l10n.abilityStr;
      case 'dexterity':
        return l10n.abilityDex;
      case 'constitution':
        return l10n.abilityCon;
      case 'intelligence':
        return l10n.abilityInt;
      case 'wisdom':
        return l10n.abilityWis;
      case 'charisma':
        return l10n.abilityCha;
      default:
        return key;
    }
  }

  String _getSkillName(AppLocalizations l10n, String key) {
    switch (key.replaceAll(' ', '').toLowerCase()) {
      case 'athletics':
        return l10n.skillAthletics;
      case 'acrobatics':
        return l10n.skillAcrobatics;
      case 'sleightofhand':
        return l10n.skillSleightOfHand;
      case 'stealth':
        return l10n.skillStealth;
      case 'arcana':
        return l10n.skillArcana;
      case 'history':
        return l10n.skillHistory;
      case 'investigation':
        return l10n.skillInvestigation;
      case 'nature':
        return l10n.skillNature;
      case 'religion':
        return l10n.skillReligion;
      case 'animalhandling':
        return l10n.skillAnimalHandling;
      case 'insight':
        return l10n.skillInsight;
      case 'medicine':
        return l10n.skillMedicine;
      case 'perception':
        return l10n.skillPerception;
      case 'survival':
        return l10n.skillSurvival;
      case 'deception':
        return l10n.skillDeception;
      case 'intimidation':
        return l10n.skillIntimidation;
      case 'performance':
        return l10n.skillPerformance;
      case 'persuasion':
        return l10n.skillPersuasion;
      default:
        return key;
    }
  }

  String _getAbilityAbbr(AppLocalizations l10n, String key) {
    switch (key.toLowerCase()) {
      case 'strength':
        return l10n.abilityStrAbbr;
      case 'dexterity':
        return l10n.abilityDexAbbr;
      case 'constitution':
        return l10n.abilityConAbbr;
      case 'intelligence':
        return l10n.abilityIntAbbr;
      case 'wisdom':
        return l10n.abilityWisAbbr;
      case 'charisma':
        return l10n.abilityChaAbbr;
      default:
        return key.length >= 3
            ? key.substring(0, 3).toUpperCase()
            : key.toUpperCase();
    }
  }

  static const _abilities = [
    'Strength',
    'Dexterity',
    'Constitution',
    'Intelligence',
    'Wisdom',
    'Charisma'
  ];
  static const _skills = {
    'Strength': ['Athletics'],
    'Dexterity': ['Acrobatics', 'Sleight of Hand', 'Stealth'],
    'Intelligence': [
      'Arcana',
      'History',
      'Investigation',
      'Nature',
      'Religion'
    ],
    'Wisdom': [
      'Animal Handling',
      'Insight',
      'Medicine',
      'Perception',
      'Survival'
    ],
    'Charisma': ['Deception', 'Intimidation', 'Performance', 'Persuasion'],
  };

  int _modifier(String ability) => switch (ability) {
        'Strength' => character.abilityScores.strengthModifier,
        'Dexterity' => character.abilityScores.dexterityModifier,
        'Constitution' => character.abilityScores.constitutionModifier,
        'Intelligence' => character.abilityScores.intelligenceModifier,
        'Wisdom' => character.abilityScores.wisdomModifier,
        _ => character.abilityScores.charismaModifier,
      };

  int _score(String ability) => switch (ability) {
        'Strength' => character.abilityScores.strength,
        'Dexterity' => character.abilityScores.dexterity,
        'Constitution' => character.abilityScores.constitution,
        'Intelligence' => character.abilityScores.intelligence,
        'Wisdom' => character.abilityScores.wisdom,
        _ => character.abilityScores.charisma,
      };

  bool _saveTrained(String ability) => character.savingThrowProficiencies
      .map((s) => s.toLowerCase())
      .contains(ability.toLowerCase());

  int _save(String ability) =>
      _modifier(ability) +
      (_saveTrained(ability) ? character.proficiencyBonus : 0);

  ({int bonus, bool proficient, bool expert}) _skill(
      String ability, String skill) {
    final id = skill.toLowerCase().replaceAll(' ', '_');
    final expert = ProficiencyIdentity.contains(character.expertSkills, id);
    final proficient =
        expert || ProficiencyIdentity.contains(character.proficientSkills, id);
    return (
      bonus: _modifier(ability) + SkillCheck.trainingBonus(character, id),
      proficient: proficient,
      expert: expert
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context), c = t.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final passive = 10 + _skill('Wisdom', 'Perception').bonus;
    final tokens = CharacterTraining.tokens(character);
    final inset = SheetPageInset.of(context);

    // The prototype's `.pchip`: a quiet label with its number in Rubik.
    Widget chip(String label, String value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
              shape: const StadiumBorder(), color: c.surfaceContainerLow),
          child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$label  '),
                TextSpan(
                    text: value,
                    style: AppType.numeric(null).copyWith(
                        color: c.onSurface, fontWeight: FontWeight.w600)),
              ]),
              style: t.textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.onSurfaceVariant)),
        );
    Widget gap(Widget child, [double space = 14]) =>
        Padding(padding: EdgeInsets.only(bottom: space), child: child);

    return ListView(
      // The page scrolls on under the floating island.
      clipBehavior: Clip.none,
      padding: EdgeInsets.fromLTRB(16, inset + 6, 16, 110),
      children: [
        gap(SectionHeading(l10n.abilities)),
        gap(Wrap(spacing: 8, runSpacing: 8, children: [
          chip(l10n.statsPassivePerception, '$passive'),
          chip(l10n.proficiencyBonusLabel, '+${character.proficiencyBonus}'),
        ])),
        gap(Row(children: [
          LineIcon('dice', size: 15, color: c.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(l10n.statsTapHintShort,
                style: t.textTheme.bodySmall
                    ?.copyWith(fontSize: 12.5, color: c.onSurfaceVariant)),
          ),
        ])),
        gap(LayoutBuilder(builder: (context, box) {
          final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final columns = large || box.maxWidth < 300 ? 2 : 3;
          final width = (box.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ability in _abilities)
              SizedBox(
                width: width,
                child: _AbilityTile(
                  ability: ability,
                  abbr: _getAbilityAbbr(l10n, ability),
                  name: _getAbilityName(l10n, ability),
                  score: _score(ability),
                  modifier: _modifier(ability),
                  save: _save(ability),
                  saveTrained: _saveTrained(ability),
                ),
              ),
          ]);
        })),
        gap(SectionHeading(l10n.skills)),
        _SkillList(groups: [
          for (final entry in _skills.entries)
            (
              header: _getAbilityName(l10n, entry.key),
              abbr: _getAbilityAbbr(l10n, entry.key),
              rows: [
                for (final skill in entry.value)
                  (
                    id: skill.toLowerCase().replaceAll(' ', '_'),
                    name: _getSkillName(l10n, skill),
                    check: _skill(entry.key, skill)
                  )
              ]
            )
        ]),
        if (tokens.isNotEmpty) ...[
          const SizedBox(height: 14),
          gap(SectionHeading(locale == 'ru' ? 'Владения' : 'Proficiencies')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final token in tokens)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: ShapeDecoration(
                    shape: StadiumBorder(
                        side: BorderSide(
                            color: c.onSurface.withValues(alpha: .14),
                            width: 1.2))),
                child: Text(CharacterTraining.label(token, locale),
                    style: t.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.onSurfaceVariant)),
              ),
          ]),
        ],
      ],
    );
  }
}

String _signed(int v) => v >= 0 ? '+$v' : '−${v.abs()}';

/// The prototype's `.at`: the tile rolls the check, its lower strip (with a
/// hairline above) rolls the saving throw; a filled dot marks proficiency.
class _AbilityTile extends StatelessWidget {
  const _AbilityTile({
    required this.ability,
    required this.abbr,
    required this.name,
    required this.score,
    required this.modifier,
    required this.save,
    required this.saveTrained,
  });
  final String ability, abbr, name;
  final int score, modifier, save;
  final bool saveTrained;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final id = ability.toLowerCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
      child: ColoredBox(
        color: c.surfaceContainerLow,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Pressable(
            key: ValueKey('stat-check-$id'),
            onTap: () => showDiceRoller(context,
                title: '${l10n.check} $abbr', modifier: modifier),
            semanticLabel: '${l10n.check}: $name ${_signed(modifier)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                child: Column(children: [
                  Text(abbr,
                      style: t.textTheme.labelSmall?.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .7,
                          color: c.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(_signed(modifier),
                      style: AppType.numeric(t.textTheme.headlineMedium)
                          .copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              height: 1.1)),
                  const SizedBox(height: 2),
                  Text('$score',
                      style: t.textTheme.bodySmall
                          ?.copyWith(fontSize: 12, color: c.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
          Pressable(
            key: ValueKey('stat-save-$id'),
            onTap: () => showDiceRoller(context,
                title: '${l10n.saveLabel} $abbr', modifier: save),
            scale: .98,
            semanticLabel: '${l10n.saveLabel}: $name ${_signed(save)}',
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: c.onSurface.withValues(alpha: .07)))),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  ProficiencyDot(on: saveTrained),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(l10n.statsSave(_signed(save)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.onSurfaceVariant)),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

typedef _SkillRow = ({
  String id,
  String name,
  ({int bonus, bool proficient, bool expert}) check
});
typedef _SkillGroup = ({String header, String abbr, List<_SkillRow> rows});

/// The prototype's skills: a wide flowing segment, then one list grouped by
/// ability. The filter folds untrained rows away by their height.
class _SkillList extends StatefulWidget {
  const _SkillList({required this.groups});
  final List<_SkillGroup> groups;
  @override
  State<_SkillList> createState() => _SkillListState();
}

class _SkillListState extends State<_SkillList> {
  bool _trainedOnly = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];
    for (final group in widget.groups) {
      final visible =
          !_trainedOnly || group.rows.any((r) => r.check.proficient);
      rows.add(Reveal(
        open: visible,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Text(group.header.toUpperCase(),
              style: t.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .96,
                  color: c.onSurfaceVariant)),
        ),
      ));
      for (final row in group.rows) {
        final check = row.check;
        rows.add(Reveal(
          open: !_trainedOnly || check.proficient,
          child: Pressable(
            key: ValueKey('skill-${row.id}'),
            scale: .99,
            onTap: () => showDiceRoller(context,
                title: '${row.name} ${l10n.check}', modifier: check.bonus),
            semanticLabel: '${row.name} ${_signed(check.bonus)}',
            child: ExcludeSemantics(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  SizedBox(
                      width: 14,
                      child: Center(
                          child: ProficiencyDot(
                              on: check.proficient, expert: check.expert))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(row.name,
                        style: t.textTheme.bodyMedium?.copyWith(fontSize: 15)),
                  ),
                  Text(_signed(check.bonus),
                      style: AppType.numeric(t.textTheme.titleMedium)
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FlowSegment<bool>(
        keyPrefix: 'skills-filter',
        values: const [false, true],
        labels: [l10n.statsFilterAll, l10n.statsFilterProficient],
        selected: _trainedOnly,
        onChanged: (v) => setState(() => _trainedOnly = v),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.xl)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      ),
    ]);
  }
}
