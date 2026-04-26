import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import '../models/character.dart';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import '../models/item.dart';
import '../models/journal_note.dart';
import '../models/spell.dart';
import 'spell_service.dart';
import 'storage_service.dart';

enum FC5ExportDiagnosticSeverity { info, warning }

class FC5ExportDiagnostic {
  final FC5ExportDiagnosticSeverity severity;
  final String code;
  final String message;
  final String? context;

  const FC5ExportDiagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.context,
  });
}

class FC5ExportResult {
  final String xml;
  final Uint8List bytes;
  final List<FC5ExportDiagnostic> diagnostics;

  const FC5ExportResult({
    required this.xml,
    required this.bytes,
    this.diagnostics = const [],
  });
}

class FC5ExportService {
  static Future<FC5ExportResult> exportCharacter(
    Character character, {
    bool includeMediaData = true,
  }) async {
    final diagnostics = <FC5ExportDiagnostic>[];
    final avatarImageData = includeMediaData
        ? await _readLocalMediaBase64(character.avatarPath, diagnostics)
        : null;
    final noteImageData = <String, String>{};
    if (includeMediaData) {
      for (final note in character.journalNotes) {
        final data = await _readLocalMediaBase64(note.imagePath, diagnostics);
        if (data != null) {
          noteImageData[note.id] = data;
        }
      }
    }

    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('pc', attributes: {'version': '5'}, nest: () {
      builder.element('character', nest: () {
        _text(builder, 'version', '37');
        _text(builder, 'uid', character.id);
        _text(builder, 'name', character.name);
        if (avatarImageData != null) {
          builder.element('imageData',
              attributes: {
                'encoding': 'base64',
                'source': 'avatar',
              },
              nest: avatarImageData);
        }
        _text(builder, 'abilities', _abilityList(character));
        _text(builder, 'hpMax', character.maxHp);
        _text(builder, 'hpCurrent', character.currentHp);
        _text(builder, 'hpTemp', character.temporaryHp);
        _writeRace(builder, character);
        _writeBackground(builder, character);
        for (final cls in _classesFor(character)) {
          _writeClass(builder, character, cls);
        }
        for (final item in character.inventory) {
          _writeItem(builder, item);
        }
        _text(builder, 'cp', character.copperPieces);
        _text(builder, 'sp', character.silverPieces);
        _text(builder, 'gp', character.goldPieces);
        _text(builder, 'pp', character.platinumPieces);
        for (final note in character.journalNotes) {
          _writeNote(builder, note, noteImageData[note.id]);
        }
        for (final quest in character.quests) {
          builder.element('note', nest: () {
            _text(builder, 'name', 'Quest: ${quest.title}');
            _text(
                builder,
                'text',
                [
                  quest.description,
                  ...quest.objectives.map(
                    (objective) => '${objective.isCompleted ? '[x]' : '[ ]'} '
                        '${objective.description}',
                  ),
                ].where((part) => part.trim().isNotEmpty).join('\n'));
          });
        }
        _writeOptionalText(builder, 'personality', character.personalityTraits);
        _writeOptionalText(builder, 'ideals', character.ideals);
        _writeOptionalText(builder, 'bonds', character.bonds);
        _writeOptionalText(builder, 'flaws', character.flaws);
        _writeOptionalText(builder, 'backstory', character.backstory);
        _writeOptionalText(builder, 'appearance', character.appearance);
      });
    });

    final xml = builder.buildDocument().toXmlString(pretty: true);
    return FC5ExportResult(
      xml: xml,
      bytes: Uint8List.fromList(utf8.encode(xml)),
      diagnostics: diagnostics,
    );
  }

  static void _writeRace(XmlBuilder builder, Character character) {
    builder.element('race', nest: () {
      _text(builder, 'name', character.race);
      _writeOptionalText(builder, 'age', character.age);
      _writeOptionalText(builder, 'height', character.height);
      _writeOptionalText(builder, 'weight', character.weight);
      _writeOptionalText(builder, 'eyes', character.eyes);
      _writeOptionalText(builder, 'skin', character.skin);
      _writeOptionalText(builder, 'hair', character.hair);
      _text(builder, 'speed', character.speed);
      for (final feature in _featuresFor(character, sourceKind: 'race')) {
        _writeFeature(builder, feature);
      }
    });
  }

  static void _writeBackground(XmlBuilder builder, Character character) {
    final background = character.background;
    if (background == null || background.trim().isEmpty) return;

    builder.element('background', nest: () {
      _text(builder, 'name', background);
      for (final skill in character.proficientSkills) {
        _text(builder, 'proficiency', _displayToken(skill));
      }
      for (final skill in character.expertSkills) {
        builder.element('proficiency', attributes: {'expert': '1'}, nest: () {
          builder.text(_displayToken(skill));
        });
      }
      for (final feature in _featuresFor(character, sourceKind: 'background')) {
        _writeFeature(builder, feature);
      }
    });
  }

  static void _writeClass(
    XmlBuilder builder,
    Character character,
    CharacterClass cls,
  ) {
    final className = cls.subclass == null || cls.subclass!.trim().isEmpty
        ? cls.name
        : '${cls.name}: ${cls.subclass}';

    builder.element('class', nest: () {
      _text(builder, 'name', className);
      _text(builder, 'level', cls.level);
      final hitDiceIndex = character.classes.indexOf(cls);
      _text(
        builder,
        'hdCurrent',
        character.hitDice.elementAtOrNull(hitDiceIndex) ?? cls.level,
      );
      _text(builder, 'slots', _slotList(character.maxSpellSlots));
      _text(builder, 'slotsCurrent', _slotList(character.spellSlots));
      for (final save in character.savingThrowProficiencies) {
        _text(builder, 'proficiency', _displayToken(save));
      }
      for (final skill in character.proficientSkills) {
        _text(builder, 'proficiency', _displayToken(skill));
      }
      for (final skill in character.expertSkills) {
        builder.element('proficiency', attributes: {'expert': '1'}, nest: () {
          builder.text(_displayToken(skill));
        });
      }
      for (final feature in _classFeaturesFor(character, cls)) {
        _writeFeature(builder, feature);
      }
      for (final spellId in character.knownSpells) {
        _writeSpellSelection(
          builder,
          spellId,
          prepared: character.preparedSpells.contains(spellId),
        );
      }
    });
  }

  static void _writeItem(XmlBuilder builder, Item item) {
    builder.element('item', nest: () {
      _text(builder, 'name', item.nameEn);
      _text(builder, 'name_ru', item.nameRu);
      _text(builder, 'type', _itemTypeCode(item));
      _text(builder, 'weight', item.weight);
      _text(builder, 'quantity', item.quantity);
      _text(builder, 'value', item.valueInGold);
      _text(builder, 'equipped', item.isEquipped ? 1 : 0);
      _text(builder, 'attuned', item.isAttuned ? 1 : 0);
      _text(builder, 'magic', item.isMagical ? 1 : 0);
      if (item.weaponProperties != null) {
        _text(builder, 'dmg1', item.weaponProperties!.damageDice);
        _text(
          builder,
          'dmgType',
          _damageTypeCode(item.weaponProperties!.damageType),
        );
        if (item.weaponProperties!.versatileDamageDice != null) {
          _text(builder, 'dmg2', item.weaponProperties!.versatileDamageDice);
        }
        if (item.weaponProperties!.weaponTags.isNotEmpty) {
          _text(
            builder,
            'property',
            item.weaponProperties!.weaponTags.join(', '),
          );
        }
      }
      if (item.armorProperties != null) {
        _text(builder, 'ac', item.armorProperties!.baseAC);
        if (item.armorProperties!.strengthRequirement != null) {
          _text(builder, 'strength', item.armorProperties!.strengthRequirement);
        }
        _text(
          builder,
          'stealth',
          item.armorProperties!.stealthDisadvantage ? 1 : 0,
        );
      }
      _writeOptionalText(builder, 'text', item.descriptionEn);
    });
  }

  static void _writeNote(
    XmlBuilder builder,
    JournalNote note,
    String? imageData,
  ) {
    builder.element('note', nest: () {
      _text(builder, 'name', note.title);
      _text(builder, 'text', note.content);
      if (imageData != null) {
        builder.element('imageData',
            attributes: {
              'encoding': 'base64',
              'source': 'note',
            },
            nest: imageData);
      }
    });
  }

  static void _writeFeature(XmlBuilder builder, CharacterFeature feature) {
    builder.element('feat', nest: () {
      _text(builder, 'name', feature.nameEn);
      _text(builder, 'text', feature.descriptionEn);
      _text(builder, 'expanded', 0);
    });
  }

  static void _writeSpellSelection(
    XmlBuilder builder,
    String spellId, {
    required bool prepared,
  }) {
    final spell = _findSpell(spellId);
    builder.element('spell', nest: () {
      _text(builder, 'name', spell?.nameEn ?? _displayToken(spellId));
      if (spell != null) {
        _text(builder, 'level', spell.level);
      }
      _text(builder, 'prepared', prepared ? 1 : 0);
    });
  }

  static List<CharacterClass> _classesFor(Character character) {
    if (character.classes.isNotEmpty) return character.classes;
    return [
      CharacterClass(
        id: _stableId(character.characterClass),
        name: character.characterClass,
        level: character.level,
        subclass: character.subclass,
        isPrimary: true,
      ),
    ];
  }

  static Iterable<CharacterFeature> _featuresFor(
    Character character, {
    required String sourceKind,
  }) {
    final prefix = 'fc5_${sourceKind}_';
    return character.features.where((feature) {
      if (feature.minLevel > character.level) return false;
      return feature.id.startsWith(prefix);
    });
  }

  static Iterable<CharacterFeature> _classFeaturesFor(
    Character character,
    CharacterClass cls,
  ) {
    final classKey = _normalize(cls.name);
    return character.features.where((feature) {
      if (feature.minLevel > cls.level) return false;
      final associatedClass = feature.associatedClass;
      if (associatedClass == null || associatedClass.trim().isEmpty) {
        return !feature.id.startsWith('fc5_race_') &&
            !feature.id.startsWith('fc5_background_');
      }
      return _normalize(associatedClass) == classKey;
    });
  }

  static String _abilityList(Character character) {
    final scores = character.abilityScores;
    return [
      scores.strength,
      scores.dexterity,
      scores.constitution,
      scores.intelligence,
      scores.wisdom,
      scores.charisma,
    ].join(',');
  }

  static String _slotList(List<int> slots) {
    final values = List<int>.filled(9, 0);
    for (var i = 0; i < values.length && i < slots.length; i++) {
      values[i] = slots[i];
    }
    return '0,${values.join(',')},';
  }

  static String _itemTypeCode(Item item) {
    switch (item.type) {
      case ItemType.weapon:
        return 'M';
      case ItemType.armor:
        return item.armorProperties?.armorType == ArmorType.shield ? 'S' : 'MA';
      case ItemType.consumable:
        return 'P';
      case ItemType.tool:
        return 'tool';
      case ItemType.treasure:
        return r'$';
      case ItemType.gear:
        return 'G';
    }
  }

  static String _damageTypeCode(DamageType type) {
    switch (type) {
      case DamageType.bludgeoning:
        return 'B';
      case DamageType.piercing:
        return 'P';
      case DamageType.slashing:
        return 'S';
      case DamageType.acid:
        return 'acid';
      case DamageType.cold:
        return 'cold';
      case DamageType.fire:
        return 'fire';
      case DamageType.force:
        return 'force';
      case DamageType.lightning:
        return 'lightning';
      case DamageType.necrotic:
        return 'necrotic';
      case DamageType.poison:
        return 'poison';
      case DamageType.psychic:
        return 'psychic';
      case DamageType.radiant:
        return 'radiant';
      case DamageType.thunder:
        return 'thunder';
    }
  }

  static Spell? _findSpell(String id) {
    final spells = <Spell>[
      ...SpellService.getAllSpells(),
    ];
    try {
      spells.addAll(StorageService.getAllSpells());
    } catch (_) {
      // Storage is optional for pure export tests and early app flows.
    }

    for (final spell in spells) {
      if (spell.id == id) return spell;
    }
    return null;
  }

  static Future<String?> _readLocalMediaBase64(
    String? path,
    List<FC5ExportDiagnostic> diagnostics,
  ) async {
    final value = path?.trim();
    if (value == null || value.isEmpty || _isRemoteMedia(value)) {
      return null;
    }
    try {
      final file = File(value);
      if (!await file.exists()) {
        diagnostics.add(
          FC5ExportDiagnostic(
            severity: FC5ExportDiagnosticSeverity.warning,
            code: 'media_missing',
            message: 'Media file was not included because it was not found.',
            context: _baseName(value),
          ),
        );
        return null;
      }
      return base64Encode(await file.readAsBytes());
    } catch (error) {
      diagnostics.add(
        FC5ExportDiagnostic(
          severity: FC5ExportDiagnosticSeverity.warning,
          code: 'media_read_failed',
          message: 'Media file could not be included.',
          context: '$error',
        ),
      );
      return null;
    }
  }

  static bool _isRemoteMedia(String value) {
    final normalized = value.toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('data:');
  }

  static String _baseName(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? path : parts.last;
  }

  static String _displayToken(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '');
  }

  static String _stableId(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static void _text(XmlBuilder builder, String name, Object? value) {
    if (value == null) return;
    builder.element(name, nest: value.toString());
  }

  static void _writeOptionalText(
    XmlBuilder builder,
    String name,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) return;
    _text(builder, name, value);
  }
}
