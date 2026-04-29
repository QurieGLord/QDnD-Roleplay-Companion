import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/character_feature.dart';
import '../../core/models/item.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/feature_service.dart';
import 'character_creation_state.dart';
import 'steps/basic_info_step.dart';
import 'steps/race_class_step.dart';
import 'steps/ability_scores_step.dart';
import 'steps/features_spells_step.dart';
import 'steps/equipment_step.dart';
import 'steps/background_step.dart';
import 'steps/skills_step.dart';
import 'steps/review_step.dart';

class CharacterCreationWizard extends StatefulWidget {
  const CharacterCreationWizard({super.key});

  @override
  State<CharacterCreationWizard> createState() =>
      _CharacterCreationWizardState();
}

class _CharacterCreationWizardState extends State<CharacterCreationWizard> {
  static const int _stepCount = 8;
  static const Duration _fastMotion = Duration(milliseconds: 160);
  static const Duration _revealMotion = Duration(milliseconds: 220);

  int _currentStep = 0;
  bool _isSaving = false;
  double _fabMorphProgress = 0;
  final _state = CharacterCreationState();

  String _getStepTitle(int index, AppLocalizations l10n) {
    switch (index) {
      case 0:
        return l10n.stepBasicInfo;
      case 1:
        return l10n.stepRaceClass;
      case 2:
        return l10n.stepAbilities;
      case 3:
        return l10n.stepFeatures;
      case 4:
        return l10n.stepEquipment;
      case 5:
        return l10n.stepBackground;
      case 6:
        return l10n.stepSkills;
      case 7:
        return l10n.stepReview;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentTitle = _getStepTitle(_currentStep, l10n);
    final nextTitle = _currentStep < _stepCount - 1
        ? _getStepTitle(_currentStep + 1, l10n)
        : null;

    return ChangeNotifierProvider.value(
      value: _state,
      child: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: _WizardHeader(
                currentStep: _currentStep,
                stepCount: _stepCount,
                title: currentTitle,
                nextTitle: nextTitle,
                isSaving: _isSaving,
                onClose: () {
                  _playNavigationHaptic();
                  Navigator.of(context).pop();
                },
              ),
            ),
            Expanded(
              child: IgnorePointer(
                ignoring: _isSaving,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleStepScrollNotification,
                  child: AnimatedSwitcher(
                    duration: _motionDuration(context, _revealMotion),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) {
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      );
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.025, 0),
                            end: Offset.zero,
                          ).animate(curved),
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<int>(_currentStep),
                      child: _buildStep(_currentStep),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _WizardFloatingActions(
          currentStep: _currentStep,
          lastStep: _stepCount - 1,
          isSaving: _isSaving,
          morphProgress: _fabMorphProgress,
          onBack: _currentStep > 0 ? _prevStep : null,
          onNext: () => _nextStep(context),
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0:
        return const BasicInfoStep();
      case 1:
        return const RaceClassStep();
      case 2:
        return const AbilityScoresStep();
      case 3:
        return const FeaturesSpellsStep();
      case 4:
        return const EquipmentStep();
      case 5:
        return const BackgroundStep();
      case 6:
        return const SkillsStep();
      case 7:
        return const ReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _playNavigationHaptic();
      setState(() {
        _currentStep--;
        _fabMorphProgress = 0;
      });
    }
  }

  void _nextStep(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentStep < _stepCount - 1) {
      // STRICT MODE VALIDATION
      if (!_state.isStepValid(_currentStep)) {
        AppSnackBar.warning(context, l10n.errorMissingFields);
        return; // BLOCK PROGRESSION
      }

      _playNavigationHaptic();
      setState(() {
        _currentStep++;
        _fabMorphProgress = 0;
      });
    } else {
      // Create character
      if (_isSaving) return;

      _playNavigationHaptic();
      setState(() {
        _isSaving = true;
      });

      try {
        await _createCharacter();

        if (!context.mounted) return;
        Navigator.of(context).pop();
        AppSnackBar.success(context, l10n.characterCreated);
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, l10n.errorCreatingCharacter(e.toString()));
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  static Duration _motionDuration(BuildContext context, Duration duration) {
    return MediaQuery.of(context).disableAnimations ? Duration.zero : duration;
  }

  bool _handleStepScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final nextProgress = _fabProgressFromExtentAfter(
      notification.metrics.maxScrollExtent <= 0
          ? double.infinity
          : notification.metrics.extentAfter,
    );
    if ((nextProgress - _fabMorphProgress).abs() > 0.01) {
      setState(() {
        _fabMorphProgress = nextProgress;
      });
    }

    return false;
  }

  static double _fabProgressFromExtentAfter(double extentAfter) {
    const compactAfter = 160.0;
    const extendedAfter = 24.0;

    if (extentAfter <= extendedAfter) return 1;
    if (extentAfter >= compactAfter) return 0;

    return ((compactAfter - extentAfter) / (compactAfter - extendedAfter))
        .clamp(0.0, 1.0);
  }

  static void _playNavigationHaptic() {
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _createCharacter() async {
    try {
      // 1. Calculate final ability scores WITH racial bonuses
      final finalScores = <String, int>{};
      _state.abilityScores.forEach((ability, baseScore) {
        int total = baseScore;

        // Add racial bonuses
        if (_state.selectedRace != null) {
          final raceBonus = _state.selectedRace!.abilityScoreIncreases;
          if (raceBonus.containsKey(ability)) {
            total += raceBonus[ability]!;
          }
        }

        // Add subrace bonuses (if any)
        if (_state.selectedSubrace != null) {
          final subraceBonus = _state.selectedSubrace!.additionalAbilityScores;
          if (subraceBonus.containsKey(ability)) {
            total += subraceBonus[ability]!;
          }
        }

        finalScores[ability] = total;
      });

      // Recalculate modifiers based on FINAL scores
      final conMod = (finalScores['constitution']! ~/ 2) - 5;
      final dexMod = (finalScores['dexterity']! ~/ 2) - 5;

      // 2. Calculate HP based on selected method
      int maxHp;
      switch (_state.hpSelectionMethod) {
        case 'max':
          maxHp = _state.selectedClass!.hitDie + conMod;
          break;
        case 'average':
          final avgRoll = ((_state.selectedClass!.hitDie / 2).ceil() + 1);
          maxHp = avgRoll.toInt() + conMod;
          break;
        case 'roll':
          maxHp = _state.rolledHp! + conMod;
          break;
        default:
          maxHp = _state.selectedClass!.hitDie + conMod;
      }

      // 3. Calculate spell slots based on caster type
      List<int> spellSlots = List.filled(9, 0);
      List<int> maxSpellSlots = List.filled(9, 0);

      if (_state.selectedClass!.spellcasting != null) {
        final spellcastingType = _state.selectedClass!.spellcasting!.type;

        if (spellcastingType == 'full') {
          // Full casters (Wizard, Cleric, etc.) get 2 level 1 slots at level 1
          spellSlots[0] = 2;
          maxSpellSlots[0] = 2;
        } else if (spellcastingType == 'half') {
          // Half casters (Paladin, Ranger) get 0 slots at level 1
          // They start getting slots at level 2
        } else if (spellcastingType == 'third') {
          // Third casters (Eldritch Knight, Arcane Trickster) get 0 slots at level 1
          // They start getting slots at level 3
        } else if (spellcastingType == 'pact') {
          // Warlock gets 1 pact slot at level 1
          spellSlots[0] = 1;
          maxSpellSlots[0] = 1;
        }
      }

      // 4. Calculate max prepared spells (if applicable)
      int maxPreparedSpells = 0;
      if (_state.selectedClass!.spellcasting != null) {
        final spellcastingAbility = _state.selectedClass!.spellcasting!.ability;
        final abilityMod = (finalScores[spellcastingAbility]! ~/ 2) - 5;

        // Formula: ability modifier + level (minimum 1)
        maxPreparedSpells = (abilityMod + 1).clamp(1, 100);
      }

      // 4.5 Aggregate all proficient skills
      final allProficientSkills = <String>{};
      allProficientSkills.addAll(_state.selectedSkills);
      if (_state.selectedBackground != null) {
        allProficientSkills
            .addAll(_state.selectedBackground!.skillProficiencies);
      }
      if (_state.selectedRace != null) {
        // Assume racial proficiencies often correspond to skills
        // We might want to filter or normalize, but for now we'll add them
        // ensuring they match skill keys if possible
        allProficientSkills.addAll(
            _state.selectedRace!.proficiencies.map((s) => s.toLowerCase()));
      }

      // 5. Create character with all calculated values
      final character = Character(
        id: const Uuid().v4(),
        name: _state.name,
        avatarPath: _state.avatarPath,
        race: _state.selectedRace!.id, // Store ID
        characterClass: _state.selectedClass!.id, // Store ID
        subclass: _state.selectedSubclass?.id, // Store ID (Class Subclass)
        background: _state.selectedBackground?.id, // Store ID
        level: 1,
        maxHp: maxHp,
        currentHp: maxHp,
        temporaryHp: 0,
        abilityScores: AbilityScores(
          strength: finalScores['strength']!,
          dexterity: finalScores['dexterity']!,
          constitution: finalScores['constitution']!,
          intelligence: finalScores['intelligence']!,
          wisdom: finalScores['wisdom']!,
          charisma: finalScores['charisma']!,
        ),
        spellSlots: spellSlots,
        maxSpellSlots: maxSpellSlots,
        armorClass: 10 + dexMod,
        speed: _state.selectedRace!.speed,
        initiative: dexMod,
        proficientSkills: allProficientSkills.toList(),
        expertSkills: _state.selectedExpertise.toList(),
        favoredEnemies: _state.selectedFeatureOptions['favored_enemy'] != null
            ? [_state.selectedFeatureOptions['favored_enemy']!]
            : [],
        naturalExplorers:
            _state.selectedFeatureOptions['natural_explorer'] != null
                ? [_state.selectedFeatureOptions['natural_explorer']!]
                : [],
        savingThrowProficiencies:
            _state.selectedClass!.savingThrowProficiencies,
        knownSpells:
            List.from(_state.selectedSpells), // Populate selected spells
        preparedSpells: [],
        maxPreparedSpells: maxPreparedSpells,
        features: [],
        inventory: [], // Start with empty inventory
        personalityTraits: _state.personalityTraits,
        ideals: _state.ideals,
        bonds: _state.bonds,
        flaws: _state.flaws,
        backstory: _state.backstory,
        age: _state.age,
        gender: _state.gender,
        height: _state.height,
        weight: _state.weight,
        eyes: _state.eyes,
        hair: _state.hair,
        skin: _state.skin,
        appearanceDescription: _state.appearanceDescription,
      );

      // 5.5 Add class features (Standard + Custom Class features)
      FeatureService.addFeaturesToCharacter(character);

      // Add features from selected class (Level 1)
      final classFeatures = _state.selectedClass!.features[1];
      if (classFeatures != null) {
        // Avoid duplicates if FeatureService already added them (by ID)
        final existingIds = character.features.map((f) => f.id).toSet();
        final selectedOptions = _state.selectedFeatureOptions.values.toSet();
        for (var feature in classFeatures) {
          if (feature.isOptional && !selectedOptions.contains(feature.id)) {
            continue;
          }
          if (!existingIds.contains(feature.id)) {
            character.features.add(feature);
          }
        }
      }

      // 5.6 ADD Selected Options (Fix for "Optional" features like Fighting Styles)
      // Some features (like Fighting Styles) are marked as 'Optional' class in JSON
      // so FeatureService.addFeaturesToCharacter skips them. We must add them manually if selected.
      for (var optionId in _state.selectedFeatureOptions.values) {
        // Check if already added
        if (!character.features.any((f) => f.id == optionId)) {
          final feature = FeatureService.getFeatureById(optionId);
          if (feature != null) {
            // Add a COPY of the feature
            // (We might need to calculate max uses if applicable, but usually these are passive)
            final featureCopy = CharacterFeature(
              id: feature.id,
              nameEn: feature.nameEn,
              nameRu: feature.nameRu,
              descriptionEn: feature.descriptionEn,
              descriptionRu: feature.descriptionRu,
              type: feature.type,
              minLevel: feature.minLevel,
              associatedClass: feature.associatedClass,
              associatedSubclass: feature.associatedSubclass,
              requiresRest: feature.requiresRest,
              actionEconomy: feature.actionEconomy,
              iconName: feature.iconName,
              consumption: feature.consumption,
              usageCostId: feature.usageCostId,
              usageInputMode: feature.usageInputMode,
              isOptional: feature.isOptional,
              resourcePool: feature.resourcePool != null
                  ? ResourcePool(
                      currentUses:
                          feature.resourcePool!.maxUses, // Assuming full on add
                      maxUses: feature.resourcePool!.maxUses,
                      recoveryType: feature.resourcePool!.recoveryType,
                      calculationFormula:
                          feature.resourcePool!.calculationFormula,
                    )
                  : null,
            );
            character.features.add(featureCopy);
          }
        }
      }

      // Sync any derived values that depend on features before equipment logic.
      character.recalculateAC();

      // 5.7 PRUNE Unselected Options (Fix for "Add All" bug)
      // We need to remove features that are "options" but were NOT selected by the user.
      final selectedOptions = _state.selectedFeatureOptions.values.toSet();

      character.features.removeWhere((feature) {
        if (feature.isOptional) {
          return !selectedOptions.contains(feature.id);
        }

        // Fighting Styles: Remove specific styles if not selected
        // Pattern: contains 'fighting-style' BUT is not the generic parent (which usually ends in 'fighting-style' like 'fighter-fighting-style')
        if (feature.id.contains('fighting-style') &&
            !feature.id.endsWith('fighting-style')) {
          return !selectedOptions.contains(feature.id);
        }

        // Draconic Ancestry: Remove specific ancestries if not selected
        if (feature.id.startsWith('dragon-ancestor-')) {
          return !selectedOptions.contains(feature.id);
        }

        return false;
      });

      // 6. Add starting equipment if selected
      if (_state.selectedEquipmentPackage == 'custom') {
        // Add custom equipment
        await _addCustomEquipment(character, _state.customEquipmentQuantities);
      } else if (_state.selectedEquipmentPackage != null) {
        // Add standard/alternative package
        await _addStartingEquipment(character, _state.selectedClass!.id,
            _state.selectedEquipmentPackage!);
      }

      // 7. Save to database
      await StorageService.saveCharacter(character);

      // Navigation is now handled by _nextStep
    } catch (e) {
      // Re-throw to let _nextStep handle the error UI
      throw Exception(e.toString());
    }
  }

  /// Add starting equipment based on class and selected package
  Future<void> _addStartingEquipment(
      Character character, String classId, String packageId) async {
    final equipment = _getEquipmentForPackage(classId, packageId);

    for (var itemId in equipment) {
      try {
        final item = ItemService.createItemFromTemplate(itemId);
        if (item != null) {
          character.inventory.add(item);
        }
      } catch (e) {
        debugPrint('Failed to add starting equipment item $itemId: $e');
      }
    }

    _autoEquipItems(character);
  }

  /// Add custom equipment from item IDs with quantities
  Future<void> _addCustomEquipment(
      Character character, Map<String, int> itemQuantities) async {
    for (var entry in itemQuantities.entries) {
      final itemId = entry.key;
      final quantity = entry.value;

      try {
        // Add the item 'quantity' times
        for (int i = 0; i < quantity; i++) {
          final item = ItemService.createItemFromTemplate(itemId);
          if (item != null) {
            character.inventory.add(item);
          }
        }
      } catch (e) {
        debugPrint('Failed to add custom equipment item $itemId: $e');
      }
    }

    _autoEquipItems(character);
  }

  /// Auto-equip first weapon and armor from inventory
  void _autoEquipItems(Character character) {
    if (character.inventory.isEmpty) return;

    // Equip first weapon
    for (var item in character.inventory) {
      if (item.type == ItemType.weapon && !item.isEquipped) {
        item.isEquipped = true;
        break;
      }
    }

    // Equip first armor
    for (var item in character.inventory) {
      if (item.type == ItemType.armor && !item.isEquipped) {
        item.isEquipped = true;
        break;
      }
    }

    // Recalculate AC after equipment changes, including barbarian unarmored defense.
    character.recalculateAC();
  }

  /// Get equipment item IDs for a specific class and package
  List<String> _getEquipmentForPackage(String classId, String packageId) {
    // Standard vs Alternative packages
    final isAlternative = packageId == 'alternative';

    switch (classId) {
      case 'paladin':
        return isAlternative
            ? [
                'scale_mail',
                'longsword',
                'javelin',
                'holy_symbol',
                'priests_pack'
              ]
            : [
                'chain_mail',
                'longsword',
                'shield',
                'holy_symbol',
                'explorers_pack'
              ];
      case 'wizard':
        return isAlternative
            ? ['dagger', 'dagger', 'arcane_focus', 'scholars_pack']
            : ['quarterstaff', 'dagger', 'component_pouch', 'scholars_pack'];
      case 'fighter':
        return isAlternative
            ? [
                'leather_armor',
                'longbow',
                'shortsword',
                'shortsword',
                'dungeons_pack'
              ]
            : [
                'chain_mail',
                'longsword',
                'shield',
                'crossbow_light',
                'explorers_pack'
              ];
      case 'rogue':
        return isAlternative
            ? [
                'leather_armor',
                'rapier',
                'shortbow',
                'thieves_tools',
                'dungeons_pack'
              ]
            : [
                'leather_armor',
                'shortsword',
                'dagger',
                'thieves_tools',
                'burglars_pack'
              ];
      case 'cleric':
        return isAlternative
            ? [
                'scale_mail',
                'warhammer',
                'shield',
                'holy_symbol',
                'explorers_pack'
              ]
            : ['chain_mail', 'mace', 'shield', 'holy_symbol', 'priests_pack'];
      case 'ranger':
        return isAlternative
            ? [
                'scale_mail',
                'shortsword',
                'shortsword',
                'longbow',
                'dungeons_pack'
              ]
            : ['leather_armor', 'longbow', 'shortsword', 'explorers_pack'];
      default:
        return ['leather_armor', 'dagger', 'explorers_pack'];
    }
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.currentStep,
    required this.stepCount,
    required this.title,
    required this.nextTitle,
    required this.isSaving,
    required this.onClose,
  });

  final int currentStep;
  final int stepCount;
  final String title;
  final String? nextTitle;
  final bool isSaving;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final duration = _CharacterCreationWizardState._motionDuration(
      context,
      _CharacterCreationWizardState._revealMotion,
    );

    return Material(
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: isSaving ? null : onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: duration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axisAlignment: -1,
                            child: child,
                          ),
                        );
                      },
                      child: _WizardHeaderTitle(
                        key: ValueKey<String>(title),
                        stepLabel: '${currentStep + 1} / $stepCount',
                        title: title,
                        nextLabel: nextTitle == null
                            ? null
                            : '${l10n.next}: $nextTitle',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _StepSegmentedRail(
                currentStep: currentStep,
                stepCount: stepCount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WizardHeaderTitle extends StatelessWidget {
  const _WizardHeaderTitle({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.nextLabel,
  });

  final String stepLabel;
  final String title;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                stepLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (nextLabel != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nextLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _StepSegmentedRail extends StatelessWidget {
  const _StepSegmentedRail({
    required this.currentStep,
    required this.stepCount,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = _CharacterCreationWizardState._motionDuration(
      context,
      _CharacterCreationWizardState._fastMotion,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: currentStep.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Row(
          children: List.generate(stepCount, (index) {
            final isComplete = value >= index;
            final isCurrent = currentStep == index;
            final color = isComplete
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest;
            final borderColor = isCurrent
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.55);

            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: index == 0 ? 0 : 3,
                  end: index == stepCount - 1 ? 0 : 3,
                ),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  height: isCurrent ? 10 : 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: borderColor),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _WizardFloatingActions extends StatelessWidget {
  const _WizardFloatingActions({
    required this.currentStep,
    required this.lastStep,
    required this.isSaving,
    required this.morphProgress,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final int lastStep;
  final bool isSaving;
  final double morphProgress;
  final VoidCallback? onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isLastStep = currentStep == lastStep;
    final fabLabel = isLastStep ? l10n.finish : l10n.next;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: _CharacterCreationWizardState._motionDuration(
                    context,
                    _CharacterCreationWizardState._fastMotion,
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: onBack == null
                      ? const SizedBox(
                          key: ValueKey('back-empty'),
                          width: 56,
                          height: 56,
                        )
                      : Material(
                          key: const ValueKey('back-button'),
                          color: colorScheme.secondaryContainer,
                          elevation: 3,
                          shadowColor:
                              colorScheme.shadow.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: l10n.back,
                            onPressed: isSaving ? null : onBack,
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                ),
                const Spacer(),
                _MorphingNextFab(
                  progress: morphProgress,
                  isSaving: isSaving,
                  isLastStep: isLastStep,
                  label: fabLabel,
                  onPressed: isSaving ? null : onNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MorphingNextFab extends StatelessWidget {
  const _MorphingNextFab({
    required this.progress,
    required this.isSaving,
    required this.isLastStep,
    required this.label,
    required this.onPressed,
  });

  final double progress;
  final bool isSaving;
  final bool isLastStep;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final duration = _CharacterCreationWizardState._motionDuration(
      context,
      const Duration(milliseconds: 240),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: progress.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final eased = value.clamp(0.0, 1.0);
        final width = lerpDouble(56, isLastStep ? 150 : 132, eased)!;
        final radius = lerpDouble(28, 22, eased)!;
        final iconOpacity = isSaving ? 0.0 : (1 - eased).clamp(0.0, 1.0);
        final labelOpacity = isSaving ? 0.0 : eased.clamp(0.0, 1.0);
        final labelWidth = lerpDouble(0, isLastStep ? 94 : 76, eased)!;
        final translateY = lerpDouble(-4, 0, eased)!;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Material(
            key: const Key('character_creation_next_fab'),
            color: colorScheme.primaryContainer,
            elevation: 5,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                width: width,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: iconOpacity,
                      child: Icon(
                        isLastStep
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        key: const Key(
                          'character_creation_next_fab_compact_icon',
                        ),
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    Offstage(
                      offstage: labelWidth <= 0.5 || isSaving,
                      child: SizedBox(
                        width: labelWidth,
                        child: Opacity(
                          opacity: labelOpacity,
                          child: Text(
                            label,
                            key: const Key(
                              'character_creation_next_fab_extended_label',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                    ),
                    if (isSaving)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
