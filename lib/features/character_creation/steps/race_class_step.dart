import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/services/character_data_service.dart';
import '../../../core/models/race_data.dart';
import '../../../core/models/class_data.dart';
import '../character_creation_state.dart';

class RaceClassStep extends StatefulWidget {
  const RaceClassStep({super.key});

  @override
  State<RaceClassStep> createState() => _RaceClassStepState();
}

class _RaceClassStepState extends State<RaceClassStep> {
  String? _expandedRaceId;
  String? _expandedClassId;

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
        return key.substring(0, 3).toUpperCase();
    }
  }

  String _getLocalizedSkill(AppLocalizations l10n, String skill) {
    switch (skill.toLowerCase()) {
      case 'athletics':
        return l10n.skillAthletics;
      case 'acrobatics':
        return l10n.skillAcrobatics;
      case 'sleight of hand':
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
      case 'animal handling':
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
        return skill;
    }
  }

  String _getLocalizedLanguage(AppLocalizations l10n, String lang) {
    if (lang.startsWith('choice:')) {
      return '${l10n.choose}: ${lang.split(':')[1]}';
    }

    switch (lang.toLowerCase()) {
      case 'common':
        return l10n.langCommon;
      case 'dwarvish':
        return l10n.langDwarvish;
      case 'elvish':
        return l10n.langElvish;
      case 'giant':
        return l10n.langGiant;
      case 'gnomish':
        return l10n.langGnomish;
      case 'goblin':
        return l10n.langGoblin;
      case 'halfling':
        return l10n.langHalfling;
      case 'orc':
        return l10n.langOrc;
      case 'abyssal':
        return l10n.langAbyssal;
      case 'celestial':
        return l10n.langCelestial;
      case 'draconic':
        return l10n.langDraconic;
      case 'deep speech':
        return l10n.langDeepSpeech;
      case 'infernal':
        return l10n.langInfernal;
      case 'primordial':
        return l10n.langPrimordial;
      case 'sylvan':
        return l10n.langSylvan;
      case 'undercommon':
        return l10n.langUndercommon;
      default:
        return lang;
    }
  }

  String _getLocalizedProficiency(AppLocalizations l10n, String prof) {
    final lower =
        prof.toLowerCase().replaceAll('_', ' '); // handle snake_case from JSON

    // Armor categories
    if (lower.contains('light armor')) return l10n.armorTypeLight;
    if (lower.contains('medium armor')) return l10n.armorTypeMedium;
    if (lower.contains('heavy armor')) return l10n.armorTypeHeavy;
    if (lower.contains('shields')) return l10n.armorTypeShield;

    // Weapon categories
    if (lower.contains('simple weapons')) return l10n.propertySimple;
    if (lower.contains('martial weapons')) return l10n.propertyMartial;

    // Specific Weapons
    switch (lower) {
      case 'club':
        return l10n.weaponClub;
      case 'dagger':
        return l10n.weaponDagger;
      case 'greatclub':
        return l10n.weaponGreatclub;
      case 'handaxe':
        return l10n.weaponHandaxe;
      case 'javelin':
        return l10n.weaponJavelin;
      case 'light hammer':
        return l10n.weaponLightHammer;
      case 'mace':
        return l10n.weaponMace;
      case 'quarterstaff':
        return l10n.weaponQuarterstaff;
      case 'sickle':
        return l10n.weaponSickle;
      case 'spear':
        return l10n.weaponSpear;
      case 'light crossbow':
        return l10n.weaponLightCrossbow;
      case 'dart':
        return l10n.weaponDart;
      case 'shortbow':
        return l10n.weaponShortbow;
      case 'sling':
        return l10n.weaponSling;
      case 'battleaxe':
        return l10n.weaponBattleaxe;
      case 'flail':
        return l10n.weaponFlail;
      case 'glaive':
        return l10n.weaponGlaive;
      case 'greataxe':
        return l10n.weaponGreataxe;
      case 'greatsword':
        return l10n.weaponGreatsword;
      case 'halberd':
        return l10n.weaponHalberd;
      case 'lance':
        return l10n.weaponLance;
      case 'longsword':
        return l10n.weaponLongsword;
      case 'maul':
        return l10n.weaponMaul;
      case 'morningstar':
        return l10n.weaponMorningstar;
      case 'pike':
        return l10n.weaponPike;
      case 'rapier':
        return l10n.weaponRapier;
      case 'scimitar':
        return l10n.weaponScimitar;
      case 'shortsword':
        return l10n.weaponShortsword;
      case 'trident':
        return l10n.weaponTrident;
      case 'war pick':
        return l10n.weaponWarPick;
      case 'warhammer':
        return l10n.weaponWarhammer;
      case 'whip':
        return l10n.weaponWhip;
      case 'blowgun':
        return l10n.weaponBlowgun;
      case 'hand crossbow':
        return l10n.weaponHandCrossbow;
      case 'heavy crossbow':
        return l10n.weaponHeavyCrossbow;
      case 'longbow':
        return l10n.weaponLongbow;
      case 'net':
        return l10n.weaponNet;
    }

    return prof;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context)!;

    final races = CharacterDataService.getAllRaces();
    final classes = CharacterDataService.getAllClasses();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.chooseRaceClass,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.raceClassSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 32),

        // Race Selection
        Text(
          l10n.race,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (races.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.loadingRaces),
            ),
          )
        else
          ...races.map((race) {
            final isSelected = state.selectedRace?.id == race.id;
            final isExpanded = _expandedRaceId == race.id;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => state.updateRace(race),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  race.getName(locale),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : null,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  race.getDescription(locale),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                  maxLines: isExpanded ? null : 2,
                                  overflow:
                                      isExpanded ? null : TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedRaceId = isExpanded ? null : race.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.2)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRaceDetails(
                              context, race, locale, isSelected, l10n),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),

        const SizedBox(height: 32),

        // Class Selection
        Text(
          l10n.classLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (classes.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.loadingClasses),
            ),
          )
        else
          ...classes.map((classData) {
            final isSelected = state.selectedClass?.id == classData.id;
            final isExpanded = _expandedClassId == classData.id;

            return Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : null,
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => state.updateClass(classData),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classData.getName(locale),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer
                                            : null,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  classData.getDescription(locale),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                  maxLines: isExpanded ? null : 2,
                                  overflow:
                                      isExpanded ? null : TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.hitDieType(classData.hitDie),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer
                                            : null,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onSecondaryContainer
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            onPressed: () {
                              setState(() {
                                _expandedClassId =
                                    isExpanded ? null : classData.id;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    Divider(
                      height: 1,
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer
                              .withValues(alpha: 0.2)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClassDetails(
                              context, classData, locale, isSelected, l10n),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRaceDetails(BuildContext context, RaceData race, String locale,
      bool isSelected, AppLocalizations l10n) {
    final textColor = isSelected
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Speed
        Row(
          children: [
            Icon(Icons.speed,
                size: 16, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.speed(race.speed),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Ability Score Increases
        if (race.abilityScoreIncreases.isNotEmpty) ...[
          Text(
            l10n.abilityScoreIncreases,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: race.abilityScoreIncreases.entries.map<Widget>((entry) {
              return Chip(
                label: Text(
                  '${_getAbilityAbbr(l10n, entry.key)}: +${entry.value}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: isSelected
                    ? Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Languages
        if (race.languages.isNotEmpty) ...[
          Text(
            l10n.languages,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            race.languages
                .map((l) => _getLocalizedLanguage(l10n, l))
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 12),
        ],

        // Traits
        if (race.traits.isNotEmpty) ...[
          Text(
            l10n.racialTraits,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          ...race.traits.map((trait) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: textColor)),
                    Expanded(
                      child: Text(
                        trait.getName(locale),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textColor.withValues(alpha: 0.8),
                            ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildClassDetails(BuildContext context, ClassData classData,
      String locale, bool isSelected, AppLocalizations l10n) {
    final textColor = isSelected
        ? Theme.of(context).colorScheme.onSecondaryContainer
        : Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hit Die
        Row(
          children: [
            Icon(Icons.favorite,
                size: 16, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              l10n.hitDieType(classData.hitDie),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Saving Throws
        if (classData.savingThrowProficiencies.isNotEmpty) ...[
          Text(
            l10n.savingThrowProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.savingThrowProficiencies
                .map((s) => _getAbilityAbbr(l10n, s))
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 12),
        ],

        // Skill Proficiencies
        Text(
          l10n.skillProficiencies,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: textColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.chooseSkills(
              classData.skillProficiencies.choose,
              classData.skillProficiencies.from
                  .map((s) => _getLocalizedSkill(l10n, s))
                  .join(', ')),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor.withValues(alpha: 0.8),
              ),
        ),
        const SizedBox(height: 12),

        // Armor & Weapon Proficiencies
        if (classData.armorProficiencies.isNotEmpty) ...[
          Text(
            l10n.armorProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.armorProficiencies
                .toList()
                .map((p) => _getLocalizedProficiency(l10n, p))
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 12),
        ],

        if (classData.weaponProficiencies.isNotEmpty) ...[
          Text(
            l10n.weaponProficiencies,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            classData.weaponProficiencies
                .toList()
                .map((p) => _getLocalizedProficiency(l10n, p))
                .join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                ),
          ),
        ],
      ],
    );
  }
}
