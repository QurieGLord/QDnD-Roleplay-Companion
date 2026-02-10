import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/item.dart';
import '../../core/constants/enums.dart';
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
  State<CharacterCreationWizard> createState() => _CharacterCreationWizardState();
}

class _CharacterCreationWizardState extends State<CharacterCreationWizard> {
  int _currentStep = 0;
  bool _isSaving = false;
  final _state = CharacterCreationState();

  String _getStepTitle(int index, AppLocalizations l10n) {
    switch (index) {
      case 0: return l10n.stepBasicInfo;
      case 1: return l10n.stepRaceClass;
      case 2: return l10n.stepAbilities;
      case 3: return l10n.stepFeatures;
      case 4: return l10n.stepEquipment;
      case 5: return l10n.stepBackground;
      case 6: return l10n.stepSkills;
      case 7: return l10n.stepReview;
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return ChangeNotifierProvider.value(
      value: _state,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getStepTitle(_currentStep, l10n)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 8,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            
            Expanded(
              child: IgnorePointer(
                ignoring: _isSaving,
                child: _buildStep(_currentStep),
              ),
            ),
            
            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _isSaving ? null : _prevStep,
                      child: Text(l10n.back),
                    )
                  else
                    const SizedBox(width: 80), // Spacer to keep alignment

                  // Next/Finish Button
                  FilledButton(
                    onPressed: _isSaving ? null : () => _nextStep(context),
                    child: _isSaving 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : Text(_currentStep == 7 ? l10n.finish : l10n.next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildStep(int step) {
    switch (step) {
      case 0: return const BasicInfoStep();
      case 1: return const RaceClassStep();
      case 2: return const AbilityScoresStep();
      case 3: return const FeaturesSpellsStep();
      case 4: return const EquipmentStep();
      case 5: return const BackgroundStep();
      case 6: return const SkillsStep();
      case 7: return const ReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _state.isStep1Valid;
      case 1:
        return _state.isStep2Valid;
      case 2:
        return _state.isStep3Valid;
      case 3:
        return _state.isStepFeaturesValid; // Features & Spells
      case 4:
        return true; // Equipment
      case 5:
        return _state.isStep4Valid; // Background (was step 4)
      case 6:
        return _state.isStep5Valid; // Skills (was step 5)
      case 7:
        return _state.isStep6Valid; // Review
      default:
        return false;
    }
  }

  void _nextStep(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (_currentStep < 7) {
      // Validate current step
      // Note: validation logic depends on state getters which are fine
      
      setState(() {
        _currentStep++;
      });
    } else {
      // Create character
      if (_isSaving) return;
      
      setState(() {
        _isSaving = true;
      });

      try {
        await _createCharacter();
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.characterCreated)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorCreatingCharacter(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  Future<void> _createCharacter() async {
    try {
      final locale = Localizations.localeOf(context).languageCode;

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

      // 5. Create character with all calculated values
      final character = Character(
        id: const Uuid().v4(),
        name: _state.name,
        avatarPath: _state.avatarPath,
        race: _state.selectedRace!.id, // Store ID
        characterClass: _state.selectedClass!.id, // Store ID
        subclass: _state.selectedSubrace?.id, // Store ID
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
        proficientSkills: _state.selectedSkills,
        savingThrowProficiencies: _state.selectedClass!.savingThrowProficiencies,
        knownSpells: List.from(_state.selectedSpells), // Populate selected spells
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
        for (var feature in classFeatures) {
          if (!existingIds.contains(feature.id)) {
            character.features.add(feature);
          }
        }
      }

      // 6. Add starting equipment if selected
      if (_state.selectedEquipmentPackage == 'custom') {
        // Add custom equipment
        await _addCustomEquipment(character, _state.customEquipmentQuantities);
      } else if (_state.selectedEquipmentPackage != null) {
        // Add standard/alternative package
        await _addStartingEquipment(character, _state.selectedClass!.id, _state.selectedEquipmentPackage!);
      }

      // 7. Save to database
      await StorageService.saveCharacter(character);
      
      // Navigation is now handled by _nextStep
    } catch (e) {
      // Re-throw to let _nextStep handle the error UI
      throw Exception(e.toString());
    }
  }

  void _confirmCancel() {
    final l10n = AppLocalizations.of(context)!;
    if (_state.name.isNotEmpty ||
        _state.selectedRace != null ||
        _state.selectedClass != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.cancelCharacterCreationTitle),
          content: Text(l10n.cancelCharacterCreationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.continueEditing),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close wizard
              },
              child: Text(l10n.discard),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  /// Add starting equipment based on class and selected package
  Future<void> _addStartingEquipment(Character character, String classId, String packageId) async {
    final equipment = _getEquipmentForPackage(classId, packageId);

    for (var itemId in equipment) {
      try {
        final item = ItemService.createItemFromTemplate(itemId);
        if (item != null) {
          character.inventory.add(item);
        }
      } catch (e) {
        print('Failed to add starting equipment item $itemId: $e');
      }
    }

    _autoEquipItems(character);
  }

  /// Add custom equipment from item IDs with quantities
  Future<void> _addCustomEquipment(Character character, Map<String, int> itemQuantities) async {
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
        print('Failed to add custom equipment item $itemId: $e');
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
        // Update character AC based on equipped armor
        _updateCharacterAC(character);
        break;
      }
    }
  }

  /// Get equipment item IDs for a specific class and package
  List<String> _getEquipmentForPackage(String classId, String packageId) {
    // Standard vs Alternative packages
    final isAlternative = packageId == 'alternative';

    switch (classId) {
      case 'paladin':
        return isAlternative
            ? ['scale_mail', 'longsword', 'javelin', 'holy_symbol', 'priests_pack']
            : ['chain_mail', 'longsword', 'shield', 'holy_symbol', 'explorers_pack'];
      case 'wizard':
        return isAlternative
            ? ['dagger', 'dagger', 'arcane_focus', 'scholars_pack']
            : ['quarterstaff', 'dagger', 'component_pouch', 'scholars_pack'];
      case 'fighter':
        return isAlternative
            ? ['leather_armor', 'longbow', 'shortsword', 'shortsword', 'dungeons_pack']
            : ['chain_mail', 'longsword', 'shield', 'crossbow_light', 'explorers_pack'];
      case 'rogue':
        return isAlternative
            ? ['leather_armor', 'rapier', 'shortbow', 'thieves_tools', 'dungeons_pack']
            : ['leather_armor', 'shortsword', 'dagger', 'thieves_tools', 'burglars_pack'];
      case 'cleric':
        return isAlternative
            ? ['scale_mail', 'warhammer', 'shield', 'holy_symbol', 'explorers_pack']
            : ['chain_mail', 'mace', 'shield', 'holy_symbol', 'priests_pack'];
      case 'ranger':
        return isAlternative
            ? ['scale_mail', 'shortsword', 'shortsword', 'longbow', 'dungeons_pack']
            : ['leather_armor', 'longbow', 'shortsword', 'explorers_pack'];
      default:
        return ['leather_armor', 'dagger', 'explorers_pack'];
    }
  }

  /// Update character AC based on equipped armor
  void _updateCharacterAC(Character character) {
    int baseAC = 10;
    int dexMod = character.abilityScores.dexterityModifier;
    int totalAC = baseAC;

    // Find equipped armor and shield
    Item? equippedArmor;
    Item? equippedShield;

    for (var item in character.inventory) {
      if (item.isEquipped && item.type == ItemType.armor && item.armorProperties != null) {
        if (item.armorProperties!.armorType == ArmorType.shield) {
          equippedShield = item;
        } else {
          equippedArmor = item;
        }
      }
    }

    // Calculate AC from armor
    if (equippedArmor != null && equippedArmor.armorProperties != null) {
      final armorProps = equippedArmor.armorProperties!;
      totalAC = armorProps.baseAC;

      // Add DEX modifier based on armor type
      if (armorProps.addDexModifier) {
        if (armorProps.maxDexBonus != null) {
          totalAC += dexMod.clamp(-10, armorProps.maxDexBonus!);
        } else {
          totalAC += dexMod; // Full DEX for light armor
        }
      }
    } else {
      // No armor = 10 + DEX
      totalAC = 10 + dexMod;
    }

    // Add shield bonus
    if (equippedShield != null && equippedShield.armorProperties != null) {
      totalAC += equippedShield.armorProperties!.baseAC;
    }

    character.armorClass = totalAC;
  }
}
