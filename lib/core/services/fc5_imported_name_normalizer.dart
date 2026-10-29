class FC5ImportedNameNormalization {
  const FC5ImportedNameNormalization({
    required this.displayName,
    required this.isOptional,
  });

  final String displayName;
  final bool isOptional;
}

class FC5ImportedNameNormalizer {
  static final RegExp _leadingOptionalMarker = RegExp(
    r'^\s*(?:\[(?:optional|опционально)\]|\((?:optional|опционально|опциональное)\))\s*',
    caseSensitive: false,
  );

  static final RegExp _trailingOptionalMarker = RegExp(
    r'\s*(?:\[(?:optional|опционально)\]|\((?:optional|опционально|опциональное)\))\s*$',
    caseSensitive: false,
  );

  static FC5ImportedNameNormalization normalize(
    String raw, {
    bool optional = false,
  }) {
    var value = _collapseWhitespace(raw);
    var isOptional = optional;
    var changed = true;

    while (changed && value.isNotEmpty) {
      changed = false;
      final leading = _leadingOptionalMarker.firstMatch(value);
      if (leading != null) {
        value = value.substring(leading.end);
        isOptional = true;
        changed = true;
      }

      final trailing = _trailingOptionalMarker.firstMatch(value);
      if (trailing != null) {
        value = value.substring(0, trailing.start);
        isOptional = true;
        changed = true;
      }

      value = _collapseWhitespace(value);
    }

    return FC5ImportedNameNormalization(
      displayName: value,
      isOptional: isOptional,
    );
  }

  static String normalizedDisplayName(String raw) => normalize(raw).displayName;

  /// FC5 compilations tag newer-rules entries in the name itself, as
  /// «Fireball [5.5e]» or «Druid [5.5e] (Circle of the Sea)»; earlier builds
  /// wrote «[2024]». The tag names the rules edition, not the entry.
  static final RegExp _editionTag = RegExp(
    r'\s*\[(5\.5e|2024|5e|2014)\](?=\s|$|[(:,])',
    caseSensitive: false,
  );

  /// [raw] without its edition tags, and the edition they name: '2024' or
  /// '2014', null when untagged. IDs keep being built from the tagged name.
  static ({String name, String? edition}) splitEdition(String raw) {
    String? edition;
    final name = raw.replaceAllMapped(_editionTag, (m) {
      final tag = m.group(1)!.toLowerCase();
      edition ??= tag == '5.5e' || tag == '2024' ? '2024' : '2014';
      return '';
    });
    return (name: _collapseWhitespace(name), edition: edition);
  }

  /// The display name of a tagged entry: [splitEdition] without the edition.
  static String withoutEdition(String raw) => splitEdition(raw).name;

  static String _collapseWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
