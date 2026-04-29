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

  static String _collapseWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
