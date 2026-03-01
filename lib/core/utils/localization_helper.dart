import 'package:qd_and_d/l10n/app_localizations.dart';

class LocalizedFeature {
  final String name;
  final String description;

  const LocalizedFeature({
    required this.name,
    required this.description,
  });
}

class LocalizationHelper {
  /// Returns a localized name and description for a Fighting Style.
  /// If the ID does not match any known SRD Fighting Style, it provides a graceful fallback
  /// by returning the raw ID as the name and an empty string for the description.
  static LocalizedFeature getLocalizedFightingStyle(
      String id, AppLocalizations l10n) {
    switch (id.toUpperCase()) {
      case 'ARCHERY':
      case 'ARCHERY_FIGHTING_STYLE':
        return LocalizedFeature(
          name: l10n.fs_archery_name,
          description: l10n.fs_archery_desc,
        );
      case 'DEFENSE':
      case 'DEFENSE_FIGHTING_STYLE':
        return LocalizedFeature(
          name: l10n.fs_defense_name,
          description: l10n.fs_defense_desc,
        );
      case 'DUELING':
      case 'DUELING_FIGHTING_STYLE':
        return LocalizedFeature(
          name: l10n.fs_dueling_name,
          description: l10n.fs_dueling_desc,
        );
      case 'GREAT_WEAPON':
      case 'GREAT_WEAPON_FIGHTING':
        return LocalizedFeature(
          name: l10n.fs_great_weapon_name,
          description: l10n.fs_great_weapon_desc,
        );
      case 'PROTECTION':
      case 'PROTECTION_FIGHTING_STYLE':
        return LocalizedFeature(
          name: l10n.fs_protection_name,
          description: l10n.fs_protection_desc,
        );
      case 'TWO_WEAPON':
      case 'TWO_WEAPON_FIGHTING':
        return LocalizedFeature(
          name: l10n.fs_two_weapon_name,
          description: l10n.fs_two_weapon_desc,
        );
      default:
        // Graceful fallback for homebrew / missing translations
        return LocalizedFeature(
          name: id,
          description: '',
        );
    }
  }
}
