import 'dart:convert';
import '../models/character.dart';
import '../models/condition.dart';
import '../models/spell.dart';
import '../progression/character_class_context.dart';

enum CastingConstraint {
  zeroHp,
  incapacitated,
  rage,
  form,
  formMaterials,
  unclearMaterials
}

extension CastingConstraintLabel on CastingConstraint {
  String label(String locale) {
    final ru = locale == 'ru';
    return switch (this) {
      CastingConstraint.zeroHp => ru ? 'При 0 ОЗ накладывание требует подтверждённого исключения стола.' : 'Casting at 0 HP requires an explicit table exception.',
      CastingConstraint.incapacitated => ru
          ? 'Текущее состояние не позволяет совершать действия и реакции.'
          : 'The current condition prevents actions and reactions.',
      CastingConstraint.rage => ru
          ? 'Во время ярости нельзя накладывать заклинания.'
          : 'Spells cannot be cast while raging.',
      CastingConstraint.form => ru
          ? 'В облике зверя заклинания не накладываются (друид сможет с 18 уровня). Сначала вернитесь в свой облик.'
          : 'A beast form cannot cast spells (a druid can from level 18). Return to your own form first.',
      CastingConstraint.formMaterials => ru
          ? 'В этой форме нельзя предоставить необходимые материальные компоненты.'
          : 'This form cannot provide the required material components.',
      CastingConstraint.unclearMaterials => ru
          ? 'В книге не уточнены материалы. Возможность накладывания в форме нужно подтвердить за столом.'
          : 'The book does not specify the materials. Confirm casting in this form at your table.',
    };
  }
}

/// Deterministic recorded restrictions only. Range, targets, silence, hands
/// and actual component ownership remain tabletop decisions, not guesses.
class CastingConstraints {
  static bool hasMaterials(Spell spell) =>
      spell.components.any((v) => {'M', 'М'}.contains(v.trim().toUpperCase()));
  static bool incapacitated(Character hero) => hero.activeConditions.any({
        ConditionType.incapacitated,
        ConditionType.paralyzed,
        ConditionType.petrified,
        ConditionType.stunned,
        ConditionType.unconscious,
      }.contains);
  static bool coreDruid(Character hero, int level) {
    final owner = CharacterClassContext(hero, 'druid'), data = owner.definition;
    return owner.level >= level &&
        data?.rulesEdition == '2014' &&
        data?.sourceId == null &&
        data?.rulesMetadata['origin'] == 'bundled';
  }

  static List<CastingConstraint> forSource(
      Character hero, Spell spell, String source) {
    final result = <CastingConstraint>[];
    if((hero.isWildShaped && hero.beastCurrentHp!=null ? hero.beastCurrentHp! : hero.currentHp)<=0) result.add(CastingConstraint.zeroHp);
    if (incapacitated(hero)) result.add(CastingConstraint.incapacitated);
    if (hero.isRaging) result.add(CastingConstraint.rage);
    if (hero.isWildShaped) {
      if (source != 'class:druid' || !coreDruid(hero, 18)) {
        result.add(CastingConstraint.form);
      } else if (hasMaterials(spell)) {
        final materials = [spell.materialComponents, spell.materialComponentsRu]
            .whereType<String>()
            .join(' ')
            .trim();
        if (!coreDruid(hero, 20)) {
          result.add(CastingConstraint.formMaterials);
        } else if (materials.isEmpty) {
          result.add(CastingConstraint.unclearMaterials);
        } else if (RegExp(
                r'\bworth\b|\bcost\b|\bconsum|стоим|ценой|расход|поглощ|\d[\d,. ]*\s*(?:gp|sp|cp|pp|зм|см|мм|пм)',
                caseSensitive: false)
            .hasMatch(materials)) {
          result.add(CastingConstraint.formMaterials);
        }
      }
    }
    return result;
  }

  static String signature(Character hero, Spell spell, String source) =>
      jsonEncode({
        'source': source,
        'restrictions':
            forSource(hero, spell, source).map((r) => r.name).toList(),
        'conditions': (hero.activeConditions
            .where((c) => {
                  ConditionType.incapacitated,
                  ConditionType.paralyzed,
                  ConditionType.petrified,
                  ConditionType.stunned,
                  ConditionType.unconscious
                }.contains(c))
            .map((c) => c.name)
            .toList()
          ..sort()),
        'rage': hero.isRaging,
        'zeroHp': (hero.isWildShaped && hero.beastCurrentHp!=null ? hero.beastCurrentHp! : hero.currentHp)<=0,
        'form': hero.isWildShaped,
        'druidLevel': CharacterClassContext(hero, 'druid').level,
        'components': spell.components,
        'materials': spell.materialComponents,
        'materialsRu': spell.materialComponentsRu
      });
}
