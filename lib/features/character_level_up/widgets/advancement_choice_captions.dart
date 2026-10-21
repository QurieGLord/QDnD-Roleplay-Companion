import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character_feature.dart';

/// Curated comparisons for verified bundled wording. Changed/homebrew rules
/// fall back to their own text, even when their IDs match a bundled option.
class AdvancementChoiceCaptions {
  static const _wording = <String, String>{
    'metamagic-careful-spell':
        '9314d122ada0ca013dd849eca901570ec3f75129cf8f01f8726301f4e6e76105',
    'metamagic-distant-spell':
        'd0d03333719bdf3cfe7821ddb0be6a0cde92be475382e161019eb134175b38a7',
    'metamagic-empowered-spell':
        '9ed8ca12dec63e287fa0819193e2bcf6666ba2cdc940601a71ceae5b63e6f6bf',
    'metamagic-extended-spell':
        '795972770b8ad7cbb14626640e0af6c7624f11c3c8cb3c36086a153514edeaf4',
    'metamagic-heightened-spell':
        '980503889051042c620e947c18e63180316d1f36ec47117c5d98989b9c2e2f32',
    'metamagic-quickened-spell':
        '30b0a4f3d010b304d3834516bbc7809c3fe727065b2497982822f1ce5ae50a2a',
    'metamagic-subtle-spell':
        '2f4495a359233697b2405417f4a42e75a3d08bdcefd21632957ec9808ad59ca8',
    'metamagic-twinned-spell':
        'affa75a594dc65f631cb061509dcffe38beffdbf9269ec4069d7fa0e13439d25',
  };
  static String? forFeature(CharacterFeature? feature, AppLocalizations l) {
    if (feature == null || !_wording.containsKey(feature.id)) return null;
    final digest = sha256
        .convert(utf8
            .encode('${feature.descriptionEn}\u0000${feature.descriptionRu}'))
        .toString();
    if (digest != _wording[feature.id]) return null;
    return switch (feature.id) {
      'metamagic-careful-spell' => l.advancementMetamagicCareful,
      'metamagic-distant-spell' => l.advancementMetamagicDistant,
      'metamagic-empowered-spell' => l.advancementMetamagicEmpowered,
      'metamagic-extended-spell' => l.advancementMetamagicExtended,
      'metamagic-heightened-spell' => l.advancementMetamagicHeightened,
      'metamagic-quickened-spell' => l.advancementMetamagicQuickened,
      'metamagic-subtle-spell' => l.advancementMetamagicSubtle,
      'metamagic-twinned-spell' => l.advancementMetamagicTwinned,
      _ => null,
    };
  }
}
