import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:qd_and_d/core/models/character_feature.dart';
import 'package:qd_and_d/core/services/spell_service.dart';
import '../character_creation_state.dart';

class ReviewStep extends StatefulWidget {
  const ReviewStep({super.key});

  @override
  State<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends State<ReviewStep> {
  bool _isLoreExpanded = false;
  bool _isSpellsExpanded = false;

  String _formatModifier(int score) {
    final mod = (score ~/ 2) - 5;
    return mod >= 0 ? '+$mod' : '$mod';
  }

  String _localizeAppearance(String? value, String locale) {
    if (value == null || value.isEmpty) return '';
    if (locale != 'ru') return value;
    final map = {
      'Female': 'Женский',
      'Male': 'Мужской',
      'Other': 'Другой',
      'Non-binary': 'Небинарный',
      'Black': 'Черные',
      'Brown': 'Коричневые',
      'Blonde': 'Блонд',
      'Red': 'Рыжие',
      'Gray': 'Серые',
      'White': 'Белые',
      'Bald': 'Лысый',
      'Blue': 'Голубые',
      'Green': 'Зеленые',
      'Hazel': 'Карие',
      'Amber': 'Янтарные',
      'Pale': 'Бледная',
      'Fair': 'Светлая',
      'Tan': 'Смуглая',
      'Olive': 'Оливковая',
      'Dark': 'Темная',
      'Ebony': 'Эбеновая',
      'Copper': 'Медная',
      'Bronze': 'Бронзовая',
      'Silver': 'Серебристая',
      'Gold': 'Золотая',
    };
    return map[value] ?? value;
  }

  String _getLocalizedSkill(AppLocalizations l10n, String skill) {
    final normalizedKey = skill.toLowerCase().replaceAll('-', '_');
    switch (normalizedKey) {
      case 'athletics':
        return l10n.skillAthletics;
      case 'acrobatics':
        return l10n.skillAcrobatics;
      case 'sleight_of_hand':
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
      case 'animal_handling':
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CharacterCreationState>();
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroSection(context, state, locale, theme, l10n),
          const SizedBox(height: 24),
          _buildAppearanceSection(context, state, locale, theme, l10n),
          _buildLoreSection(context, state, theme, l10n),
          const SizedBox(height: 24),
          _buildCombatStats(context, state, theme, l10n),
          const SizedBox(height: 16),
          _buildAbilityScoresGrid(context, state, theme, l10n),
          if (state.selectedSkills.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSkillsSection(context, state, theme, l10n),
          ],
          _buildDynamicFeaturesSection(context, state, locale, theme, l10n),
          const SizedBox(height: 32),
          _buildInfoFooter(context, theme, l10n),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, CharacterCreationState state,
      String locale, ThemeData theme, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (state.avatarPath != null)
              Hero(
                tag: 'character_avatar',
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onPrimaryContainer
                          .withValues(alpha: 0.2),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.file(
                      File(state.avatarPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildDefaultAvatarPattern(theme),
                    ),
                  ),
                ),
              )
            else
              _buildDefaultAvatarPattern(theme),
            const SizedBox(height: 20),
            Text(
              l10n.characterReady,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.name.isEmpty ? l10n.unnamed : state.name,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            if (state.selectedRace != null && state.selectedClass != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      '${state.selectedRace!.getName(locale)} ${state.selectedClass!.getName(locale)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (state.selectedSubclass != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          state.selectedSubclass!.getName(locale),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (state.selectedBackground != null) ...[
              const SizedBox(height: 8),
              Text(
                state.selectedBackground!.getName(locale),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer
                      .withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatarPattern(ThemeData theme) {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          size: 48,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(
      BuildContext context,
      CharacterCreationState state,
      String locale,
      ThemeData theme,
      AppLocalizations l10n) {
    final Map<String, String> attributes = {};
    if (state.age?.isNotEmpty == true) attributes[l10n.age] = state.age!;
    if (state.gender?.isNotEmpty == true) {
      attributes[l10n.gender] = _localizeAppearance(state.gender, locale);
    }
    if (state.height?.isNotEmpty == true) {
      attributes[l10n.height] = state.height!;
    }
    if (state.weight?.isNotEmpty == true) {
      attributes[l10n.weight] = state.weight!;
    }
    if (state.eyes?.isNotEmpty == true) {
      attributes[l10n.eyes] = _localizeAppearance(state.eyes, locale);
    }
    if (state.hair?.isNotEmpty == true) {
      attributes[l10n.hair] = _localizeAppearance(state.hair, locale);
    }
    if (state.skin?.isNotEmpty == true) {
      attributes[l10n.skin] = _localizeAppearance(state.skin, locale);
    }

    if (attributes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.physicalAppearance,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: attributes.entries.map((entry) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoreSection(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    final hasLore = (state.personalityTraits != null &&
            state.personalityTraits!.isNotEmpty) ||
        (state.ideals != null && state.ideals!.isNotEmpty) ||
        (state.bonds != null && state.bonds!.isNotEmpty) ||
        (state.flaws != null && state.flaws!.isNotEmpty) ||
        (state.backstory != null && state.backstory!.isNotEmpty) ||
        (state.appearanceDescription != null &&
            state.appearanceDescription!.isNotEmpty);

    if (!hasLore) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _isLoreExpanded = !_isLoreExpanded;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.history_edu,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.personality,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _isLoreExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
              child: _isLoreExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          if (state.personalityTraits?.isNotEmpty == true)
                            _buildLoreItem(context, theme, l10n.traits,
                                state.personalityTraits!),
                          if (state.ideals?.isNotEmpty == true)
                            _buildLoreItem(
                                context, theme, l10n.ideals, state.ideals!),
                          if (state.bonds?.isNotEmpty == true)
                            _buildLoreItem(
                                context, theme, l10n.bonds, state.bonds!),
                          if (state.flaws?.isNotEmpty == true)
                            _buildLoreItem(
                                context, theme, l10n.flaws, state.flaws!),
                          if (state.appearanceDescription?.isNotEmpty == true)
                            _buildLoreItem(context, theme, l10n.appearanceDesc,
                                state.appearanceDescription!),
                          if (state.backstory?.isNotEmpty == true)
                            _buildLoreItem(context, theme, l10n.backstory,
                                state.backstory!),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoreItem(
      BuildContext context, ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombatStats(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    if (state.selectedClass == null || state.selectedRace == null) {
      return const SizedBox.shrink();
    }

    final conMod = (state.abilityScores['constitution']! ~/ 2) - 5;
    final maxHp = state.hpSelectionMethod == 'roll' && state.rolledHp != null
        ? state.rolledHp! + conMod
        : state.selectedClass!.hitDie + conMod;

    final dexMod = (state.abilityScores['dexterity']! ~/ 2) - 5;

    return Row(
      children: [
        Expanded(
          child: _buildCombatCard(
            context,
            theme,
            l10n.hpShort,
            '$maxHp',
            Icons.favorite,
            theme.colorScheme.errorContainer,
            theme.colorScheme.onErrorContainer,
            true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCombatCard(
            context,
            theme,
            l10n.armorClassAC,
            '${10 + dexMod}',
            Icons.shield,
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurfaceVariant,
            false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCombatCard(
            context,
            theme,
            l10n.initiativeINIT,
            _formatModifier(state.abilityScores['dexterity']!),
            Icons.flash_on,
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurfaceVariant,
            false,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildCombatCard(
            context,
            theme,
            l10n.speedSPEED,
            '${state.selectedRace!.speed}',
            Icons.directions_run,
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.onSurfaceVariant,
            false,
          ),
        ),
      ],
    );
  }

  Widget _buildCombatCard(
      BuildContext context,
      ThemeData theme,
      String label,
      String value,
      IconData icon,
      Color bgColor,
      Color textColor,
      bool isAccent) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon,
              color: isAccent
                  ? textColor.withValues(alpha: 0.9)
                  : theme.colorScheme.primary,
              size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: isAccent ? textColor : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isAccent
                  ? textColor.withValues(alpha: 0.8)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAbilityScoresGrid(BuildContext context,
      CharacterCreationState state, ThemeData theme, AppLocalizations l10n) {
    final abilities = [
      ('strength', l10n.abilityStrAbbr, Icons.fitness_center),
      ('dexterity', l10n.abilityDexAbbr, Icons.directions_run),
      ('constitution', l10n.abilityConAbbr, Icons.favorite),
      ('intelligence', l10n.abilityIntAbbr, Icons.lightbulb),
      ('wisdom', l10n.abilityWisAbbr, Icons.visibility),
      ('charisma', l10n.abilityChaAbbr, Icons.people),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.8,
        children: abilities.map((ability) {
          final key = ability.$1;
          final abbr = ability.$2;
          final icon = ability.$3;
          final baseScore = state.abilityScores[key]!;
          final racialBonus =
              state.selectedRace?.abilityScoreIncreases[key] ?? 0;
          final finalScore = baseScore + racialBonus;
          final finalModifier = (finalScore ~/ 2) - 5;
          final modifierStr =
              finalModifier >= 0 ? '+$finalModifier' : '$finalModifier';

          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(icon,
                        size: 14,
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.5)),
                  ),
                ),
                if (racialBonus > 0)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '+$racialBonus',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        '$finalScore',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          height: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          modifierStr,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      abbr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSkillsSection(BuildContext context, CharacterCreationState state,
      ThemeData theme, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${l10n.skillProficiencies} (${state.selectedSkills.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: state.selectedSkills.map((skill) {
            final isExpertise = state.selectedExpertise.contains(skill);
            return Chip(
              label: Text(_getLocalizedSkill(l10n, skill)),
              backgroundColor: isExpertise
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                color: isExpertise
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              avatar: isExpertise
                  ? Icon(Icons.stars,
                      color: theme.colorScheme.onTertiaryContainer)
                  : null,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDynamicFeaturesSection(
      BuildContext context,
      CharacterCreationState state,
      String locale,
      ThemeData theme,
      AppLocalizations l10n) {
    final features = <CharacterFeature>[];
    if (state.selectedRace != null) {
      features.addAll(state.selectedRace!.traits);
    }
    if (state.selectedClass != null &&
        state.selectedClass!.features.containsKey(1)) {
      features.addAll(state.selectedClass!.features[1]!);
    }

    List<String> spells = List<String>.from(state.selectedSpells);
    final limits = state.getSpellLimits();
    if (limits.spellsKnown >= 999 && state.selectedClass != null) {
      final classSpells =
          SpellService.getSpellsForClass(state.selectedClass!.id);
      final level1Spells =
          classSpells.where((s) => s.level == 1).map((s) => s.id).toList();
      spells.addAll(level1Spells);
    }

    spells = spells.toSet().toList(); // Deduplicate

    if (features.isEmpty && spells.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        /*
         Using English raw strings for now to match exactly what you want,
         feel free to map these to l10n keys if they exist!
        */
        Text(
          'Стартовые умения (Ур. 1)',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (spells.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Заклинания (Фокусы / 1 ур.)',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.tertiary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final displaySpells =
                _isSpellsExpanded ? spells : spells.take(3).toList();

            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              child: Column(
                children: [
                  ...displaySpells.map((spellId) =>
                      _buildSpellCard(context, spellId, locale, theme, l10n)),
                  if (spells.length > 3) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSpellsExpanded = !_isSpellsExpanded;
                        });
                      },
                      icon: Icon(
                        _isSpellsExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(
                        _isSpellsExpanded
                            ? (locale == 'ru' ? 'Скрыть' : 'Hide')
                            : (locale == 'ru'
                                ? 'Показать все (${spells.length})'
                                : 'Show all (${spells.length})'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
        if (features.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Умения расы и класса',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...features
              .map((f) => _buildFeatureCard(context, f, locale, theme, l10n)),
        ],
      ],
    );
  }

  Widget _buildSpellCard(BuildContext context, String spellId, String locale,
      ThemeData theme, AppLocalizations l10n) {
    // 1. Resolve spell by ID to get full localization
    final spell = SpellService.getSpellById(spellId);
    final spellName = spell != null
        ? (locale == 'ru' ? spell.nameRu : spell.nameEn)
        : spellId;
    final spellLevel = spell != null
        ? (spell.level == 0 ? 'Фокус' : '${spell.level} уровень')
        : 'Заклинание';

    // 2. Build Card UI instead of Chip
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.auto_fix_high,
              color: theme.colorScheme.onTertiaryContainer, size: 20),
        ),
        title: Text(
          spellName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          spellLevel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature,
      String locale, ThemeData theme, AppLocalizations l10n) {
    final featureName = locale == 'ru' ? feature.nameRu : feature.nameEn;
    final featureType = feature.type == FeatureType.passive
        ? 'Пассивное умение'
        : 'Активное умение';

    // 2. Build Card UI instead of Chip
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.auto_awesome,
              color: theme.colorScheme.onSecondaryContainer, size: 20),
        ),
        title: Text(
          featureName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          featureType,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoFooter(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.level1Info,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
