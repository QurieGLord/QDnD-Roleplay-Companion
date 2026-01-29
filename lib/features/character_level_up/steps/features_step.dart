import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/models/class_data.dart';

class FeaturesStep extends StatefulWidget {
  final List<CharacterFeature> newFeatures;
  final List<int> newSpellSlots;
  final List<int> oldSpellSlots;
  final VoidCallback onNext;
  final ClassData classData;
  final int nextLevel;
  final Function(String featureId, String optionId) onOptionSelected;

  const FeaturesStep({
    Key? key,
    required this.newFeatures,
    required this.newSpellSlots,
    required this.oldSpellSlots,
    required this.onNext,
    required this.classData,
    required this.nextLevel,
    required this.onOptionSelected,
  }) : super(key: key);

  @override
  State<FeaturesStep> createState() => _FeaturesStepState();
}

class _FeaturesStepState extends State<FeaturesStep> {
  final Map<String, String> _selections = {}; // featureId -> optionId

  // Fighting Styles (Hardcoded for now as they aren't in JSON structure yet)
  final List<Map<String, String>> _fightingStyles = [
    {'id': 'defense', 'name': 'Defense', 'desc': '+1 bonus to AC while wearing armor'},
    {'id': 'dueling', 'name': 'Dueling', 'desc': '+2 damage with one-handed melee weapon'},
    {'id': 'great_weapon', 'name': 'Great Weapon Fighting', 'desc': 'Reroll 1 or 2 on damage dice for two-handed weapons'},
    {'id': 'protection', 'name': 'Protection', 'desc': 'Use reaction to impose disadvantage on attack against ally'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    
    final hasSpellChanges = widget.newSpellSlots.isNotEmpty && 
        (widget.newSpellSlots.length > widget.oldSpellSlots.length || 
         widget.newSpellSlots.asMap().entries.any((e) => e.value > (widget.oldSpellSlots.length > e.key ? widget.oldSpellSlots[e.key] : 0)));

    // Determine required choices
    bool needsFightingStyle = widget.newFeatures.any((f) => f.id == 'fighting_style');
    bool needsSubclass = widget.nextLevel == widget.classData.subclassLevel;

    bool allChoicesMade = true;
    if (needsFightingStyle && !_selections.containsKey('fighting_style')) allChoicesMade = false;
    if (needsSubclass && !_selections.containsKey('subclass')) allChoicesMade = false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            l10n.newAbilities,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.unlocksAtLevel(widget.nextLevel),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                if (widget.newFeatures.isEmpty && !hasSpellChanges && !needsSubclass)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(l10n.noNewFeaturesAtLevel),
                    ),
                  ),

                if (hasSpellChanges) ...[
                  _buildSectionHeader(context, l10n.magic),
                  Card(
                    elevation: 2,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_fix_high, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                l10n.spellSlotsIncreased,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSpellSlotGrid(context, l10n),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (needsSubclass) ...[
                  _buildSectionHeader(context, _getSubclassTitle(l10n, widget.classData.id)),
                  _buildSubclassChoice(context),
                  const SizedBox(height: 16),
                ],

                if (widget.newFeatures.isNotEmpty) ...[
                  _buildSectionHeader(context, l10n.classFeatures),
                  ...widget.newFeatures.map((feature) {
                    if (feature.id == 'fighting_style') {
                      return _buildFightingStyleChoice(context, feature, l10n);
                    }
                    return _buildFeatureCard(context, feature);
                  }).toList(),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: allChoicesMade ? widget.onNext : null,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: Text(allChoicesMade ? l10n.continueLabel : l10n.makeChoices),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubclassChoice(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      children: widget.classData.subclasses.map((subclass) {
        final isSelected = _selections['subclass'] == subclass.id;
        final colorScheme = Theme.of(context).colorScheme;
        
        return Card(
          elevation: isSelected ? 4 : 1,
          color: isSelected ? colorScheme.primaryContainer : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selections['subclass'] = subclass.id;
                widget.onOptionSelected('subclass', subclass.id);
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Radio<String>(
                    value: subclass.id,
                    groupValue: _selections['subclass'],
                    onChanged: (value) {
                      setState(() {
                        _selections['subclass'] = value!;
                        widget.onOptionSelected('subclass', value);
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subclass.getName(locale),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subclass.getDescription(locale),
                          style: TextStyle(
                            fontSize: 14,
                             color: isSelected ? colorScheme.onPrimaryContainer.withOpacity(0.8) : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) 
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check_circle, color: colorScheme.primary),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFightingStyleChoice(BuildContext context, CharacterFeature feature, AppLocalizations l10n) {
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFeatureCard(context, feature), // Show description first
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text(l10n.chooseFightingStyle, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ..._fightingStyles.map((style) {
          final isSelected = _selections['fighting_style'] == style['id'];
          return Card(
            elevation: isSelected ? 4 : 1,
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
            margin: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
            child: RadioListTile<String>(
              value: style['id']!,
              groupValue: _selections['fighting_style'],
              onChanged: (value) {
                setState(() {
                  _selections['fighting_style'] = value!;
                  widget.onOptionSelected('fighting_style', value);
                });
              },
              title: Text(style['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(style['desc']!),
              secondary: Icon(Icons.sports_martial_arts),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  String _getSubclassTitle(AppLocalizations l10n, String classId) {
    switch (classId.toLowerCase()) {
      case 'barbarian':
      case 'варвар':
        return l10n.primalPath;
      case 'bard':
      case 'бард':
        return l10n.bardCollege;
      case 'cleric':
      case 'жрец':
        return l10n.divineDomain;
      case 'druid':
      case 'друид':
        return l10n.druidCircle;
      case 'fighter':
      case 'воин':
        return l10n.martialArchetype;
      case 'monk':
      case 'монах':
        return l10n.monasticTradition;
      case 'paladin':
      case 'паладин':
        return l10n.sacredOath;
      case 'ranger':
      case 'следопыт':
        return l10n.rangerArchetype;
      case 'rogue':
      case 'плут':
        return l10n.roguishArchetype;
      case 'sorcerer':
      case 'чародей':
        return l10n.sorcerousOrigin;
      case 'warlock':
      case 'колдун':
        return l10n.otherworldlyPatron;
      case 'wizard':
      case 'волшебник':
        return l10n.arcaneTradition;
      default:
        return l10n.selectSubclass;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  String _getFeatureTypeLabel(AppLocalizations l10n, FeatureType type) {
    switch (type) {
      case FeatureType.passive:
        return l10n.featureTypePassive;
      case FeatureType.action:
        return l10n.featureTypeAction;
      case FeatureType.bonusAction:
        return l10n.featureTypeBonusAction;
      case FeatureType.reaction:
        return l10n.featureTypeReaction;
      default:
        return l10n.featureTypeOther;
    }
  }

  Widget _buildFeatureCard(BuildContext context, CharacterFeature feature) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    IconData icon = Icons.star;
    if (feature.iconName != null) {
       switch(feature.iconName) {
         case 'healing': icon = Icons.favorite; break;
         case 'visibility': icon = Icons.visibility; break;
         case 'flash_on': icon = Icons.flash_on; break;
         case 'swords': icon = Icons.shield; break;
         case 'auto_fix_high': icon = Icons.auto_fix_high; break;
         case 'health_and_safety': icon = Icons.health_and_safety; break;
         case 'auto_awesome': icon = Icons.auto_awesome; break;
       }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.getName(locale),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getFeatureTypeLabel(l10n, feature.type).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(feature.getDescription(locale)),
          ],
        ),
      ),
    );
  }

  Widget _buildSpellSlotGrid(BuildContext context, AppLocalizations l10n) {
    List<Widget> levelRows = [];
    
    for (int i = 0; i < widget.newSpellSlots.length; i++) {
      int level = i + 1;
      int newCount = widget.newSpellSlots[i];
      int oldCount = i < widget.oldSpellSlots.length ? widget.oldSpellSlots[i] : 0;
      
      if (newCount > oldCount) {
        levelRows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(l10n.lvlShort(level), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                ...List.generate(oldCount, (_) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.0),
                  child: Icon(Icons.circle, size: 16, color: Colors.grey),
                )),
                if (oldCount > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ),
                ...List.generate(newCount - oldCount, (index) {
                   return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Icon(
                      Icons.circle, 
                      size: 16, 
                      color: Theme.of(context).colorScheme.primary
                    ),
                  );
                }),
              ],
            ),
          )
        );
      }
    }
    
    return Column(children: levelRows);
  }
}
