import 'dart:math' as math;

import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../models/ability_scores.dart';
import '../models/background_data.dart';
import '../models/character.dart';
import '../models/character_class.dart';
import '../models/character_feature.dart';
import '../models/class_data.dart';
import '../models/item.dart';
import '../models/journal_note.dart';
import '../models/race_data.dart';
import '../models/spell.dart';
import 'feature_hydration_service.dart';
import 'spell_service.dart';

enum FC5DiagnosticSeverity { info, warning, error }

class FC5Diagnostic {
  final FC5DiagnosticSeverity severity;
  final String code;
  final String message;
  final String? context;

  const FC5Diagnostic({
    required this.severity,
    required this.code,
    required this.message,
    this.context,
  });
}

class FC5ParseDiagnostics {
  final List<FC5Diagnostic> entries;

  FC5ParseDiagnostics([List<FC5Diagnostic>? entries]) : entries = entries ?? [];

  bool get hasWarnings =>
      entries.any((entry) => entry.severity == FC5DiagnosticSeverity.warning);

  bool get hasErrors =>
      entries.any((entry) => entry.severity == FC5DiagnosticSeverity.error);

  int get warningCount => entries
      .where((entry) => entry.severity == FC5DiagnosticSeverity.warning)
      .length;

  int get errorCount => entries
      .where((entry) => entry.severity == FC5DiagnosticSeverity.error)
      .length;

  bool get isEmpty => entries.isEmpty;

  void add(
    FC5DiagnosticSeverity severity,
    String code,
    String message, {
    String? context,
  }) {
    entries.add(
      FC5Diagnostic(
        severity: severity,
        code: code,
        message: message,
        context: context,
      ),
    );
  }

  void info(String code, String message, {String? context}) {
    add(FC5DiagnosticSeverity.info, code, message, context: context);
  }

  void warning(String code, String message, {String? context}) {
    add(FC5DiagnosticSeverity.warning, code, message, context: context);
  }

  void error(String code, String message, {String? context}) {
    add(FC5DiagnosticSeverity.error, code, message, context: context);
  }

  void merge(FC5ParseDiagnostics other) {
    entries.addAll(other.entries);
  }

  FC5ParseDiagnostics copy() => FC5ParseDiagnostics(List.of(entries));
}

/// Result object containing all parsed entities from an FC5 XML file.
class FC5ParseResult {
  final List<Item> items;
  final List<Spell> spells;
  final List<RaceData> races;
  final List<ClassData> classes;
  final List<BackgroundData> backgrounds;
  final List<CharacterFeature> feats;
  final FC5ParseDiagnostics diagnostics;

  FC5ParseResult({
    this.items = const [],
    this.spells = const [],
    this.races = const [],
    this.classes = const [],
    this.backgrounds = const [],
    this.feats = const [],
    FC5ParseDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? FC5ParseDiagnostics();

  bool get isEmpty =>
      items.isEmpty &&
      spells.isEmpty &&
      races.isEmpty &&
      classes.isEmpty &&
      backgrounds.isEmpty &&
      feats.isEmpty;

  int get supportedEntityCount =>
      items.length +
      spells.length +
      races.length +
      classes.length +
      backgrounds.length +
      feats.length;
}

class FC5CharacterImportCandidate {
  final Character character;
  final int index;
  final String sourceNode;
  final FC5ParseDiagnostics diagnostics;
  final List<FC5EmbeddedMedia> media;

  FC5CharacterImportCandidate({
    required this.character,
    required this.index,
    required this.sourceNode,
    required this.diagnostics,
    this.media = const [],
  });
}

class FC5EmbeddedMedia {
  final String kind;
  final String rawData;
  final String? encoding;
  final String? source;
  final String? referenceId;
  final String? mimeType;
  final String? format;
  final int? noteIndex;
  final int? itemIndex;
  final String context;

  const FC5EmbeddedMedia({
    required this.kind,
    required this.rawData,
    this.encoding,
    this.source,
    this.referenceId,
    this.mimeType,
    this.format,
    this.noteIndex,
    this.itemIndex,
    required this.context,
  });
}

class FC5CharacterParseResult {
  final List<FC5CharacterImportCandidate> candidates;
  final FC5ParseDiagnostics diagnostics;

  FC5CharacterParseResult({
    required this.candidates,
    FC5ParseDiagnostics? diagnostics,
  }) : diagnostics = diagnostics ?? FC5ParseDiagnostics();

  bool get isEmpty => candidates.isEmpty;

  int get warningCount => diagnostics.warningCount;
}

class FC5Parser {
  static const Uuid _uuid = Uuid();
  static const String _separator = '---RU---';
  static const String _defaultSourceId = 'fc5_import';

  static const Map<String, String> _classNameMap = {
    'паладин': 'Paladin',
    'воин': 'Fighter',
    'варвар': 'Barbarian',
    'монах': 'Monk',
    'плут': 'Rogue',
    'разбойник': 'Rogue',
    'следопыт': 'Ranger',
    'рейнджер': 'Ranger',
    'друид': 'Druid',
    'жрец': 'Cleric',
    'клирик': 'Cleric',
    'волшебник': 'Wizard',
    'маг': 'Wizard',
    'чародей': 'Sorcerer',
    'колдун': 'Warlock',
    'бард': 'Bard',
    'изобретатель': 'Artificer',
  };

  static const Map<String, String> _raceNameMap = {
    'человек': 'Human',
    'эльф': 'Elf',
    'дварф': 'Dwarf',
    'дварфы': 'Dwarf',
    'гном': 'Gnome',
    'полурослик': 'Halfling',
    'халфлинг': 'Halfling',
    'драконорожденный': 'Dragonborn',
    'драконорождённый': 'Dragonborn',
    'тифлинг': 'Tiefling',
    'полуорк': 'Half-Orc',
    'полуэльф': 'Half-Elf',
  };

  static const Map<String, String> _backgroundNameMap = {
    'прислужник': 'Acolyte',
    'аколит': 'Acolyte',
    'солдат': 'Soldier',
    'народный герой': 'Folk Hero',
  };

  static const Map<String, String> _subclassNameMap = {
    'клятва покорения': 'Oath of Conquest',
    'клятва преданности': 'Oath of Devotion',
    'клятва древних': 'Oath of the Ancients',
    'клятва мести': 'Oath of Vengeance',
    'клятва короны': 'Oath of the Crown',
    'клятва искупления': 'Oath of Redemption',
    'клятва славы': 'Oath of Glory',
    'клятва стражей': 'Oath of the Watchers',
    'домен жизни': 'Life Domain',
    'чемпион': 'Champion',
    'эвокация': 'Evocation',
  };

  static const Map<String, String> _abilityCodeMap = {
    '0': 'strength',
    '1': 'dexterity',
    '2': 'constitution',
    '3': 'intelligence',
    '4': 'wisdom',
    '5': 'charisma',
    'str': 'strength',
    'strength': 'strength',
    'сила': 'strength',
    'сил': 'strength',
    'dex': 'dexterity',
    'dexterity': 'dexterity',
    'ловкость': 'dexterity',
    'лов': 'dexterity',
    'con': 'constitution',
    'constitution': 'constitution',
    'телосложение': 'constitution',
    'тел': 'constitution',
    'int': 'intelligence',
    'intelligence': 'intelligence',
    'интеллект': 'intelligence',
    'инт': 'intelligence',
    'wis': 'wisdom',
    'wisdom': 'wisdom',
    'мудрость': 'wisdom',
    'мдр': 'wisdom',
    'cha': 'charisma',
    'charisma': 'charisma',
    'харизма': 'charisma',
    'хар': 'charisma',
  };

  static const Map<String, String> _skillMap = {
    '100': 'acrobatics',
    '101': 'animal_handling',
    '102': 'arcana',
    '103': 'athletics',
    '104': 'deception',
    '105': 'history',
    '106': 'insight',
    '107': 'intimidation',
    '108': 'investigation',
    '109': 'medicine',
    '110': 'nature',
    '111': 'perception',
    '112': 'performance',
    '113': 'persuasion',
    '114': 'religion',
    '115': 'sleight_of_hand',
    '116': 'stealth',
    '117': 'survival',
    'acrobatics': 'acrobatics',
    'акробатика': 'acrobatics',
    'animal handling': 'animal_handling',
    'уход за животными': 'animal_handling',
    'arcana': 'arcana',
    'магия': 'arcana',
    'athletics': 'athletics',
    'атлетика': 'athletics',
    'deception': 'deception',
    'обман': 'deception',
    'history': 'history',
    'история': 'history',
    'insight': 'insight',
    'проницательность': 'insight',
    'intimidation': 'intimidation',
    'запугивание': 'intimidation',
    'investigation': 'investigation',
    'анализ': 'investigation',
    'расследование': 'investigation',
    'medicine': 'medicine',
    'медицина': 'medicine',
    'nature': 'nature',
    'природа': 'nature',
    'perception': 'perception',
    'восприятие': 'perception',
    'performance': 'performance',
    'выступление': 'performance',
    'persuasion': 'persuasion',
    'убеждение': 'persuasion',
    'religion': 'religion',
    'религия': 'religion',
    'sleight of hand': 'sleight_of_hand',
    'sleight_of_hand': 'sleight_of_hand',
    'ловкость рук': 'sleight_of_hand',
    'stealth': 'stealth',
    'скрытность': 'stealth',
    'survival': 'survival',
    'выживание': 'survival',
  };

  static const Map<String, String> _schoolMap = {
    '1': 'Abjuration',
    'a': 'Abjuration',
    'abjuration': 'Abjuration',
    'ограждение': 'Abjuration',
    '2': 'Conjuration',
    'c': 'Conjuration',
    'conjuration': 'Conjuration',
    'вызов': 'Conjuration',
    '3': 'Divination',
    'd': 'Divination',
    'divination': 'Divination',
    'прорицание': 'Divination',
    '4': 'Enchantment',
    'en': 'Enchantment',
    'enchantment': 'Enchantment',
    'очарование': 'Enchantment',
    '5': 'Evocation',
    'ev': 'Evocation',
    'evocation': 'Evocation',
    'эвокация': 'Evocation',
    '6': 'Illusion',
    'i': 'Illusion',
    'illusion': 'Illusion',
    'иллюзия': 'Illusion',
    '7': 'Necromancy',
    'n': 'Necromancy',
    'necromancy': 'Necromancy',
    'некромантия': 'Necromancy',
    '8': 'Transmutation',
    't': 'Transmutation',
    'transmutation': 'Transmutation',
    'преобразование': 'Transmutation',
  };

  static const Map<String, DamageType> _damageTypeMap = {
    '1': DamageType.bludgeoning,
    'b': DamageType.bludgeoning,
    'bludgeoning': DamageType.bludgeoning,
    'дробящий': DamageType.bludgeoning,
    '2': DamageType.piercing,
    'p': DamageType.piercing,
    'piercing': DamageType.piercing,
    'колющий': DamageType.piercing,
    '3': DamageType.slashing,
    's': DamageType.slashing,
    'slashing': DamageType.slashing,
    'рубящий': DamageType.slashing,
    'a': DamageType.acid,
    'acid': DamageType.acid,
    'кислота': DamageType.acid,
    'c': DamageType.cold,
    'cold': DamageType.cold,
    'холод': DamageType.cold,
    'f': DamageType.fire,
    'fire': DamageType.fire,
    'огонь': DamageType.fire,
    'fc': DamageType.force,
    'force': DamageType.force,
    'силовой': DamageType.force,
    'l': DamageType.lightning,
    'lightning': DamageType.lightning,
    'электричество': DamageType.lightning,
    'n': DamageType.necrotic,
    'necrotic': DamageType.necrotic,
    'некротический': DamageType.necrotic,
    'ps': DamageType.poison,
    'poison': DamageType.poison,
    'яд': DamageType.poison,
    'psychic': DamageType.psychic,
    'психический': DamageType.psychic,
    'r': DamageType.radiant,
    'radiant': DamageType.radiant,
    'излучение': DamageType.radiant,
    't': DamageType.thunder,
    'thunder': DamageType.thunder,
    'звук': DamageType.thunder,
  };

  /// Main entry point to parse FC5 XML content for compendium data.
  static Future<FC5ParseResult> parseCompendium(
    String xmlContent, {
    String? sourceId,
  }) async {
    final diagnostics = FC5ParseDiagnostics();
    final sid = sourceId ?? _defaultSourceId;

    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;

      if (root.name.local == 'collection') {
        final docs = root.findAllElements('doc').length;
        diagnostics.error(
          'collection_unsupported',
          docs == 0
              ? 'Collection XML is not a compiled FC5 compendium.'
              : 'Collection XML references $docs external document(s) and must be compiled before import.',
          context: 'collection',
        );
        return FC5ParseResult(diagnostics: diagnostics);
      }

      Iterable<XmlElement> nodes;
      if (root.name.local == 'compendium') {
        nodes = root.childElements;
      } else {
        diagnostics.warning(
          'unexpected_root',
          'Expected <compendium>, got <${root.name.local}>. Trying to parse the root element as one entity.',
          context: root.name.local,
        );
        nodes = [root];
      }

      final items = <Item>[];
      final spells = <Spell>[];
      final races = <RaceData>[];
      final classes = <ClassData>[];
      final backgrounds = <BackgroundData>[];
      final feats = <CharacterFeature>[];

      for (final node in nodes) {
        final nodeName = node.name.local;
        try {
          switch (nodeName) {
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
              classes.add(_parseClass(node, sid, diagnostics));
              break;
            case 'background':
              backgrounds.add(_parseBackground(node, sid));
              break;
            case 'feat':
              feats.add(_parseFeat(node, sid));
              break;
            case 'monster':
            case 'vehicle':
              diagnostics.warning(
                'unsupported_node',
                'Unsupported FC5 node <$nodeName> was skipped.',
                context: nodeName,
              );
              break;
            case 'imageData':
              diagnostics.warning(
                'skipped_image_data',
                'Embedded imageData was skipped.',
                context: nodeName,
              );
              break;
            default:
              if (_hasNonWhitespaceText(node) ||
                  node.childElements.isNotEmpty) {
                diagnostics.warning(
                  'unknown_node',
                  'Unknown FC5 node <$nodeName> was skipped.',
                  context: nodeName,
                );
              }
              break;
          }
        } catch (error) {
          diagnostics.warning(
            'entity_parse_failed',
            'Failed to parse <$nodeName>: $error',
            context: _getTag(node, 'name').ifEmpty(nodeName),
          );
        }
      }

      return FC5ParseResult(
        items: items,
        spells: spells,
        races: races,
        classes: classes,
        backgrounds: backgrounds,
        feats: feats,
        diagnostics: diagnostics,
      );
    } catch (error) {
      diagnostics.error(
        'xml_parse_failed',
        'Failed to parse FC5 XML: $error',
      );
      return FC5ParseResult(diagnostics: diagnostics);
    }
  }

  /// Parses all supported characters from FC5 player or GM export XML.
  static FC5CharacterParseResult parseCharacters(String xmlContent) {
    final diagnostics = FC5ParseDiagnostics();

    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;
      final characterNodes = _findCharacterNodes(root, diagnostics);
      final imageDataDefinitions = _extractImageDataDefinitions(root);

      if (characterNodes.isEmpty) {
        diagnostics.error(
          'character_not_found',
          'No <character> or GM <npc> element found in XML.',
        );
        return FC5CharacterParseResult(
          candidates: const [],
          diagnostics: diagnostics,
        );
      }

      if (characterNodes.length > 1) {
        diagnostics.info(
          'multiple_characters',
          'Found ${characterNodes.length} characters in this FC5 file.',
          context: root.name.local,
        );
      }

      final candidates = <FC5CharacterImportCandidate>[];
      for (var i = 0; i < characterNodes.length; i++) {
        final node = characterNodes[i];
        final localDiagnostics = FC5ParseDiagnostics();
        try {
          final character = _parseCharacterNode(
            node,
            localDiagnostics,
            index: i,
          );
          final media = _extractCharacterMedia(
            node,
            localDiagnostics,
            imageDataDefinitions,
          );
          candidates.add(
            FC5CharacterImportCandidate(
              character: character,
              index: i,
              sourceNode: node.name.local,
              diagnostics: localDiagnostics,
              media: media,
            ),
          );
        } catch (error) {
          localDiagnostics.error(
            'character_parse_failed',
            'Failed to parse character #${i + 1}: $error',
            context: _getTag(node, 'name').ifEmpty(node.name.local),
          );
        }
        diagnostics.merge(localDiagnostics);
      }

      return FC5CharacterParseResult(
        candidates: candidates,
        diagnostics: diagnostics,
      );
    } catch (error) {
      diagnostics.error(
        'xml_parse_failed',
        'Failed to parse FC5 character XML: $error',
      );
      return FC5CharacterParseResult(
        candidates: const [],
        diagnostics: diagnostics,
      );
    }
  }

  /// Legacy single-character entry point kept for existing callers.
  static Character parseCharacter(String xmlContent) {
    final result = parseCharacters(xmlContent);
    if (result.candidates.isEmpty) {
      final diagnostic = result.diagnostics.entries.firstOrNull;
      throw FormatException(
        diagnostic?.message ?? 'No <character> element found in XML.',
      );
    }
    return result.candidates.first.character;
  }

  static List<XmlElement> _findCharacterNodes(
    XmlElement root,
    FC5ParseDiagnostics diagnostics,
  ) {
    switch (root.name.local) {
      case 'pc':
        return root.findElements('character').toList();
      case 'characters':
        final npcs = root.findElements('npc').toList();
        final characters = root.findElements('character').toList();
        return [...npcs, ...characters];
      case 'character':
      case 'npc':
        return [root];
      default:
        diagnostics.warning(
          'unexpected_character_root',
          'Expected <pc>, <character>, or <characters>, got <${root.name.local}>.',
          context: root.name.local,
        );
        return root.findAllElements('character').toList();
    }
  }

  static List<FC5EmbeddedMedia> _extractCharacterMedia(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
    Map<String, _FC5ImageDataDefinition> imageDataDefinitions,
  ) {
    final media = <FC5EmbeddedMedia>[];
    final supportedNodes = <XmlElement>{};
    final noteNodes = node.findElements('note').toList();
    final itemNodes = node.findElements('item').toList();

    for (var noteIndex = 0; noteIndex < noteNodes.length; noteIndex++) {
      final noteNode = noteNodes[noteIndex];
      final title = _getTag(noteNode, 'name').ifEmpty('Imported note');
      var noteImageIndex = 0;
      for (final imageNode in noteNode.findAllElements('imageData')) {
        supportedNodes.add(imageNode);
        media.add(
          _embeddedMediaFromNode(
            imageNode,
            kind: 'note',
            noteIndex: noteIndex,
            imageDataDefinitions: imageDataDefinitions,
            context: noteImageIndex == 0
                ? 'note "$title"'
                : 'note "$title" image #$noteImageIndex',
          ),
        );
        noteImageIndex++;
      }
    }

    var parsedItemIndex = 0;
    for (final itemNode in itemNodes) {
      final itemName = _getTag(itemNode, 'name').ifEmpty('Imported item');
      if (_isCurrencyItem(itemNode)) continue;
      var itemImageIndex = 0;
      for (final imageNode in itemNode.findAllElements('imageData')) {
        supportedNodes.add(imageNode);
        media.add(
          _embeddedMediaFromNode(
            imageNode,
            kind: 'item',
            itemIndex: parsedItemIndex,
            imageDataDefinitions: imageDataDefinitions,
            context: itemImageIndex == 0
                ? 'item "$itemName"'
                : 'item "$itemName" image #$itemImageIndex',
          ),
        );
        itemImageIndex++;
      }
      parsedItemIndex++;
    }

    var avatarIndex = 0;
    for (final imageNode in node.findAllElements('imageData')) {
      if (supportedNodes.contains(imageNode)) continue;
      if (!_isCharacterAvatarImageData(imageNode, node)) continue;

      supportedNodes.add(imageNode);
      media.add(
        _embeddedMediaFromNode(
          imageNode,
          kind: 'avatar',
          imageDataDefinitions: imageDataDefinitions,
          context: avatarIndex == 0 ? 'avatar' : 'avatar#$avatarIndex',
        ),
      );
      avatarIndex++;
    }

    for (final imageNode in node.findAllElements('imageData')) {
      if (supportedNodes.contains(imageNode)) continue;
      diagnostics.warning(
        'unsupported_image_data_location',
        'Embedded imageData outside character avatar or notes was skipped.',
        context: _getTag(node, 'name').ifEmpty(node.name.local),
      );
    }

    return media;
  }

  static Map<String, _FC5ImageDataDefinition> _extractImageDataDefinitions(
    XmlElement root,
  ) {
    final definitions = <String, _FC5ImageDataDefinition>{};
    for (final imageNode in root.findAllElements('imageData')) {
      final uid = _imageDataUid(imageNode);
      if (uid.isEmpty) continue;

      final encodedNode = imageNode.findElements('encoded').firstOrNull;
      final encoded = encodedNode?.innerText.trim() ??
          imageNode.getAttribute('encoded')?.trim() ??
          '';
      if (encoded.isEmpty) continue;

      definitions[uid] = _FC5ImageDataDefinition(
        encoded: encoded,
        encoding: imageNode.getAttribute('encoding') ??
            encodedNode?.getAttribute('encoding'),
        mimeType: imageNode.getAttribute('mime') ??
            imageNode.getAttribute('mimeType') ??
            encodedNode?.getAttribute('mime') ??
            encodedNode?.getAttribute('mimeType'),
        format: imageNode.getAttribute('format') ??
            imageNode.getAttribute('extension') ??
            encodedNode?.getAttribute('format') ??
            encodedNode?.getAttribute('extension'),
      );
    }
    return definitions;
  }

  static String _imageDataUid(XmlElement node) {
    return (node.getAttribute('uid') ?? _getTag(node, 'uid')).trim();
  }

  static bool _isCharacterAvatarImageData(
    XmlElement imageNode,
    XmlElement characterNode,
  ) {
    final source = _normalizeLoose(
      imageNode.getAttribute('source') ?? imageNode.getAttribute('kind') ?? '',
    );
    if (source == 'avatar' ||
        source == 'portrait' ||
        source == 'token' ||
        source == 'character_avatar' ||
        source == 'character portrait') {
      return true;
    }

    final directParent = imageNode.parentElement;
    if (directParent == characterNode) return true;

    const directAvatarContainers = {
      'avatar',
      'portrait',
      'token',
      'picture',
      'image',
    };
    if (directParent?.parentElement == characterNode &&
        directAvatarContainers.contains(directParent!.name.local)) {
      return true;
    }

    final avatarContainers = {'avatar', 'portrait', 'token', 'picture'};
    final unsupportedOwners = {
      'item',
      'spell',
      'race',
      'class',
      'background',
      'feat',
      'feature',
      'trait',
      'note',
    };

    XmlElement? current = directParent;
    while (current != null && current != characterNode) {
      final name = current.name.local;
      if (unsupportedOwners.contains(name)) return false;
      if (avatarContainers.contains(name)) return true;
      current = current.parentElement;
    }

    return false;
  }

  static FC5EmbeddedMedia _embeddedMediaFromNode(
    XmlElement node, {
    required String kind,
    required String context,
    required Map<String, _FC5ImageDataDefinition> imageDataDefinitions,
    int? noteIndex,
    int? itemIndex,
  }) {
    final uid = _imageDataUid(node);
    final definition = uid.isEmpty ? null : imageDataDefinitions[uid];
    final encoded = node.findElements('encoded').firstOrNull;
    final directEncoded = encoded?.innerText.trim() ??
        node.getAttribute('encoded')?.trim() ??
        _directImageDataText(node);

    return FC5EmbeddedMedia(
      kind: kind,
      rawData: definition?.encoded ?? directEncoded,
      encoding: node.getAttribute('encoding') ??
          encoded?.getAttribute('encoding') ??
          definition?.encoding,
      source: node.getAttribute('source'),
      referenceId: uid.isEmpty ? null : uid,
      mimeType: node.getAttribute('mime') ??
          node.getAttribute('mimeType') ??
          encoded?.getAttribute('mime') ??
          encoded?.getAttribute('mimeType') ??
          definition?.mimeType,
      format: node.getAttribute('format') ??
          node.getAttribute('extension') ??
          encoded?.getAttribute('format') ??
          encoded?.getAttribute('extension') ??
          definition?.format,
      noteIndex: noteIndex,
      itemIndex: itemIndex,
      context: context,
    );
  }

  static String _directImageDataText(XmlElement node) {
    if (node.childElements.isEmpty) return node.innerText.trim();
    return '';
  }

  static Character _parseCharacterNode(
    XmlElement node,
    FC5ParseDiagnostics diagnostics, {
    required int index,
  }) {
    final name = _getTag(node, 'name');
    if (name.isEmpty) {
      throw const FormatException('FC5 character is missing required <name>.');
    }

    final abilities = _parseCharacterAbilities(node, diagnostics);
    final hp = _parseHitPoints(node, diagnostics);
    final raceInfo = _parseCharacterRace(node, diagnostics);
    final backgroundInfo = _parseCharacterBackground(node, diagnostics);
    final classesInfo = _parseCharacterClasses(node, diagnostics);
    final inventoryInfo = _parseCharacterInventory(node, diagnostics);
    final spellInfo = _parseCharacterSpells(node, diagnostics);
    final notes = _parseCharacterNotes(node, diagnostics);

    final slots = _parseCharacterSpellSlots(
      node,
      classesInfo.classNodes,
      'slots',
      diagnostics,
    );
    final currentSlots = _parseCharacterSpellSlots(
      node,
      classesInfo.classNodes,
      'slotsCurrent',
      diagnostics,
    );

    final totalLevel = math.max(
      1,
      classesInfo.classes.fold<int>(0, (sum, item) => sum + item.level),
    );
    final primaryClass = classesInfo.classes.isNotEmpty
        ? classesInfo.classes.first
        : CharacterClass(
            id: 'unknown',
            name: 'Unknown',
            level: totalLevel,
            isPrimary: true,
          );

    final features = <CharacterFeature>[];
    _addFeatures(features, raceInfo.features);
    _addFeatures(features, backgroundInfo.features);
    _addFeatures(features, classesInfo.features);

    final character = Character(
      id: _uuid.v4(),
      name: name,
      race: raceInfo.name,
      characterClass: primaryClass.name,
      subclass: primaryClass.subclass,
      level: totalLevel,
      maxHp: hp.max,
      currentHp: hp.current,
      temporaryHp: hp.temporary,
      abilityScores: abilities,
      background: backgroundInfo.name,
      spellSlots: currentSlots,
      maxSpellSlots: slots,
      knownSpells: spellInfo.knownSpells,
      preparedSpells: spellInfo.preparedSpells,
      maxPreparedSpells: spellInfo.maxPreparedSpells,
      armorClass: 10 + abilities.dexterityModifier,
      speed: raceInfo.speed,
      initiative: abilities.dexterityModifier,
      proficientSkills: classesInfo.skills,
      savingThrowProficiencies: classesInfo.savingThrows,
      appearance: raceInfo.appearance,
      features: features,
      inventory: inventoryInfo.items,
      age: raceInfo.age,
      height: raceInfo.height,
      weight: raceInfo.weight,
      eyes: raceInfo.eyes,
      hair: raceInfo.hair,
      skin: raceInfo.skin,
      copperPieces: inventoryInfo.copperPieces,
      silverPieces: inventoryInfo.silverPieces,
      goldPieces: inventoryInfo.goldPieces,
      platinumPieces: inventoryInfo.platinumPieces,
      journalNotes: notes,
      classes: classesInfo.classes,
      expertSkills: classesInfo.expertSkills,
      hitDice: classesInfo.hitDice.isNotEmpty
          ? classesInfo.hitDice
          : List<int>.filled(classesInfo.classes.length.clamp(1, 20), 1),
      maxHitDice: totalLevel,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    character.recalculateAC();
    return character;
  }

  static AbilityScores _parseCharacterAbilities(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final abilitiesText = _getTag(node, 'abilities');
    if (abilitiesText.isNotEmpty) {
      final values = _parseIntList(abilitiesText);
      if (values.length < 6) {
        diagnostics.warning(
          'abilities_incomplete',
          'Expected 6 ability scores, found ${values.length}. Missing scores default to 10.',
          context: _getTag(node, 'name'),
        );
      }
      return AbilityScores(
        strength: values.elementAtOrNull(0) ?? 10,
        dexterity: values.elementAtOrNull(1) ?? 10,
        constitution: values.elementAtOrNull(2) ?? 10,
        intelligence: values.elementAtOrNull(3) ?? 10,
        wisdom: values.elementAtOrNull(4) ?? 10,
        charisma: values.elementAtOrNull(5) ?? 10,
      );
    }

    final directScores = [
      _parseInt(_getTag(node, 'str')),
      _parseInt(_getTag(node, 'dex')),
      _parseInt(_getTag(node, 'con')),
      _parseInt(_getTag(node, 'int')),
      _parseInt(_getTag(node, 'wis')),
      _parseInt(_getTag(node, 'cha')),
    ];

    if (directScores.any((score) => score != null)) {
      return AbilityScores(
        strength: directScores[0] ?? 10,
        dexterity: directScores[1] ?? 10,
        constitution: directScores[2] ?? 10,
        intelligence: directScores[3] ?? 10,
        wisdom: directScores[4] ?? 10,
        charisma: directScores[5] ?? 10,
      );
    }

    diagnostics.warning(
      'abilities_missing',
      'Missing ability scores. Defaulting all abilities to 10.',
      context: _getTag(node, 'name'),
    );
    return AbilityScores(
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    );
  }

  static _ParsedHitPoints _parseHitPoints(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final max = _parseInt(_getAnyTag(node, ['hpMax', 'maxHp', 'hp']));
    if (max == null || max <= 0) {
      throw const FormatException(
        'FC5 character is missing required positive <hpMax>.',
      );
    }

    final current =
        _parseInt(_getAnyTag(node, ['hpCurrent', 'currentHp'])) ?? max;
    final temporary = _parseInt(
          _getAnyTag(node, ['hpTemp', 'tempHp', 'temporaryHp', 'hpTemporary']),
        ) ??
        0;

    if (current < 0) {
      diagnostics.warning(
        'hp_current_invalid',
        'Current HP was negative and has been clamped to 0.',
        context: _getTag(node, 'name'),
      );
    }

    return _ParsedHitPoints(
      max: max,
      current: current.clamp(0, max),
      temporary: math.max(0, temporary),
    );
  }

  static _ParsedRaceInfo _parseCharacterRace(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final raceNode = node.findElements('race').firstOrNull;
    if (raceNode == null) {
      diagnostics.warning(
        'race_missing',
        'Missing race. Defaulting to Unknown.',
        context: _getTag(node, 'name'),
      );
      return const _ParsedRaceInfo(name: 'Unknown');
    }

    final rawName = _getTag(raceNode, 'name').ifEmpty('Unknown');
    final age = _getTag(raceNode, 'age').emptyToNull;
    final height = _getTag(raceNode, 'height').emptyToNull;
    final weight = _getTag(raceNode, 'weight').emptyToNull;
    final eyes = _getTag(raceNode, 'eyes').emptyToNull;
    final skin = _getTag(raceNode, 'skin').emptyToNull;
    final hair = _getTag(raceNode, 'hair').emptyToNull;
    final speed = _parseInt(_getTag(raceNode, 'speed')) ?? 30;

    final appearanceLines = <String>[
      if (age != null) 'Age: $age',
      if (height != null) 'Height: $height',
      if (weight != null) 'Weight: $weight',
      if (eyes != null) 'Eyes: $eyes',
      if (skin != null) 'Skin: $skin',
      if (hair != null) 'Hair: $hair',
    ];

    return _ParsedRaceInfo(
      name: _canonicalRaceName(rawName),
      speed: speed,
      appearance: appearanceLines.isEmpty ? null : appearanceLines.join('\n'),
      age: age,
      height: height,
      weight: weight,
      eyes: eyes,
      skin: skin,
      hair: hair,
      features: _parseCharacterFeaturesFromContainer(
        raceNode,
        diagnostics,
        sourceKind: 'race',
      ),
    );
  }

  static _ParsedBackgroundInfo _parseCharacterBackground(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final backgroundNode = node.findElements('background').firstOrNull;
    if (backgroundNode == null) {
      return const _ParsedBackgroundInfo();
    }

    final rawName = _getTag(backgroundNode, 'name').emptyToNull;
    final proficiencies = _parseCharacterProficiencyElements(
      backgroundNode.findElements('proficiency'),
      diagnostics,
      context: 'background',
      classContext: false,
    );

    return _ParsedBackgroundInfo(
      name: rawName != null ? _canonicalBackgroundName(rawName) : null,
      skills: proficiencies.skillValuesForCharacter,
      expertSkills: proficiencies.expertSkills,
      features: _parseCharacterFeaturesFromContainer(
        backgroundNode,
        diagnostics,
        sourceKind: 'background',
      ),
    );
  }

  static _ParsedCharacterClasses _parseCharacterClasses(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final classNodes = node.findElements('class').toList();
    if (classNodes.isEmpty) {
      diagnostics.warning(
        'class_missing',
        'Missing class. Defaulting to Unknown level 1.',
        context: _getTag(node, 'name'),
      );
      return _ParsedCharacterClasses(
        classes: [
          CharacterClass(
            id: 'unknown',
            name: 'Unknown',
            level: 1,
            isPrimary: true,
          )
        ],
        classNodes: const [],
        skills: const [],
        savingThrows: const [],
        expertSkills: const [],
        hitDice: const [1],
        features: const [],
      );
    }

    final classes = <CharacterClass>[];
    final skills = <String>[];
    final saves = <String>[];
    final expertSkills = <String>[];
    final hitDice = <int>[];
    final features = <CharacterFeature>[];

    for (var i = 0; i < classNodes.length; i++) {
      final classNode = classNodes[i];
      final rawClassText = _getTag(classNode, 'name').ifEmpty('Unknown');
      final classParts = _splitClassName(rawClassText);
      final className = _canonicalClassName(classParts.base);
      final subclass = classParts.subclass == null
          ? null
          : _canonicalSubclassName(classParts.subclass!);
      final level = math.max(1, _parseInt(_getTag(classNode, 'level')) ?? 1);

      classes.add(
        CharacterClass(
          id: _stableId(className),
          name: className,
          level: level,
          subclass: subclass,
          isPrimary: i == 0,
        ),
      );

      hitDice.add(_parseInt(_getTag(classNode, 'hdCurrent')) ?? level);

      final proficiencies = _parseCharacterProficiencyElements(
        classNode.findElements('proficiency'),
        diagnostics,
        context: className,
        classContext: true,
      );

      _addAllUnique(skills, proficiencies.skillValuesForCharacter);
      _addAllUnique(saves, proficiencies.savingThrows);
      _addAllUnique(expertSkills, proficiencies.expertSkills);

      _addFeatures(
        features,
        _parseCharacterFeaturesFromContainer(
          classNode,
          diagnostics,
          sourceKind: 'class',
          associatedClass: className,
          associatedSubclass: subclass,
          maxLevel: level,
        ),
      );
    }

    final background = _parseCharacterBackground(node, diagnostics);
    _addAllUnique(skills, background.skills);
    _addAllUnique(expertSkills, background.expertSkills);

    final raceNode = node.findElements('race').firstOrNull;
    if (raceNode != null) {
      final proficiencies = _parseCharacterProficiencyElements(
        raceNode.findElements('proficiency'),
        diagnostics,
        context: 'race',
        classContext: false,
      );
      _addAllUnique(skills, proficiencies.skillValuesForCharacter);
      _addAllUnique(saves, proficiencies.savingThrows);
      _addAllUnique(expertSkills, proficiencies.expertSkills);
    }

    return _ParsedCharacterClasses(
      classes: classes,
      classNodes: classNodes,
      skills: skills,
      savingThrows: saves,
      expertSkills: expertSkills,
      hitDice: hitDice,
      features: features,
    );
  }

  static List<int> _parseCharacterSpellSlots(
    XmlElement characterNode,
    List<XmlElement> classNodes,
    String tag,
    FC5ParseDiagnostics diagnostics,
  ) {
    final direct = _getTag(characterNode, tag);
    if (direct.isNotEmpty) {
      return _slotListToNineLevels(_parseIntList(direct));
    }

    for (final classNode in classNodes) {
      final value = _getTag(classNode, tag);
      if (value.isNotEmpty) {
        return _slotListToNineLevels(_parseIntList(value));
      }
    }

    return List<int>.filled(9, 0);
  }

  static _ParsedInventory _parseCharacterInventory(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final items = <Item>[];
    var copperPieces = _parseInt(_getAnyTag(node, ['cp', 'copper'])) ?? 0;
    var silverPieces = _parseInt(_getAnyTag(node, ['sp', 'silver'])) ?? 0;
    var goldPieces = _parseInt(_getAnyTag(node, ['gp', 'gold'])) ?? 0;
    var platinumPieces = _parseInt(_getAnyTag(node, ['pp', 'platinum'])) ?? 0;
    var goldFromItem = false;

    for (final itemNode in node.findElements('item')) {
      final itemName = _getTag(itemNode, 'name');
      if (_isCurrencyItem(itemNode)) {
        final currency = _currencyFromItem(itemNode);
        copperPieces += currency.copperPieces;
        silverPieces += currency.silverPieces;
        goldPieces += currency.goldPieces;
        platinumPieces += currency.platinumPieces;
        if (_normalizeLoose(itemName).contains('gold') ||
            _normalizeLoose(itemName).contains('gp')) {
          goldFromItem = true;
        }
        continue;
      }

      try {
        items.add(_parseItem(itemNode, null));
      } catch (error) {
        diagnostics.warning(
          'character_item_skipped',
          'Item "$itemName" was skipped: $error',
          context: itemName.ifEmpty('item'),
        );
      }
    }

    final moneyText = _getTag(node, 'money');
    if (!goldFromItem && moneyText.isNotEmpty) {
      goldPieces += (_parseDouble(moneyText) ?? 0).round();
    }

    return _ParsedInventory(
      items: items,
      copperPieces: copperPieces,
      silverPieces: silverPieces,
      goldPieces: goldPieces,
      platinumPieces: platinumPieces,
    );
  }

  static _ParsedSpellSelection _parseCharacterSpells(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final known = <String>[];
    final prepared = <String>[];

    for (final spellNode in node.findElements('spell')) {
      _addCharacterSpell(spellNode, known, prepared, diagnostics);
    }

    for (final classNode in node.findElements('class')) {
      for (final spellNode in classNode.findElements('spell')) {
        _addCharacterSpell(spellNode, known, prepared, diagnostics);
      }
    }

    return _ParsedSpellSelection(
      knownSpells: known,
      preparedSpells: prepared,
      maxPreparedSpells: prepared.length,
    );
  }

  static void _addCharacterSpell(
    XmlElement spellNode,
    List<String> known,
    List<String> prepared,
    FC5ParseDiagnostics diagnostics,
  ) {
    final name = _getTag(spellNode, 'name');
    if (name.isEmpty) {
      diagnostics.warning(
        'character_spell_skipped',
        'A character spell without a name was skipped.',
      );
      return;
    }

    final id = _resolveSpellId(name);
    _addUnique(known, id);

    final preparedValue = _getTag(spellNode, 'prepared');
    if (_parseBool(preparedValue) == true) {
      _addUnique(prepared, id);
    }
  }

  static List<JournalNote> _parseCharacterNotes(
    XmlElement node,
    FC5ParseDiagnostics diagnostics,
  ) {
    final notes = <JournalNote>[];
    for (final noteNode in node.findElements('note')) {
      final title = _getTag(noteNode, 'name').ifEmpty('Imported note');
      final text = _getText(noteNode);
      notes.add(
        JournalNote(
          id: _uuid.v4(),
          title: title,
          content: text,
          category: _noteCategoryFor(title, text),
          tags: const ['fc5'],
        ),
      );
    }
    return notes;
  }

  static NoteCategory _noteCategoryFor(String title, String content) {
    final combined = _normalizeLoose('$title $content');
    if (combined.contains('quest') ||
        combined.contains('objective') ||
        combined.contains('квест') ||
        combined.contains('задание') ||
        combined.contains('цель')) {
      return NoteCategory.story;
    }
    if (combined.contains('session') || combined.contains('сессия')) {
      return NoteCategory.session;
    }
    return NoteCategory.general;
  }

  static List<CharacterFeature> _parseCharacterFeaturesFromContainer(
    XmlElement container,
    FC5ParseDiagnostics diagnostics, {
    required String sourceKind,
    String? associatedClass,
    String? associatedSubclass,
    int? maxLevel,
  }) {
    final features = <CharacterFeature>[];

    for (final featNode in container.findElements('feat')) {
      final feature = _parseCharacterFeature(
        featNode,
        sourceKind: sourceKind,
        associatedClass: associatedClass,
        associatedSubclass: associatedSubclass,
        minLevel: 1,
      );
      if (feature != null) {
        _addFeature(features, feature);
      }
    }

    for (final featureNode in container.findElements('feature')) {
      final feature = _parseCharacterFeature(
        featureNode,
        sourceKind: sourceKind,
        associatedClass: associatedClass,
        associatedSubclass: associatedSubclass,
        minLevel: 1,
      );
      if (feature != null) {
        _addFeature(features, feature);
      }
    }

    for (final autolevel in container.findElements('autolevel')) {
      final level = _autolevelNumber(autolevel) ?? 1;
      if (maxLevel != null && level > maxLevel) continue;

      for (final featNode in autolevel.findElements('feat')) {
        final feature = _parseCharacterFeature(
          featNode,
          sourceKind: sourceKind,
          associatedClass: associatedClass,
          associatedSubclass: associatedSubclass,
          minLevel: level,
        );
        if (feature != null) {
          _addFeature(features, feature);
        }
      }

      for (final featureNode in autolevel.findElements('feature')) {
        final feature = _parseCharacterFeature(
          featureNode,
          sourceKind: sourceKind,
          associatedClass: associatedClass,
          associatedSubclass: associatedSubclass,
          minLevel: level,
        );
        if (feature != null) {
          _addFeature(features, feature);
        }
      }
    }

    return features;
  }

  static CharacterFeature? _parseCharacterFeature(
    XmlElement node, {
    required String sourceKind,
    String? associatedClass,
    String? associatedSubclass,
    required int minLevel,
  }) {
    var name = _getTag(node, 'name');
    if (name.isEmpty) return null;

    final optional = _parseBool(
            node.getAttribute('optional') ?? _getTag(node, 'optional')) ==
        true;
    if (optional && !name.toLowerCase().contains('optional')) {
      name = '$name (Optional)';
    }

    final text = _getText(node);
    final id =
        'fc5_${sourceKind}_${_stableId(associatedClass ?? '')}_${_stableId(name)}';

    return CharacterFeature(
      id: id,
      nameEn: name,
      nameRu: name,
      descriptionEn: text,
      descriptionRu: text,
      type: FeatureType.passive,
      minLevel: minLevel,
      associatedClass: associatedClass,
      associatedSubclass: associatedSubclass,
    );
  }

  static _ParsedCharacterProficiencies _parseCharacterProficiencyElements(
    Iterable<XmlElement> proficiencyNodes,
    FC5ParseDiagnostics diagnostics, {
    required String context,
    required bool classContext,
  }) {
    final skills = <String>[];
    final expertSkills = <String>[];
    final savingThrows = <String>[];

    for (final proficiencyNode in proficiencyNodes) {
      final raw = proficiencyNode.innerText.trim();
      final expert =
          _parseBool(proficiencyNode.getAttribute('expert')) == true ||
              _parseBool(proficiencyNode.getAttribute('expertise')) == true ||
              _parseBool(proficiencyNode.getAttribute('double')) == true;

      final parsed = _parseProficiencyText(
        raw,
        diagnostics,
        context: context,
        classContext: classContext,
      );

      _addAllUnique(skills, parsed.skillValuesForCharacter);
      _addAllUnique(savingThrows, parsed.savingThrows);
      if (expert) {
        final parsedSkillIds = parsed.skillIds.isNotEmpty
            ? parsed.skillIds
            : parsed.skillValuesForCharacter
                .map(_normalizeSkillId)
                .whereType<String>();
        _addAllUnique(expertSkills, parsedSkillIds);
      }
      _addAllUnique(expertSkills, parsed.expertSkills);
    }

    return _ParsedCharacterProficiencies(
      skillIds: skills
          .map(_normalizeSkillId)
          .whereType<String>()
          .toList(growable: false),
      skillValuesForCharacter: skills,
      expertSkills: expertSkills,
      savingThrows: savingThrows,
    );
  }

  static _ParsedCharacterProficiencies _parseProficiencyText(
    String raw,
    FC5ParseDiagnostics diagnostics, {
    required String context,
    required bool classContext,
  }) {
    final skills = <String>[];
    final expertSkills = <String>[];
    final savingThrows = <String>[];

    if (raw.trim().isEmpty) {
      return const _ParsedCharacterProficiencies();
    }

    final normalizedRaw = _normalizeLoose(raw);

    if (normalizedRaw.contains('saving throws') &&
        normalizedRaw.contains('skills')) {
      final savingPart = raw
          .split(RegExp(r'[;]'))
          .firstWhere(
            (part) => _normalizeLoose(part).contains('saving throws'),
            orElse: () => '',
          )
          .replaceFirst(RegExp(r'.*?:'), '');
      final skillPart = raw
          .split(RegExp(r'[;]'))
          .firstWhere(
            (part) => _normalizeLoose(part).contains('skills'),
            orElse: () => '',
          )
          .replaceFirst(RegExp(r'.*?:'), '')
          .replaceFirst(
              RegExp(r'choose\s+\d+\s+from', caseSensitive: false), '');

      for (final token in _splitList(savingPart)) {
        final ability = _normalizeAbility(token);
        if (ability != null) _addUnique(savingThrows, ability);
      }
      for (final token in _splitList(skillPart)) {
        _addCharacterSkillValues(skills, token);
      }
      return _ParsedCharacterProficiencies(
        skillValuesForCharacter: skills,
        expertSkills: expertSkills,
        savingThrows: savingThrows,
      );
    }

    for (final token in _splitList(raw)) {
      final normalized = _normalizeLoose(token);
      if (normalized.isEmpty) continue;

      final ability = _normalizeAbility(
        normalized
            .replaceAll('saving throws', '')
            .replaceAll('saving throw', '')
            .trim(),
      );
      final skillId = _normalizeSkillId(normalized);

      if (normalized.contains('expert') || normalized.contains('эксперт')) {
        if (skillId != null) {
          _addUnique(expertSkills, skillId);
          _addCharacterSkillValues(skills, skillId);
        }
        continue;
      }

      if (normalized.contains('saving throw')) {
        if (ability != null) _addUnique(savingThrows, ability);
        continue;
      }

      if (skillId != null) {
        _addCharacterSkillValues(skills, skillId);
        continue;
      }

      if (ability != null && classContext) {
        _addUnique(savingThrows, ability);
        continue;
      }
    }

    return _ParsedCharacterProficiencies(
      skillValuesForCharacter: skills,
      expertSkills: expertSkills,
      savingThrows: savingThrows,
    );
  }

  static void _addCharacterSkillValues(List<String> target, String value) {
    final skillId = _normalizeSkillId(value);
    if (skillId == null) return;
    _addUnique(target, skillId);
  }

  static Item _parseItem(XmlElement node, String? sourceId) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Item');
    final nameRu = _getTag(node, 'name_ru');
    final descEn = _getText(node);
    final descRu = _getText(node, suffix: '_ru');
    final typeCode = _normalizeLoose(_getTag(node, 'type'));
    final hasDamage = _getAnyTag(
      node,
      ['dmg1', 'damage1H', 'damage', 'damage2H', 'dmg2'],
    ).isNotEmpty;
    final acValue = _parseInt(_getTag(node, 'ac'));

    var type = _itemTypeFromCode(typeCode, hasDamage: hasDamage, ac: acValue);
    WeaponProperties? weaponProps;
    ArmorProperties? armorProps;

    if (type == ItemType.weapon) {
      final damageDice = _getAnyTag(node, ['dmg1', 'damage1H', 'damage']);
      final versatileDice = _getAnyTag(node, ['dmg2', 'damage2H']).emptyToNull;
      final damageType = _damageTypeFromText(
        _getAnyTag(node, ['dmgType', 'damageType']),
      );
      final properties = _parseWeaponProperties(
        _getAnyTag(node, ['property', 'weaponProperty']),
      );
      final rangeValues = _parseRange(_getTag(node, 'range'));

      weaponProps = WeaponProperties(
        damageDice: damageDice.ifEmpty('1d4'),
        damageType: damageType,
        weaponTags: properties,
        range: rangeValues.$1,
        longRange: rangeValues.$2,
        versatileDamageDice: versatileDice,
      );
    } else if (type == ItemType.armor) {
      final armorType = _armorTypeFromCode(typeCode, nameEn);
      final isShield = armorType == ArmorType.shield;
      final baseAc =
          acValue != null && acValue > 0 ? acValue : (isShield ? 2 : 10);
      armorProps = ArmorProperties(
        baseAC: baseAc,
        armorType: armorType,
        addDexModifier:
            armorType == ArmorType.light || armorType == ArmorType.medium,
        maxDexBonus: armorType == ArmorType.medium ? 2 : null,
        strengthRequirement: _parseInt(_getTag(node, 'strength')),
        stealthDisadvantage: _parseBool(_getTag(node, 'stealth')) == true ||
            _normalizeLoose(_getTag(node, 'stealth')).contains('disadvantage'),
      );
    }

    if (type == ItemType.gear && hasDamage) {
      type = ItemType.weapon;
    }

    return Item(
      id: _entityId(nameEn, 'item', sourceId),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      descriptionEn: descEn,
      descriptionRu: descRu.isNotEmpty ? descRu : descEn,
      type: type,
      rarity: _itemRarityFromText(_getTag(node, 'rarity')),
      quantity: _parseInt(_getTag(node, 'quantity')) ?? 1,
      weight: _parseDouble(_getTag(node, 'weight')) ?? 0,
      valueInCopper:
          ((_parseDouble(_getTag(node, 'value')) ?? 0) * 100).round(),
      isEquipped: _parseBool(_getTag(node, 'equipped')) == true ||
          _parseBool(_getTag(node, 'isEquipped')) == true,
      isAttuned: _parseBool(_getTag(node, 'attuned')) == true ||
          _parseBool(_getTag(node, 'isAttuned')) == true,
      weaponProperties: weaponProps,
      armorProperties: armorProps,
      isMagical: _parseBool(_getTag(node, 'magic')) == true ||
          _parseBool(_getTag(node, 'magical')) == true,
      sourceId: sourceId,
    );
  }

  static Spell _parseSpell(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Spell');
    final nameRu = _getTag(node, 'name_ru');
    final levelStr = _getTag(node, 'level');
    final time = _getTag(node, 'time');
    final range = _getTag(node, 'range');
    final duration = _getTag(node, 'duration');
    final descEn = _getText(node);
    final descRu = _getText(node, suffix: '_ru');
    final componentsData = _parseSpellComponents(node);
    final ritual = _parseBool(_getTag(node, 'ritual')) ?? false;

    final classNames = <String>[];
    final classesRaw = _splitBilingual(_getTag(node, 'classes'))['en'] ?? '';
    _addAllUnique(classNames, _parseIds(classesRaw));
    for (final sclass in node.findElements('sclass')) {
      final className = _classNameWithoutSubclass(sclass.innerText);
      final canonical = _canonicalClassName(className);
      _addUnique(classNames, _stableId(canonical).replaceAll('_', ' '));
    }

    return Spell(
      id: _entityId(nameEn, 'spell', sourceId),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      level: _parseInt(levelStr) ?? 0,
      school: _schoolFromText(_getTag(node, 'school')),
      castingTime: time,
      range: range,
      duration: duration,
      concentration: _normalizeLoose(duration).contains('concentration') ||
          _normalizeLoose(duration).contains('концентрация'),
      ritual: ritual,
      components: componentsData.components,
      materialComponents: componentsData.materials,
      materialComponentsRu: componentsData.materialsRu,
      descriptionEn: descEn,
      descriptionRu: descRu.isNotEmpty ? descRu : descEn,
      availableToClasses: classNames,
      sourceId: sourceId,
    );
  }

  static RaceData _parseRace(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Race');
    final nameRu = _getTag(node, 'name_ru');
    final size = _sizeFromText(_getTag(node, 'size'));
    final speed =
        _parseInt(_getTag(node, 'speed').replaceAll(RegExp(r'[^0-9-]'), '')) ??
            30;
    final abilityMap = _parseAbilityBonuses(_getTag(node, 'ability'));

    final traits = <CharacterFeature>[];
    for (final traitNode in node.findElements('trait')) {
      final tNameEn = _getTag(traitNode, 'name');
      if (tNameEn.isEmpty) continue;
      final tNameRu = _getTag(traitNode, 'name_ru');
      final tDescEn = _getText(traitNode);
      final tDescRu = _getText(traitNode, suffix: '_ru');
      traits.add(
        CharacterFeature(
          id: _entityId(tNameEn, 'race_trait', sourceId),
          nameEn: tNameEn,
          nameRu: tNameRu.isNotEmpty ? tNameRu : tNameEn,
          descriptionEn: tDescEn,
          descriptionRu: tDescRu.isNotEmpty ? tDescRu : tDescEn,
          type: FeatureType.passive,
          minLevel: 1,
          sourceId: sourceId,
        ),
      );
    }

    return RaceData(
      id: _entityId(nameEn, 'race', sourceId),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {
        'en': _getText(node),
        'ru': _getText(node, suffix: '_ru').ifEmpty(_getText(node)),
      },
      speed: speed,
      abilityScoreIncreases: abilityMap,
      languages: const [],
      proficiencies: _parseIds(_getTag(node, 'proficiency')),
      traits: traits,
      size: size,
      sourceId: sourceId,
    );
  }

  static ClassData _parseClass(
    XmlElement node,
    String sourceId,
    FC5ParseDiagnostics diagnostics,
  ) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Class');
    final nameRu = _getTag(node, 'name_ru');
    final hitDie = _parseInt(_getTag(node, 'hd')) ?? 8;
    final features = <int, List<CharacterFeature>>{};
    final subclassMap = <String, Map<String, String>>{};
    int? detectedSubclassLevel;

    for (final autolevel in node.findElements('autolevel')) {
      final level = _autolevelNumber(autolevel);
      if (level == null || level < 1) continue;
      features.putIfAbsent(level, () => []);

      final subclassEn = autolevel.getAttribute('subclass') ??
          autolevel.getAttribute('name') ??
          '';
      final normalizedSubclass = subclassEn.trim().isEmpty ? null : subclassEn;
      if (subclassEn.trim().isNotEmpty) {
        final subclassRu = autolevel.getAttribute('subclass_ru') ??
            autolevel.getAttribute('name_ru') ??
            subclassEn;
        final id = _stableId(subclassEn);
        subclassMap.putIfAbsent(
          id,
          () => {'en': subclassEn, 'ru': subclassRu},
        );
        detectedSubclassLevel = detectedSubclassLevel == null
            ? level
            : math.min(detectedSubclassLevel, level);
      }

      final featureNodes = [
        ...autolevel.findElements('feature'),
        ...autolevel.findElements('feat'),
      ];
      for (final featureNode in featureNodes) {
        final feature = _parseClassFeature(
          featureNode,
          sourceId,
          className: nameEn,
          subclassName: normalizedSubclass,
          level: level,
        );
        if (feature != null) {
          final hydration = FeatureHydrationService.hydrateClassFeatures(
            [feature],
            className: nameEn,
            subclassName: normalizedSubclass,
          );
          _mergeHydrationDiagnostics(diagnostics, hydration.diagnostics);
          features[level]!.addAll(hydration.features);
        }
      }

      final slots = _getTag(autolevel, 'slots');
      if (slots.isNotEmpty) {
        diagnostics.info(
          'class_spell_slots_progression',
          'Spell slot progression for "$nameEn" level $level was imported as progression data for future support, not as a character feature.',
          context: nameEn,
        );
      }
    }

    final classProficiencies = _parseClassProficiencies(node);
    final spellAbility = _normalizeAbility(_getTag(node, 'spellAbility'));

    final subclasses = subclassMap.entries.map((entry) {
      return SubclassData(
        id: entry.key,
        name: entry.value,
        description: {
          'en': 'Subclass of $nameEn',
          'ru': nameRu.isNotEmpty ? 'Подкласс $nameRu' : '',
        },
      );
    }).toList();

    return ClassData(
      id: _entityId(nameEn, 'class', sourceId),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {
        'en': _getText(node),
        'ru': _getText(node, suffix: '_ru').ifEmpty(_getText(node)),
      },
      hitDie: hitDie,
      primaryAbilities: spellAbility == null ? const [] : [spellAbility],
      savingThrowProficiencies: classProficiencies.savingThrows,
      armorProficiencies: classProficiencies.armor,
      weaponProficiencies: classProficiencies.weapons,
      skillProficiencies: SkillProficiencies(
        choose: _parseInt(_getTag(node, 'numSkills')) ?? 0,
        from: classProficiencies.skillIds,
      ),
      subclasses: subclasses,
      subclassLevel: detectedSubclassLevel ?? 3,
      features: features,
      spellcasting: spellAbility == null
          ? null
          : SpellcastingInfo(
              ability: spellAbility,
              type: _spellcastingTypeForClass(nameEn),
            ),
      sourceId: sourceId,
    );
  }

  static CharacterFeature? _parseClassFeature(
    XmlElement featureNode,
    String sourceId, {
    required String className,
    String? subclassName,
    required int level,
  }) {
    var fNameEn = _getTag(featureNode, 'name');
    if (fNameEn.isEmpty) return null;
    var fNameRu = _getTag(featureNode, 'name_ru');
    final optional = _parseBool(
          featureNode.getAttribute('optional') ??
              _getTag(featureNode, 'optional'),
        ) ==
        true;
    if (optional) {
      fNameEn = '[Optional] $fNameEn';
      fNameRu =
          fNameRu.isNotEmpty ? '[Опционально] $fNameRu' : '[Optional] $fNameEn';
    }

    final fDescEn = _getText(featureNode);
    final fDescRu = _getText(featureNode, suffix: '_ru');

    return CharacterFeature(
      id: _entityId('$className $fNameEn $level', 'class_feature', sourceId),
      nameEn: fNameEn,
      nameRu: fNameRu.isNotEmpty ? fNameRu : fNameEn,
      descriptionEn: fDescEn,
      descriptionRu: fDescRu.isNotEmpty ? fDescRu : fDescEn,
      type: FeatureType.passive,
      minLevel: level,
      associatedClass: className,
      associatedSubclass: subclassName,
      sourceId: sourceId,
    );
  }

  static BackgroundData _parseBackground(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Background');
    final nameRu = _getTag(node, 'name_ru');
    var skillStr = _getTag(node, 'skill');
    if (skillStr.isEmpty) {
      skillStr = _getTag(node, 'proficiency');
    }
    final skills = _parseIds(skillStr);

    final traitNodes = node.findElements('trait').toList();
    final featureNameEn = traitNodes.isNotEmpty
        ? _getTag(traitNodes.first, 'name')
        : _getTag(node, 'name');
    final featureNameRu = traitNodes.isNotEmpty
        ? _getTag(traitNodes.first, 'name_ru')
        : _getTag(node, 'name_ru');
    final descEn = StringBuffer();
    final descRu = StringBuffer();

    for (final trait in traitNodes) {
      final traitNameEn = _getTag(trait, 'name');
      final traitNameRu = _getTag(trait, 'name_ru');
      final traitTextEn = _getText(trait);
      final traitTextRu = _getText(trait, suffix: '_ru');
      if (descEn.isNotEmpty) descEn.write('\n\n');
      if (descRu.isNotEmpty) descRu.write('\n\n');
      if (traitNameEn.isNotEmpty) descEn.write('$traitNameEn:\n');
      if (traitNameRu.isNotEmpty || traitNameEn.isNotEmpty) {
        descRu.write('${traitNameRu.ifEmpty(traitNameEn)}:\n');
      }
      descEn.write(traitTextEn);
      descRu.write(traitTextRu.ifEmpty(traitTextEn));
    }

    final proficiencyText = _getTag(node, 'proficiency');
    final descriptionEn = [
      _getText(node),
      if (proficiencyText.isNotEmpty) 'Proficiencies: $proficiencyText',
    ].where((part) => part.trim().isNotEmpty).join('\n\n');

    return BackgroundData(
      id: _entityId(nameEn, 'background', sourceId),
      name: {'en': nameEn, 'ru': nameRu.isNotEmpty ? nameRu : nameEn},
      description: {
        'en': descriptionEn,
        'ru': _getText(node, suffix: '_ru').ifEmpty(descriptionEn),
      },
      skillProficiencies: skills,
      toolProficiencies: const {},
      languages: 0,
      feature: BackgroundFeature(
        name: {
          'en': featureNameEn,
          'ru': featureNameRu.isNotEmpty ? featureNameRu : featureNameEn,
        },
        description: {
          'en': descEn.toString(),
          'ru': descRu.toString().ifEmpty(descEn.toString()),
        },
      ),
      equipment: const {},
      sourceId: sourceId,
    );
  }

  static CharacterFeature _parseFeat(XmlElement node, String sourceId) {
    final nameEn = _getTag(node, 'name').ifEmpty('Unnamed Feat');
    final nameRu = _getTag(node, 'name_ru');
    final textEn = _getText(node);
    final textRu = _getText(node, suffix: '_ru');
    final prerequisiteEn = _getTag(node, 'prerequisite');
    final prerequisiteRu = _getTag(node, 'prerequisite_ru');
    final proficiency = _getTag(node, 'proficiency');

    final descEn = [
      if (prerequisiteEn.isNotEmpty) 'Prerequisite: $prerequisiteEn',
      if (proficiency.isNotEmpty) 'Proficiency: $proficiency',
      textEn,
    ].where((part) => part.trim().isNotEmpty).join('\n\n');

    final descRu = [
      if (prerequisiteRu.isNotEmpty) 'Требование: $prerequisiteRu',
      if (prerequisiteRu.isEmpty && prerequisiteEn.isNotEmpty)
        'Prerequisite: $prerequisiteEn',
      if (proficiency.isNotEmpty) 'Proficiency: $proficiency',
      textRu.ifEmpty(textEn),
    ].where((part) => part.trim().isNotEmpty).join('\n\n');

    return CharacterFeature(
      id: _entityId(nameEn, 'feat', sourceId),
      nameEn: nameEn,
      nameRu: nameRu.isNotEmpty ? nameRu : nameEn,
      descriptionEn: descEn,
      descriptionRu: descRu,
      type: FeatureType.passive,
      minLevel: 1,
      sourceId: sourceId,
    );
  }

  static _ParsedClassProficiencies _parseClassProficiencies(XmlElement node) {
    final savingThrows = <String>[];
    final skillIds = <String>[];
    var armor = _parseArmorProficiencies(_getTag(node, 'armor'));
    var weapons = _parseWeaponProficiencies(_getTag(node, 'weapons'));

    for (final profNode in node.findElements('proficiency')) {
      final text = profNode.innerText.trim();
      final normalized = _normalizeLoose(text);
      if (normalized.isEmpty) continue;

      if (normalized.contains('saving throws') &&
          normalized.contains('skills')) {
        final segments = text.split(';');
        for (final segment in segments) {
          final lower = _normalizeLoose(segment);
          final afterColon = segment.replaceFirst(RegExp(r'.*?:'), '');
          if (lower.contains('saving throws')) {
            for (final token in _splitList(afterColon)) {
              final ability = _normalizeAbility(token);
              if (ability != null) _addUnique(savingThrows, ability);
            }
          } else if (lower.contains('skills')) {
            final clean = afterColon.replaceFirst(
              RegExp(r'choose\s+\d+\s+from', caseSensitive: false),
              '',
            );
            _addAllUnique(skillIds, _parseIds(clean));
          }
        }
        continue;
      }

      for (final token in _splitList(text)) {
        final clean = token
            .replaceAll(RegExp(r'\bSaving Throws?\b', caseSensitive: false), '')
            .trim();
        final lower = _normalizeLoose(token);
        final ability = _normalizeAbility(clean);
        final skill = _normalizeSkillId(clean);

        if (lower.contains('saving throw')) {
          if (ability != null) _addUnique(savingThrows, ability);
        } else if (skill != null) {
          _addUnique(skillIds, skill);
        } else if (ability != null) {
          _addUnique(savingThrows, ability);
        } else {
          armor =
              _mergeArmorProficiencies(armor, _parseArmorProficiencies(token));
          weapons = _mergeWeaponProficiencies(
            weapons,
            _parseWeaponProficiencies(token),
          );
        }
      }
    }

    return _ParsedClassProficiencies(
      savingThrows: savingThrows,
      skillIds: skillIds,
      armor: armor,
      weapons: weapons,
    );
  }

  static ArmorProficiencies _parseArmorProficiencies(String text) {
    final normalized = _normalizeLoose(text);
    return ArmorProficiencies(
      light: normalized.contains('light armor') ||
          normalized.contains('лёгкие доспехи') ||
          normalized.contains('легкие доспехи') ||
          normalized.contains('all armor') ||
          normalized.contains('все виды доспехов'),
      medium: normalized.contains('medium armor') ||
          normalized.contains('средние доспехи') ||
          normalized.contains('all armor') ||
          normalized.contains('все виды доспехов'),
      heavy: normalized.contains('heavy armor') ||
          normalized.contains('тяжёлые доспехи') ||
          normalized.contains('тяжелые доспехи') ||
          normalized.contains('all armor') ||
          normalized.contains('все виды доспехов'),
      shields: normalized.contains('shield') || normalized.contains('щиты'),
    );
  }

  static ArmorProficiencies _mergeArmorProficiencies(
    ArmorProficiencies a,
    ArmorProficiencies b,
  ) {
    return ArmorProficiencies(
      light: a.light || b.light,
      medium: a.medium || b.medium,
      heavy: a.heavy || b.heavy,
      shields: a.shields || b.shields,
    );
  }

  static WeaponProficiencies _parseWeaponProficiencies(String text) {
    final normalized = _normalizeLoose(text);
    final specific = <String>[];
    if (!normalized.contains('simple weapon') &&
        !normalized.contains('martial weapon') &&
        !normalized.contains('простое оружие') &&
        !normalized.contains('воинское оружие')) {
      specific.addAll(_parseIds(text));
    }
    return WeaponProficiencies(
      simple: normalized.contains('simple weapon') ||
          normalized.contains('простое оружие'),
      martial: normalized.contains('martial weapon') ||
          normalized.contains('воинское оружие'),
      specific: specific,
    );
  }

  static WeaponProficiencies _mergeWeaponProficiencies(
    WeaponProficiencies a,
    WeaponProficiencies b,
  ) {
    return WeaponProficiencies(
      simple: a.simple || b.simple,
      martial: a.martial || b.martial,
      specific: {...a.specific, ...b.specific}.toList(),
    );
  }

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

  static String _getAnyTag(XmlElement node, List<String> tagNames) {
    for (final tagName in tagNames) {
      final value = _getTag(node, tagName);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _getText(XmlElement node, {String suffix = ''}) {
    final tagName = suffix.isEmpty ? 'text' : 'text$suffix';
    final elements = node.findElements(tagName);
    if (elements.isEmpty && suffix.isNotEmpty) {
      return _getText(node);
    }
    return elements
        .map((element) => element.innerText.trim())
        .where((text) => text.isNotEmpty)
        .join('\n')
        .trim();
  }

  static List<String> _parseIds(String text) {
    if (text.trim().isEmpty) return [];
    return _splitList(text)
        .map((item) {
          var value = item.trim();
          final parenIndex = value.indexOf('(');
          if (parenIndex > 0) value = value.substring(0, parenIndex).trim();
          final skill = _normalizeSkillId(value);
          if (skill != null) return skill.replaceAll('_', ' ');
          final ability = _normalizeAbility(value);
          if (ability != null) return ability;
          return _canonicalClassName(value).toLowerCase();
        })
        .where((value) => value.isNotEmpty)
        .toList();
  }

  static List<String> _splitList(String text) {
    return text
        .split(RegExp(r'[,;\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
  }

  static List<int> _parseIntList(String text) {
    return text
        .split(RegExp(r'[,;\n]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map((part) => _parseInt(part))
        .whereType<int>()
        .toList();
  }

  static int? _parseInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed) ??
        int.tryParse(RegExp(r'-?\d+').firstMatch(trimmed)?.group(0) ?? '');
  }

  static double? _parseDouble(String text) {
    final trimmed = text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed) ??
        double.tryParse(
          RegExp(r'-?\d+(?:[.,]\d+)?')
                  .firstMatch(trimmed)
                  ?.group(0)
                  ?.replaceAll(',', '.') ??
              '',
        );
  }

  static bool? _parseBool(String? text) {
    final normalized = _normalizeLoose(text ?? '');
    if (normalized.isEmpty) return null;
    if (['yes', 'true', '1', 'да'].contains(normalized)) return true;
    if (['no', 'false', '0', 'нет'].contains(normalized)) return false;
    return null;
  }

  static List<int> _slotListToNineLevels(List<int> raw) {
    final slots = List<int>.filled(9, 0);
    if (raw.isEmpty) return slots;
    final offset = raw.length >= 10 ? 1 : 0;
    for (var i = 0; i < slots.length; i++) {
      final sourceIndex = i + offset;
      if (sourceIndex >= raw.length) break;
      slots[i] = raw[sourceIndex];
    }
    return slots;
  }

  static Map<String, int> _parseAbilityBonuses(String text) {
    final result = <String, int>{};
    for (final token in _splitList(text)) {
      final match = RegExp(
        r'([A-Za-zА-Яа-яёЁ]+)\s*([+-]?\d+)',
        caseSensitive: false,
      ).firstMatch(token);
      if (match == null) continue;
      final ability = _normalizeAbility(match.group(1) ?? '');
      final value = int.tryParse(match.group(2) ?? '');
      if (ability != null && value != null) {
        result[ability] = value;
      }
    }
    return result;
  }

  static String? _normalizeAbility(String value) {
    final normalized = _normalizeLoose(value)
        .replaceAll('saving throws', '')
        .replaceAll('saving throw', '')
        .replaceAll('score', '')
        .trim();
    return _abilityCodeMap[normalized];
  }

  static String? _normalizeSkillId(String value) {
    final normalized = _normalizeLoose(value)
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .trim();
    return _skillMap[normalized];
  }

  static String _canonicalClassName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = _normalizeLoose(trimmed);
    return _classNameMap[normalized] ?? _titleCase(trimmed);
  }

  static String _canonicalRaceName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = _normalizeLoose(trimmed);
    return _raceNameMap[normalized] ?? _titleCase(trimmed);
  }

  static String _canonicalBackgroundName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = _normalizeLoose(trimmed);
    return _backgroundNameMap[normalized] ?? _titleCase(trimmed);
  }

  static String _canonicalSubclassName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    final normalized = _normalizeLoose(trimmed);
    return _subclassNameMap[normalized] ?? _titleCase(trimmed);
  }

  static _ClassNameParts _splitClassName(String text) {
    final index = text.indexOf(':');
    if (index == -1) {
      return _ClassNameParts(base: text.trim());
    }
    return _ClassNameParts(
      base: text.substring(0, index).trim(),
      subclass: text.substring(index + 1).trim().emptyToNull,
    );
  }

  static String _classNameWithoutSubclass(String text) {
    final index = text.indexOf('(');
    final cleaned = index == -1 ? text : text.substring(0, index);
    return cleaned.trim();
  }

  static String _spellcastingTypeForClass(String className) {
    switch (_stableId(_canonicalClassName(className))) {
      case 'paladin':
      case 'ranger':
        return 'half';
      case 'warlock':
        return 'pact';
      case 'fighter':
      case 'rogue':
        return 'third';
      default:
        return 'full';
    }
  }

  static int? _autolevelNumber(XmlElement autolevel) {
    return _parseInt(autolevel.getAttribute('level') ?? '') ??
        _parseInt(_getTag(autolevel, 'level'));
  }

  static String _resolveSpellId(String name) {
    final target = _stableId(name);
    for (final spell in SpellService.getAllSpells()) {
      if (_stableId(spell.id) == target ||
          _stableId(spell.nameEn) == target ||
          _stableId(spell.nameRu) == target) {
        return spell.id;
      }
    }
    return target;
  }

  static _ParsedSpellComponents _parseSpellComponents(XmlElement node) {
    final raw = _getTag(node, 'components');
    final components = <String>[];
    String? materials;
    String? materialsRu = _getTag(node, 'materials_ru').emptyToNull;

    if (raw.isNotEmpty) {
      final upper = raw.toUpperCase();
      if (upper.contains('V')) components.add('V');
      if (upper.contains('S')) components.add('S');
      if (upper.contains('M')) components.add('M');
      final match = RegExp(r'\((.*)\)').firstMatch(raw);
      materials = match?.group(1)?.trim();
    } else {
      if (_parseBool(_getTag(node, 'v')) == true) components.add('V');
      if (_parseBool(_getTag(node, 's')) == true) components.add('S');
      if (_parseBool(_getTag(node, 'm')) == true) components.add('M');
    }

    materials ??= _getTag(node, 'materials').emptyToNull;
    return _ParsedSpellComponents(
      components: components,
      materials: materials,
      materialsRu: materialsRu,
    );
  }

  static String _schoolFromText(String text) {
    final normalized = _normalizeLoose(text);
    if (normalized.isEmpty) return 'Abjuration';
    return _schoolMap[normalized] ?? _titleCase(text);
  }

  static DamageType _damageTypeFromText(String text) {
    final normalized = _normalizeLoose(text);
    return _damageTypeMap[normalized] ?? DamageType.slashing;
  }

  static ItemType _itemTypeFromCode(
    String typeCode, {
    required bool hasDamage,
    required int? ac,
  }) {
    if (hasDamage) return ItemType.weapon;
    if (['m', 'r', 'st', 'weapon', 'melee weapon', 'ranged weapon', '5', '6']
        .contains(typeCode)) {
      return ItemType.weapon;
    }
    if ([
      'a',
      'la',
      'ma',
      'ha',
      's',
      'armor',
      'light armor',
      'medium armor',
      'heavy armor',
      'shield',
      '2',
      '3',
      '4'
    ].contains(typeCode)) {
      return ItemType.armor;
    }
    if (ac != null && ac > 0) return ItemType.armor;
    if (['p', 'sc', 'potion', 'scroll', '10', '11'].contains(typeCode)) {
      return ItemType.consumable;
    }
    if (['\$', 'money', 'treasure', '15'].contains(typeCode)) {
      return ItemType.treasure;
    }
    if (['tool', 'tools'].contains(typeCode)) return ItemType.tool;
    return ItemType.gear;
  }

  static ArmorType _armorTypeFromCode(String typeCode, String name) {
    final normalizedName = _normalizeLoose(name);
    if (typeCode == 's' ||
        typeCode == 'shield' ||
        normalizedName.contains('shield') ||
        normalizedName.contains('щит')) {
      return ArmorType.shield;
    }
    if (typeCode == 'ma' ||
        typeCode == '3' ||
        normalizedName.contains('chain shirt')) {
      return ArmorType.medium;
    }
    if (typeCode == 'ha' || typeCode == '4') return ArmorType.heavy;
    return ArmorType.light;
  }

  static List<String> _parseWeaponProperties(String raw) {
    if (raw.trim().isEmpty) return const [];
    final normalized = _normalizeLoose(raw);
    if (normalized == '512') return const ['versatile'];
    if (normalized == '260') return const ['heavy', 'two_handed'];

    final result = <String>[];
    for (final token in _splitList(raw)) {
      switch (token.trim().toUpperCase()) {
        case 'A':
          result.add('ammunition');
          break;
        case 'F':
          result.add('finesse');
          break;
        case 'H':
          result.add('heavy');
          break;
        case 'L':
          result.add('light');
          break;
        case 'LD':
          result.add('loading');
          break;
        case 'R':
          result.add('reach');
          break;
        case 'S':
          result.add('special');
          break;
        case 'T':
          result.add('thrown');
          break;
        case '2H':
          result.add('two_handed');
          break;
        case 'V':
          result.add('versatile');
          break;
        case 'M':
          result.add('monk');
          break;
        default:
          result.add(_stableId(token));
      }
    }
    return result.where((item) => item.isNotEmpty).toSet().toList();
  }

  static (int?, int?) _parseRange(String raw) {
    final values = RegExp(r'\d+')
        .allMatches(raw)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    return (values.elementAtOrNull(0), values.elementAtOrNull(1));
  }

  static ItemRarity _itemRarityFromText(String raw) {
    final normalized = _normalizeLoose(raw);
    switch (normalized) {
      case 'uncommon':
        return ItemRarity.uncommon;
      case 'rare':
        return ItemRarity.rare;
      case 'very rare':
      case 'very_rare':
        return ItemRarity.veryRare;
      case 'legendary':
        return ItemRarity.legendary;
      case 'artifact':
        return ItemRarity.artifact;
      default:
        return ItemRarity.common;
    }
  }

  static String _sizeFromText(String raw) {
    switch (_normalizeLoose(raw)) {
      case 't':
        return 'Tiny';
      case 's':
        return 'Small';
      case 'l':
        return 'Large';
      case 'h':
        return 'Huge';
      case 'g':
        return 'Gargantuan';
      case 'm':
      case '':
        return 'Medium';
      default:
        return _titleCase(raw);
    }
  }

  static bool _isCurrencyItem(XmlElement node) {
    final typeCode = _normalizeLoose(_getTag(node, 'type'));
    final name = _normalizeLoose(_getTag(node, 'name'));
    return typeCode == r'$' ||
        typeCode == '15' ||
        name.contains('gold') ||
        name.contains('gp') ||
        name.contains('silver') ||
        name.contains('sp') ||
        name.contains('copper') ||
        name.contains('cp') ||
        name.contains('platinum') ||
        name.contains('pp');
  }

  static _ParsedInventory _currencyFromItem(XmlElement node) {
    final name = _normalizeLoose(_getTag(node, 'name'));
    final quantity = _parseInt(_getTag(node, 'quantity')) ?? 0;
    if (name.contains('copper') || name.contains('cp')) {
      return _ParsedInventory(copperPieces: quantity);
    }
    if (name.contains('silver') || name.contains('sp')) {
      return _ParsedInventory(silverPieces: quantity);
    }
    if (name.contains('platinum') || name.contains('pp')) {
      return _ParsedInventory(platinumPieces: quantity);
    }
    return _ParsedInventory(goldPieces: quantity);
  }

  static bool _hasNonWhitespaceText(XmlElement node) {
    return node.innerText.trim().isNotEmpty;
  }

  static String _entityId(String name, String kind, String? sourceId) {
    if (sourceId == null) return _uuid.v4();
    if (sourceId == _defaultSourceId &&
        (kind == 'race' || kind == 'class' || kind == 'background')) {
      return name.toLowerCase().trim();
    }
    return 'fc5_${_stableId(sourceId)}_${kind}_${_stableId(name)}';
  }

  static String _stableId(String value) {
    final normalized = value.toLowerCase().trim();
    final buffer = StringBuffer();
    var previousWasSeparator = false;
    for (final rune in normalized.runes) {
      final char = String.fromCharCode(rune);
      final isAsciiLetter = rune >= 97 && rune <= 122;
      final isDigit = rune >= 48 && rune <= 57;
      final isCyrillic = (rune >= 0x0400 && rune <= 0x04FF);
      if (isAsciiLetter || isDigit || isCyrillic) {
        buffer.write(char);
        previousWasSeparator = false;
      } else if (!previousWasSeparator) {
        buffer.write('_');
        previousWasSeparator = true;
      }
    }
    return buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _normalizeLoose(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp(r'[А-Яа-яЁё]').hasMatch(trimmed)) return trimmed;
    const smallWords = {'of', 'the', 'and', 'or', 'a', 'an', 'to', 'in'};
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.asMap().entries.map((entry) {
      final index = entry.key;
      final part = entry.value;
      if (part.isEmpty) return part;
      final lower = part.toLowerCase();
      if (index > 0 && smallWords.contains(lower)) return lower;
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
  }

  static void _addUnique<T>(List<T> target, T value) {
    if (!target.contains(value)) target.add(value);
  }

  static void _addAllUnique<T>(List<T> target, Iterable<T> values) {
    for (final value in values) {
      _addUnique(target, value);
    }
  }

  static void _addFeature(
      List<CharacterFeature> target, CharacterFeature value) {
    final key = _stableId('${value.associatedClass ?? ''}:${value.nameEn}');
    final exists = target.any(
      (feature) =>
          _stableId('${feature.associatedClass ?? ''}:${feature.nameEn}') ==
          key,
    );
    if (!exists) target.add(value);
  }

  static void _addFeatures(
    List<CharacterFeature> target,
    Iterable<CharacterFeature> values,
  ) {
    for (final value in values) {
      _addFeature(target, value);
    }
  }

  static void _mergeHydrationDiagnostics(
    FC5ParseDiagnostics diagnostics,
    Iterable<FeatureHydrationDiagnostic> entries,
  ) {
    for (final entry in entries) {
      switch (entry.severity) {
        case FeatureHydrationDiagnosticSeverity.warning:
          diagnostics.warning(
            entry.code,
            entry.message,
            context: entry.context,
          );
          break;
        case FeatureHydrationDiagnosticSeverity.info:
          diagnostics.info(
            entry.code,
            entry.message,
            context: entry.context,
          );
          break;
      }
    }
  }
}

class _ParsedHitPoints {
  final int max;
  final int current;
  final int temporary;

  const _ParsedHitPoints({
    required this.max,
    required this.current,
    required this.temporary,
  });
}

class _ParsedRaceInfo {
  final String name;
  final int speed;
  final String? appearance;
  final String? age;
  final String? height;
  final String? weight;
  final String? eyes;
  final String? skin;
  final String? hair;
  final List<CharacterFeature> features;

  const _ParsedRaceInfo({
    required this.name,
    this.speed = 30,
    this.appearance,
    this.age,
    this.height,
    this.weight,
    this.eyes,
    this.skin,
    this.hair,
    this.features = const [],
  });
}

class _ParsedBackgroundInfo {
  final String? name;
  final List<String> skills;
  final List<String> expertSkills;
  final List<CharacterFeature> features;

  const _ParsedBackgroundInfo({
    this.name,
    this.skills = const [],
    this.expertSkills = const [],
    this.features = const [],
  });
}

class _ParsedCharacterClasses {
  final List<CharacterClass> classes;
  final List<XmlElement> classNodes;
  final List<String> skills;
  final List<String> savingThrows;
  final List<String> expertSkills;
  final List<int> hitDice;
  final List<CharacterFeature> features;

  const _ParsedCharacterClasses({
    required this.classes,
    required this.classNodes,
    required this.skills,
    required this.savingThrows,
    required this.expertSkills,
    required this.hitDice,
    required this.features,
  });
}

class _ParsedInventory {
  final List<Item> items;
  final int copperPieces;
  final int silverPieces;
  final int goldPieces;
  final int platinumPieces;

  const _ParsedInventory({
    this.items = const [],
    this.copperPieces = 0,
    this.silverPieces = 0,
    this.goldPieces = 0,
    this.platinumPieces = 0,
  });
}

class _ParsedSpellSelection {
  final List<String> knownSpells;
  final List<String> preparedSpells;
  final int maxPreparedSpells;

  const _ParsedSpellSelection({
    required this.knownSpells,
    required this.preparedSpells,
    required this.maxPreparedSpells,
  });
}

class _ParsedCharacterProficiencies {
  final List<String> skillIds;
  final List<String> skillValuesForCharacter;
  final List<String> expertSkills;
  final List<String> savingThrows;

  const _ParsedCharacterProficiencies({
    this.skillIds = const [],
    this.skillValuesForCharacter = const [],
    this.expertSkills = const [],
    this.savingThrows = const [],
  });
}

class _ParsedClassProficiencies {
  final List<String> savingThrows;
  final List<String> skillIds;
  final ArmorProficiencies armor;
  final WeaponProficiencies weapons;

  const _ParsedClassProficiencies({
    required this.savingThrows,
    required this.skillIds,
    required this.armor,
    required this.weapons,
  });
}

class _ParsedSpellComponents {
  final List<String> components;
  final String? materials;
  final String? materialsRu;

  const _ParsedSpellComponents({
    required this.components,
    this.materials,
    this.materialsRu,
  });
}

class _ClassNameParts {
  final String base;
  final String? subclass;

  const _ClassNameParts({
    required this.base,
    this.subclass,
  });
}

class _FC5ImageDataDefinition {
  final String encoded;
  final String? encoding;
  final String? mimeType;
  final String? format;

  const _FC5ImageDataDefinition({
    required this.encoded,
    this.encoding,
    this.mimeType,
    this.format,
  });
}

extension _StringFc5Parsing on String {
  String? get emptyToNull {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
