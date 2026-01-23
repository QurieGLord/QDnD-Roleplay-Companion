import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/models/ability_scores.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/models/item.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/import_service.dart';
import 'widgets/character_card.dart';
import 'widgets/empty_state.dart';
import 'package:qd_and_d/features/character_sheet/character_sheet_screen.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/features/character_edit/character_edit_screen.dart';

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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.characters),
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
        label: Text(l10n.createNewCharacter),
      ),
    );
  }

  void _showCreateCharacterDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.createNewCharacter,
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
              label: Text(l10n.createNewCharacter),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _importFromFC5(context);
              },
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.importFC5),
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterOptions(BuildContext context, Character character) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.viewDetails),
              onTap: () {
                Navigator.pop(context);
                _showCharacterDetails(context, character);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CharacterEditScreen(character: character),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.duplicate),
              onTap: () async {
                Navigator.pop(context);
                await _duplicateCharacter(context, character);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(l10n.delete,
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
            child: Text(AppLocalizations.of(context)!.close),
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmationTitle),
        content: Text(l10n.deleteConfirmationMessage(character.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              await StorageService.deleteCharacter(character.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.deletedSuccess(character.name)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _duplicateCharacter(BuildContext context, Character original) async {
    final l10n = AppLocalizations.of(context)!;
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
        features: List<CharacterFeature>.from(original.features.map((f) {
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
        })),
        inventory: List<Item>.from(original.inventory.map((item) {
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
        })),
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
            content: Text(l10n.duplicatedSuccess(original.name)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate character: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _importFromFC5(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
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
      
      // Use ImportService to handle parsing, feature addition, and saving
      final character = await ImportService.importFromFC5File(file);
      
      print('🔧 _importFromFC5: Character imported successfully: ${character.name}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.importedSuccess(character.name)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 2),
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
