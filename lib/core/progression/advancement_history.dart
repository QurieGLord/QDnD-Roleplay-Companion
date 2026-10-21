import 'dart:convert';
import 'dart:math' as math;
import 'package:uuid/uuid.dart';
import '../models/character.dart';
import '../services/qdnd_bundle_codec.dart';
import '../services/qdnd_bundle_schema.dart';
import '../services/gameplay_actions_service.dart';
import '../services/storage_service.dart';
import 'progression_catalog_stamp.dart';
import 'character_class_rules.dart';
import 'feature_evolution.dart';
import 'character_class_context.dart';
import '../services/feature_service.dart';
import '../models/character_feature.dart';
import '../magic/spellbook_state.dart';

/// A sparse inverse of confirmed development, never a copy of the whole sheet.
/// Journal, inventory, money, active effects and current HP are not recorded.
class DevelopmentState {
  static const fields = {
    'level',
    'classes',
    'subclass',
    'maxHp',
    'abilityScores',
    'hitDice',
    'maxHitDice',
    'features',
    'proficientSkills',
    'expertSkills',
    'savingThrowProficiencies',
    'magicData',
    'spellbookData',
    'knownSpells',
    'preparedSpells',
    'maxPreparedSpells',
    'spellSlots',
    'maxSpellSlots',
    'spellMasterySpells',
    'signatureSpells',
    'signatureSpellsUsed',
    'favoredEnemies',
    'naturalExplorers',
    'channelDivinityCharges',
    'wildShapeCharges',
    'armorClass',
    'armorClassOverride',
    'usesAutomaticArmorClass',
  };
  static Map<String, dynamic> capture(Character hero) {
    final json = QdndBundleCodec.characterToJson(hero);
    final result = {for (final key in fields) key: json[key]};
    result['classes'] = {
      for (final c in hero.classes) c.id: jsonDecode(jsonEncode(c.toJson()))
    };
    final features = <String, dynamic>{},
        groups = <String, List<Map<String, dynamic>>>{};
    for (final raw in json['features'] as List) {
      final f = Map<String, dynamic>.from(raw as Map),
          definition = CharacterFeature.fromJson(f);
      final key =
          '${FeatureEvolution.key(definition)}|${f['associatedSubclass'] ?? ''}';
      groups.putIfAbsent(key, () => []).add(f);
    }
    for (final group in groups.entries) {
      final candidates = List<Map<String, dynamic>>.from(group.value);
      bool available(Map<String, dynamic> f) {
        final owner = f['associatedClass'];
        if (owner == null || FeatureService.classKey(owner) == 'optional') {
          return (f['minLevel'] as int) <= hero.level;
        }
        return CharacterClassContext(hero, FeatureService.classKey(owner))
            .canUseFeature(CharacterFeature.fromJson(f));
      }

      candidates.sort((a, b) {
        final usable = (available(b) ? 1 : 0) - (available(a) ? 1 : 0);
        return usable != 0
            ? usable
            : (b['minLevel'] as int).compareTo(a['minLevel'] as int);
      });
      final primary = candidates.first;
      features[group.key] = primary;
      var extra = 0;
      for (final f in group.value) {
        if (!identical(f, primary)) {
          features[
              '${group.key}|legacy:${f['id']}:${f['minLevel']}:${extra++}'] = f;
      }
        }
    }
    result['features'] = features;
    result['hitDice'] = {
      for (var i = 0; i < hero.classes.length; i++)
        hero.classes[i].id: i < hero.hitDice.length ? hero.hitDice[i] : 0
    };
    for (final field in ['spellSlots', 'maxSpellSlots']) {
      final values = json[field] as List;
      result[field] = {
        for (var i = 0; i < values.length; i++) '${i + 1}': values[i]
      };
    }
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(result)) as Map);
  }

  static Character materialize(Character live, Map<String, dynamic> state) {
    final json = QdndBundleCodec.characterToJson(live)
      ..['advancementData'] = <String, dynamic>{};
    for (final field in fields) {
      json[field] = state[field];
    }
    for (final field in ['spellbookData', 'magicData']) {
      final data = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(state[field])) as Map);
      if (data.isNotEmpty) {
        data['version'] ??= 1;
        if (field == 'spellbookData') data['sources'] ??= <String, dynamic>{};
      }
      json[field] = data;
    }
    final classes = state['classes'] as Map;
    json['classes'] = classes.values.toList();
    json['features'] = (state['features'] as Map).values.toList();
    json['hitDice'] = [
      for (final id in classes.keys) (state['hitDice'] as Map)[id] ?? 0
    ];
    for (final field in ['spellSlots', 'maxSpellSlots']) {
      final values = state[field] as Map;
      final length =
          values.keys.map((k) => int.parse(k as String)).fold<int>(0, math.max);
      json[field] = [for (var i = 1; i <= length; i++) values['$i'] ?? 0];
    }
    final result = QdndBundleCodec.characterFromJson(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map));
    result.spellSlots = List<int>.from(json['spellSlots'] as List);
    result.maxSpellSlots = List<int>.from(json['maxSpellSlots'] as List);
    return result;
  }

  static void copy(Character from, Character to) {
    to.level = from.level;
    to.classes = from.classes;
    to.subclass = from.subclass;
    to.maxHp = from.maxHp;
    to.abilityScores = from.abilityScores;
    to.hitDice = from.hitDice;
    to.maxHitDice = from.maxHitDice;
    to.features = from.features;
    to.proficientSkills = from.proficientSkills;
    to.expertSkills = from.expertSkills;
    to.savingThrowProficiencies = from.savingThrowProficiencies;
    to.magicData = from.magicData;
    to.spellbookData = from.spellbookData;
    to.knownSpells = from.knownSpells;
    to.preparedSpells = from.preparedSpells;
    to.maxPreparedSpells = from.maxPreparedSpells;
    to.spellSlots = from.spellSlots;
    to.maxSpellSlots = from.maxSpellSlots;
    to.spellMasterySpells = from.spellMasterySpells;
    to.signatureSpells = from.signatureSpells;
    to.signatureSpellsUsed = from.signatureSpellsUsed;
    to.favoredEnemies = from.favoredEnemies;
    to.naturalExplorers = from.naturalExplorers;
    to.channelDivinityCharges = from.channelDivinityCharges;
    to.wildShapeCharges = from.wildShapeCharges;
    to.armorClass = from.armorClass;
    to.armorClassOverride = from.armorClassOverride;
    to.usesAutomaticArmorClass = from.usesAutomaticArmorClass;
  }
}

class AdvancementRecord {
  AdvancementRecord._(this.json);
  final Map<String, dynamic> json;
  String get id => json['id'] as String;
  String get classId => json['classId'] as String;
  int get from => json['from'] as int;
  int get to => json['to'] as int;
  List get changes => json['changes'] as List;
  static AdvancementRecord create(
      Character before, Character after, String classId) {
    final b = DevelopmentState.capture(before),
        a = DevelopmentState.capture(after);
    final beforeClasses = b['classes'] as Map,
        afterClasses = a['classes'] as Map;
    for (final id in beforeClasses.keys) {
      if ((beforeClasses[id] as Map)['rulesSnapshot'] == null &&
          afterClasses[id] is Map &&
          (afterClasses[id] as Map)['rulesSnapshot'] != null) {
        // Pinning an existing class's rules repairs provenance; it is not a
        // level benefit to discard when reverting that level.
        (beforeClasses[id] as Map)['rulesSnapshot'] =
            (afterClasses[id] as Map)['rulesSnapshot'];
      }
    }
    if (before.usesAutomaticArmorClass && after.usesAutomaticArmorClass) {
      a['armorClass'] = b['armorClass'];
    }
    return _seal({
      'id': const Uuid().v4(),
      'classId': classId,
      'from': before.level,
      'to': after.level,
      'at': DateTime.now().toIso8601String(),
      'changes': _diff(b, a)
    });
  }

  static AdvancementRecord _seal(Map<String, dynamic> payload) =>
      AdvancementRecord._(
          {...payload, 'digest': ProgressionCatalogStamp.fingerprint(payload)});
  static AdvancementRecord read(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Invalid development history.');
    }
    final json = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map),
        payload = Map<String, dynamic>.from(jsonDecode(jsonEncode(raw)) as Map)
          ..remove('digest');
    if (json['id'] is! String ||
        json['classId'] is! String ||
        json['from'] is! int ||
        json['to'] != json['from'] + 1 ||
        json['from'] < 1 ||
        json['to'] > 20 ||
        json['changes'] is! List ||
        json['digest'] != ProgressionCatalogStamp.fingerprint(payload)) {
      throw const FormatException('Invalid development history.');
    }
    for (final change in json['changes'] as List) {
      if (change is! Map ||
          change['path'] is! List ||
          (change['path'] as List).isEmpty ||
          !(change['path'] as List).every((v) => v is String) ||
          !DevelopmentState.fields.contains((change['path'] as List).first) ||
          change['hadBefore'] is! bool ||
          change['hadAfter'] is! bool) {
        throw const FormatException('Invalid development patch.');
      }
    }
    return AdvancementRecord._(json);
  }

  static List<Map<String, dynamic>> _diff(Map before, Map after,
      [List<String> path = const []]) {
    final result = <Map<String, dynamic>>[];
    for (final key in {...before.keys, ...after.keys}) {
      final b = before[key], a = after[key], p = [...path, key as String];
      if (_same(b, a) && before.containsKey(key) == after.containsKey(key)) {
        continue;
      }
      if (a is Map &&
          (b is Map ||
              !before.containsKey(key) && p.first == 'spellbookData')) {
        result.addAll(_diff(b is Map ? b : {}, a, p));
        continue;
      }
      result.add({
        'path': p,
        'hadBefore': before.containsKey(key),
        'hadAfter': after.containsKey(key),
        'before': b,
        'after': a
      });
    }
    return result;
  }
}

bool _same(Object? a, Object? b) =>
    ProgressionCatalogStamp.fingerprint({'value': a}) ==
    ProgressionCatalogStamp.fingerprint({'value': b});

class AdvancementHistory {
  static List<AdvancementRecord> read(Character hero) {
    final data = hero.advancementData;
    if (data.isEmpty) return [];
    if (data['version'] != 1 ||
        data['entries'] is! List ||
        (data['entries'] as List).length > 19) {
      throw const FormatException('Unsupported development history.');
    }
    final records =
        (data['entries'] as List).map(AdvancementRecord.read).toList();
    if (records.map((r) => r.id).toSet().length != records.length) {
      throw const FormatException('Duplicate development history.');
    }
    for (var i = 1; i < records.length; i++) {
      if (records[i - 1].to != records[i].from) {
        throw const FormatException('Broken development history.');
    }
      }
    return records;
  }

  static Map<String, dynamic> append(
      Character before, Character after, String classId) {
    final entries = read(before);
    if (entries.isNotEmpty && entries.last.to != before.level) {
      throw StateError('Development history no longer matches this level.');
    }
    return {
      ...before.advancementData,
      'version': 1,
      'entries': [
        ...entries.map((r) => r.json),
        AdvancementRecord.create(before, after, classId).json
      ]
    };
  }

  static Map<String, dynamic> _clone(Map<String, dynamic> value) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  static Map _parent(Map root, List path) {
    var node = root;
    for (final key in path.take(path.length - 1)) {
      if (node[key] is! Map) {
        throw StateError('A later change conflicts with development rollback.');
      }
      node = node[key] as Map;
    }
    return node;
  }

  static bool _numericResource(List path) =>
      path.first == 'maxHp' ||
      path.first == 'maxPreparedSpells' ||
      path.first == 'abilityScores' ||
      path.first == 'hitDice' ||
      path.first == 'maxHitDice' ||
      path.first == 'spellSlots' ||
      path.first == 'maxSpellSlots' ||
      path.first == 'wildShapeCharges' ||
      path.first == 'channelDivinityCharges' ||
      path.contains('resourcePool') &&
          {'currentUses', 'maxUses'}.contains(path.last) ||
      path.first == 'magicData' &&
          path.contains('pact') &&
          {'current', 'maximum'}.contains(path.last);
  static void _reverse(Map state, Map change) {
    final path = change['path'] as List,
        parent = _parent(state, path),
        key = path.last;
    final b = change['before'], a = change['after'], live = parent[key];
    if (_numericResource(path) &&
        (b == null || b is int) &&
        (a == null || a is int) &&
        (live == null || live is int)) {
      final n = (live as int? ?? 0) + (b as int? ?? 0) - (a as int? ?? 0);
      if (path.first == 'abilityScores' && n < 1) {
        throw StateError('A later ability edit conflicts with rollback.');
      }
      if (change['hadBefore'] == false && n <= 0) {
        parent.remove(key);
      } else {
        parent[key] = math.max(0, n);
      }
    } else if (b == null &&
        a is Map &&
        (path.contains('resourcePool') ||
            path.first == 'magicData' && path.last == 'pact')) {
      if (path.last == 'pact' && live is Map && live['owner'] != a['owner']) {
        throw StateError('The Pact owner changed.');
      }
      if (change['hadBefore'] == true) {
        parent[key] = null;
      } else {
        parent.remove(key);
      }
    } else if ((b is List || !change['hadBefore']) &&
        a is List &&
        live is List) {
      final previous = b is List ? b : <dynamic>[];
      if (!_same(previous.toSet().length, previous.length) ||
          !_same(a.toSet().length, a.length)) {
        throw StateError('Ambiguous list changes.');
      }
      parent[key] = [
        ...live.where((v) =>
            !a.any((x) => _same(x, v)) || previous.any((x) => _same(x, v))),
        ...previous.where(
            (v) => !a.any((x) => _same(x, v)) && !live.any((x) => _same(x, v)))
      ];
    } else if (change['hadBefore'] == false) {
      // A newly acquired feature/class is removed; a later class level change
      // is never guessed away. Its removal is visible in the preview.
      if (path.first == 'classes' &&
          live is Map &&
          a is Map &&
          (live['level'] != a['level'] || live['isPrimary'] != a['isPrimary'])) {
        throw StateError('The class level changed.');
      }
      parent.remove(key);
    } else {
      if (!_same(live, a)) {
        throw StateError(
            'A later edit conflicts with this development choice.');
      }
      parent[key] = b;
    }
  }

  static RollbackPreview preview(Character live, String targetId) {
    final entries = read(live),
        index = entries.indexWhere((r) => r.id == targetId);
    if (index < 0 || entries.last.to != live.level) {
      throw StateError('No matching development checkpoint.');
    }
    final state = DevelopmentState.capture(live);
    for (final record in entries.sublist(index).reversed) {
      if (state['level'] != record.to) {
        throw StateError('The character level changed.');
      }
      for (final change in record.changes.reversed) {
        _reverse(state, change as Map);
      }
    }
    final magic = state['magicData'] as Map;
    if (magic.isNotEmpty) magic['version'] ??= 1;
    final bookData = state['spellbookData'] as Map;
    if (bookData.isNotEmpty) {
      bookData['version'] ??= 1;
      bookData['sources'] ??= <String, dynamic>{};
    }
    final result = DevelopmentState.materialize(live, state);
    if (result.level < 1 ||
        result.classes.fold<int>(0, (n, c) => n + c.level) != result.level ||
        result.classes.any((c) => c.level < 1)) {
      throw StateError('Invalid rollback result.');
    }
    // A removed class cannot leave a source-owned book entry behind, but other
    // sources of the same spell remain. Unrelated session state stays live.
    final sources = result.spellbookData['sources'];
    if (sources is Map) {
      sources.removeWhere((key, value) =>
          key is String &&
          key.startsWith('class:') &&
          !result.classes.any((c) => key == 'class:${c.id}'));
    }
    final book = SpellbookState.read(result.spellbookData),
        oldBook = SpellbookState.read(live.spellbookData);
    final removedSources = oldBook.sources.where((source) =>
        source.startsWith('class:') &&
        !result.classes.any((c) => source == 'class:${c.id}'));
    final removedIds = {
      for (final source in removedSources)
        for (final list in [
          'known',
          'prepared',
          'alwaysPrepared',
          'ritualOnly'
        ])
          ...oldBook.ids(source, list)
    };
    result.knownSpells = {
      ...result.knownSpells.where((id) => !removedIds.contains(id)),
      ...book.allKnown
    }.toList();
    result.preparedSpells = {
      ...result.preparedSpells.where((id) => !removedIds.contains(id)),
      ...book.allPrepared
    }.toList();
    result.advancementData = {
      ...live.advancementData,
      'version': 1,
      'entries': entries.take(index).map((r) => r.json).toList()
    };
    if (result.channelDivinityResources.isNotEmpty) {
      result.setChannelDivinityCharges(result.channelDivinityCharges);
    }
    result.recalculateAC();
    return RollbackPreview._(
        result,
        entries.length - index,
        ProgressionCatalogStamp.fingerprint(
            QdndBundleCodec.characterToJson(live)),
        targetId);
  }

  static Future<void> apply(Character hero, RollbackPreview preview,
          {Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        if (preview.baseline !=
            ProgressionCatalogStamp.fingerprint(
                QdndBundleCodec.characterToJson(hero))) {
          throw StateError('The character changed after the rollback preview.');
        }
        final verified =
            AdvancementHistory.preview(hero, preview.targetId).result;
        final before = QdndBundleCodec.cloneCharacter(hero),
            history = _clone(hero.advancementData),
            time = hero.updatedAt;
        try {
          DevelopmentState.copy(verified, hero);
          hero.advancementData = verified.advancementData;
          await (write ?? StorageService.saveCharacter)(hero);
        } catch (_) {
          DevelopmentState.copy(before, hero);
          hero.advancementData = history;
          hero.updatedAt = time;
          rethrow;
        }
      });

  /// Strip external source text from frozen rule definitions in exported
  /// patches, while preserving mechanical data and re-signing integrity.
  static Map<String, dynamic> forExport(Character hero) {
    Object? clean(Object? value) {
      if (value is Map) {
        if (value['version'] == 1 &&
            value['definition'] is Map &&
            value['features'] is List &&
            value.containsKey('digest')) {
          return CharacterClassRules.fromSnapshot(
                  Map<String, dynamic>.from(value))
              .forExport();
        }
        if (value['sourceId'] != null &&
            value.containsKey('nameEn') &&
            value.containsKey('descriptionEn')) {
          return QdndBundleCodec.featureToJson(
              CharacterFeature.fromJson(Map<String, dynamic>.from(value)),
              policy: QdndBundleExportPolicy.referenceOnly);
        }
        return value.map((key, v) => MapEntry(key, clean(v)));
      }
      if (value is List) return value.map(clean).toList();
      return value;
    }

    if (hero.advancementData.isEmpty) return {};
    return {
      'version': 1,
      'entries': [
        for (final r in read(hero))
          AdvancementRecord._seal(Map<String, dynamic>.from(clean({...r.json}
                ..remove('digest')
                ..['changes'] = [
                  for (final c in r.changes)
                    if (!((c['path'] as List).first == 'features' &&
                        {'descriptionEn', 'descriptionRu'}
                            .contains((c['path'] as List).last)))
                      c
                ]) as Map))
              .json
      ]
    };
  }

  /// Rebuild sparse patches from detached historical views so the native
  /// bundle's existing ID mapper also covers references used only by rollback.
  static List<Character> historicalViews(Character hero) {
    final records = read(hero);
    if (records.isEmpty) return [];
    final state = DevelopmentState.capture(hero), views = <Character>[];
    for (final r in records.reversed) {
      for (final after in [true, false]) {
        for (final change in r.changes) {
          final parent = _parent(state, change['path'] as List),
              key = (change['path'] as List).last;
          if (change[after ? 'hadAfter' : 'hadBefore'] == true) {
            parent[key] = change[after ? 'after' : 'before'];
          } else {
            parent.remove(key);
          }
        }
        views.add(DevelopmentState.materialize(hero, _clone(state)));
      }
    }
    return views;
  }

  static Map<String, dynamic> remap(
      Character hero, void Function(Character) mapper) {
    if (hero.advancementData.isEmpty) return {};
    final records = read(hero).reversed.toList(),
        views = historicalViews(hero),
        mapped = <AdvancementRecord>[];
    for (var i = 0; i < records.length; i++) {
      final after = views[i * 2], before = views[i * 2 + 1];
      final classIndex =
          after.classes.indexWhere((c) => c.id == records[i].classId);
      mapper(after);
      mapper(before);
      final payload = {...records[i].json}..remove('digest');
      if (classIndex >= 0) payload['classId'] = after.classes[classIndex].id;
      payload['changes'] = AdvancementRecord._diff(
          DevelopmentState.capture(before), DevelopmentState.capture(after));
      mapped.add(AdvancementRecord._seal(payload));
    }
    return {
      'version': 1,
      'entries': mapped.reversed.map((r) => r.json).toList()
    };
  }
}

class RollbackPreview {
  RollbackPreview._(this.result, this.count, this.baseline, this.targetId);
  final Character result;
  final int count;
  final String baseline, targetId;
}
