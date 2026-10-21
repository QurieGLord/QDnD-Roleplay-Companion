import '../models/character.dart';
import '../models/spell.dart';
import '../services/feature_service.dart';
import '../services/spell_eligibility_service.dart';
import 'journal_search.dart';

enum AlmanacAvailability { all, now, classList, future, known }

enum AlmanacProperty { any, yes, no }

class SpellCatalogFilter {
  const SpellCatalogFilter({
    this.query = '',
    this.circle,
    this.school,
    this.classId,
    this.sourceId,
    this.concentration = AlmanacProperty.any,
    this.ritual = AlmanacProperty.any,
    this.availability = AlmanacAvailability.all,
    this.searchDescriptions = false,
  });
  final String query;
  final int? circle;
  final String? school, classId, sourceId;
  final AlmanacProperty concentration, ritual;
  final AlmanacAvailability availability;
  final bool searchDescriptions;
  SpellCatalogFilter copyWith({
    String? query,
    int? circle,
    bool clearCircle = false,
    String? school,
    bool clearSchool = false,
    String? classId,
    bool clearClass = false,
    String? sourceId,
    bool clearSource = false,
    AlmanacProperty? concentration,
    AlmanacProperty? ritual,
    AlmanacAvailability? availability,
    bool? searchDescriptions,
  }) =>
      SpellCatalogFilter(
        query: query ?? this.query,
        circle: clearCircle ? null : circle ?? this.circle,
        school: clearSchool ? null : school ?? this.school,
        classId: clearClass ? null : classId ?? this.classId,
        sourceId: clearSource ? null : sourceId ?? this.sourceId,
        concentration: concentration ?? this.concentration,
        ritual: ritual ?? this.ritual,
        availability: availability ?? this.availability,
        searchDescriptions: searchDescriptions ?? this.searchDescriptions,
      );

  bool get isActive =>
      query.trim().isNotEmpty ||
      circle != null ||
      school != null ||
      classId != null ||
      sourceId != null ||
      concentration != AlmanacProperty.any ||
      ritual != AlmanacProperty.any ||
      availability != AlmanacAvailability.all ||
      searchDescriptions;
  int get count => [
        circle,
        school,
        classId,
        sourceId,
        if (concentration != AlmanacProperty.any) concentration,
        if (ritual != AlmanacProperty.any) ritual,
        if (searchDescriptions) true,
      ].where((v) => v != null).length;
}

/// Search broadens words, never spell identity. Different books/IDs remain
/// distinct. The result order is deterministic, and rows can be built lazily.
class SpellCatalog {
  SpellCatalog(Iterable<Spell> spells) : spells = List.unmodifiable(spells);
  final List<Spell> spells;
  List<String> get classes => _values(
        spells.expand((s) => s.availableToClasses).map(FeatureService.classKey),
      );
  List<String> get schools =>
      _values(spells.map((s) => s.school.toLowerCase().trim()));
  List<String> get sources => _values(spells.map((s) => s.sourceId ?? ''));
  List<String> _values(Iterable<String> values) =>
      values.toSet().toList()..sort();

  List<Spell> select(
    SpellCatalogFilter f, {
    required String locale,
    Character? hero,
    Map<String, SpellEligibilityResult>? eligibility,
  }) {
    bool property(bool value, AlmanacProperty filter) => switch (filter) {
          AlmanacProperty.any => true,
          AlmanacProperty.yes => value,
          AlmanacProperty.no => !value,
        };
    final search = JournalSearch(f.query);
    final hasQuery = f.query.trim().isNotEmpty;
    final scored = <({Spell spell, int score})>[];
    for (final s in spells) {
      if (f.circle != null && s.level != f.circle ||
          f.school != null && s.school.toLowerCase().trim() != f.school ||
          f.sourceId != null && (s.sourceId ?? '') != f.sourceId ||
          f.classId != null &&
              !s.availableToClasses.any(
                (v) => FeatureService.classKey(v) == f.classId,
              ) ||
          !property(s.concentration, f.concentration) ||
          !property(s.ritual, f.ritual)) {
        continue;
      }
      if (hero != null && f.availability != AlmanacAvailability.all) {
        if (f.availability == AlmanacAvailability.known) {
          if (!hero.knownSpells.contains(s.id)) continue;
        } else {
          final access = eligibility?[s.id] ??
              SpellEligibilityService.checkEligibility(hero, s);
          final allowed = switch (f.availability) {
            AlmanacAvailability.now => access.canLearn,
            AlmanacAvailability.future => access.sources.any(
                (a) => a.state == SpellAccessState.future,
              ),
            AlmanacAvailability.classList => access.sources.any(
                (a) => {
                  SpellAccessState.available,
                  SpellAccessState.future,
                  SpellAccessState.conditional,
                }.contains(a.state),
              ),
            _ => true,
          };
          if (!allowed) continue;
        }
      }
      final fields = hasQuery
          ? <String>[
              s.getName(locale),
              s.nameEn,
              s.nameRu,
              ..._aliases('${s.nameEn} ${s.nameRu}'),
              if (f.searchDescriptions) ...[s.descriptionEn, s.descriptionRu],
            ]
          : const <String>[];
      final score = hasQuery ? search.score(fields) : 1;
      if (score > 0) scored.add((spell: s, score: score));
    }
    scored.sort((a, b) {
      if (f.query.trim().isNotEmpty && a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      final circle = a.spell.level.compareTo(b.spell.level);
      if (circle != 0) return circle;
      final name = a.spell
          .getName(locale)
          .toLowerCase()
          .compareTo(b.spell.getName(locale).toLowerCase());
      if (name != 0) return name;
      final source = (a.spell.sourceId ?? '').compareTo(b.spell.sourceId ?? '');
      return source != 0 ? source : a.spell.id.compareTo(b.spell.id);
    });
    return scored.map((v) => v.spell).toList();
  }

  static final _terms = [
    'fire flame fiery огонь огненный пламя',
    'heal healing cure исцеление лечение лечить',
    'cold frost ice холод мороз лед ледяной',
    'poison venom яд ядовитый',
    'armor armour броня доспех',
    'shield щит',
    'invisible invisibility невидимость невидимый',
    'summon conjure призыв вызов призывать',
    'teleport телепортация телепорт',
  ];
  static final _groups = [
    for (final line in _terms) JournalSearch.tokens(line).toList(),
  ];
  static Iterable<String> _aliases(String name) sync* {
    final roots = JournalSearch.tokens(name).map(JournalSearch.stem).toSet();
    for (final g in _groups) {
      if (g.any((t) => roots.contains(JournalSearch.stem(t)))) {
        yield g.join(' ');
      }
    }
  }
}
