import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/condition.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/condition_presentation.dart';
import 'value_editor_dialog.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../../../../core/ui/companion_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class SheetConditionChips extends StatefulWidget {
  const SheetConditionChips(
      {super.key,
      required this.character,
      required this.onChanged,
      this.onAdd});
  final Character character;
  final VoidCallback onChanged;

  /// Opens the state editor; shown as a trailing chip when given.
  final VoidCallback? onAdd;
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
    final t = Theme.of(context), colors = t.colorScheme;
    // The prototype's `.cond`: a tertiary chip with its name and a round
    // cross that clears it; the name opens what the condition does.
    Widget chip(String id, String label, ConditionType? condition,
            {bool warning = false}) =>
        Container(
          key: ValueKey('sheet-condition-$id'),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          decoration: BoxDecoration(
              color: warning ? colors.errorContainer : colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.md)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: GestureDetector(
                onTap: _busy ? null : () => _details(condition),
                child: Text(label,
                    style: t.textTheme.labelLarge?.copyWith(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.sheetRemoveCondition(label),
              child: Pressable(
                onTap: _busy ? null : () => _remove(condition),
                scale: .9,
                semanticLabel: l10n.sheetRemoveCondition(label),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.onSurface.withValues(alpha: .1)),
                  child: Center(
                      child:
                          LineIcon('x', size: 13, color: colors.onSurface)),
                ),
              ),
            ),
          ]),
        );
    final empty = widget.character.activeConditions.isEmpty &&
        widget.character.exhaustionLevel == 0;
    // Chips that join or leave let their neighbours glide, not jump.
    return FlipWrap(spacing: 8, runSpacing: 8, children: [
      if (empty && widget.onAdd != null)
        Padding(
          key: const ValueKey('sheet-condition-none'),
          padding: const EdgeInsets.only(top: 9, right: 4),
          child: Text(l10n.overviewNoConditions,
              style: t.textTheme.bodyMedium
                  ?.copyWith(fontSize: 13.5, color: colors.onSurfaceVariant)),
        ),
      for (final condition in widget.character.activeConditions.toSet())
        chip(condition.name, ConditionPresentation.label(l10n, condition),
            condition),
      if (widget.character.exhaustionLevel > 0)
        chip('exhaustion',
            l10n.conditionExhaustion(widget.character.exhaustionLevel), null,
            warning: true),
      if (widget.onAdd != null)
        OutlineChip(
          key: const ValueKey('sheet-condition-add'),
          label: l10n.overviewAddCondition,
          leading: const LineIcon('plus'),
          strong: true,
          onTap: _busy ? null : widget.onAdd,
        ),
    ]);
  }
}

enum ConditionPickerResult { unchanged, changed, allParameters }

/// The prototype's condition sheet: every condition as a chip that changes
/// its shape when it applies; neighbours glide as chips grow. Changes save
/// as they are made.
Future<ConditionPickerResult> showConditionPicker(
    BuildContext context, Character character) async {
  var changed = false;
  final result = await showCompanionSheet<ConditionPickerResult>(context,
      builder: (context) => _ConditionPicker(
          character: character, onChanged: () => changed = true));
  if (result == ConditionPickerResult.allParameters) return result!;
  return changed ? ConditionPickerResult.changed : ConditionPickerResult.unchanged;
}

class _ConditionPicker extends StatefulWidget {
  const _ConditionPicker({required this.character, required this.onChanged});
  final Character character;
  final VoidCallback onChanged;
  @override
  State<_ConditionPicker> createState() => _ConditionPickerState();
}

class _ConditionPickerState extends State<_ConditionPicker> {
  bool _busy = false;

  Future<void> _toggle(ConditionType condition) async {
    if (_busy) return;
    final active = !widget.character.activeConditions.contains(condition);
    setState(() => _busy = true);
    try {
      if (await GameplayActionsService.setCondition(
          widget.character, condition,
          active: active)) {
        widget.onChanged();
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final active = widget.character.activeConditions.toSet();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeading(l10n.overviewConditions,
          subtitle: l10n.conditionsPickerHint),
      const SizedBox(height: 14),
      FlipWrap(spacing: 8, runSpacing: 8, children: [
        for (final condition in ConditionType.values)
          ExpressiveStateChip(
            key: ValueKey('condition-pick-${condition.name}'),
            label: ConditionPresentation.label(l10n, condition),
            selected: active.contains(condition),
            selectedColor: c.tertiaryContainer,
            onTap: _busy ? null : () => _toggle(condition),
          ),
      ]),
      const SizedBox(height: 14),
      ToneButton(
        key: const ValueKey('condition-pick-done'),
        kind: ToneKind.primary,
        height: 52,
        expand: true,
        label: l10n.conditionsDone,
        onPressed: () => Navigator.pop(context, ConditionPickerResult.changed),
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: () =>
            Navigator.pop(context, ConditionPickerResult.allParameters),
        child: Text(l10n.conditionsAllParameters),
      ),
    ]);
  }
}
