import '../magic/spell_preparation_rules.dart';
import '../models/character.dart';
import '../progression/character_class_rules.dart';
import 'gameplay_actions_service.dart';
import 'storage_service.dart';

class SpellPreparationRulesService {
  static Future<void> save(
          Character hero, String classId, SpellPreparationRules rules,
          {required String expectedDigest,
          required int expectedLevel,
          required String? expectedSubclass,
          Future<void> Function(Character)? write}) =>
      GameplayActionsService.serializeCharacter(hero, () async {
        final entry = hero.classes.where((c) => c.id == classId).single;
        final owned = CharacterClassRules.resolve(entry);
        if (owned.snapshot['digest'] != expectedDigest ||
            entry.level != expectedLevel ||
            entry.subclass != expectedSubclass) {
          throw StateError(
              'The class changed while its magic rules were open.');
        }
        final raw = owned.data.rulesMetadata['spellPreparation'];
        if (owned.data.rulesMetadata.containsKey('spellPreparation') && SpellPreparationRules.fromJson(raw) == null) {
          throw UnsupportedError('Preserve unsupported preparation rules.');
        }
        if (owned.data.rulesEdition != '2014' ||
            owned.data.spellcasting == null ||
            SpellPreparationRules.fromJson(rules.toJson()) == null) {
          throw StateError('Explicit supported spellcasting rules are needed.');
        }
        final before = entry.rulesSnapshot, timestamp = hero.updatedAt;
        try {
          owned.withMetadata({
            ...owned.data.rulesMetadata,
            'spellPreparation': rules.toJson()
          }).attachTo(entry);
          await (write ?? StorageService.saveCharacter)(hero);
        } catch (_) {
          entry.rulesSnapshot = before;
          hero.updatedAt = timestamp;
          rethrow;
        }
      });
}
