import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/character.dart';
import '../../core/magic/spellbook_state.dart';
import '../../core/magic/class_spell_grants.dart';
import '../../core/progression/character_class_rules.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/character_feature.dart';
import '../../core/models/item.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/feature_service.dart';
import 'character_creation_state.dart';
import 'prologue.dart';
import '../character_list/widgets/hero_deck.dart' show HeroDeck;

/// Character creation (wave 6, «Пролог»): the chapters live in
/// [Prologue]; this wizard holds their state and turns it into a hero.
class CharacterCreationWizard extends StatefulWidget {
  const CharacterCreationWizard({super.key});

  @override
  State<CharacterCreationWizard> createState() =>
      _CharacterCreationWizardState();
}

class _CharacterCreationWizardState extends State<CharacterCreationWizard> {
  bool _isSaving = false;
  final _state = CharacterCreationState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _state,
      child: Prologue(
        saving: _isSaving,
        compose: _compose,
        onCreate: () => _create(context),
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);
    try {
      final hero = await _createCharacter();
      if (!context.mounted) return;
      // The lobby turns to the new hero and their card rises into the party.
      HeroDeck.arrived.value = hero.id;
      Navigator.of(context).pop();
      AppSnackBar.success(context, l10n.characterCreated);
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, l10n.errorCreatingCharacter(e.toString()));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The hero as the chapters describe it, not yet saved: the finale
  /// reads its numbers from here, and creation saves exactly this.
  Character _compose() {
    {
      if (!{'unknown', '2014'}.contains(_state.selectedClass?.rulesEdition)) {
        throw StateError('Unsupported class rules profile.');
      }
      // 1. Calculate final ability scores WITH racial bonuses
      final finalScores = <String, int>{};
      _state.abilityScores.forEach((ability, baseScore) {
        // The people's bonuses, an «all» bonus included.
        finalScores[ability] = baseScore + _state.racialBonus(ability);
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

      final rules = CharacterClassRules.capture(_state.selectedClass!);
      final chosen = _state.selectedFeatureOptions.values.toSet();
      for (final feature in rules.atLevel(1, _state.selectedSubclass?.id)) {
        character.features.add(feature.copyForCharacter());
      }
      for (final feature
          in rules.definitions.where((f) => chosen.contains(f.id))) {
        if (!character.features.any((existing) => existing.id == feature.id)) {
          character.features.add(feature.copyForCharacter());
        }
      }
      FeatureService.updateFeatureMaxUses(character);
      for (final feature in character.features) {
        if (feature.resourcePool != null) {
          feature.resourcePool!.currentUses = feature.resourcePool!.maxUses;
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
        _addCustomEquipment(character, _state.customEquipmentQuantities);
      } else if (_state.selectedEquipmentPackage != null) {
        // Add standard/alternative package
        _addStartingEquipment(character, _state.selectedClass!.id,
            _state.selectedEquipmentPackage!);
      }

      // 7. Save to database
      rules.attachTo(character.classes.single);
      final book = SpellbookState.read(character.spellbookData);
      for (final spell in _state.selectedSpells) {
        book.setKnown('class:${_state.selectedClass!.id}', spell, true);
      }
      character.spellbookData = book.toJson();
      ClassSpellGrants.apply(character, _state.selectedClass!.id);
      return character;
    }
  }

  Future<Character> _createCharacter() async {
    try {
      final hero = _compose();
      await StorageService.saveCharacter(hero);
      return hero;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Add starting equipment based on class and selected package
  void _addStartingEquipment(
      Character character, String classId, String packageId) {
    final equipment = starterEquipment(classId, packageId);

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
  void _addCustomEquipment(
      Character character, Map<String, int> itemQuantities) {
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
      if (item.type == ItemType.armor &&
          item.armorProperties?.armorType != ArmorType.shield &&
          !item.isEquipped) {
        item.isEquipped = true;
        break;
      }
    }

    final usesTwoHands = character.inventory.any(
      (item) =>
          item.isEquipped &&
          (item.weaponProperties?.weaponTags.contains('two-handed') ?? false),
    );
    if (!usesTwoHands) {
      final shield = character.inventory
          .where((item) => item.armorProperties?.armorType == ArmorType.shield)
          .firstOrNull;
      if (shield != null) shield.isEquipped = true;
    }

    // Recalculate AC after equipment changes, including barbarian unarmored defense.
    character.recalculateAC();
  }
}

/// The item templates of a class's starting set: «standard» or
/// «alternative».
/// Get equipment item IDs for a specific class and package
List<String> starterEquipment(String classId, String packageId) {
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
