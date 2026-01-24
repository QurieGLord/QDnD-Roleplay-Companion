import 'package:xml/xml.dart';
import '../models/character.dart';
import '../models/ability_scores.dart';
import '../models/item.dart';
import '../models/spell.dart';
import 'package:uuid/uuid.dart';

class CompendiumData {
  final List<Item> items;
  final List<Spell> spells;

  CompendiumData({required this.items, required this.spells});
}

class FC5Parser {
  static Future<CompendiumData> parseCompendium(String xmlContent) async {
    final document = XmlDocument.parse(xmlContent);
    final items = <Item>[];
    final spells = <Spell>[];

    // Check root element
    // Valid roots: <compendium>, <items>, <spells> (though usually compendium for mixed)
    final root = document.rootElement;
    print('🔧 FC5Parser: Parsing compendium with root <${root.name}>');

    // Parse Items
    final itemElements = root.findAllElements('item');
    print('🔧 FC5Parser: Found ${itemElements.length} items to parse');
    
    for (var node in itemElements) {
      try {
        final fullName = node.findElements('name').first.innerText;
        
        String nameEn = fullName;
        String nameRu = fullName;

        if (fullName.contains('---RU---')) {
          final parts = fullName.split('---RU---');
          nameEn = parts[0].trim();
          if (parts.length > 1) {
            nameRu = parts[1].trim();
          }
        }

        final typeCode = node.findElements('type').firstOrNull?.innerText ?? 'G';
        final weightStr = node.findElements('weight').firstOrNull?.innerText ?? '0';
        
        // Combine text tags for description
        final fullDescription = node.findAllElements('text').map((e) => e.innerText).join('\n').trim();
        
        String descriptionEn = fullDescription;
        String descriptionRu = fullDescription;

        if (fullDescription.contains('---RU---')) {
          final parts = fullDescription.split('---RU---');
          descriptionEn = parts[0].trim();
          if (parts.length > 1) {
            descriptionRu = parts[1].trim();
          }
        }
        
        // Parse type
        ItemType type = ItemType.gear;
        ArmorProperties? armorProps;
        WeaponProperties? weaponProps;
        
        // Type mapping
        // M: Melee Weapon, R: Ranged Weapon, ST: Staff/Rod? (treat as weapon if it has dmg)
        // A: Armor, LA: Light, MA: Medium, HA: Heavy, S: Shield
        // P: Potion, SC: Scroll, W: Wondrous
        // G: Gear, $: Treasure/Money
        
        if (['M', 'R', 'ST'].contains(typeCode) || (typeCode == 'ST' && node.findElements('dmg1').isNotEmpty)) {
          type = ItemType.weapon;
          
          final dmg1 = node.findElements('dmg1').firstOrNull?.innerText ?? '';
          final dmgTypeStr = node.findElements('dmgType').firstOrNull?.innerText ?? '';
          final properties = node.findElements('property').firstOrNull?.innerText ?? '';
          
          DamageType dmgType = DamageType.slashing;
          if (dmgTypeStr.contains('piercing')) dmgType = DamageType.piercing;
          else if (dmgTypeStr.contains('bludgeoning')) dmgType = DamageType.bludgeoning;
          else if (dmgTypeStr.contains('fire')) dmgType = DamageType.fire;
          else if (dmgTypeStr.contains('cold')) dmgType = DamageType.cold;
          else if (dmgTypeStr.contains('lightning')) dmgType = DamageType.lightning;
          else if (dmgTypeStr.contains('poison')) dmgType = DamageType.poison;
          else if (dmgTypeStr.contains('acid')) dmgType = DamageType.acid;
          else if (dmgTypeStr.contains('psychic')) dmgType = DamageType.psychic;
          else if (dmgTypeStr.contains('necrotic')) dmgType = DamageType.necrotic;
          else if (dmgTypeStr.contains('radiant')) dmgType = DamageType.radiant;
          else if (dmgTypeStr.contains('thunder')) dmgType = DamageType.thunder;
          else if (dmgTypeStr.contains('force')) dmgType = DamageType.force;

          weaponProps = WeaponProperties(
            damageDice: dmg1,
            damageType: dmgType,
            weaponTags: properties.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          );
        } else if (['A', 'LA', 'MA', 'HA', 'S'].contains(typeCode)) {
          type = ItemType.armor;
          
          final acStr = node.findElements('ac').firstOrNull?.innerText ?? '10';
          int ac = int.tryParse(acStr) ?? 10;
          
          ArmorType armorType = ArmorType.light;
          if (typeCode == 'MA') armorType = ArmorType.medium;
          if (typeCode == 'HA') armorType = ArmorType.heavy;
          if (typeCode == 'S') armorType = ArmorType.shield;
          
          final stealthStr = node.findElements('stealth').firstOrNull?.innerText ?? '';
          
          armorProps = ArmorProperties(
            baseAC: ac,
            armorType: armorType,
            addDexModifier: ['LA', 'MA'].contains(typeCode), // Light adds full, Medium adds up to 2
            maxDexBonus: typeCode == 'MA' ? 2 : null,
            stealthDisadvantage: stealthStr.toLowerCase().contains('disadvantage'),
          );
        } else if (['P', 'SC', 'W'].contains(typeCode)) {
          type = ItemType.consumable;
        } else if (typeCode == '\$') {
          type = ItemType.treasure;
        } else {
          type = ItemType.gear;
        }

        final item = Item(
          id: const Uuid().v4(),
          nameEn: nameEn,
          nameRu: nameRu,
          descriptionEn: descriptionEn,
          descriptionRu: descriptionRu,
          type: type,
          rarity: ItemRarity.common, // FC5 doesn't always specify rarity clearly in 'type'
          weight: double.tryParse(weightStr) ?? 0.0,
          weaponProperties: weaponProps,
          armorProperties: armorProps,
        );
        
        items.add(item);
      } catch (e) {
        print('⚠️ FC5Parser: Failed to parse item: $e');
      }
    }

    // Parse Spells
    final spellElements = root.findAllElements('spell');
    print('🔧 FC5Parser: Found ${spellElements.length} spells to parse');

    for (var node in spellElements) {
      try {
        final fullName = node.findElements('name').first.innerText;
        
        String nameEn = fullName;
        String nameRu = fullName;

        if (fullName.contains('---RU---')) {
          final parts = fullName.split('---RU---');
          nameEn = parts[0].trim();
          if (parts.length > 1) {
            nameRu = parts[1].trim();
          }
        }

        final levelStr = node.findElements('level').firstOrNull?.innerText ?? '0';
        final schoolCode = node.findElements('school').firstOrNull?.innerText ?? 'A';
        final time = node.findElements('time').firstOrNull?.innerText ?? '';
        final range = node.findElements('range').firstOrNull?.innerText ?? '';
        final duration = node.findElements('duration').firstOrNull?.innerText ?? '';
        final classesStr = node.findElements('classes').firstOrNull?.innerText ?? '';
        final fullDescription = node.findAllElements('text').map((e) => e.innerText).join('\n').trim();
        
        String descriptionEn = fullDescription;
        String descriptionRu = fullDescription;

        if (fullDescription.contains('---RU---')) {
          final parts = fullDescription.split('---RU---');
          descriptionEn = parts[0].trim();
          if (parts.length > 1) {
            descriptionRu = parts[1].trim();
          }
        }

        final componentsStr = node.findElements('components').firstOrNull?.innerText ?? '';
        final ritualStr = node.findElements('ritual').firstOrNull?.innerText ?? 'NO';
        
        // School mapping
        String school = 'Abjuration';
        if (schoolCode == 'C') school = 'Conjuration';
        if (schoolCode == 'D') school = 'Divination';
        if (schoolCode == 'EN') school = 'Enchantment';
        if (schoolCode == 'EV') school = 'Evocation';
        if (schoolCode == 'I') school = 'Illusion';
        if (schoolCode == 'N') school = 'Necromancy';
        if (schoolCode == 'T') school = 'Transmutation';

        // Components parsing
        List<String> components = [];
        if (componentsStr.contains('V')) components.add('V');
        if (componentsStr.contains('S')) components.add('S');
        if (componentsStr.contains('M')) components.add('M');

        // Material components usually in text "(a pinch of dust)"
        String? materials;
        if (componentsStr.contains('(')) {
          final start = componentsStr.indexOf('(');
          final end = componentsStr.lastIndexOf(')');
          if (end > start) {
            materials = componentsStr.substring(start + 1, end);
          }
        }

        final spell = Spell(
          id: const Uuid().v4(),
          nameEn: nameEn,
          nameRu: nameRu,
          level: int.tryParse(levelStr) ?? 0,
          school: school,
          castingTime: time,
          range: range,
          duration: duration,
          concentration: duration.toLowerCase().contains('concentration'),
          ritual: ritualStr.toUpperCase() == 'YES',
          components: components,
          materialComponents: materials,
          descriptionEn: descriptionEn,
          descriptionRu: descriptionRu,
          availableToClasses: classesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        );

        spells.add(spell);
      } catch (e) {
        print('⚠️ FC5Parser: Failed to parse spell: $e');
      }
    }

    return CompendiumData(items: items, spells: spells);
  }

  static Character parseXml(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    print('🔧 FC5Parser: Root element = ${document.rootElement.name}');
    print('🔧 FC5Parser: Root children count = ${document.rootElement.children.length}');

    // FC5 XML structure can be:
    // 1. <pc><character>...</character></pc> - single character export
    // 2. <characters><npc>...</npc>...</characters> - Game Master mode (NPC/monster format)
    // 3. <compendium><character>...</character></compendium> - multiple characters

    XmlElement? characterNode;

    // Check if root IS named "characters" (GM mode export)
    if (document.rootElement.name.local == 'characters') {
      print('🔧 FC5Parser: Root is <characters> - GM mode export detected');

      // GM mode can contain multiple NPCs - take the first one
      final npcElements = document.rootElement.findElements('npc');
      if (npcElements.isNotEmpty) {
        print('🔧 FC5Parser: Found ${npcElements.length} <npc> elements, parsing first one');
        characterNode = npcElements.first;
      } else {
        print('❌ FC5Parser: No <npc> elements found in GM mode export');
        throw Exception('GM mode export must contain at least one <npc> element');
      }
    } else {
      // Try to find <character> children
      final characterElements = document.rootElement.findElements('character');
      print('🔧 FC5Parser: Found ${characterElements.length} <character> elements');

      if (characterElements.isEmpty) {
        print('❌ FC5Parser: No <character> element found!');
        print('❌ FC5Parser: Available child elements:');
        for (var child in document.rootElement.childElements) {
          print('  - <${child.name}>');
        }
        throw Exception('No <character> element found in XML. Root is <${document.rootElement.name}> but expected <character> child elements.');
      }

      characterNode = characterElements.first;
    }

    // Parse name
    final name = characterNode.findElements('name').first.innerText;

    // Parse abilities (comma-separated: STR,DEX,CON,INT,WIS,CHA)
    final abilitiesText = characterNode.findElements('abilities').first.innerText;
    final abilitiesList = abilitiesText
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => int.parse(s.trim()))
        .toList();

    final abilityScores = AbilityScores(
      strength: abilitiesList.isNotEmpty ? abilitiesList[0] : 10,
      dexterity: abilitiesList.length > 1 ? abilitiesList[1] : 10,
      constitution: abilitiesList.length > 2 ? abilitiesList[2] : 10,
      intelligence: abilitiesList.length > 3 ? abilitiesList[3] : 10,
      wisdom: abilitiesList.length > 4 ? abilitiesList[4] : 10,
      charisma: abilitiesList.length > 5 ? abilitiesList[5] : 10,
    );

    // Parse HP
    final maxHp = int.parse(characterNode.findElements('hpMax').first.innerText);
    final currentHp = int.parse(characterNode.findElements('hpCurrent').first.innerText);

    // Parse race
    final raceNode = characterNode.findElements('race').first;
    final race = raceNode.findElements('name').first.innerText;

    // Parse appearance from race node
    String? appearance;
    try {
      final age = raceNode.findElements('age').firstOrNull?.innerText;
      final height = raceNode.findElements('height').firstOrNull?.innerText;
      final weight = raceNode.findElements('weight').firstOrNull?.innerText;
      final eyes = raceNode.findElements('eyes').firstOrNull?.innerText;
      final skin = raceNode.findElements('skin').firstOrNull?.innerText;
      final hair = raceNode.findElements('hair').firstOrNull?.innerText;

      if (age != null || height != null) {
        appearance = 'Age: ${age ?? 'Unknown'}\n'
            'Height: ${height ?? 'Unknown'} cm\n'
            'Weight: ${weight ?? 'Unknown'} kg\n'
            'Eyes: ${eyes ?? 'Unknown'}\n'
            'Skin: ${skin ?? 'Unknown'}\n'
            'Hair: ${hair ?? 'Unknown'}';
      }
    } catch (e) {
      // Ignore if appearance data not available
    }

    // Parse background
    final backgroundNode = characterNode.findElements('background').firstOrNull;
    final background = backgroundNode?.findElements('name').firstOrNull?.innerText;

    // Parse class
    String characterClass = 'Unknown';
    String? subclass;
    int level = 1;
    XmlElement? classNode;

    final classElements = characterNode.findElements('class');
    if (classElements.isNotEmpty) {
      classNode = classElements.first;
      
      try {
        final classText = classNode.findElements('name').first.innerText;
        level = int.parse(classNode.findElements('level').first.innerText);

        if (classText.contains(':')) {
          final parts = classText.split(':');
          characterClass = parts[0].trim();
          subclass = parts[1].trim();
        } else {
          characterClass = classText.trim();
        }
      } catch (e) {
        print('⚠️ FC5Parser: Error parsing class details: $e');
      }
    } else {
      print('⚠️ FC5Parser: No <class> element found');
    }

    // Parse spell slots
    // FC5 XML format: <slots>cantrips,1st,2nd,3rd,...9th</slots>
    // We skip cantrips (index 0) and take levels 1-9
    List<int> maxSpellSlots = List.filled(9, 0);
    List<int> currentSpellSlots = List.filled(9, 0);

    if (classNode != null) {
      try {
        final slotsText = classNode!.findElements('slots').first.innerText;
        final slotsList = slotsText
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();

        // Skip index 0 (cantrips), copy indices 1-9 as spell levels 1-9
        for (int i = 1; i < slotsList.length && i <= 9; i++) {
          maxSpellSlots[i - 1] = slotsList[i];
        }

        final currentSlotsText = classNode!.findElements('slotsCurrent').first.innerText;
        final currentSlotsList = currentSlotsText
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) => int.parse(s.trim()))
            .toList();

        // Skip index 0 (cantrips), copy indices 1-9 as spell levels 1-9
        for (int i = 1; i < currentSlotsList.length && i <= 9; i++) {
          currentSpellSlots[i - 1] = currentSlotsList[i];
        }
      } catch (e) {
        // No spell slots (non-caster or error)
        maxSpellSlots = List.filled(9, 0);
        currentSpellSlots = List.filled(9, 0);
      }
    }

    // Parse proficient skills
    List<String> proficientSkills = [];
    if (classNode != null) {
      try {
        final proficiencies = classNode!.findAllElements('proficiency');
        for (var prof in proficiencies) {
          proficientSkills.add(prof.innerText);
        }
      } catch (e) {
        // No proficiencies found
      }
    }

    // Parse spells - for now, we'll add some default spells for Paladins
    // FC5 XML format stores spells, but we'll use our own spell IDs
    List<String> knownSpells = [];
    List<String> preparedSpells = [];
    int maxPreparedSpells = 0;

    // Check if Paladin (support both EN and RU)
    final isPaladin = characterClass.toLowerCase() == 'paladin' ||
                      characterClass.toLowerCase() == 'паладин';

    if (isPaladin) {
      // Level 2+ Paladin knows all Paladin spells (can prepare subset)
      if (level >= 2) {
        // Add starting Paladin spells from our database
        knownSpells = [
          'bless',
          'cure_wounds',
          'divine_favor',
          'shield_of_faith',
          'command',
          'detect_magic',
        ];
        // Calculate max prepared: CHA modifier + half paladin level
        maxPreparedSpells = abilityScores.charismaModifier + (level ~/ 2);
        if (maxPreparedSpells < 1) maxPreparedSpells = 1;

        // Prepare some default spells
        preparedSpells = knownSpells.take(maxPreparedSpells).toList();
      }
    }

    // Calculate AC (simplified - base 10 + DEX modifier)
    // In reality, would need to parse armor from equipment
    int baseAc = 10 + abilityScores.dexterityModifier;

    // Calculate speed (default for medium humanoid)
    int speed = 30;

    return Character(
      id: const Uuid().v4(),
      name: name,
      race: race,
      characterClass: characterClass,
      subclass: subclass,
      level: level,
      maxHp: maxHp,
      currentHp: currentHp,
      abilityScores: abilityScores,
      background: background,
      spellSlots: currentSpellSlots,
      maxSpellSlots: maxSpellSlots,
      knownSpells: knownSpells,
      preparedSpells: preparedSpells,
      maxPreparedSpells: maxPreparedSpells,
      armorClass: baseAc,
      speed: speed,
      initiative: abilityScores.dexterityModifier,
      proficientSkills: proficientSkills,
      savingThrowProficiencies: [],
      appearance: appearance,
      features: [], // Empty mutable list - will be populated by FeatureService
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
