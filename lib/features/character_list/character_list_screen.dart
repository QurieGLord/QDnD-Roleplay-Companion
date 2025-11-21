import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import '../../core/models/character.dart';
import '../../core/models/ability_scores.dart';
import '../../core/models/character_feature.dart';
import '../../core/models/item.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/import_service.dart';
import '../../core/services/fc5_parser.dart';
import '../character_sheet/character_sheet_screen.dart';
import '../character_creation/character_creation_wizard.dart';
import 'widgets/empty_state.dart';
import 'widgets/character_card.dart';

class CharacterListScreen extends StatefulWidget {
  const CharacterListScreen({super.key});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  @override
  void initState() {
    super.initState();
    // Load example character on first run
    ImportService.loadExampleCharacterIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Characters'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Character>('characters').listenable(),
        builder: (context, Box<Character> box, _) {
          final characters = box.values.toList();

          if (characters.isEmpty) {
            return const EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final character = characters[index];
              return CharacterCard(
                character: character,
                onTap: () async {
                  // Navigate to character sheet
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CharacterSheetScreen(
                        character: character,
                      ),
                    ),
                  );
                  // Force rebuild after returning
                  if (mounted) setState(() {});
                },
                onLongPress: () {
                  _showCharacterOptions(context, character);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCharacterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Character'),
      ),
    );
  }

  void _showCreateCharacterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create New Character',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CharacterCreationWizard(),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Create Manually'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Character templates - coming in Session 5!'),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline),
              label: const Text('Choose Template'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _importFromFC5(context);
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Import from Fight Club 5'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterOptions(BuildContext context, Character character) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                _showCharacterDetails(context, character);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit coming in Session 4!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () async {
                Navigator.pop(context);
                await _duplicateCharacter(context, character);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, character);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterDetails(BuildContext context, Character character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(character.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${character.race} • Level ${character.level} ${character.characterClass}'),
              if (character.subclass != null) Text('Subclass: ${character.subclass}'),
              if (character.background != null)
                Text('Background: ${character.background}'),
              const Divider(),
              Text(
                  'HP: ${character.currentHp}/${character.maxHp}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('AC: ${character.armorClass}'),
              Text('Speed: ${character.speed} ft'),
              Text('Initiative: ${character.formatModifier(character.initiativeBonus)}'),
              Text('Proficiency Bonus: +${character.proficiencyBonus}'),
              const Divider(),
              Text('ABILITY SCORES', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _buildAbilityRow('STR', character.abilityScores.strength,
                  character.abilityScores.strengthModifier),
              _buildAbilityRow('DEX', character.abilityScores.dexterity,
                  character.abilityScores.dexterityModifier),
              _buildAbilityRow('CON', character.abilityScores.constitution,
                  character.abilityScores.constitutionModifier),
              _buildAbilityRow('INT', character.abilityScores.intelligence,
                  character.abilityScores.intelligenceModifier),
              _buildAbilityRow('WIS', character.abilityScores.wisdom,
                  character.abilityScores.wisdomModifier),
              _buildAbilityRow('CHA', character.abilityScores.charisma,
                  character.abilityScores.charismaModifier),
              if (character.appearance != null) ...[
                const Divider(),
                Text('APPEARANCE', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(character.appearance!, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAbilityRow(String name, int score, int modifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text('$score (${modifier >= 0 ? '+' : ''}$modifier)'),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Character character) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text(
            'Are you sure you want to delete ${character.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await StorageService.deleteCharacter(character.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${character.name} deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateCharacter(BuildContext context, Character original) async {
    try {
      // Create a new character with copied data
      final duplicate = Character(
        id: const Uuid().v4(), // New unique ID
        name: '${original.name} (Copy)', // Add (Copy) suffix
        avatarPath: original.avatarPath,
        race: original.race,
        characterClass: original.characterClass,
        subclass: original.subclass,
        background: original.background,
        level: original.level,
        maxHp: original.maxHp,
        currentHp: original.currentHp,
        temporaryHp: original.temporaryHp,
        abilityScores: AbilityScores(
          strength: original.abilityScores.strength,
          dexterity: original.abilityScores.dexterity,
          constitution: original.abilityScores.constitution,
          intelligence: original.abilityScores.intelligence,
          wisdom: original.abilityScores.wisdom,
          charisma: original.abilityScores.charisma,
        ),
        proficientSkills: List<String>.from(original.proficientSkills),
        savingThrowProficiencies: List<String>.from(original.savingThrowProficiencies),
        armorClass: original.armorClass,
        speed: original.speed,
        initiative: original.initiative,
        spellSlots: List<int>.from(original.spellSlots),
        maxSpellSlots: List<int>.from(original.maxSpellSlots),
        knownSpells: List<String>.from(original.knownSpells),
        preparedSpells: List<String>.from(original.preparedSpells),
        maxPreparedSpells: original.maxPreparedSpells,
        features: original.features.map((f) {
          // Deep copy features with their resource pools
          return CharacterFeature(
            id: f.id,
            nameEn: f.nameEn,
            nameRu: f.nameRu,
            descriptionEn: f.descriptionEn,
            descriptionRu: f.descriptionRu,
            type: f.type,
            minLevel: f.minLevel,
            associatedClass: f.associatedClass,
            associatedSubclass: f.associatedSubclass,
            requiresRest: f.requiresRest,
            actionEconomy: f.actionEconomy,
            iconName: f.iconName,
            resourcePool: f.resourcePool != null
                ? ResourcePool(
                    currentUses: f.resourcePool!.currentUses,
                    maxUses: f.resourcePool!.maxUses,
                    recoveryType: f.resourcePool!.recoveryType,
                    calculationFormula: f.resourcePool!.calculationFormula,
                  )
                : null,
          );
        }).toList(),
        inventory: original.inventory.map((item) {
          // Deep copy inventory items with their properties
          return Item(
            id: item.id,
            nameEn: item.nameEn,
            nameRu: item.nameRu,
            descriptionEn: item.descriptionEn,
            descriptionRu: item.descriptionRu,
            type: item.type,
            rarity: item.rarity,
            quantity: item.quantity,
            weight: item.weight,
            valueInCopper: item.valueInCopper,
            isEquipped: item.isEquipped,
            isAttuned: item.isAttuned,
            weaponProperties: item.weaponProperties != null
                ? WeaponProperties(
                    damageDice: item.weaponProperties!.damageDice,
                    damageType: item.weaponProperties!.damageType,
                    weaponTags: List<String>.from(item.weaponProperties!.weaponTags),
                    range: item.weaponProperties!.range,
                    longRange: item.weaponProperties!.longRange,
                    versatileDamageDice: item.weaponProperties!.versatileDamageDice,
                  )
                : null,
            armorProperties: item.armorProperties != null
                ? ArmorProperties(
                    baseAC: item.armorProperties!.baseAC,
                    armorType: item.armorProperties!.armorType,
                    addDexModifier: item.armorProperties!.addDexModifier,
                    maxDexBonus: item.armorProperties!.maxDexBonus,
                    strengthRequirement: item.armorProperties!.strengthRequirement,
                    stealthDisadvantage: item.armorProperties!.stealthDisadvantage,
                  )
                : null,
            isMagical: item.isMagical,
            iconName: item.iconName,
          );
        }).toList(),
        personalityTraits: original.personalityTraits,
        ideals: original.ideals,
        bonds: original.bonds,
        flaws: original.flaws,
        backstory: original.backstory,
        appearance: original.appearance,
        createdAt: DateTime.now(), // New creation time for the duplicate
        updatedAt: DateTime.now(),
      );

      // Save the duplicate to database
      await StorageService.saveCharacter(duplicate);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${original.name} duplicated successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate character: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importFromFC5(BuildContext context) async {
    try {
      print('🔧 _importFromFC5: Starting FC5 import');

      // Pick XML file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );

      if (result == null || result.files.isEmpty) {
        print('🔧 _importFromFC5: User cancelled file picker');
        return; // User cancelled
      }

      print('🔧 _importFromFC5: File selected: ${result.files.single.path}');

      final file = File(result.files.single.path!);
      final xmlContent = await file.readAsString();

      print('🔧 _importFromFC5: Read ${xmlContent.length} characters from file');

      // Parse XML to Character
      print('🔧 _importFromFC5: Parsing XML...');
      final character = FC5Parser.parseXml(xmlContent);
      print('🔧 _importFromFC5: Parsed character: ${character.name} (${character.characterClass} level ${character.level})');

      // Save to database
      print('🔧 _importFromFC5: Saving to database...');
      await StorageService.saveCharacter(character);
      print('🔧 _importFromFC5: Character saved successfully!');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${character.name} imported successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ _importFromFC5: ERROR: $e');
      print('❌ Stack trace: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import character: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
