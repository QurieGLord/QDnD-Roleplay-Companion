import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import 'hp_keypad_sheet.dart';
import 'value_editors.dart';
import 'expressive_hold_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../../core/ui/companion_kit.dart';
import '../../../../core/ui/expressive_kit.dart';

/// Health on the Overview, as in the prototype's `vitals`: a quiet label and
/// a large rolling number, the bar with its damage trail and temporary HP,
/// the hero's state, death saves at 0 HP, and damage / healing buttons.
/// Tapping the number opens the number pad; holding the panel edits values.
class SheetHealthPanel extends StatefulWidget {
  const SheetHealthPanel(
      {super.key, required this.character, this.onChanged, this.random});
  final Character character;
  final VoidCallback? onChanged;
  final math.Random? random;
  @override
  State<SheetHealthPanel> createState() => _SheetHealthPanelState();
}

class _SheetHealthPanelState extends State<SheetHealthPanel> {
  bool _busy = false;
  bool get _hasForm =>
      widget.character.isWildShaped &&
      widget.character.beastCurrentHp != null &&
      widget.character.beastMaxHp != null;

  Future<void> _edit({bool? form}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final changed = await showHealthValueEditor(context, widget.character,
        form: form ?? _hasForm);
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) widget.onChanged?.call();
  }

  Future<void> _action(HpChange mode) async {
    if (_busy) return;
    setState(() => _busy = true);
    final changed = await showHpKeypad(context, widget.character, mode: mode);
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) widget.onChanged?.call();
  }

  Future<void> _deathSave() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    final c = widget.character;
    if (!c.combatState.canRollDeathSaveThisRound) {
      AppSnackBar.warning(context, l10n.deathSaveAlreadyRolled);
      return;
    }
    setState(() => _busy = true);
    final roll = (widget.random ?? math.Random()).nextInt(20) + 1;
    try {
      await GameplayActionsService.rollDeathSave(c, roll);
      if (!mounted) return;
      if (roll == 20) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      AppSnackBar.info(
          context,
          roll == 20
              ? l10n.deathSaveNat20
              : roll == 1
                  ? l10n.deathSaveNat1
                  : roll >= 10
                      ? l10n.deathSaveSuccessResult(roll)
                      : l10n.deathSaveFailureResult(roll));
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l10n.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character, t = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = t.colorScheme;
    final current = _hasForm ? c.beastCurrentHp! : c.currentHp;
    final maximum = _hasForm ? c.beastMaxHp! : c.maxHp;
    final temp = _hasForm ? 0 : c.temporaryHp;
    final total = math.max(maximum, current + temp);
    final down = !_hasForm && current == 0;
    final saves = c.deathSaves;
    final state = !down
        ? l10n.vitalsStanding
        : saves.isStabilized
            ? l10n.stabilized
            : saves.isDead
                ? l10n.deadLabel
                : l10n.vitalsUnconscious;
    const radius = BorderRadius.only(
        topLeft: Radius.circular(AppRadii.xlPlus),
        topRight: Radius.circular(AppRadii.xlPlus),
        bottomRight: Radius.circular(AppRadii.xlPlus),
        bottomLeft: Radius.circular(AppRadii.lgPlus));
    final muted = t.textTheme.bodySmall
        ?.copyWith(fontSize: 13, color: color.onSurfaceVariant);

    return ExpressiveHoldSurface(
      enabled: !_busy,
      semanticLabel: _hasForm ? l10n.sheetHealthForm : l10n.hitPoints,
      hint: l10n.sheetHoldToEdit,
      onHold: () => _edit(),
      child: ImpactPulse(
        value: current + temp,
        glowColor: AppPaletteRoles.heal(context),
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              borderRadius: radius,
              color: Color.alphaBlend(color.secondary.withValues(alpha: .10),
                  color.surfaceContainer)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                      _hasForm
                          ? c.beastName ?? l10n.sheetHealthForm
                          : l10n.hpShort.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.labelMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                          color: color.onSurfaceVariant)),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .6),
                child: KeyedSubtree(
                  key: const ValueKey('sheet-health-edit'),
                  child: Semantics(
                    button: true,
                    label: '$current / $maximum',
                    excludeSemantics: true,
                    onTap: _busy || _hasForm
                        ? null
                        : () => _action(HpChange.damage),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy || _hasForm
                          ? null
                          : () => _action(HpChange.damage),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              RollingNumber(current,
                                  style:
                                      AppType.numeric(t.textTheme.displayMedium)
                                          .copyWith(
                                              fontSize: 52,
                                              height: 1,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -1.5,
                                              color: down
                                                  ? color.onSurfaceVariant
                                                  : current > maximum
                                                      ? color.tertiary
                                                      : color.primary)),
                              const SizedBox(width: 6),
                              Text('/ $maximum',
                                  style: AppType.numeric(t.textTheme.titleLarge)
                                      .copyWith(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500,
                                          color: color.onSurfaceVariant)),
                            ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            TrailBar(
                height: 10,
                value: total > 0 ? current / total : 0,
                extra: total > 0 ? temp / total : 0,
                extraColor: color.secondary,
                background: color.onSurface.withValues(alpha: .09),
                color: color.primary),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _hasForm
                    ? ExpressiveHoldSurface(
                        onHold: () => _edit(form: false),
                        enabled: !_busy,
                        child: Text(
                            '${l10n.sheetHealthBase}: ${c.currentHp} / ${c.maxHp}',
                            style: muted?.copyWith(color: color.primary)))
                    : Text('${l10n.tempHp}: $temp', style: muted),
              ),
              Text(state, style: muted),
            ]),
            if (c.isWildShaped && !_hasForm)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: _busy ? null : () => _edit(form: true),
                    child: Text(l10n.sheetFormMissing)),
              ),
            Reveal(
              open: down,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _DeathSaves(
                  character: c,
                  busy: _busy,
                  onRoll: _deathSave,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: ToneButton(
                      key: const ValueKey('sheet-health-damage'),
                      kind: ToneKind.tonal,
                      expand: true,
                      icon: const LineIcon('down'),
                      label: l10n.damage,
                      onPressed:
                          _busy ? null : () => _action(HpChange.damage))),
              const SizedBox(width: 8),
              Expanded(
                  child: ToneButton(
                      key: const ValueKey('sheet-health-heal'),
                      kind: ToneKind.tonal,
                      expand: true,
                      icon: const LineIcon('plus'),
                      label: l10n.heal,
                      onPressed:
                          _busy ? null : () => _action(HpChange.healing))),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// The prototype's death-save block: the situation in words, three marks
/// for successes and failures, and the roll itself.
class _DeathSaves extends StatelessWidget {
  const _DeathSaves(
      {required this.character, required this.busy, required this.onRoll});
  final Character character;
  final bool busy;
  final VoidCallback onRoll;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final saves = character.deathSaves;
    final message = saves.isDead
        ? l10n.deathSaveThreeFailures
        : saves.isStabilized
            ? l10n.deathSaveThreeSuccesses
            : l10n.deathSaveUnconscious;
    Widget marks(String label, int count, bool success) => Row(children: [
          SizedBox(
              width: 76,
              child: Text(label,
                  style: t.textTheme.bodySmall
                      ?.copyWith(fontSize: 13, color: c.onSurfaceVariant))),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Mark(
                  filled: i < count,
                  success: success,
                  color: success ? AppPaletteRoles.heal(context) : c.primary),
            ),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: Color.alphaBlend(
              c.primary.withValues(alpha: .12), c.surfaceContainerLow),
          borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(message,
            style: t.textTheme.titleSmall?.copyWith(
                fontFamily: AppType.display,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3)),
        const SizedBox(height: 10),
        Semantics(
            label: '${l10n.successes}: ${saves.successes} / 3',
            excludeSemantics: true,
            child: marks(l10n.successes, saves.successes, true)),
        const SizedBox(height: 10),
        Semantics(
            label: '${l10n.failures}: ${saves.failures} / 3',
            excludeSemantics: true,
            child: marks(l10n.failures, saves.failures, false)),
        if (saves.isActive) ...[
          const SizedBox(height: 10),
          ToneButton(
              key: const ValueKey('sheet-death-save'),
              kind: ToneKind.primary,
              expand: true,
              label: l10n.rollDeathSave,
              onPressed: busy ? null : onRoll),
        ],
      ]),
    );
  }
}

/// A death-save mark: an empty ring that fills on a success, or turns into
/// a tilted square on a failure.
class _Mark extends StatelessWidget {
  const _Mark(
      {required this.filled, required this.success, required this.color});
  final bool filled, success;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final d = AppMotion.of(context, AppMotion.snappySettle);
    final failed = filled && !success;
    return AnimatedRotation(
      turns: failed ? 1 / 8 : 0,
      duration: d,
      curve: AppMotion.snappyCurve,
      child: AnimatedScale(
        scale: failed ? .86 : 1,
        duration: d,
        curve: AppMotion.snappyCurve,
        child: AnimatedContainer(
          duration: d,
          curve: AppMotion.standard,
          width: 16,
          height: 16,
          decoration: ShapeDecoration(
            color: filled ? color : Colors.transparent,
            shape: failed
                ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))
                : CircleBorder(
                    side: BorderSide(
                        color: filled ? Colors.transparent : c.outline,
                        width: 2)),
          ),
        ),
      ),
    );
  }
}
