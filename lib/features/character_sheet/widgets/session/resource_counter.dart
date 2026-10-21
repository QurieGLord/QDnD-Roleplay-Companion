import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'expressive_hold_surface.dart';
import '../../../../core/ui/companion_surface.dart';

/// Reading is quiet. Tap spends one; hold opens the full value editor.
class SheetResourceCounter extends StatefulWidget {
  const SheetResourceCounter(
      {super.key,
      required this.name,
      required this.current,
      required this.maximum,
      required this.onStep,
      required this.onEdit,
      this.onChanged,
      this.accent,
      this.badge,
      this.prominent = false});
  final String name;
  final int Function() current, maximum;
  final Future<bool> Function(int delta) onStep;
  final Future<bool> Function() onEdit;
  final VoidCallback? onChanged;
  final Color? accent;
  final String? badge;
  final bool prominent;
  @override
  State<SheetResourceCounter> createState() => _SheetResourceCounterState();
}

class _SheetResourceCounterState extends State<SheetResourceCounter> {
  bool _busy = false;
  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final changed = await action();
      if (mounted && changed) widget.onChanged?.call();
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
    final theme = Theme.of(context), l10n = AppLocalizations.of(context)!;
    final current = widget.current(), maximum = widget.maximum();
    final colors = theme.colorScheme;
    final excess = current > maximum;
    final foreground = excess ? colors.onTertiaryContainer : colors.onSurface;
    return ExpressiveHoldSurface(
      key: ValueKey('counter-edit-${widget.name}'),
      enabled: !_busy,
      excludeChildSemantics: true,
      semanticLabel:
          '${widget.name}, ${l10n.sheetCounterDescription(current, maximum)}',
      hint: l10n.sheetTapHoldHint,
      onTap: current > 0 ? () => _run(() => widget.onStep(-1)) : null,
      onHold: () => _run(widget.onEdit),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
                horizontal: widget.prominent ? 18 : 8,
                vertical: widget.prominent ? 14 : 6),
            constraints: const BoxConstraints(minHeight: 36),
            decoration: companionDecoration(context,
                color: excess
                    ? colors.tertiaryContainer.withValues(alpha: .75)
                    : widget.prominent
                        ? colors.surface
                        : colors.surfaceContainerHigh,
                raised: widget.prominent,
                quiet: !widget.prominent,
                shape: widget.prominent
                    ? const CompanionShape(contour: CompanionContour.seal)
                    : RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.badge != null) ...[
                      Container(
                          width: widget.prominent ? 40 : 20,
                          height: widget.prominent ? 40 : 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: widget.prominent
                                  ? colors.secondaryContainer
                                  : colors.surface,
                              shape: BoxShape.circle),
                          child: FittedBox(
                              child: Text(widget.badge!,
                                  style: (widget.prominent
                                          ? theme.textTheme.titleLarge
                                          : theme.textTheme.labelLarge)
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: foreground)))),
                      SizedBox(width: widget.prominent ? 12 : 6),
                    ],
                    Flexible(
                        fit: FlexFit.loose,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AnimatedSwitcher(
                                duration:
                                    MediaQuery.disableAnimationsOf(context)
                                        ? Duration.zero
                                        : const Duration(milliseconds: 160),
                                child: Text('$current / $maximum',
                                    key: ValueKey(
                                        'counter-value-$current-$maximum'),
                                    style: (widget.prominent
                                            ? theme.textTheme.headlineSmall
                                            : theme.textTheme.labelLarge)
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: current == 0
                                                ? colors.onSurfaceVariant
                                                : foreground))))),
                  ]),
              if (widget.prominent) ...[
                const SizedBox(height: 7),
                Text(widget.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
