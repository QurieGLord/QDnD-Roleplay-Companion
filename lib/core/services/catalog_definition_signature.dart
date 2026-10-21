import 'dart:convert';

/// Compares definitions inside one source, ignoring only root identity and
/// provenance. Nested IDs can refer to mechanics and remain significant.
class CatalogDefinitionSignature {
  static String of(Map<String, dynamic> data) {
    dynamic canonical(dynamic value, {bool root = false}) {
      if (value is Map) {
        final keys = value.keys
            .map((k) => k.toString())
            .where((k) =>
                !{'sourceId', 'exportPolicy'}.contains(k) &&
                !(root && k == 'id'))
            .toList()
          ..sort();
        return {for (final key in keys) key: canonical(value[key])};
      }
      if (value is List) return value.map((v) => canonical(v)).toList();
      return value;
    }

    return jsonEncode(canonical(data, root: true));
  }
}
