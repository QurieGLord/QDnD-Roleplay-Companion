import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../widgets/advancement_layout.dart';
import '../../../core/ui/companion_surface.dart';
import '../../character_sheet/widgets/session/value_editor_dialog.dart';

class HpIncreaseStep extends StatefulWidget {
  const HpIncreaseStep(
      {super.key,
      required this.hitDie,
      required this.conMod,
      required this.onRoll,
      required this.onAverage,
      this.currentHp,
      this.maximumHp,
      this.additionalHp = 0,
      this.additionalHpLabel});
  final int hitDie, conMod;
  final int additionalHp;
  final String? additionalHpLabel;
  final int? currentHp, maximumHp;
  final ValueChanged<int> onRoll;
  final VoidCallback onAverage;
  @override
  State<HpIncreaseStep> createState() => _HpIncreaseStepState();
}

class _HpIncreaseStepState extends State<HpIncreaseStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _animation;
  int? _roll;
  int _display = 1;
  bool _rolling = false;
  String _method = 'average';
  @override
  void dispose() {
    _animation?.cancel();
    super.dispose();
  }

  void _startRoll() {
    if (_rolling) return;
    HapticFeedback.lightImpact();
    setState(() {
      _method = 'roll';
      _rolling = true;
      _roll = null;
    });
    final random = Random();
    var ticks = 0;
    final reduced = MediaQuery.disableAnimationsOf(context);
    _animation?.cancel();
    _animation =
        Timer.periodic(Duration(milliseconds: reduced ? 1 : 65), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _display = random.nextInt(widget.hitDie) + 1;
        if (reduced || ++ticks >= 10) {
          timer.cancel();
          _roll = _display;
          _rolling = false;
          HapticFeedback.mediumImpact();
        }
      });
    });
  }

  Future<void> _ownRoll() async {
    final l10n = AppLocalizations.of(context)!;
    await showSheetValueEditor(context,
        title: l10n.advancementOwnHitDie,
        icon: Icons.casino_outlined,
        fields: [
          SheetNumberField(
              'roll', l10n.advancementDieResult(widget.hitDie), _roll ?? 1,
              minimum: 1, maximum: widget.hitDie)
        ],
        actionLabel: l10n.advancementUseRoll,
        onSave: (values, automatic) async {
      if (mounted) {
        setState(() {
          _roll = values['roll'];
          _method = 'manual';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final die = _method == 'average' ? widget.hitDie ~/ 2 + 1 : _roll;
    final gain =
        die == null ? null : max(1, die + widget.conMod) + widget.additionalHp;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Column(children: [
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
            AdvancementHeading(
                title: l10n.advancementHealthTitle,
                subtitle: l10n.advancementHealthHint),
            AnimatedContainer(
                duration: motion,
                padding: const EdgeInsets.all(24),
                decoration: companionDecoration(context,
                    raised: true,
                    color: colors.secondaryContainer,
                    shape:
                        const CompanionShape(contour: CompanionContour.facet)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(l10n.advancementMaximumHp,
                                      style: theme.textTheme.labelLarge),
                                  const SizedBox(height: 8),
                                  AnimatedSwitcher(
                                      duration: motion,
                                      child: Text(
                                          _rolling
                                              ? '$_display'
                                              : gain == null
                                                  ? '—'
                                                  : '+$gain',
                                          key: ValueKey(
                                              '$_rolling:$gain:$_display'),
                                          style: theme.textTheme.displayMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: -1.5))),
                                ])),
                            Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                    color: colors.surface.withValues(alpha: .7),
                                    borderRadius: BorderRadius.circular(22)),
                                child: Column(children: [
                                  Icon(Icons.casino_outlined,
                                      color: colors.onSecondaryContainer,
                                      size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${Localizations.localeOf(context).languageCode == 'ru' ? 'к' : 'd'}${widget.hitDie}',
                                      style: theme.textTheme.labelLarge),
                                ])),
                          ]),
                      const SizedBox(height: 16),
                      if (widget.maximumHp != null && gain != null)
                        Text(
                            '${widget.maximumHp} → ${widget.maximumHp! + gain}',
                            style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                          l10n.advancementConIncluded(
                              '${widget.conMod >= 0 ? '+' : ''}${widget.conMod}'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                      if (widget.additionalHp != 0)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                l10n.advancementHpBonus(
                                    widget.additionalHpLabel ??
                                        l10n.classFeatures,
                                    widget.additionalHp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant))),
                    ])),
            const SizedBox(height: 20),
            _methodTile(
                'average',
                l10n.average,
                l10n.advancementAverageDie(widget.hitDie ~/ 2 + 1),
                Icons.balance_rounded, () {
              _animation?.cancel();
              setState(() {
                _method = 'average';
                _rolling = false;
              });
            }),
            const SizedBox(height: 10),
            _methodTile(
                'roll',
                l10n.roll,
                _roll == null
                    ? (l10n.advancementRollHere(widget.hitDie))
                    : (l10n.advancementRollAgain(_roll!)),
                Icons.casino_outlined,
                _startRoll),
            const SizedBox(height: 10),
            _methodTile('manual', l10n.advancementOwnDie,
                l10n.advancementOwnDieHint, Icons.edit_note_rounded, _ownRoll),
            const SizedBox(height: 20),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.favorite_outline_rounded,
                  size: 18, color: colors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      widget.currentHp == null
                          ? (l10n.advancementNoHealing)
                          : (l10n.advancementHpPreserved(widget.currentHp!)),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant)))
            ]),
          ])),
      AdvancementFooter(
          label: l10n.continueLabel,
          hint: _rolling ? (l10n.advancementRolling) : null,
          onPressed: gain == null || _rolling
              ? null
              : () {
                  if (_method == 'average') {
                    widget.onAverage();
                  } else {
                    widget.onRoll(_roll!);
                  }
                }),
    ]);
  }

  Widget _methodTile(String id, String title, String subtitle, IconData icon,
      VoidCallback action) {
    final colors = Theme.of(context).colorScheme;
    final selected = _method == id;
    return Semantics(
        selected: selected,
        child: Material(
            color: selected
                ? colors.surfaceContainerHigh
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                key: ValueKey('hp-method-$id'),
                onTap: _rolling
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        action();
                      },
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(icon, color: colors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant))
                          ])),
                      const SizedBox(width: 12),
                      Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: selected ? colors.primary : colors.outline,
                          size: 22),
                    ])))));
  }
}
