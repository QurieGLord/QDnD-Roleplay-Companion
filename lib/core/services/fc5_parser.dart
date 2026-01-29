import 'package:xml/xml.dart';
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../models/ability_scores.dart';
import '../models/item.dart';
import '../models/spell.dart';
import '../models/race_data.dart';
import '../models/class_data.dart';
import '../models/background_data.dart';
import '../models/character_feature.dart';

/// Result object containing all parsed entities from an FC5 XML
class FC5ParseResult {
  final List<Item> items;
  final List<Spell> spells;
  final List<RaceData> races;
  final List<ClassData> classes;
  final List<BackgroundData> backgrounds;
  final List<CharacterFeature> feats;

  FC5ParseResult({
    this.items = const [],
    this.spells = const [],
    this.races = const [],
    this.classes = const [],
    this.backgrounds = const [],
    this.feats = const [],
  });

  bool get isEmpty => 
      items.isEmpty && 
      spells.isEmpty && 
      races.isEmpty && 
      classes.isEmpty && 
      backgrounds.isEmpty && 
      feats.isEmpty;
}

class FC5Parser {
  static const Uuid _uuid = Uuid();
  static const String _separator = '---RU---';

  /// Main entry point to parse FC5 XML content for Compendium Data
  static Future<FC5ParseResult> parseCompendium(String xmlContent, {String? sourceId}) async {
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;
      final sid = sourceId ?? 'fc5_import';
      
      // Initialize lists
      final items = <Item>[];
      final spells = <Spell>[];
      final races = <RaceData>[];
      final classes = <ClassData>[];
      final backgrounds = <BackgroundData>[];
      final feats = <CharacterFeature>[];

      // Determine nodes to iterate
      Iterable<XmlElement> nodes;
      if (root.name.local == 'compendium') {
        nodes = root.childElements;
      } else {
        nodes = [root];
      }

      for (var node in nodes) {
        try {
          switch (node.name.local) {
            case 'item':
              items.add(_parseItem(node, sid));
              break;
            case 'spell':
              spells.add(_parseSpell(node, sid));
              break;
            case 'race':
              races.add(_parseRace(node, sid));
              break;
            case 'class':
              classes.add(_parseClass(node, sid));
              break;
            case 'background':
              backgrounds.add(_parseBackground(node, sid));
              break;
            case 'feat':
              feats.add(_parseFeat(node, sid));
              break;
            default:
              break;
          }
        } catch (e) {
          print('⚠️ FC5Parser: Failed to parse ${node.name.local}: $e');
        }
      }

      return FC5ParseResult(
        items: items,
        spells: spells,
        races: races,
        classes: classes,
        backgrounds: backgrounds,
        feats: feats,
      );
    } catch (e) {
      print('❌ FC5Parser: Critical error parsing XML: $e');
      return FC5ParseResult();
    }
  }

  /// Parses a single character from FC5 XML
  static Character parseCharacter(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    XmlElement? characterNode;

    if (document.rootElement.name.local == 'characters') {
      final npcElements = document.rootElement.findElements('npc');
      if (npcElements.isNotEmpty) {
        characterNode = npcElements.first;
      } else {
        throw Exception('GM mode export must contain at least one <npc> element');
      }
    } else {
      final characterElements = document.rootElement.findElements('character');
      if (characterElements.isEmpty) {
        throw Exception('No <character> element found in XML.');
      }
      characterNode = characterElements.first;
    }

    // Parse name
    final name = characterNode.findElements('name').first.innerText;

    // Parse abilities
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

    // Parse appearance
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
      // Ignore
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
        // Ignore
      }
    }

    // Parse spell slots
    List<int> maxSpellSlots = List.filled(9, 0);
    List<int> currentSpellSlots = List.filled(9, 0);

    if (classNode != null) {
      try {
        final slotsText = classNode.findElements('slots').first.innerText;
        final slotsList = slotsText.split(',').where((s) => s.isNotEmpty).map((s) => int.parse(s.trim())).toList();
        for (int i = 1; i < slotsList.length && i <= 9; i++) {
          maxSpellSlots[i - 1] = slotsList[i];
        }

        final currentSlotsText = classNode.findElements('slotsCurrent').first.innerText;
        final currentSlotsList = currentSlotsText.split(',').where((s) => s.isNotEmpty).map((s) => int.parse(s.trim())).toList();
        for (int i = 1; i < currentSlotsList.length && i <= 9; i++) {
          currentSpellSlots[i - 1] = currentSlotsList[i];
        }
      } catch (e) {
        // Ignore
      }
    }

    // Parse proficient skills
    List<String> proficientSkills = [];
    if (classNode != null) {
      try {
        final proficiencies = classNode.findAllElements('proficiency');
        for (var prof in proficiencies) {
          proficientSkills.add(prof.innerText);
        }
      } catch (e) {
        // Ignore
      }
    }

    List<String> knownSpells = [];
    List<String> preparedSpells = [];
    int maxPreparedSpells = 0;

    final isPaladin = characterClass.toLowerCase() == 'paladin' || characterClass.toLowerCase() == 'паладин';
    if (isPaladin) {
      if (level >= 2) {
        knownSpells = ['bless', 'cure_wounds', 'divine_favor', 'shield_of_faith', 'command', 'detect_magic'];
        maxPreparedSpells = abilityScores.charismaModifier + (level ~/ 2);
        if (maxPreparedSpells < 1) maxPreparedSpells = 1;
        preparedSpells = knownSpells.take(maxPreparedSpells).toList();
      }
    }

    int baseAc = 10 + abilityScores.dexterityModifier;
    int speed = 30;

    return Character(
      id: _uuid.v4(),
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
      features: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // --- Helper Methods ---

  static Map<String, String> _splitBilingual(String text) {
    if (text.contains(_separator)) {
      final parts = text.split(_separator);
      return {
        'en': parts[0].trim(),
        'ru': parts.length > 1 ? parts[1].trim() : '',
      };
    }
    return {'en': text, 'ru': ''};
  }

  static String _getTag(XmlElement node, String tagName) {
    return node.findElements(tagName).firstOrNull?.innerText.trim() ?? '';
  }

  static String _getText(XmlElement node, {String suffix = ''}) {
    final tagName = suffix.isEmpty ? 'text' : 'text$suffix';
    final elements = node.findAllElements(tagName);
    if (elements.isEmpty && suffix.isNotEmpty) {
       // Fallback to base text if specific language text is missing
       return _getText(node, suffix: '');
    }
    return elements.map((e) => e.innerText.trim()).join('\n').trim();
  }

  // Parses comma-separated IDs, trimming whitespace and removing parenthetical notes
  static List<String> _parseIds(String text) {
    if (text.isEmpty) return [];
    return text.split(',').map((s) {
      var item = s.trim();
      // Remove text in parentheses if it's at the end (e.g. "Stealth (Dex)")
      if (item.contains('(')) {
        final idx = item.indexOf('(');
        if (idx > 0) item = item.substring(0, idx).trim();
      }
      return item.toLowerCase();
    }).where((s) => s.isNotEmpty).toList();
  }

  // --- Entity Parsers ---
  
  static Item _parseItem(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');
    
    final descEn = _getText(node);
    final descRu = _getText(node, suffix: '_ru');
    
    final typeCode = _getTag(node, 'type').toLowerCase(); // Strict ID parsing
    final weight = double.tryParse(_getTag(node, 'weight')) ?? 0.0;
    
    ItemType type = ItemType.gear;
    ArmorProperties? armorProps;
    WeaponProperties? weaponProps;
    
    // Check for damage tag (dmg1 or damage1H)
    final hasDamage = node.findElements('dmg1').isNotEmpty || node.findElements('damage1H').isNotEmpty;
    
    // Logic remains similar, but relies on strictly English type codes or damage presence
    if (['m', 'r', 'st', 'weapon'].contains(typeCode) || (typeCode == 'st' && hasDamage)) {
      type = ItemType.weapon;
      
      var dmg1 = _getTag(node, 'dmg1');
      if (dmg1.isEmpty) dmg1 = _getTag(node, 'damage1H');
      
      final dmgTypeStr = _getTag(node, 'dmgType'); // Should be English ID
      final dmgTypeClean = dmgTypeStr.toLowerCase();
      
      final properties = _getTag(node, 'property');
      
      DamageType dmgType = DamageType.slashing;
      if (dmgTypeClean.contains('piercing')) dmgType = DamageType.piercing;
      else if (dmgTypeClean.contains('bludgeoning')) dmgType = DamageType.bludgeoning;
      else if (dmgTypeClean.contains('fire')) dmgType = DamageType.fire;
      else if (dmgTypeClean.contains('cold')) dmgType = DamageType.cold;
      else if (dmgTypeClean.contains('lightning')) dmgType = DamageType.lightning;
      else if (dmgTypeClean.contains('poison')) dmgType = DamageType.poison;
      else if (dmgTypeClean.contains('acid')) dmgType = DamageType.acid;
      else if (dmgTypeClean.contains('psychic')) dmgType = DamageType.psychic;
      else if (dmgTypeClean.contains('necrotic')) dmgType = DamageType.necrotic;
      else if (dmgTypeClean.contains('radiant')) dmgType = DamageType.radiant;
      else if (dmgTypeClean.contains('thunder')) dmgType = DamageType.thunder;
      else if (dmgTypeClean.contains('force')) dmgType = DamageType.force;

      weaponProps = WeaponProperties(
        damageDice: dmg1,
        damageType: dmgType,
        weaponTags: _parseIds(properties),
      );
    } else if (['a', 'la', 'ma', 'ha', 's'].contains(typeCode) || typeCode.startsWith('armor')) {
      type = ItemType.armor;
      final acStr = _getTag(node, 'ac');
      int ac = int.tryParse(acStr) ?? 10;
      
      ArmorType armorType = ArmorType.light;
      if (typeCode == 'ma') armorType = ArmorType.medium;
      if (typeCode == 'ha') armorType = ArmorType.heavy;
      if (typeCode == 's') armorType = ArmorType.shield;
      if (typeCode.contains('medium')) armorType = ArmorType.medium;
      if (typeCode.contains('heavy')) armorType = ArmorType.heavy;
      if (typeCode.contains('shield')) armorType = ArmorType.shield;
      
      final stealthStr = _getTag(node, 'stealth'); // English ID
      
      armorProps = ArmorProperties(
        baseAC: ac,
        armorType: armorType,
        addDexModifier: ['la', 'ma'].contains(typeCode) || typeCode.contains('light') || typeCode.contains('medium'),
        maxDexBonus: (typeCode == 'ma' || typeCode.contains('medium')) ? 2 : null,
        stealthDisadvantage: stealthStr.toLowerCase().contains('disadvantage'),
      );
    } else if (['p', 'sc', 'w'].contains(typeCode)) {
      type = ItemType.consumable;
    } else if (typeCode == '\$' || typeCode == 'treasure') {
      type = ItemType.treasure;
    } else if (typeCode == 'tool') {
        type = ItemType.tool;
    }

    return Item(
      id: _uuid.v4(),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      descriptionEn: descEn,
      descriptionRu: descRu,
      type: type,
      rarity: ItemRarity.common,
      weight: weight,
      weaponProperties: weaponProps,
      armorProperties: armorProps,
      sourceId: sourceId,
    );
  }

  static Spell _parseSpell(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');

    final levelStr = _getTag(node, 'level');
    final schoolCode = _getTag(node, 'school').toLowerCase(); // English ID
    final time = _getTag(node, 'time');
    final range = _getTag(node, 'range');
    final duration = _getTag(node, 'duration');
    final durationRu = _getTag(node, 'duration_ru');
    
    // Parse classes: Handle bilingual split BEFORE parsing IDs to ensure we get clean English IDs
    final classesRaw = _getTag(node, 'classes');
    final classesStr = _splitBilingual(classesRaw)['en']!; 
    
    final descEn = _getText(node);
    final descRu = _getText(node, suffix: '_ru');

    final componentsStr = _getTag(node, 'components'); // English IDs
    final ritualStr = _getTag(node, 'ritual');

    String school = 'Abjuration';
    // Simplified mapping or keep English as base
    if (schoolCode == 'c' || schoolCode.startsWith('conj')) school = 'Conjuration';
    else if (schoolCode == 'd' || schoolCode.startsWith('div')) school = 'Divination';
    else if (schoolCode == 'en' || schoolCode.startsWith('ench')) school = 'Enchantment';
    else if (schoolCode == 'ev' || schoolCode.startsWith('evoc')) school = 'Evocation';
    else if (schoolCode == 'i' || schoolCode.startsWith('illu')) school = 'Illusion';
    else if (schoolCode == 'n' || schoolCode.startsWith('necr')) school = 'Necromancy';
    else if (schoolCode == 't' || schoolCode.startsWith('trans')) school = 'Transmutation';

    List<String> components = [];
    if (componentsStr.contains('V')) components.add('V');
    if (componentsStr.contains('S')) components.add('S');
    if (componentsStr.contains('M')) components.add('M');

    // Material components often in text "(a pinch of dust)"
    String? materials;
    if (componentsStr.contains('(')) {
      final start = componentsStr.indexOf('(');
      final end = componentsStr.lastIndexOf(')');
      if (end > start) {
        materials = componentsStr.substring(start + 1, end);
      }
    }
    // We could parse materials_ru if available, but for now stick to structure

    return Spell(
      id: _uuid.v4(),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      level: int.tryParse(levelStr) ?? 0,
      school: school,
      castingTime: time, // Logic suggests using EN for standard fields if strict IDs not required, but bilingual is nicer.
      // However, Spell model usually stores just one string for these technical fields in simple schema.
      // If Spell model supports bilingual time/range, we'd assign it.
      // Checking Spell model (I know it has `nameRu` etc, but not `castingTimeRu`).
      // Assume standard fields are English/Base for mechanics.
      range: range,
      duration: duration,
      concentration: duration.toLowerCase().contains('concentration'),
      ritual: ritualStr.toUpperCase() == 'YES',
      components: components,
      materialComponents: materials,
      descriptionEn: descEn,
      descriptionRu: descRu,
      availableToClasses: _parseIds(classesStr),
      sourceId: sourceId,
    );
  }

  static RaceData _parseRace(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');
    
    final size = _getTag(node, 'size');
    final speedStr = _getTag(node, 'speed');
    final speed = int.tryParse(speedStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 30;
    
    final abilityMap = <String, int>{};
    final abilityStr = _getTag(node, 'ability');
    if (abilityStr.isNotEmpty) {
      final parts = abilityStr.split(',');
      for (var part in parts) {
        part = part.trim();
        final regex = RegExp(r'([A-Z]{3})\s*(\d+)');
        final match = regex.firstMatch(part);
        if (match != null) {
          final abilityCode = match.group(1) ?? '';
          final score = int.tryParse(match.group(2) ?? '0') ?? 0;
          String abilityKey = '';
          switch (abilityCode) {
            case 'STR': abilityKey = 'strength'; break;
            case 'DEX': abilityKey = 'dexterity'; break;
            case 'CON': abilityKey = 'constitution'; break;
            case 'INT': abilityKey = 'intelligence'; break;
            case 'WIS': abilityKey = 'wisdom'; break;
            case 'CHA': abilityKey = 'charisma'; break;
          }
          if (abilityKey.isNotEmpty) {
            abilityMap[abilityKey] = score;
          }
        }
      }
    }

    final traits = <CharacterFeature>[];
    for (var traitNode in node.findAllElements('trait')) {
      final tNameEn = _getTag(traitNode, 'name');
      final tNameRu = _getTag(traitNode, 'name_ru');
      
      final tDescEn = _getText(traitNode);
      final tDescRu = _getText(traitNode, suffix: '_ru');
      
      if (tNameEn.isNotEmpty) {
        traits.add(CharacterFeature(
          id: _uuid.v4(),
          nameEn: tNameEn,
          nameRu: tNameRu.isNotEmpty ? tNameRu : tNameEn,
          descriptionEn: tDescEn,
          descriptionRu: tDescRu,
          type: FeatureType.passive,
          minLevel: 1,
          sourceId: sourceId,
        ));
      }
    }
    
    // Parse proficiencies - Strict IDs
    final profStr = _getTag(node, 'proficiency');
    List<String> proficiencies = _parseIds(profStr);

    return RaceData(
      id: nameEn.toLowerCase(),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {'en': _getText(node), 'ru': _getText(node, suffix: '_ru')},
      speed: speed,
      abilityScoreIncreases: abilityMap,
      languages: [],
      proficiencies: proficiencies,
      traits: traits,
      size: size == 'S' ? 'Small' : 'Medium',
      sourceId: sourceId,
    );
  }

  static ClassData _parseClass(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');
    
    final hdStr = _getTag(node, 'hd');
    final hitDie = int.tryParse(hdStr) ?? 8;
    final primaryAbilityStr = _getTag(node, 'spellAbility');

    final features = <int, List<CharacterFeature>>{};
    
    // Subclass extraction variables
    // Key: Subclass ID (English Name Lowercase), Value: {en: Name, ru: Name}
    final subclassMap = <String, Map<String, String>>{}; 
    int? detectedSubclassLevel;

    for (var autolevel in node.findAllElements('autolevel')) {
      final levelStr = autolevel.getAttribute('level');
      if (levelStr == null) continue;
      final level = int.tryParse(levelStr) ?? 0;
      if (level < 1) continue;

      if (!features.containsKey(level)) {
        features[level] = [];
      }
      
      // Check for subclass definition
      final subclassEn = autolevel.getAttribute('subclass');
      if (subclassEn != null && subclassEn.isNotEmpty) {
         String? subclassRu = autolevel.getAttribute('subclass_ru');
         // Fallback: Check for 'name_ru' attribute on the autolevel tag itself
         if (subclassRu == null || subclassRu.isEmpty) {
            subclassRu = autolevel.getAttribute('name_ru');
         }
         
         // If attribute still contains old separator (legacy support/mixed xml), verify
         // But per instruction we focus on suffix attributes or clean strings
         // We assume subclassEn is the English name now.
         
         final id = subclassEn.toLowerCase();
         if (!subclassMap.containsKey(id)) {
            subclassMap[id] = {
              'en': subclassEn,
              'ru': subclassRu != null && subclassRu.isNotEmpty ? subclassRu : subclassEn
            };
         }
         
         if (detectedSubclassLevel == null || level < detectedSubclassLevel) {
            detectedSubclassLevel = level;
         }
      }

      for (var featureNode in autolevel.findElements('feature')) {
        var fNameEn = _getTag(featureNode, 'name');
        var fNameRu = _getTag(featureNode, 'name_ru');
        
        final fDescEn = _getText(featureNode);
        final fDescRu = _getText(featureNode, suffix: '_ru');
        
        // Handle optional feature
        final optional = featureNode.getAttribute('optional');
        if (optional != null && optional.toUpperCase() == 'YES') {
          fNameEn = '[Optional] $fNameEn';
          fNameRu = fNameRu.isNotEmpty ? '[Опционально] $fNameRu' : '[Опционально] $fNameEn';
        }
        
        if (fNameEn.isNotEmpty) {
          features[level]!.add(CharacterFeature(
            id: _uuid.v4(),
            nameEn: fNameEn,
            nameRu: fNameRu.isNotEmpty ? fNameRu : fNameEn,
            descriptionEn: fDescEn,
            descriptionRu: fDescRu,
            type: FeatureType.passive,
            minLevel: level,
            associatedClass: nameEn, 
            sourceId: sourceId,
          ));
        }
      }
    }
    
    SpellcastingInfo? spellcasting;
    if (primaryAbilityStr.isNotEmpty) {
      spellcasting = SpellcastingInfo(
        ability: primaryAbilityStr.toLowerCase(),
        type: 'full',
      );
    }
    
    // Parse Proficiencies - Strict IDs
    final proficienciesStr = _getTag(node, 'proficiency'); // e.g., "Saving Throws: Wisdom, Charisma; Skills: History..."
    
    final savingThrows = <String>[];
    int skillChoose = 0;
    final skillFrom = <String>[];
    bool foundSkillsLabel = false;
    
    if (proficienciesStr.isNotEmpty) {
      // Split by semicolon, newline, or comma (if no semicolon exists)
      final parts = proficienciesStr.split(RegExp(r'[;\n]'));
      
      for (var part in parts) {
        part = part.trim();
        final lowerPart = part.toLowerCase();
        
        if (lowerPart.contains('saving throws')) {
          final colonIndex = part.indexOf(':');
          if (colonIndex != -1) {
             final stList = part.substring(colonIndex + 1);
             savingThrows.addAll(_parseIds(stList));
          }
        } else if (lowerPart.contains('skills')) {
           foundSkillsLabel = true;
           final colonIndex = part.indexOf(':');
           if (colonIndex != -1) {
             final skillPart = part.substring(colonIndex + 1).trim();
             
             final chooseRegex = RegExp(r'Choose\s+(\d+)\s+from\s+(.*)', caseSensitive: false);
             final match = chooseRegex.firstMatch(skillPart);
             
             if (match != null) {
               if (skillChoose == 0) {
                  skillChoose = int.tryParse(match.group(1) ?? '0') ?? 0;
               }
               final skillsList = match.group(2) ?? '';
               skillFrom.addAll(_parseIds(skillsList));
             } else {
               skillFrom.addAll(_parseIds(skillPart));
             }
           }
        }
      }
      
      if (!foundSkillsLabel && skillFrom.isEmpty) {
         if (!proficienciesStr.toLowerCase().contains('saving throws:')) {
            skillFrom.addAll(_parseIds(proficienciesStr));
         }
      }
    }
    
    final numSkillsStr = _getTag(node, 'numSkills');
    if (numSkillsStr.isNotEmpty) {
        skillChoose = int.tryParse(numSkillsStr) ?? 0;
    }
    
    // Convert subclass names to SubclassData
    final subclasses = subclassMap.entries.map((entry) {
       final id = entry.key;
       final names = entry.value;
       final nameEn = names['en']!;
       
       return SubclassData(
         id: id,
         name: names,
         description: {'en': 'Subclass of $nameEn', 'ru': ''}, // Placeholder description
       );
    }).toList();

    return ClassData(
      id: nameEn.toLowerCase(),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {'en': _getText(node), 'ru': _getText(node, suffix: '_ru')},
      hitDie: hitDie,
      primaryAbilities: [],
      savingThrowProficiencies: savingThrows,
      armorProficiencies: ArmorProficiencies(),
      weaponProficiencies: WeaponProficiencies(),
      skillProficiencies: SkillProficiencies(choose: skillChoose, from: skillFrom),
      subclasses: subclasses,
      subclassLevel: detectedSubclassLevel ?? 3,
      features: features,
      spellcasting: spellcasting,
      sourceId: sourceId,
    );
  }

  static BackgroundData _parseBackground(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');
    
    // Parse skills from <skill> OR <proficiency> - Strict IDs
    String skillStr = _getTag(node, 'skill');
    if (skillStr.isEmpty) {
        skillStr = _getTag(node, 'proficiency');
    }
    
    final skills = _parseIds(skillStr);

    final traitNodes = node.findAllElements('trait');
    
    final nameBufferEn = StringBuffer();
    final nameBufferRu = StringBuffer();
    final descBufferEn = StringBuffer();
    final descBufferRu = StringBuffer();
    
    if (traitNodes.isNotEmpty) {
      final first = traitNodes.first;
      final firstNameEn = _getTag(first, 'name');
      final firstNameRu = _getTag(first, 'name_ru');
      nameBufferEn.write(firstNameEn);
      nameBufferRu.write(firstNameRu.isNotEmpty ? firstNameRu : firstNameEn);
      
      final firstDescEn = _getText(first);
      final firstDescRu = _getText(first, suffix: '_ru');
      descBufferEn.write(firstDescEn);
      descBufferRu.write(firstDescRu);
      
      for (var i = 1; i < traitNodes.length; i++) {
        final t = traitNodes.elementAt(i);
        final tNameEn = _getTag(t, 'name');
        final tNameRu = _getTag(t, 'name_ru');
        
        final tDescEn = _getText(t);
        final tDescRu = _getText(t, suffix: '_ru');
        
        descBufferEn.write('\n\n$tNameEn:\n$tDescEn');
        
        final safeNameRu = tNameRu.isNotEmpty ? tNameRu : tNameEn;
        descBufferRu.write('\n\n$safeNameRu:\n$tDescRu');
      }
    }

    return BackgroundData(
      id: nameEn.toLowerCase(),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {'en': _getText(node), 'ru': _getText(node, suffix: '_ru')},
      skillProficiencies: skills,
      toolProficiencies: {},
      languages: 0,
      feature: BackgroundFeature(
        name: {'en': nameBufferEn.toString(), 'ru': nameBufferRu.toString()},
        description: {'en': descBufferEn.toString(), 'ru': descBufferRu.toString()},
      ),
      equipment: {},
    );
  }

  static CharacterFeature _parseFeat(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name');
    final nameRu = _getTag(node, 'name_ru');

    final textEn = _getText(node);
    final textRu = _getText(node, suffix: '_ru');

    final prerequisiteEn = _getTag(node, 'prerequisite');
    final prerequisiteRu = _getTag(node, 'prerequisite_ru');

    String fullDescEn = textEn;
    if (prerequisiteEn.isNotEmpty) {
      fullDescEn = 'Prerequisite: $prerequisiteEn\n\n$fullDescEn';
    }

    String fullDescRu = textRu;
    if (prerequisiteRu.isNotEmpty) {
      fullDescRu = 'Требование: $prerequisiteRu\n\n$fullDescRu';
    } else if (prerequisiteEn.isNotEmpty) {
       // Fallback for prerequisite in RU description if RU prereq missing
       fullDescRu = 'Prerequisite: $prerequisiteEn\n\n$fullDescRu';
    }

    return CharacterFeature(
      id: _uuid.v4(),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      descriptionEn: fullDescEn,
      descriptionRu: fullDescRu,
      type: FeatureType.passive,
      minLevel: 1,
      sourceId: sourceId,
    );
  }
}
