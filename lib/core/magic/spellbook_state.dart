import 'dart:convert';

import '../models/character.dart';

/// Additive ownership. Flat legacy lists remain the compatibility projection;
/// reading old sheets never guesses an owner or writes a migration.
class SpellbookState {
  SpellbookState._(this._data);
  final Map<String, dynamic> _data;
  factory SpellbookState.read(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return SpellbookState._({'version': 1, 'sources': <String, dynamic>{}});
    }
    final copy = Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
    if (copy['version'] != 1 || copy['sources'] is! Map) {
      throw const FormatException('Unsupported spellbook data.');
    }
    for (final entry in (copy['sources'] as Map).entries) {
      if (entry.key is! String ||
          (entry.key as String).isEmpty ||
          entry.value is! Map) {
        throw const FormatException('Invalid spell source.');
      }
      for (final key in [
        'known',
        'prepared',
        'alwaysPrepared',
        'ritualOnly',
        'unrestricted'
      ]) {
        final v = (entry.value as Map)[key];
        if (v != null &&
            (v is! List || v.any((id) => id is! String || id.isEmpty))) {
          throw const FormatException('Invalid owned spell list.');
        }
      }
    }
    return SpellbookState._(copy);
  }
  Iterable<String> get sources => (_data['sources'] as Map).keys.cast<String>();
  Set<String> ids(String source, String list) => Set<String>.from(
        ((_data['sources'] as Map)[source] as Map?)?[list] as List? ?? [],
      );
  Set<String> all(String list) => sources.expand((s) => ids(s, list)).toSet();
  Set<String> get allKnown => {
        ...all('known'),
        ...all('prepared'),
        ...all('alwaysPrepared'),
        ...all('ritualOnly'),
      };
  Set<String> get allPrepared => {...all('prepared'), ...all('alwaysPrepared')};
  List<String> ownersOf(String spellId) => sources
      .where(
        (s) =>
            ids(s, 'known').contains(spellId) ||
            ids(s, 'prepared').contains(spellId) ||
            ids(s, 'alwaysPrepared').contains(spellId) ||
            ids(s, 'ritualOnly').contains(spellId),
      )
      .toList();
  bool knows(String source, String id) => ownersOf(id).contains(source);
  Set<String> unassignedKnown(Character hero) =>
      hero.knownSpells.toSet().difference(allKnown);
  Set<String> unassignedPrepared(Character hero) =>
      hero.preparedSpells.toSet().difference(allPrepared);
  void setKnown(String source, String id, bool known) {
    if (source.trim().isEmpty || id.trim().isEmpty) {
      throw ArgumentError('Empty spell identity.');
    }
    final lists = Map<String, dynamic>.from(
      (_data['sources'] as Map)[source] as Map? ?? {},
    );
    final values = ids(source, 'known');
    if (known) {
      values.add(id);
    } else {
      values.remove(id);
      // Always-prepared gifts are not ordinary learned entries.
      if (ids(source, 'alwaysPrepared').contains(id)) {
        throw StateError(
          'Always-prepared spells belong to their granting feature.',
        );
      }
      lists['prepared'] = ids(
        source,
        'prepared',
      ).where((s) => s != id).toList();
      lists['unrestricted'] =
          ids(source, 'unrestricted').where((s) => s != id).toList();
    }
    lists['known'] = values.toList();
    (_data['sources'] as Map)[source] = lists;
  }

  void addAlwaysPrepared(String source, String id) {
    setKnown(source, id, true);
    final lists =
        Map<String, dynamic>.from((_data['sources'] as Map)[source] as Map);
    lists['alwaysPrepared'] = {...ids(source, 'alwaysPrepared'), id}.toList();
    (_data['sources'] as Map)[source] = lists;
  }

  void addRitual(String source, String id) {
    final lists = Map<String, dynamic>.from(
        (_data['sources'] as Map)[source] as Map? ?? {});
    lists['ritualOnly'] = {...ids(source, 'ritualOnly'), id}.toList();
    (_data['sources'] as Map)[source] = lists;
  }

  void addUnrestricted(String source, String id) {
    setKnown(source, id, true);
    final lists =
        Map<String, dynamic>.from((_data['sources'] as Map)[source] as Map);
    lists['unrestricted'] = {...ids(source, 'unrestricted'), id}.toList();
    (_data['sources'] as Map)[source] = lists;
  }

  void bindArcanum(String source, int circle, String id) {
    setKnown(source, id, true);
    final lists =
        Map<String, dynamic>.from((_data['sources'] as Map)[source] as Map);
    lists['arcanum'] = {
      ...Map<String, dynamic>.from(lists['arcanum'] as Map? ?? {}),
      '$circle': id
    };
    (_data['sources'] as Map)[source] = lists;
  }

  void setPrepared(String source, String id, bool prepared) {
    if (!knows(source, id)) {
      throw StateError('Spell must belong to this source first.');
    }
    if (ids(source, 'alwaysPrepared').contains(id)) {
      throw StateError('This spell is always prepared.');
    }
    final lists = Map<String, dynamic>.from(
      (_data['sources'] as Map)[source] as Map,
    );
    final values = ids(source, 'prepared');
    if (prepared) {
      values.add(id);
    } else {
      values.remove(id);
    }
    lists['prepared'] = values.toList();
    (_data['sources'] as Map)[source] = lists;
  }

  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(_data)) as Map);

  /// Remap identities without merging independent class sources by name.
  Map<String, dynamic> remap({
    required String Function(String) spell,
    required String Function(String) classId,
  }) {
    final result = toJson();
    final mapped = <String, dynamic>{};
    for (final source in sources) {
      final key = source.startsWith('class:')
          ? 'class:${classId(source.substring(6))}'
          : source;
      if (mapped.containsKey(key)) {
        throw const FormatException('Spell source collision.');
      }
      final lists = Map<String, dynamic>.from(
        (result['sources'] as Map)[source] as Map,
      );
      for (final list in [
        'known',
        'prepared',
        'alwaysPrepared',
        'ritualOnly',
        'unrestricted'
      ]) {
        if (lists[list] != null) {
          lists[list] =
              (lists[list] as List).cast<String>().map(spell).toSet().toList();
        }
      }
      if (lists['arcanum'] is Map) {
        lists['arcanum'] = {
          for (final e in (lists['arcanum'] as Map).entries)
            e.key: spell(e.value as String)
        };
      }
      mapped[key] = lists;
    }
    result['sources'] = mapped;
    if (result['contentReferences'] is Map) {
      final references = <String, dynamic>{};
      for (final entry in (result['contentReferences'] as Map).entries) {
        final key = spell(entry.key as String);
        if (references.containsKey(key)) {
          final first = references[key] as Map, next = entry.value as Map;
          if (first['variantKey'] != next['variantKey']) {
            throw const FormatException(
                'Conflicting spell reference variants.');
          }
          references[key] = {
            ...first,
            'originalIds': {
              ...?first['originalIds'] as List?,
              ...?next['originalIds'] as List?
            }.toList()
          };
        } else {
          references[key] = entry.value;
        }
      }
      result['contentReferences'] = references;
    }
    return result;
  }
}
