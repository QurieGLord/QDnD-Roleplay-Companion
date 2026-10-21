import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../core/utils/dice_expression.dart';
import '../../core/utils/dice_utils.dart';
import '../../l10n/app_localizations.dart';

Future<void> showFormulaRoller(BuildContext context,
        {required String title, required String formula}) =>
    showResponsiveSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _FormulaRollSheet(title: title, formula: formula));

class _FormulaRollSheet extends StatefulWidget {
  const _FormulaRollSheet({required this.title, required this.formula});
  final String title, formula;
  @override
  State<_FormulaRollSheet> createState() => _FormulaRollSheetState();
}

class _FormulaRollSheetState extends State<_FormulaRollSheet> {
  ({int total, List<int> rolls})? _result;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l = AppLocalizations.of(context)!;
    final expression = DiceExpression.tryParse(widget.formula);
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title,
                  style: t.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              CompanionSurface(
                  color: c.secondaryContainer,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DiceUtils.formatDice(widget.formula, context),
                            style: t.textTheme.titleLarge),
                        if (_result != null) ...[
                          const SizedBox(height: 12),
                          Text('${max(0, _result!.total)}',
                              style: t.textTheme.displayMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          if (_result!.rolls.isNotEmpty)
                            Text(_result!.rolls.join(' · '),
                                style: t.textTheme.bodyMedium),
                        ],
                      ])),
              const SizedBox(height: 16),
              if (expression == null)
                Text(
                    ru
                        ? 'Эта формула требует ручного броска. Исходное выражение сохранено.'
                        : 'This formula needs a manual roll. The original expression is preserved.',
                    style: t.textTheme.bodyLarge)
              else
                FilledButton.tonalIcon(
                    onPressed: () {
                      setState(() => _result = expression.roll(Random()));
                      HapticFeedback.mediumImpact();
                    },
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(l.roll)),
            ]));
  }
}
