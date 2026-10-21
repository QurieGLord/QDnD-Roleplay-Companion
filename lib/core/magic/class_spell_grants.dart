import '../models/character.dart';
import '../models/spell.dart';
import '../progression/character_class_context.dart';
import '../services/feature_service.dart';
import '../services/spell_service.dart';
import 'spellbook_state.dart';

/// SRD 5.1 personal subclass lists. Expanded lists are choices, not learned spells.
class ClassSpellGrants {
  static const _life = {
    1: ['bless', 'cure-wounds'],
    3: ['lesser-restoration', 'spiritual-weapon'],
    5: ['beacon-of-hope', 'revivify'],
    7: ['death-ward', 'guardian-of-faith'],
    9: ['mass-cure-wounds', 'raise-dead']
  };
  static const _devotion = {
    3: ['protection-from-evil-and-good', 'sanctuary'],
    5: ['lesser-restoration', 'zone-of-truth'],
    9: ['beacon-of-hope', 'dispel-magic'],
    13: ['freedom-of-movement', 'guardian-of-faith'],
    17: ['commune', 'flame-strike']
  };
  static const _fiend = {
    1: ['burning-hands', 'command'],
    3: ['blindness-deafness', 'scorching-ray'],
    5: ['fireball', 'stinking-cloud'],
    7: ['fire-shield', 'wall-of-fire'],
    9: ['flame-strike', 'hallow']
  };
  static const _land = {
    'arctic': {
      3: ['hold-person', 'spike-growth'],
      5: ['sleet-storm', 'slow'],
      7: ['freedom-of-movement', 'ice-storm'],
      9: ['commune-with-nature', 'cone-of-cold']
    },
    'coast': {
      3: ['mirror-image', 'misty-step'],
      5: ['water-breathing', 'water-walk'],
      7: ['control-water', 'freedom-of-movement'],
      9: ['conjure-elemental', 'scrying']
    },
    'desert': {
      3: ['blur', 'silence'],
      5: ['create-food-and-water', 'protection-from-energy'],
      7: ['blight', 'hallucinatory-terrain'],
      9: ['insect-plague', 'wall-of-stone']
    },
    'forest': {
      3: ['barkskin', 'spider-climb'],
      5: ['call-lightning', 'plant-growth'],
      7: ['divination', 'freedom-of-movement'],
      9: ['commune-with-nature', 'tree-stride']
    },
    'grassland': {
      3: ['invisibility', 'pass-without-trace'],
      5: ['daylight', 'haste'],
      7: ['divination', 'freedom-of-movement'],
      9: ['dream', 'insect-plague']
    },
    'mountain': {
      3: ['spider-climb', 'spike-growth'],
      5: ['lightning-bolt', 'meld-into-stone'],
      7: ['stone-shape', 'stoneskin'],
      9: ['passwall', 'wall-of-stone']
    },
    'swamp': {
      3: ['darkness', 'acid-arrow'],
      5: ['water-walk', 'stinking-cloud'],
      7: ['freedom-of-movement', 'locate-creature'],
      9: ['insect-plague', 'scrying']
    },
    'underdark': {
      3: ['spider-climb', 'web'],
      5: ['gaseous-form', 'stinking-cloud'],
      7: ['greater-invisibility', 'stone-shape'],
      9: ['cloudkill', 'insect-plague']
    },
  };
  static Map<int, List<String>> _list(Character hero, String classId,
      {required bool expanded}) {
    final owner = CharacterClassContext(hero, classId),
        data = CharacterClassContext(hero, classId).definition;
    if (data?.sourceId != null ||
        data?.rulesMetadata['origin'] != 'bundled' ||
        data?.rulesEdition != '2014') {
      return {};
    }
    if (expanded) {
      return classId == 'warlock' &&
              FeatureService.matchesSubclass('fiend', owner.subclass)
          ? _fiend
          : {};
    }
    if (classId == 'cleric' &&
        FeatureService.matchesSubclass('life', owner.subclass)) {
      return _life;
    }
    if (classId == 'paladin' &&
        FeatureService.matchesSubclass('devotion', owner.subclass)) {
      return _devotion;
    }
    if (classId == 'druid' &&
        FeatureService.matchesSubclass('land', owner.subclass)) {
      for (final terrain in _land.keys) {
        if (hero.features.any((f) => f.id == 'circle-of-the-land-$terrain')) {
          return _land[terrain]!;
        }
      }
    }
    return {};
  }

  static List<String> ids(Character hero, String classId,
          {bool expanded = false, int? level}) =>
      [
        for (final entry in _list(hero, classId, expanded: expanded).entries)
          if (entry.key <=
              (level ?? CharacterClassContext(hero, classId).level))
            ...entry.value
      ];
  static int _revision = -1;
  static final _index = <String, Spell>{};
  static Spell? spell(String id) {
    if (_revision != SpellService.catalogRevision) {
      _revision = SpellService.catalogRevision;
      _index.clear();
      for (final s
          in SpellService.getAllSpells().where((s) => s.sourceId == null)) {
        _index.putIfAbsent(s.id.replaceAll(RegExp('[^a-z0-9]'), ''), () => s);
        _index.putIfAbsent(
            s.nameEn.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), ''),
            () => s);
      }
    }
    return _index[id.replaceAll(RegExp('[^a-z0-9]'), '')];
  }

  static List<Spell> expanded(Character hero, String classId) =>
      ids(hero, classId, expanded: true).map(spell).whereType<Spell>().toList();
  static void apply(Character hero, String classId) {
    final book = SpellbookState.read(hero.spellbookData);
    for (final id in ids(hero, classId)) {
      final value = spell(id);
      if (value == null) throw StateError('Missing granted spell: $id');
      book.addAlwaysPrepared('class:$classId', value.id);
    }
    hero.spellbookData = book.toJson();
    hero.knownSpells = {...hero.knownSpells, ...book.allKnown}.toList();
    hero.preparedSpells =
        {...hero.preparedSpells, ...book.allPrepared}.toList();
  }
}
