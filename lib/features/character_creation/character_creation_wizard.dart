import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/character.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/item.dart';
import '../../core/constants/enums.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/item_service.dart';
import 'character_creation_state.dart';
import 'steps/basic_info_step.dart';
import 'steps/race_class_step.dart';
import 'steps/ability_scores_step.dart';
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
  final _state = CharacterCreationState();

  final List<String> _stepTitles = [
    'Basic Info',
    'Race & Class',
    'Ability Scores & HP',
    'Equipment',
    'Background',
    'Skills',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_stepTitles[_currentStep]),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmCancel(),
          ),
        ),
        body: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            // Current step
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: const [
                  BasicInfoStep(),
                  RaceClassStep(),
                  AbilityScoresStep(),
                  EquipmentStep(),
                  BackgroundStep(),
                  SkillsStep(),
                  ReviewStep(),
                ],
              ),
            ),
            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(7, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Consumer<CharacterCreationState>(
      builder: (context, state, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentStep--;
                        });
                      },
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _canProceed() ? _handleNext : null,
                    child: Text(_currentStep == 6 ? 'Create Character' : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        return true; // Equipment step is always valid (placeholder)
      case 4:
        return _state.isStep4Valid;
      case 5:
        return _state.isStep5Valid;
      case 6:
        return _state.isStep6Valid;
      default:
        return false;
    }
  }

  void _handleNext() async {
    if (_currentStep < 6) {
      setState(() {
        _currentStep++;
      });
    } else {
      // Create character
      await _createCharacter();
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
        race: _state.selectedRace!.getName(locale),
        characterClass: _state.selectedClass!.getName(locale),
        subclass: _state.selectedSubrace?.getName(locale),
        background: _state.selectedBackground?.getName(locale),
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
        knownSpells: [],
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

      // 6. Add starting equipment if selected
      if (_state.selectedEquipmentPackage == 'custom') {
        // Add custom equipment
        await _addCustomEquipment(character, _state.customEquipmentIds);
      } else if (_state.selectedEquipmentPackage != null) {
        // Add standard/alternative package
        await _addStartingEquipment(character, _state.selectedClass!.id, _state.selectedEquipmentPackage!);
      }

      // 7. Save to database
      await StorageService.saveCharacter(character);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${character.name} created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating character: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _confirmCancel() {
    if (_state.name.isNotEmpty ||
        _state.selectedRace != null ||
        _state.selectedClass != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel Character Creation?'),
          content: const Text('All progress will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close wizard
              },
              child: const Text('Discard'),
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

  /// Add custom equipment from item IDs
  Future<void> _addCustomEquipment(Character character, List<String> itemIds) async {
    for (var itemId in itemIds) {
      try {
        final item = ItemService.createItemFromTemplate(itemId);
        if (item != null) {
          character.inventory.add(item);
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
