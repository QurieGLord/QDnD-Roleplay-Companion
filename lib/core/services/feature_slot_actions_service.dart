import 'package:uuid/uuid.dart';
import '../magic/casting_constraints.dart';
import '../magic/magic_slots.dart';
import '../models/character.dart';
import '../models/character_feature.dart';
import '../models/combat_state.dart';
import '../progression/character_class_context.dart';
import '../progression/character_class_rules.dart';
import 'magic_resource_actions_service.dart';

/// An ability paid with a slot is not a spell cast. It uses its own eligibility
/// and the same payment transaction, rather than decrementing legacy arrays.
class FeatureSlotActionsService {
  static bool supportsPrimeval(Character hero, CharacterFeature feature) {
    final owner = CharacterClassContext(hero, 'ranger');
    return owner.level >= 3 &&
        owner.definition?.rulesEdition == '2014' &&
        owner.acceptsFeature(feature) &&
        feature.minLevel <= owner.level &&
        feature.id.replaceAll('_', '-') == 'primeval-awareness';
  }

  static Future<int> primevalAwareness(Character hero,
          {required String classId,
          required String featureId,
          required MagicPool pool,
          required int circle,
          required String locale,
          required String expectedRulesDigest,
          bool tableRuling = false,
          Future<void> Function(Character)? write}) =>
      MagicResourceActionsService.change(hero, () {
        final owner = CharacterClassContext(hero, classId);
        final entry = owner.entry;
        if (entry == null ||
            !identical(CharacterClassContext(hero, 'ranger').entry, entry) ||
            owner.level < 3 ||
            CharacterClassRules.resolve(entry).snapshot['digest'] !=
                expectedRulesDigest) {
          throw StateError('The feature owner changed.');
        }
        final features = hero.features
            .where((f) => f.id == featureId && owner.acceptsFeature(f))
            .toList();
        if (features.length != 1 ||
            features.single.minLevel > owner.level ||
            features.single.id.replaceAll('_', '-') != 'primeval-awareness' ||
            owner.definition?.rulesEdition != '2014' ||
            CastingConstraints.incapacitated(hero) ||
            (hero.isWildShaped && hero.beastCurrentHp != null
                    ? hero.beastCurrentHp!
                    : hero.currentHp) <=
                0) {
          throw StateError('This action is unavailable.');
        }
        // The source explicitly says a ranger slot. A Pact reserve needs an
        // explicit table ruling; it is never silently substituted for shared slots.
        if (pool == MagicPool.pact && !tableRuling) {
          throw StateError('Confirm the Pact payment ruling.');
        }
        MagicSlots.spendOn(hero, pool, circle);
        final name = features.single.getName(locale);
        final payment = pool == MagicPool.pact
            ? (locale == 'ru' ? 'Магия договора' : 'Pact Magic')
            : (locale == 'ru' ? 'общая ячейка' : 'shared slot');
        hero.combatState.addLogEntry(CombatLogEntry(
            id: const Uuid().v4(),
            timestamp: DateTime.now(),
            type: CombatLogType.other,
            description:
                '$name · $payment · $circle · ${locale == 'ru' ? '$circle мин.' : '$circle min'}',
            round: hero.combatState.currentRound));
        return circle;
      }, write: write);
}
