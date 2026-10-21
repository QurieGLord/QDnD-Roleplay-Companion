import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import 'value_editors.dart';
import '../../../../core/ui/companion_surface.dart';
import 'expressive_hold_surface.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../../core/ui/expressive_kit.dart';

class SheetHealthPanel extends StatefulWidget {
  const SheetHealthPanel({super.key, required this.character, this.onChanged});
  final Character character;
  final VoidCallback? onChanged;
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

  Future<void> _action(bool healing) async {
    if (_busy) return;
    setState(() => _busy = true);
    final changed =
        await showHealthAction(context, widget.character, healing: healing);
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character, theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final color = theme.colorScheme;
    final current = _hasForm ? c.beastCurrentHp! : c.currentHp;
    final maximum = _hasForm ? c.beastMaxHp! : c.maxHp;
    final ratio = maximum > 0 ? (current / maximum).clamp(0.0, 1.0) : 0.0;
    return ExpressiveHoldSurface(
      enabled: !_busy,
      semanticLabel: _hasForm ? l10n.sheetHealthForm : l10n.hitPoints,
      hint: l10n.sheetHoldToEdit,
      onHold: () => _edit(),
      child: ImpactPulse(
        value: current + (_hasForm ? 0 : c.temporaryHp),
        glowColor: color.secondary,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.xlPlus),
            topRight: Radius.circular(AppRadii.xlPlus),
            bottomLeft: Radius.circular(AppRadii.xlPlus),
            bottomRight: Radius.circular(AppRadii.lgPlus)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: companionDecoration(context,
              raised: true,
              color: color.secondaryContainer,
              accent: color.secondary,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadii.xlPlus),
                      topRight: Radius.circular(AppRadii.xlPlus),
                      bottomLeft: Radius.circular(AppRadii.xlPlus),
                      bottomRight: Radius.circular(AppRadii.lgPlus)))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            LayoutBuilder(
                builder: (context, constraints) => Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 8,
                      children: [
                        Text(
                            _hasForm
                                ? c.beastName ?? l10n.sheetHealthForm
                                : l10n.hpShort,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: constraints.maxWidth),
                          child: Padding(
                            key: const ValueKey('sheet-health-edit'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            child: Semantics(
                              label: '$current / $maximum',
                              excludeSemantics: true,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerEnd,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RollingNumber(current,
                                          style: theme.textTheme.displaySmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: -1.2,
                                                  color: current > maximum
                                                      ? color.tertiary
                                                      : (ratio < .3
                                                          ? color.error
                                                          : color.primary))),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 5),
                                        child: Text(' / $maximum',
                                            style: theme.textTheme.titleLarge
                                                ?.copyWith(
                                                    color:
                                                        color.onSurfaceVariant,
                                                    fontWeight:
                                                        FontWeight.w500)),
                                      ),
                                    ]),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )),
            const SizedBox(height: 8),
            TrailBar(
                value: maximum > 0 ? current / maximum : (current > 0 ? 1 : 0),
                extra: !_hasForm && maximum > 0 ? c.temporaryHp / maximum : 0,
                extraColor: color.secondary,
                background: color.surfaceContainerHighest,
                color: ratio < .3 ? color.error : color.primary),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, children: [
              Text('${l10n.tempHp}: ${c.temporaryHp}',
                  style: theme.textTheme.bodyMedium),
              if (_hasForm)
                ExpressiveHoldSurface(
                    onHold: () => _edit(form: false),
                    enabled: !_busy,
                    child: Text(
                        '${l10n.sheetHealthBase}: ${c.currentHp} / ${c.maxHp}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: color.primary))),
              if (c.isWildShaped && !_hasForm)
                TextButton(
                    onPressed: _busy ? null : () => _edit(form: true),
                    child: Text(l10n.sheetFormMissing)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: FilledButton.tonalIcon(
                      key: const ValueKey('sheet-health-damage'),
                      onPressed: _busy ? null : () => _action(false),
                      icon: const Icon(Icons.remove),
                      label: Text(l10n.damage))),
              const SizedBox(width: 8),
              Expanded(
                  child: FilledButton.tonalIcon(
                      key: const ValueKey('sheet-health-heal'),
                      onPressed: _busy ? null : () => _action(true),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.heal))),
            ]),
          ]),
        ),
      ),
    );
  }
}
