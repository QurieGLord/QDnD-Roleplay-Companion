import '../models/character.dart';
import '../services/gameplay_actions_service.dart';
import '../services/qdnd_bundle_codec.dart';
import '../services/storage_service.dart';
import 'level_up_draft.dart';
import 'advancement_history.dart';

/// Development uses the same queue as health, rest, casting and the journal.
class LevelUpCommit {
  static Future<void> apply(Character source,
      {required LevelUpDraft baseline,
      required Character result,
      bool Function()? validateContext,
      Future<void> Function(Character)? write}) {
    final proposed = QdndBundleCodec.cloneCharacter(result);
    return GameplayActionsService.serializeCharacter(source, () async {
      if (validateContext != null && !validateContext()) {
        throw StateError('catalogChanged');
      }
      if (!baseline.isCurrentFor(source)) {
        throw StateError('The character changed after the level-up preview.');
      }
      _validate(source, proposed, baseline.classId);
      final before = QdndBundleCodec.cloneCharacter(source);
      final timestamp = source.updatedAt;
      final oldHistory = source.advancementData;
      final history =
          AdvancementHistory.append(source, proposed, baseline.classId);
      try {
        _copyDevelopment(proposed, source);
        source.advancementData = history;
        await (write ?? StorageService.saveCharacter)(source);
      } catch (_) {
        _copyDevelopment(before, source);
        source.advancementData = oldHistory;
        source.updatedAt = timestamp;
        rethrow;
      }
    });
  }

  static void _validate(Character before, Character after, String classId) {
    if (after.id != before.id ||
        after.level != before.level + 1 ||
        after.level > 20 ||
        after.maxHp < 0 ||
        after.currentHp != before.currentHp ||
        after.classes.map((c) => c.id).toSet().length != after.classes.length ||
        after.classes.any((c) => c.level < 1) ||
        after.classes.fold<int>(0, (sum, c) => sum + c.level) != after.level) {
      throw StateError('Invalid development result.');
    }
    final previous = {for (final c in before.classes) c.id: c};
    for (final cls in after.classes) {
      final old = previous.remove(cls.id);
      if (cls.id == classId) {
        if (cls.level != (old?.level ?? 0) + 1 ||
            cls.isPrimary != (old?.isPrimary ?? false)) {
          throw StateError('Only the chosen class can advance by one.');
        }
      } else if (old == null ||
          cls.level != old.level ||
          cls.subclass != old.subclass ||
          cls.isPrimary != old.isPrimary) {
        throw StateError('Another class changed during development.');
      }
    }
    if (previous.isNotEmpty || !after.classes.any((c) => c.id == classId)) {
      throw StateError('Development lost a class.');
    }
  }

  // Copy only development-owned values. Journal/media, equipment, money, active
  // conditions, temporary health, form and combat history stay on the live sheet.
  static void _copyDevelopment(Character from, Character to) {
    to.level = from.level;
    to.classes = from.classes;
    to.subclass = from.subclass;
    to.maxHp = from.maxHp;
    to.currentHp = from.currentHp;
    to.abilityScores = from.abilityScores;
    to.hitDice = from.hitDice;
    to.maxHitDice = from.maxHitDice;
    to.features = from.features;
    to.proficientSkills = from.proficientSkills;
    to.expertSkills = from.expertSkills;
    to.savingThrowProficiencies = from.savingThrowProficiencies;
    to.magicData = from.magicData;
    to.spellbookData = from.spellbookData;
    to.knownSpells = from.knownSpells;
    to.preparedSpells = from.preparedSpells;
    to.maxPreparedSpells = from.maxPreparedSpells;
    to.spellSlots = from.spellSlots;
    to.maxSpellSlots = from.maxSpellSlots;
    to.spellMasterySpells = from.spellMasterySpells;
    to.signatureSpells = from.signatureSpells;
    to.signatureSpellsUsed = from.signatureSpellsUsed;
    to.favoredEnemies = from.favoredEnemies;
    to.naturalExplorers = from.naturalExplorers;
    to.channelDivinityCharges = from.channelDivinityCharges;
    to.wildShapeCharges = from.wildShapeCharges;
    to.armorClass = from.armorClass;
    to.armorClassOverride = from.armorClassOverride;
    to.usesAutomaticArmorClass = from.usesAutomaticArmorClass;
  }
}
