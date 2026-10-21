import 'dart:convert';
import 'dart:math' as math;

import '../models/ability_scores.dart';
import '../models/character.dart';
import '../models/character_class.dart';
import '../services/qdnd_bundle_codec.dart';
import 'resource_growth.dart';

/// A detached calculation, never a mutation or a save of the active sheet.
/// Rule-specific eligibility and choices are supplied by the progression flow.
class LevelUpDraft {
  LevelUpDraft._(this._original, this._result, this.classId, this._baseline);

  final Character _original;
  final Character _result;
  final String classId;
  final String _baseline;

  static Character _copy(Character source) {
    final result = QdndBundleCodec.cloneCharacter(source);
    // The bundle codec preserves the journal map by reference; a development
    // draft must not expose the original graph through its preview.
    result.journalData = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(source.journalData)) as Map);
    return result;
  }

  factory LevelUpDraft.begin(Character source,
      {required String classId, String? newClassName}) {
    if (source.level < 1 || source.level >= 20) {
      throw StateError('Character level must be between 1 and 19.');
    }
    if (source.classes.isEmpty ||
        source.classes.any((c) => c.level < 1 || c.id.isEmpty) ||
        source.classes.map((c) => c.id).toSet().length !=
            source.classes.length ||
        source.classes.fold<int>(0, (sum, c) => sum + c.level) !=
            source.level) {
      throw StateError('Class levels do not describe the current character.');
    }
    if (classId.isEmpty || classId.trim() != classId) {
      throw ArgumentError.value(classId, 'classId');
    }
    final original = _copy(source);
    final result = _copy(source);
    final index = result.classes.indexWhere((c) => c.id == classId);
    if (index == -1) {
      if (newClassName == null || newClassName.trim().isEmpty) {
        throw ArgumentError('A new class needs a resolved display name.');
      }
      result.classes.add(CharacterClass(
          id: classId, name: newClassName, level: 1, isPrimary: false));
    } else {
      result.classes[index].level++;
    }
    result.level++;
    return LevelUpDraft._(original, result, classId,
        jsonEncode(QdndBundleCodec.characterToJson(source)));
  }

  int get characterLevelBefore => _original.level;
  int get characterLevelAfter => _result.level;
  int get classLevelBefore => _original.classes
      .where((c) => c.id == classId)
      .fold(0, (sum, c) => sum + c.level);
  int get classLevelAfter => classLevelBefore + 1;

  /// The caller resolves the die value (a roll, fixed value or table exception).
  /// Replacing a choice recalculates from the original, never accumulates gains.
  void chooseHealth(int dieValue, {AbilityScores? abilityScores}) {
    if (dieValue < 1) {
      throw ArgumentError.value(dieValue, 'dieValue');
    }
    final scores = abilityScores ?? _original.abilityScores;
    final oldCon = _original.abilityScores.constitutionModifier;
    final newCon = scores.constitutionModifier;
    final gain = math.max(1, dieValue + newCon);
    final retroactive = (newCon - oldCon) * _original.level;
    final maximum = _original.maxHp + gain + retroactive;
    if (maximum < 0) {
      throw StateError('The resulting maximum HP cannot be negative.');
    }
    _result.abilityScores = scores.copyWith();
    _result.maxHp = maximum;
    // Levelling is not healing. This includes zero and an explicit overfill.
    _result.currentHp = _original.currentHp;
  }

  /// Shared spell slots only: Pact is a separate pool whose circle may move.
  /// The rule resolver supplies norms; this method does not guess caster type.
  void chooseSharedSlotMaximums(List<int> maximums) {
    if (maximums.length > 9 || maximums.any((value) => value < 0)) {
      throw ArgumentError.value(maximums, 'maximums');
    }
    final length = math.max(maximums.length,
        math.max(_original.spellSlots.length, _original.maxSpellSlots.length));
    if (length > 9) {
      throw StateError('Shared slots have more than nine circles.');
    }
    int at(List<int> values, int index) =>
        index < values.length ? values[index] : 0;
    final nextCurrent = [
      for (var i = 0; i < length; i++)
        ResourceGrowth.remaining(
            current: at(_original.spellSlots, i),
            oldMaximum: at(_original.maxSpellSlots, i),
            newMaximum: at(maximums, i))
    ];
    _result.spellSlots = nextCurrent;
    _result.maxSpellSlots = [for (var i = 0; i < length; i++) at(maximums, i)];
  }

  /// Class advancement without previous health/slot/ability selections.
  Character get classPreview {
    final result = _copy(_original);
    result.level = _result.level;
    result.classes = _result.classes
        .map((c) => CharacterClass.fromJson(c.toJson()))
        .toList();
    return result;
  }

  /// Return another detached copy so rendering cannot alter the draft either.
  Character get preview => _copy(_result);

  /// Confirmation must reject a result calculated before another sheet action.
  bool isCurrentFor(Character source) =>
      jsonEncode(QdndBundleCodec.characterToJson(source)) == _baseline;
}
