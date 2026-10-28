import 'package:flutter/material.dart';
import '../../character_level_up/widgets/advancement_climb.dart';
import '../../character_level_up/widgets/advancement_spells.dart';
import '../../../core/ui/companion_kit.dart' show LineIcon;
import '../../../core/ui/page_kit.dart' show Tr;
import '../../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart' show classAccent, classSigil;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/services/feature_service.dart';
import '../../../core/services/spell_service.dart';
import '../../../core/constants/ranger_options.dart';
import '../character_creation_state.dart';
import '../../../ui/widgets/expressive_choice_selector.dart';
import '../../../core/utils/localization_helper.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class FeaturesSpellsStep extends StatelessWidget {
  const FeaturesSpellsStep({super.key, this.embedded = false});

  /// Inside the «Пролог» page: the chapter asks the question itself, and
  /// the list leaves room for the island dock.
  final bool embedded;

  static const Map<String, List<String>> _fightingStyleOptions = {
    'fighter': [
      'archery',
      'defense',
      'dueling',
      'great_weapon',
      'protection',
      'two_weapon'
    ],
    'paladin': ['defense', 'dueling', 'great_weapon', 'protection'],
    'ranger': ['archery', 'defense', 'dueling', 'two_weapon'],
  };

  // Map internal style names to potential Feature IDs
  // We check multiple patterns because IDs might vary (e.g. generic vs class-specific)
  String? _findFeatureIdForStyle(String style, String classId) {
    // Try class specific first
    final classSpecificId =
        '$classId-fighting-style-$style'; // e.g. fighter-fighting-style-archery
    if (FeatureService.getFeatureById(classSpecificId) != null) {
      return classSpecificId;
    }

    // Try generic
    final genericId = 'fighting-style-$style'; // e.g. fighting-style-archery
    if (FeatureService.getFeatureById(genericId) != null) return genericId;

    // Try alternate generic (e.g. great-weapon-fighting)
    if (style == 'great_weapon') {
      if (FeatureService.getFeatureById(
              'fighting-style-great-weapon-fighting') !=
          null) {
        return 'fighting-style-great-weapon-fighting';
      }
      if (FeatureService.getFeatureById(
              '$classId-fighting-style-great-weapon-fighting') !=
          null) {
        return '$classId-fighting-style-great-weapon-fighting';
      }
    }
    if (style == 'two_weapon') {
      if (FeatureService.getFeatureById('fighting-style-two-weapon-fighting') !=
          null) {
        return 'fighting-style-two-weapon-fighting';
      }
      if (FeatureService.getFeatureById(
              '$classId-fighting-style-two-weapon-fighting') !=
          null) {
        return '$classId-fighting-style-two-weapon-fighting';
      }
    }

    return null;
  }

  static const List<String> _draconicAncestryIds = [
    'dragon-ancestor-black---acid-damage',
    'dragon-ancestor-blue---lightning-damage',
    'dragon-ancestor-brass---fire-damage',
    'dragon-ancestor-bronze---lightning-damage',
    'dragon-ancestor-copper---acid-damage',
    'dragon-ancestor-gold---fire-damage',
    'dragon-ancestor-green---poison-damage',
    'dragon-ancestor-red---fire-damage',
    'dragon-ancestor-silver---cold-damage',
    'dragon-ancestor-white---cold-damage',
  ];

  String _getLocalizedActionEconomy(AppLocalizations l10n, String economy) {
    final lower = economy.toLowerCase();
    if (lower.contains('bonus')) return l10n.actionTypeBonus;
    if (lower.contains('reaction')) return l10n.actionTypeReaction;
    if (lower.contains('action')) return l10n.actionTypeAction;
    if (lower.contains('free')) return l10n.actionTypeFree;
    return economy;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterCreationState>(
      builder: (context, state, child) {
        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).languageCode;

        if (state.selectedClass == null || state.selectedRace == null) {
          return Center(child: Text(l10n.selectClassFirst));
        }

        // Create temporary character to check for features
        final tempChar = Character(
          id: const Uuid().v4(),
          name: 'Temp',
          race: state.selectedRace!.id,
          characterClass: state.selectedClass!.id,
          subclass: state.selectedSubclass?.id,
          level: 1,
          maxHp: 10,
          currentHp: 10,
          abilityScores: AbilityScores(
            strength: 10,
            dexterity: 10,
            constitution: 10,
            intelligence: 10,
            wisdom: 10,
            charisma: 10,
          ),
          spellSlots: [],
          maxSpellSlots: [],
        );

        // Get standard features from FeatureService
        final standardFeatures =
            FeatureService.getFeaturesForCharacter(tempChar);

        // Get features from the ClassData object itself (for imported/custom classes)
        final classFeatures = state.selectedClass!.features[1] ?? [];

        // Merge lists, avoiding duplicates by ID
        final allFeatures = [...standardFeatures];
        final existingIds = standardFeatures.map((f) => f.id).toSet();

        for (var feature in classFeatures) {
          // The same feature can come from both sources under two ids.
          if (!existingIds.contains(feature.id) &&
              !allFeatures.any((f) => f.nameEn == feature.nameEn)) {
            allFeatures.add(feature);
            existingIds.add(feature.id);
          }
        }

        // One card per feature even when two sources name it twice.
        final seen = <String>{};
        allFeatures.retainWhere((f) =>
            seen.add(f.nameEn.trim().toLowerCase()) &
            seen.add('ru:${f.nameRu.trim().toLowerCase()}'));

        // Filter and Categorize Features
        final choiceFeatures = <CharacterFeature>[];
        final optionalFeatures = <CharacterFeature>[];
        final passiveFeatures = <CharacterFeature>[];

        for (var f in allFeatures) {
          if (f.isOptional) {
            optionalFeatures.add(f);
            continue;
          }

          // Skip known individual option features
          if (f.id.startsWith('dragon-ancestor-')) continue;

          if (f.id.contains('fighting-style')) {
            if (f.id.endsWith('fighting-style')) {
              choiceFeatures.add(f); // Parent Fighting Style
            }
            continue; // Skip specific styles
          }

          if (f.id == 'dragon-ancestor') {
            choiceFeatures.add(f);
            continue;
          }

          if (f.id == 'expertise' || f.id.contains('expertise')) {
            choiceFeatures.add(f);
            continue;
          }

          if (f.id == 'favored-enemy' || f.id == 'natural-explorer') {
            choiceFeatures.add(f);
            continue;
          }

          // Default to passive
          passiveFeatures.add(f);
        }

        // Subclass Selection Logic
        final showSubclassSelection =
            state.selectedClass!.subclasses.isNotEmpty &&
                state.selectedClass!.subclassLevel <= 1;

        // Inside the «Пролог» page the chapter scrolls with the page.
        final scroll = embedded
            ? (Widget child) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 148),
                child: child)
            : (Widget child) => SingleChildScrollView(
                padding: const EdgeInsets.all(16), child: child);
        return scroll(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!embedded) ...[
                Text(
                  l10n.featuresStepTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.featuresStepSubtitle(
                      state.selectedClass!.getName(locale)),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
              ],

              // 1. Subclass Selector (Highest Priority)
              if (showSubclassSelection) ...[
                _buildSubclassSelection(context, state, l10n, locale),
                const SizedBox(height: 24),
              ],

              if (choiceFeatures.isEmpty &&
                  passiveFeatures.isEmpty &&
                  optionalFeatures.isEmpty)
                _buildNoFeaturesMessage(context, l10n)
              else
                ...choiceFeatures.map((feature) =>
                    _buildFeatureItem(context, state, feature, l10n, locale)),

              // 4. Passive Features
              if (passiveFeatures.isNotEmpty) ...[
                if (choiceFeatures.isNotEmpty) const Divider(height: 32),
                ...passiveFeatures.map((feature) =>
                    _buildFeatureItem(context, state, feature, l10n, locale)),
              ],

              if (optionalFeatures.isNotEmpty) ...[
                if (choiceFeatures.isNotEmpty || passiveFeatures.isNotEmpty)
                  const Divider(height: 32),
                Text(
                  l10n.optionalFeaturesLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 12),
                ...optionalFeatures.map(
                  (feature) => _buildOptionalFeatureCard(
                      context, state, feature, locale),
                ),
              ],

              // Spell Selection
              if (state.selectedClass!.spellcasting != null) ...[
                const SizedBox(height: 24),
                _buildSpellSelection(context, state, l10n, locale),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(BuildContext context, CharacterCreationState state,
      CharacterFeature feature, AppLocalizations l10n, String locale) {
    final id = feature.id.toLowerCase();

    // 1. Гибкий перехват для Избранного врага
    if (id.contains('favored') || id.contains('enemy')) {
      return _buildFavoredEnemyChoice(context, state, feature, l10n, locale);
    }

    // 2. Гибкий перехват для Исследователя природы
    if (id.contains('natural') || id.contains('explorer')) {
      return _buildNaturalExplorerChoice(context, state, feature, l10n, locale);
    }

    // Другие специфичные выборы
    if (id == 'dragon-ancestor') {
      return _buildDraconicAncestryChoice(
          context, state, feature, l10n, locale);
    }
    if (id.endsWith('fighting-style')) {
      return _buildFightingStyleChoice(context, state, feature, l10n, locale);
    }

    // 3. Стандартный рендер для всего остального
    return _buildFeatureCard(context, feature, locale, l10n);
  }

  Widget _buildSubclassSelection(BuildContext context,
      CharacterCreationState state, AppLocalizations l10n, String locale) {
    // The subclass as choice cards with the whole text behind the «i».
    final cls = state.selectedClass!;
    final accent = classAccent(context, cls.id);
    final glyph = classSigil(cls.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _group(context, l10n.selectSubclass, cls.getName(locale)),
      for (final sub in cls.subclasses)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AdvancementPick(
            selected: state.selectedSubclass?.id == sub.id,
            title: sub.getName(locale),
            subtitle: advancementGist(sub.getDescription(locale), max: 120),
            icon: glyph,
            accent: accent,
            onTap: () => state.updateSubclass(sub),
            onInfo: () => showAdvancementInfo(
                context,
                AdvancementInfo(
                    kicker: '${l10n.selectSubclass} · ${cls.getName(locale)}',
                    title: sub.getName(locale),
                    icon: glyph,
                    accent: accent,
                    text: sub.getDescription(locale))),
          ),
        ),
    ]);
  }

  Widget _group(BuildContext context, String title, [String? note]) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
        ),
        if (note != null)
          Text(note,
              style: TextStyle(fontSize: 12.5, color: c.onSurfaceVariant)),
      ]),
    );
  }

  Widget _buildNoFeaturesMessage(BuildContext context, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            size: 32,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noFeaturesAtLevel1,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature,
      String locale, AppLocalizations l10n) {
    // A gained feature as a card with a seal and a short line; the whole
    // text opens in a sheet (wave 6).
    final classId =
        context.read<CharacterCreationState>().selectedClass?.id ?? '';
    final accent = classAccent(context, classId);
    final glyph = advancementFeatureGlyph(feature.iconName);
    final economy = feature.actionEconomy == null
        ? null
        : _getLocalizedActionEconomy(l10n, feature.actionEconomy!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AdvancementGain(
        icon: glyph,
        title: feature.getName(locale),
        text: [
          if (economy != null) economy,
          advancementGist(feature.getDescription(locale), max: 110),
        ].join(' · '),
        accent: accent,
        onTap: () => showAdvancementInfo(
            context,
            AdvancementInfo(
                kicker: [
                  if (economy != null) economy,
                  context
                          .read<CharacterCreationState>()
                          .selectedClass
                          ?.getName(locale) ??
                      '',
                ].where((e) => e.isNotEmpty).join(' · '),
                title: feature.getName(locale),
                icon: glyph,
                accent: accent,
                text: feature.getDescription(locale))),
      ),
    );
  }

  Widget _buildOptionalFeatureCard(
    BuildContext context,
    CharacterCreationState state,
    CharacterFeature feature,
    String locale,
  ) {
    final selected = state.selectedFeatureOptions[feature.id] == feature.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: selected ? 3 : 1,
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) {
          state.toggleOptionalFeature(feature.id, value ?? false);
        },
        secondary: Icon(
          Icons.tune_rounded,
          color: selected ? colorScheme.primary : colorScheme.outline,
        ),
        title: Text(
          feature.getName(locale),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          feature.getDescription(locale),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildFightingStyleChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    final classId = state.selectedClass!.id.toLowerCase();
    final styles =
        _fightingStyleOptions[classId] ?? _fightingStyleOptions['fighter']!;
    final accent = classAccent(context, classId);
    // The style as choice cards (wave 6): a long press or the «i» reads it.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _group(context, feature.getName(locale), l10n.chooseFightingStyle),
      for (final style in styles)
        if (_findFeatureIdForStyle(style, classId) case final id?)
          Builder(builder: (context) {
            final localized =
                LocalizationHelper.getLocalizedFightingStyle(style, l10n);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AdvancementPick(
                selected: state.selectedFeatureOptions[feature.id] == id,
                title: localized.name,
                subtitle: localized.description,
                icon: 'sword',
                accent: accent,
                onTap: () => state.selectFeatureOption(feature.id, id),
                onInfo: () => showAdvancementInfo(
                    context,
                    AdvancementInfo(
                        kicker: feature.getName(locale),
                        title: localized.name,
                        icon: 'sword',
                        accent: accent,
                        text: localized.description)),
              ),
            );
          }),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildDraconicAncestryChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
            color: Theme.of(context).colorScheme.secondary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pets,
                    color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(feature.getDescription(locale)),
            const SizedBox(height: 16),
            ExpressiveChoiceSelector<String>(
              value: state.selectedFeatureOptions[feature.id],
              items: _draconicAncestryIds,
              placeholder: l10n.choose,
              title: feature.getName(locale),
              labelBuilder: (id) {
                final f = FeatureService.getFeatureById(id);
                return f?.getName(locale) ?? id;
              },
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption(feature.id, value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoredEnemyChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(Icons.gps_fixed,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feature.getDescription(locale),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ExpressiveChoiceSelector<String>(
              value: state.selectedFeatureOptions['favored_enemy'],
              items: RangerOptions.favoredEnemies.keys.toList(),
              placeholder: l10n.choose,
              title: feature.getName(locale),
              labelBuilder: (key) {
                return locale == 'ru'
                    ? RangerOptions.favoredEnemies[key]!['ru']!
                    : RangerOptions.favoredEnemies[key]!['en']!;
              },
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption('favored_enemy', value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNaturalExplorerChoice(
      BuildContext context,
      CharacterCreationState state,
      CharacterFeature feature,
      AppLocalizations l10n,
      String locale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(Icons.terrain,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    feature.getName(locale),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feature.getDescription(locale),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ExpressiveChoiceSelector<String>(
              value: state.selectedFeatureOptions['natural_explorer'],
              items: RangerOptions.naturalExplorers.keys.toList(),
              placeholder: l10n.choose,
              title: feature.getName(locale),
              labelBuilder: (key) {
                return locale == 'ru'
                    ? RangerOptions.naturalExplorers[key]!['ru']!
                    : RangerOptions.naturalExplorers[key]!['en']!;
              },
              onChanged: (value) {
                if (value != null) {
                  state.selectFeatureOption('natural_explorer', value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellSelection(BuildContext context,
      CharacterCreationState state, AppLocalizations l10n, String locale) {
    final c = Theme.of(context).colorScheme;
    if (!state.hasAnySpellChoicesAtLevel1) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          LineIcon('magic', size: 20, color: c.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.noSpellsAtLevel1,
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.onSurfaceVariant))),
        ]),
      );
    }
    final classSpells = SpellService.getSpellsForClass(state.selectedClass!.id);
    final cantrips = classSpells.where((s) => s.level == 0).toList()
      ..sort((a, b) => a.getName(locale).compareTo(b.getName(locale)));
    final firsts = classSpells.where((s) => s.level == 1).toList()
      ..sort((a, b) => a.getName(locale).compareTo(b.getName(locale)));
    final limits = state.getSpellLimits();
    // Over the limit a new pick takes the place of the earliest one of the
    // same circle.
    void pick(String id, List<dynamic> pool, int limit) {
      if (!state.selectedSpells.contains(id) && limit > 0 && limit < 999) {
        final mine = state.selectedSpells
            .where((s) => pool.any((p) => p.id == s))
            .toList();
        if (mine.length >= limit) state.toggleSpell(mine.first);
      }
      state.toggleSpell(id);
    }

    Set<String> picked(List<dynamic> pool) => {
          for (final id in state.selectedSpells)
            if (pool.any((p) => p.id == id)) id
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (cantrips.isNotEmpty && limits.cantrips > 0) ...[
        AdvancementSpellList(
          title: l10n.cantrips,
          spells: cantrips.cast(),
          selected: picked(cantrips),
          limit: limits.cantrips,
          school: (s) => spellLine(context, s),
          onToggle: (id) => pick(id, cantrips, limits.cantrips),
        ),
        const SizedBox(height: 18),
      ],
      if (firsts.isNotEmpty && limits.spellsKnown > 0)
        AdvancementSpellList(
          title: Tr(context).t('Заклинания 1-го круга', 'Level 1 spells'),
          spells: firsts.cast(),
          selected: picked(firsts),
          limit: limits.spellsKnown >= 999 ? 0 : limits.spellsKnown,
          note: limits.spellsKnown >= 999
              ? Tr(context).t(
                  'Класс готовит заклинания из всего списка каждый день — выбирать сейчас не обязательно.',
                  'The class prepares from its whole list each day — no need to pick now.')
              : null,
          school: (s) => spellLine(context, s),
          onToggle: (id) => pick(id, firsts, limits.spellsKnown),
        ),
    ]);
  }

}
