import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/condition.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/condition_presentation.dart';
import 'value_editor_dialog.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SheetConditionChips extends StatefulWidget {
  const SheetConditionChips(
      {super.key, required this.character, required this.onChanged});
  final Character character;
  final VoidCallback onChanged;
  @override
  State<SheetConditionChips> createState() => _SheetConditionChipsState();
}

class _SheetConditionChipsState extends State<SheetConditionChips> {
  bool _busy = false;

  Future<void> _remove(ConditionType? condition) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (condition == null) {
        await GameplayActionsService.editExhaustion(widget.character, 0);
      } else {
        await GameplayActionsService.setCondition(widget.character, condition,
            active: false);
      }
      if (mounted) widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details(ConditionType? condition) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final changed = await showSheetValueEditor(context,
        title: condition == null
            ? l10n.gameStateExhaustion
            : ConditionPresentation.label(l10n, condition),
        icon: condition == null
            ? Icons.battery_alert_outlined
            : ConditionPresentation.icon(condition),
        description: condition
            ?.getDescription(Localizations.localeOf(context).languageCode),
        fields: condition == null
            ? [
                SheetNumberField('value', l10n.gameStateExhaustion,
                    widget.character.exhaustionLevel,
                    maximum: 6)
              ]
            : const [],
        actionLabel: condition == null ? l10n.save : l10n.sheetClearCondition,
        onSave: (values, _) async {
      if (condition == null) {
        await GameplayActionsService.editExhaustion(
            widget.character, values['value']!);
      } else {
        await GameplayActionsService.setCondition(widget.character, condition,
            active: false);
      }
    });
    if (mounted && changed) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    Widget chip(
            String id, String label, IconData icon, ConditionType? condition,
            {bool warning = false}) =>
        InputChip(
          key: ValueKey('sheet-condition-$id'),
          avatar: Icon(icon,
              size: 18,
              color: warning
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer),
          label: Text(label),
          backgroundColor:
              warning ? colors.errorContainer : colors.secondaryContainer,
          labelStyle: TextStyle(
              color: warning
                  ? colors.onErrorContainer
                  : colors.onSecondaryContainer),
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onPressed: _busy ? null : () => _details(condition),
          deleteIcon: const Icon(Icons.close, size: 18),
          deleteButtonTooltipMessage: l10n.sheetRemoveCondition(label),
          onDeleted: _busy ? null : () => _remove(condition),
        );
    return Wrap(spacing: 8, runSpacing: 4, children: [
      for (final condition in widget.character.activeConditions.toSet())
        chip(condition.name, ConditionPresentation.label(l10n, condition),
            ConditionPresentation.icon(condition), condition),
      if (widget.character.exhaustionLevel > 0)
        chip(
            'exhaustion',
            l10n.conditionExhaustion(widget.character.exhaustionLevel),
            Icons.battery_alert_outlined,
            null,
            warning: true),
    ]);
  }
}
