import 'package:flutter/material.dart';

import '../../../core/models/character.dart';
import '../../../core/models/character_feature.dart';
import '../../../core/progression/character_class_context.dart';
import '../../../core/services/feature_service.dart';
import '../../../shared/widgets/subclass_details_sheet.dart';
import 'abilities/abilities_tab_logic.dart';
import 'class_widgets/bard_inspiration_widget.dart';
import 'class_widgets/cleric_magic_widget.dart';
import 'class_widgets/druid_magic_widget.dart';
import 'class_widgets/fighter_combat_widget.dart';
import 'class_widgets/instrument/instrument_kit.dart' show subclassDisplayName;
import 'class_widgets/instrument/universal_kit_panel.dart';
import 'class_widgets/ki_tracker_widget.dart';
import 'class_widgets/paladin_divine_widget.dart';
import 'class_widgets/rage_control_widget.dart';
import 'class_widgets/ranger_survival_widget.dart';
import 'class_widgets/rogue_tools_widget.dart';
import 'class_widgets/shared/class_panel_deck.dart';
import 'class_widgets/sorcerer_magic_widget.dart';
import 'class_widgets/warlock_magic_widget.dart';
import 'class_widgets/wizard_magic_widget.dart';

/// The twelve classes drawn by their own instruments; any other class is
/// drawn by the universal kit.
const builtInClasses = {
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'fighter',
  'monk',
  'paladin',
  'ranger',
  'rogue',
  'sorcerer',
  'warlock',
  'wizard',
};

Widget _safeBuild(Widget Function() builder) {
  try {
    return builder();
  } catch (e) {
    debugPrint('Error building widget item: $e');
    return const SizedBox.shrink();
  }
}

bool _renderable(Widget widget) =>
    widget is! SizedBox ||
    widget.width != null ||
    widget.height != null ||
    widget.child != null;

/// The hero's class instruments (wave 2), one panel per class: shared by
/// the Magic tab and the combat arsenal, so an ability looks and behaves
/// the same in both.
List<ClassPanelEntry> buildClassPanels(BuildContext context, Character c,
    {required VoidCallback onChanged}) {
  final locale = Localizations.localeOf(context).languageCode;
  final logic = AbilitiesTabLogic(c);
  final allFeatures = c.features.where((f) {
    if (f.associatedClass == null ||
        FeatureService.classKey(f.associatedClass!) == 'optional') {
      return f.minLevel <= c.level;
    }
    final key = FeatureService.classKey(f.associatedClass!);
    final owner = CharacterClassContext(c, key);
    if (owner.entry == null && !builtInClasses.contains(key)) {
      return f.minLevel <= c.level;
    }
    return owner.canUseFeature(f);
  }).toList();

  // A class outside the built-in twelve (third-party, homebrew, an
  // import) is drawn by the universal kit from its own features.
  final kitClasses = <String, List<CharacterFeature>>{
    for (final entry in c.classes)
      if (!builtInClasses.contains(FeatureService.classKey(entry.id)))
        FeatureService.classKey(entry.id): c.features
            .where((f) =>
                f.associatedClass != null &&
                CharacterClassContext(c, FeatureService.classKey(entry.id))
                    .acceptsFeature(f) &&
                FeatureService.classKey(f.associatedClass!) != 'optional')
            .toList(),
  }..removeWhere((_, features) => features.isEmpty);

  // Deep Search for Class Widgets
  final monkKiFeature = logic.findFeatureDeep(allFeatures, ['ki']);
  final barbarianRageFeature = logic.findFeatureDeep(allFeatures, [
    'rage',
    'barbarian_rage',
  ]);
  final rogueSneakAttack = logic.findFeatureDeep(allFeatures, ['sneak_attack']);
  final bardInspiration = logic.findFeatureDeep(allFeatures, [
    'bardic_inspiration',
    'bardic-inspiration',
  ]);

  final fighterActionSurge = logic.findFeatureDeep(allFeatures, [
    'action_surge',
    'action surge',
  ]);
  final fighterSecondWind = logic.findFeatureDeep(allFeatures, [
    'second_wind',
    'second wind',
  ]);
  final fighterIndomitable =
      logic.findFeatureDeep(allFeatures, ['indomitable']);

  // Paladin Features
  final paladinLayOnHands = logic.findFeatureDeep(allFeatures, [
    'lay-on-hands',
    'lay_on_hands',
  ]);
  final paladinDivineSense = logic.findFeatureDeep(allFeatures, [
    'divine-sense',
    'divine_sense',
  ]);
  final paladinDivineSmite = logic.findFeatureDeep(allFeatures, [
    'divine-smite',
    'divine_smite',
  ]);
  final paladinChannelDivinity = logic.findFeatureDeep(allFeatures, [
    'channel-divinity',
    'channel_divinity',
  ]);

  // Ranger Features
  final primevalAwareness = logic.findFeatureDeep(allFeatures, [
    'primeval-awareness',
    'primeval_awareness',
  ]);

  // Sorcerer Features (Robust Search)
  final sorceryPoints = logic.findFeatureDeep(allFeatures, [
        'sorcery_points',
        'sorcery-points',
        'sorcery_point',
        'sorcery-point',
        'font_of_magic',
        'font-of-magic',
      ]) ??
      allFeatures
          .where(
            (f) =>
                f.resourcePool != null &&
                (f.nameEn.toLowerCase().contains('sorcery point') ||
                    f.nameRu.toLowerCase().contains(
                          'единицы чародейства',
                        ) ||
                    f.nameEn.toLowerCase().contains('font of magic') ||
                    f.nameRu.toLowerCase().contains('источник магии')),
          )
          .firstOrNull;

  final metamagicOptions = allFeatures
      .where(
        (f) =>
            (f.id).toLowerCase().contains('metamagic') ||
            f.nameEn.toLowerCase().contains('metamagic') ||
            f.nameRu.toLowerCase().contains('метамагия'),
      )
      .toList();

  final sorcererAncestry = allFeatures
      .where(
        (f) =>
            (f.id).toLowerCase().contains('dragon-ancestor') ||
            (f.id).toLowerCase().contains('draconic') ||
            (f.id).toLowerCase().contains('dragon') ||
            f.nameEn.toLowerCase().contains('draconic') ||
            f.nameRu.toLowerCase().contains('дракон'),
      )
      .toList();

  // Warlock Features
  final warlockPatron = logic.findFeatureDeep(allFeatures, [
    'patron',
    'fiend',
    'archfey',
    'great_old_one',
    'celestial',
    'hexblade',
    'fathomless',
    'genie',
    'undead',
  ]);
  final warlockPactBoon = logic.findFeatureDeep(allFeatures, [
    'pact-boon',
    'pact_boon',
    'pact-of-the-chain',
    'pact_of_the_chain',
    'pact-of-the-blade',
    'pact_of_the_blade',
    'pact-of-the-tome',
    'pact_of_the_tome',
    'pact-of-the-talismam',
    'pact_of_the_talismam',
  ]);
  final warlockInvocations = allFeatures
      .where(
        (f) =>
            (f.id).toLowerCase().contains('invocation') ||
            f.nameEn.toLowerCase().contains('invocation') ||
            f.nameRu.toLowerCase().contains('воззвание'),
      )
      .toList();

  List<CharacterFeature> paladinChannelSpells = [];
  if (paladinChannelDivinity != null) {
    paladinChannelSpells = allFeatures
        .where((f) {
          final id = (f.id).toLowerCase();
          final usageCost = (f.usageCostId ?? '').toLowerCase();
          return (id.startsWith('channel-divinity-') ||
                  id.startsWith('channel_divinity_')) ||
              (usageCost.contains('channel-divinity') ||
                  usageCost.contains('channel_divinity'));
        })
        .where((f) => f.id != paladinChannelDivinity.id)
        .toList();
  }

  final featuredModules = <ClassPanelEntry>[];

  void addFeaturedModule(String id, Widget panel) {
    if (_renderable(panel)) {
      final owner = CharacterClassContext(c, id);
      featuredModules.add(
        ClassPanelEntry(
          id: id,
          name: owner.name(locale),
          level: owner.level,
          subclass: subclassDisplayName(c, id, locale),
          onSubclass: () async {
            await showClassSubclassDetails(context, c, id);
            onChanged();
          },
          child: panel,
        ),
      );
    }
  }

  if (c.classLevel('monk') > 0) {
    addFeaturedModule(
      'monk',
      _safeBuild(() {
        final martialArts = logic.findFeatureDeep(allFeatures, [
          'martial_arts',
          'martial-arts',
        ]);
        if (monkKiFeature == null && martialArts == null) {
          return const SizedBox.shrink();
        }
        return KiTrackerWidget(
          character: c,
          kiFeature: monkKiFeature ??
              CharacterFeature(
                id: 'ki_fallback',
                nameEn: 'Ki',
                nameRu: 'Энергия Ци',
                descriptionEn: '',
                descriptionRu: '',
                type: FeatureType.resourcePool,
                minLevel: 2,
                resourcePool: ResourcePool(
                  currentUses: 0,
                  maxUses: 0,
                  recoveryType: RecoveryType.shortRest,
                ),
              ),
          onChanged: () => onChanged(),
        );
      }),
    );
  }

  if (c.classLevel('barbarian') > 0 && barbarianRageFeature != null) {
    addFeaturedModule(
      'barbarian',
      _safeBuild(
        () => RageControlWidget(
          character: c,
          rageFeature: barbarianRageFeature,
          onChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('rogue') > 0 && rogueSneakAttack != null) {
    addFeaturedModule(
      'rogue',
      _safeBuild(() => RogueToolsWidget(character: c)),
    );
  }

  if (c.classLevel('fighter') > 0 &&
      (fighterSecondWind != null ||
          fighterActionSurge != null ||
          fighterIndomitable != null)) {
    addFeaturedModule(
      'fighter',
      _safeBuild(
        () => FighterCombatWidget(
          character: c,
          secondWindFeature: fighterSecondWind,
          actionSurgeFeature: fighterActionSurge,
          indomitableFeature: fighterIndomitable,
          onChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('bard') > 0 && bardInspiration != null) {
    addFeaturedModule(
      'bard',
      _safeBuild(
        () => BardInspirationWidget(
          character: c,
          inspirationFeature: bardInspiration,
          onChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('paladin') > 0) {
    addFeaturedModule(
      'paladin',
      _safeBuild(() {
        if (paladinLayOnHands == null &&
            paladinDivineSense == null &&
            paladinChannelDivinity == null) {
          return const SizedBox.shrink();
        }
        return PaladinDivineWidget(
          character: c,
          layOnHands: paladinLayOnHands ??
              CharacterFeature(
                id: 'lay_on_hands_fallback',
                nameEn: 'Lay on Hands',
                nameRu: 'Наложение рук',
                descriptionEn: '',
                descriptionRu: '',
                type: FeatureType.resourcePool,
                minLevel: 1,
                resourcePool: ResourcePool(
                  currentUses: 0,
                  maxUses: 0,
                  recoveryType: RecoveryType.longRest,
                ),
              ),
          divineSense: paladinDivineSense,
          divineSmite: paladinDivineSmite,
          channelDivinityResource: paladinChannelDivinity,
          channelDivinitySpells: paladinChannelSpells,
          onChanged: () => onChanged(),
        );
      }),
    );
  }

  if (c.classLevel('sorcerer') > 0) {
    addFeaturedModule(
      'sorcerer',
      _safeBuild(() {
        if (sorceryPoints == null &&
            metamagicOptions.isEmpty &&
            sorcererAncestry.isEmpty) {
          return const SizedBox.shrink();
        }
        return SorcererMagicWidget(
          character: c,
          sorceryPoints: sorceryPoints,
          metamagic: metamagicOptions,
          ancestryFeatures: sorcererAncestry,
          onChanged: () => onChanged(),
        );
      }),
    );
  }

  if (c.classLevel('warlock') > 0) {
    addFeaturedModule(
      'warlock',
      _safeBuild(() {
        if (warlockPatron == null &&
            warlockPactBoon == null &&
            warlockInvocations.isEmpty) {
          return const SizedBox.shrink();
        }
        return WarlockMagicWidget(
          character: c,
          patron: warlockPatron,
          pactBoon: warlockPactBoon,
          invocations: warlockInvocations,
          onChanged: () => onChanged(),
        );
      }),
    );
  }

  if (c.classLevel('druid') > 0) {
    addFeaturedModule(
      'druid',
      _safeBuild(
        () => DruidMagicWidget(
          character: c,
          onStateChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('wizard') > 0) {
    addFeaturedModule(
      'wizard',
      _safeBuild(
        () => WizardMagicWidget(
          character: c,
          onStateChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('cleric') > 0) {
    addFeaturedModule(
      'cleric',
      _safeBuild(
        () => ClericMagicWidget(
          character: c,
          onStateChanged: () => onChanged(),
        ),
      ),
    );
  }

  if (c.classLevel('ranger') > 0) {
    addFeaturedModule(
      'ranger',
      _safeBuild(() {
        if (primevalAwareness == null &&
            c.favoredEnemies.isEmpty &&
            c.naturalExplorers.isEmpty &&
            c.beastName == null) {
          return const SizedBox.shrink();
        }
        return RangerSurvivalWidget(
          character: c,
          primevalAwareness: primevalAwareness,
          onChanged: () => onChanged(),
        );
      }),
    );
  }

  for (final MapEntry(key: id, value: features) in kitClasses.entries) {
    final level = CharacterClassContext(c, id).level;
    addFeaturedModule(
      id,
      _safeBuild(
        () => UniversalKitPanel(
          hero: c,
          classId: id,
          features: features
              .where(CharacterClassContext(c, id).canUseFeature)
              .toList(),
          locked: features.where((f) => f.minLevel > level).toList(),
          onChanged: () => onChanged(),
        ),
      ),
    );
  }
  return featuredModules;
}
