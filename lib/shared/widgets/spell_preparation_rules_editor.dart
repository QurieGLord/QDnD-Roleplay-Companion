import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/magic/spell_preparation_rules.dart';
import '../../core/ui/companion_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// A small explicit declaration, shared by advancement and the session sheet.
class SpellPreparationRulesEditor extends StatefulWidget {
  const SpellPreparationRulesEditor(
      {super.key, this.initial, required this.onChanged, this.enabled = true});
  final SpellPreparationRules? initial;
  final ValueChanged<SpellPreparationRules?> onChanged;
  final bool enabled;
  @override
  State<SpellPreparationRulesEditor> createState() =>
      _SpellPreparationRulesEditorState();
}

class _SpellPreparationRulesEditorState
    extends State<SpellPreparationRulesEditor> {
  SpellPreparationMode? _mode;
  RitualPreparationMode? _ritual;
  int? _divisor;
  @override
  void initState() {
    super.initState();
    _mode = widget.initial?.mode;
    _ritual = widget.initial?.ritual;
    _divisor = widget.initial?.divisor;
  }

  void _changed(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
    widget.onChanged(_mode == null ||
            _ritual == null ||
            (_mode != SpellPreparationMode.known && _divisor == null)
        ? null
        : SpellPreparationRules(_mode!,
            divisor: _divisor ?? 1, ritual: _ritual!));
  }

  @override
  Widget build(BuildContext context) {
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    Widget choices<T>(List<T> values, T? selected, String Function(T) label,
            ValueChanged<T> onSelect) =>
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in values)
            ChoiceChip(
                label: Text(label(v)),
                selected: selected == v,
                showCheckmark: false,
                onSelected:
                    widget.enabled ? (_) => _changed(() => onSelect(v)) : null)
        ]);
    final modeLabels = ru
        ? ['Известные', 'Из списка', 'Из книги']
        : ['Known spells', 'Class list', 'Spellbook'];
    final descriptions = ru
        ? [
            'Изученные заклинания готовы к применению. Отдельная подготовка не требуется.',
            'Выбирай подготовленные заклинания из доступного списка своего класса.',
            'Сначала добавь заклинание в книгу, затем подготовь его.'
          ]
        : [
            'Learned spells are ready to cast. Separate preparation is not required.',
            'Prepare spells from the available list for your class.',
            'Add a spell to your book first, then prepare it.'
          ];
    return CompanionSurface(
        quiet: true,
        contour: CompanionContour.soft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ru ? 'Как устроена магия' : 'How your magic works',
              style: t.titleLarge),
          const SizedBox(height: 8),
          Text(
              ru
                  ? 'Сверь с описанием класса в своей книге.'
                  : 'Match the class description in your book.',
              style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: 16),
          choices(SpellPreparationMode.values, _mode,
              (v) => modeLabels[v.index], (v) => _mode = v),
          AnimatedSize(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: AppMotion.standard,
              alignment: Alignment.topCenter,
              child: _mode == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(descriptions[_mode!.index],
                                style: t.bodyMedium),
                            if (_mode != SpellPreparationMode.known) ...[
                              const SizedBox(height: 20),
                              Text(
                                  ru
                                      ? 'Число подготовленных'
                                      : 'Preparation allowance',
                                  style: t.titleSmall),
                              const SizedBox(height: 6),
                              Text(
                                  ru
                                      ? 'Модификатор базовой характеристики + …'
                                      : 'Spellcasting ability modifier + …',
                                  style: t.bodySmall),
                              const SizedBox(height: 10),
                              choices(
                                  [1, 2],
                                  _divisor,
                                  (v) => v == 1
                                      ? (ru ? 'Уровень класса' : 'Class level')
                                      : (ru
                                          ? 'Половина уровня ↓'
                                          : 'Half class level ↓'),
                                  (v) => _divisor = v),
                              const SizedBox(height: 8),
                              Text(
                                  ru
                                      ? 'Округление вниз; минимум одно заклинание.'
                                      : 'Round down; at least one spell.',
                                  style: t.bodySmall),
                            ],
                          ]))),
          const SizedBox(height: 20),
          Text(ru ? 'Ритуалы' : 'Ritual casting', style: t.titleSmall),
          const SizedBox(height: 10),
          choices(
              RitualPreparationMode.values,
              _ritual,
              (v) => (ru
                  ? ['Нет', 'Готовые заклинания', 'Из книги без подготовки']
                  : ['None', 'Ready spells', 'From book, unprepared'])[v.index],
              (v) => _ritual = v),
        ]));
  }
}
