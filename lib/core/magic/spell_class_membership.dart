import '../models/spell.dart';
import '../services/feature_service.dart';
import '../services/fc5_content_identity_service.dart';

/// FC5 list annotations are restrictions, not disposable display suffixes.
class SpellClassMembership {
  static List<String> split(String value) {
    final result = <String>[];
    var start = 0, depth = 0;
    for (var i = 0; i < value.length; i++) {
      if (value[i] == '(') depth++;
      if (value[i] == ')' && depth > 0) depth--;
      if (depth == 0 && {',', ';', '\n'}.contains(value[i])) {
        final part = value.substring(start, i).trim();
        if (part.isNotEmpty) result.add(part);
        start = i + 1;
      }
    }
    final last = value.substring(start).trim();
    if (last.isNotEmpty) result.add(last);
    return result;
  }

  static ({bool matches, bool conditional}) check(
      Spell spell, Iterable<String> names, String? subclass) {
    final keys = names
        .where((v) => v.trim().isNotEmpty)
        .map(FC5ContentIdentityService.canonicalClassId)
        .toSet();
    var conditional = false;
    for (final token in spell.availableToClasses) {
      final match =
          RegExp(r'^\s*([^(:]+?)\s*(?:\((.*)\)|:(.*))?\s*$').firstMatch(token);
      if (match == null) continue;
      if (!keys.contains(
          FC5ContentIdentityService.canonicalClassId(match.group(1)!))) {
        continue;
      }
      final scope = (match.group(2) ?? match.group(3) ?? '').trim();
      if (scope.isEmpty) return (matches: true, conditional: false);
      if (subclass != null &&
          split(scope).any((v) =>
              FC5ContentIdentityService.canonicalSubclassName(v) ==
                  FC5ContentIdentityService.canonicalSubclassName(subclass) ||
              FeatureService.matchesSubclass(v, subclass))) {
        return (matches: true, conditional: false);
      }
      conditional = true;
    }
    return (matches: false, conditional: conditional);
  }
}
