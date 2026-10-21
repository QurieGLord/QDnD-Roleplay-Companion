import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/magic/spell_preparation_rules.dart';
import '../../../shared/widgets/spell_preparation_rules_editor.dart';
import '../../../core/models/class_data.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

bool classNeedsRuleReview(ClassData data) =>
    !data.declares('hitDie') ||
    data.rulesEdition == 'unknown' ||
    (data.spellcasting != null && SpellPreparationRules.resolve(data) == null);

/// Resolves missing supported mechanics for this hero, never edits the book.
class ClassRulesReview extends StatefulWidget {
  const ClassRulesReview(
      {super.key, required this.data, required this.onResolved});
  final ClassData data;
  final ValueChanged<ClassData> onResolved;
  @override
  State<ClassRulesReview> createState() => _ClassRulesReviewState();
}

class _ClassRulesReviewState extends State<ClassRulesReview> {
  SpellPreparationRules? _preparation;
  bool get _futurePreparation =>
      widget.data.rulesMetadata.containsKey('spellPreparation') &&
      SpellPreparationRules.fromJson(
              widget.data.rulesMetadata['spellPreparation']) ==
          null;
  int? _die;
  String? _caster;
  String? _ability;
  @override
  void initState() {
    super.initState();
    _die = widget.data.declares('hitDie') ? widget.data.hitDie : null;
    _caster = widget.data.declares('spellcasting')
        ? widget.data.spellcasting?.type
        : null;
    _ability = widget.data.spellcasting?.ability;
    _preparation = SpellPreparationRules.resolve(widget.data);
  }

  Widget _choices<T>(List<T> values, T? selected, String Function(T) label,
          ValueChanged<T> changed) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            selected: value == selected,
            showCheckmark: false,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => changed(value));
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
          )
      ]);
  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ready = _die != null &&
        _caster != null &&
        !_futurePreparation &&
        (_caster == 'none' || (_ability != null && _preparation != null));
    final casterLabels = ru
        ? {
            'none': 'Без заклинательства',
            'full': 'Полный',
            'half': 'Половинный',
            'third': 'Треть',
            'pact': 'Магия договора'
          }
        : {
            'none': 'No spellcasting',
            'full': 'Full caster',
            'half': 'Half caster',
            'third': 'Third caster',
            'pact': 'Pact Magic'
          };
    final abilityLabels = ru
        ? {
            'strength': 'Сила',
            'dexterity': 'Ловкость',
            'constitution': 'Телосложение',
            'intelligence': 'Интеллект',
            'wisdom': 'Мудрость',
            'charisma': 'Харизма'
          }
        : {
            'strength': 'Strength',
            'dexterity': 'Dexterity',
            'constitution': 'Constitution',
            'intelligence': 'Intelligence',
            'wisdom': 'Wisdom',
            'charisma': 'Charisma'
          };
    return Column(children: [
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.xl)),
                    child: Icon(Icons.auto_stories_rounded,
                        size: 28, color: colors.onPrimaryContainer))),
            const SizedBox(height: 20),
            Text(ru ? 'Правила для этого героя' : 'Rules for this hero',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(widget.data.getName(ru ? 'ru' : 'en'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: colors.primary)),
            const SizedBox(height: 12),
            Text(
                ru
                    ? 'Уточни недостающие сведения по правилам своего стола. Они сохранятся с героем; сама книга останется прежней.'
                    : 'Set the missing details to match your table. They will be saved with your hero; the book stays unchanged.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            Text(ru ? 'Кость хитов' : 'Hit die',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _choices<int>(
                [4, 6, 8, 10, 12, 20], _die, (n) => 'd$n', (n) => _die = n),
            const SizedBox(height: 24),
            Text(ru ? 'Заклинательство' : 'Spellcasting',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            _choices<String>(casterLabels.keys.toList(), _caster,
                (v) => casterLabels[v]!, (v) => _caster = v),
            AnimatedSize(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: AppMotion.standard,
                child: _caster == null || _caster == 'none'
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  ru
                                      ? 'Базовая характеристика'
                                      : 'Spellcasting ability',
                                  style: theme.textTheme.titleSmall),
                              const SizedBox(height: 10),
                              _choices<String>(
                                  abilityLabels.keys.toList(),
                                  _ability,
                                  (v) => abilityLabels[v]!,
                                  (v) => _ability = v),
                            ]))),
            if (_futurePreparation)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(ru
                      ? 'В книге указан неподдерживаемый вариант правил подготовки. Его нельзя заменить этой формой.'
                      : 'This book declares unsupported preparation rules. This form cannot replace them.'))
            else if (_caster != null && _caster != 'none')
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SpellPreparationRulesEditor(
                      initial: _preparation,
                      onChanged: (v) => setState(() => _preparation = v))),
            const SizedBox(height: 24),
            Text(
                ru
                    ? 'Используются таблицы D&D 2014. Неизвестные свойства книги сохраняются как текст; эти настройки не превращают их в автоматические эффекты.'
                    : 'Uses D&D 2014 progression tables. Unknown book properties remain as text; these settings do not turn them into automatic effects.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 24),
          ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      key: const ValueKey('class-rules-apply'),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                          ru ? 'Использовать для героя' : 'Use for this hero'),
                      onPressed: !ready
                          ? null
                          : () {
                              final json =
                                  QdndBundleCodec.classToJson(widget.data);
                              json['hitDie'] = _die;
                              json['spellcasting'] = _caster == 'none'
                                  ? null
                                  : {'type': _caster, 'ability': _ability};
                              json['rulesMetadata'] = {
                                ...widget.data.rulesMetadata,
                                'edition': '2014',
                                if (_caster != 'none')
                                  'spellPreparation': _preparation!.toJson(),
                                'selectedByPlayer': true,
                                'declaredFields': {
                                  ...?(widget
                                          .data.rulesMetadata['declaredFields']
                                      as List?),
                                  'hitDie',
                                  'spellcasting'
                                }.toList()
                              };
                              widget.onResolved(
                                  QdndBundleCodec.classFromJson(json));
                            }))))
    ]);
  }
}
