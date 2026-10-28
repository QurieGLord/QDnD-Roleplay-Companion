import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../widgets/advancement_layout.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/page_kit.dart';
import '../../character_sheet/widgets/class_widgets/instrument/instrument_kit.dart';
import '../../character_sheet/widgets/session/value_editor_dialog.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// How the maximum grows (wave 6): a card with the new maximum rolling to
/// its value beside the hit die, and three ways in a row — the average,
/// a roll of the die right here, or the die rolled at the table.
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
  Timer? _landing;
  int? _roll;
  int _tosses = 0;
  bool _rolling = false;
  String _method = 'average';
  @override
  void dispose() {
    _landing?.cancel();
    super.dispose();
  }

  void _startRoll() {
    if (_rolling) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final result = Random().nextInt(widget.hitDie) + 1;
    setState(() {
      _method = 'roll';
      _rolling = !reduced;
      _roll = result;
      _tosses++;
    });
    _landing?.cancel();
    if (reduced) return;
    // The maximum moves once the die has landed.
    _landing = Timer(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      setState(() => _rolling = false);
      if (result == widget.hitDie) HapticFeedback.mediumImpact();
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
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tr = Tr(context);
    final heal = AppPaletteRoles.heal(context);
    final avg = widget.hitDie ~/ 2 + 1;
    final die = _method == 'average' ? avg : _roll;
    final gain = die == null || _rolling
        ? null
        : max(1, die + widget.conMod) + widget.additionalHp;
    final d = '${tr.t('к', 'd')}${widget.hitDie}';
    final con = widget.conMod >= 0 ? '+${widget.conMod}' : '−${-widget.conMod}';
    return Column(children: [
      AdvancementStepList(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 20 + AdvancementDockScope.inset(context)),
              children: [
            AdvancementHeading(
                title: l10n.advancementHealthTitle,
                subtitle: l10n.advancementHealthHint),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                    begin: const Alignment(-.6, -1),
                    end: const Alignment(.6, 1),
                    colors: [
                      pageMix(heal, .16, c.surfaceContainerLow),
                      c.surfaceContainerLow
                    ],
                    stops: const [0, .7]),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PageCap(l10n.advancementMaximumHp, accent: heal),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              RollingNumber(
                                  (widget.maximumHp ?? 0) + (gain ?? 0),
                                  style: TextStyle(
                                      fontFamily: AppType.display,
                                      fontSize: 44,
                                      height: 1,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -1.3,
                                      color: c.onSurface)),
                              const SizedBox(width: 10),
                              AnimatedSwitcher(
                                duration:
                                    AppMotion.of(context, AppMotion.snappySettle),
                                switchInCurve: AppMotion.snappyCurve,
                                transitionBuilder: (child, a) =>
                                    ScaleTransition(scale: a, child: child),
                                child: Text(gain == null ? '' : '+$gain',
                                    key: ValueKey(gain),
                                    style: TextStyle(
                                        fontFamily: AppType.display,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: heal)),
                              ),
                            ]),
                        const SizedBox(height: 6),
                        Text(
                            tr.t('Кость хитов $d · Телосложение $con',
                                'Hit die $d · Constitution $con'),
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                                color: c.onSurfaceVariant)),
                        if (widget.additionalHp != 0)
                          Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                  l10n.advancementHpBonus(
                                      widget.additionalHpLabel ??
                                          l10n.classFeatures,
                                      widget.additionalHp),
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: c.onSurfaceVariant))),
                      ]),
                ),
                const SizedBox(width: 12),
                TumbleDie(
                    shape: dieShapeFor(widget.hitDie),
                    label: _method == 'average' || _roll == null
                        ? d
                        : '$_roll',
                    accent: heal,
                    rollKey: _tosses,
                    size: 84,
                    sides: widget.hitDie,
                    natural: _method == 'average' ? null : _roll),
              ]),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                    child: _tile('average', l10n.average,
                        '$avg $con = ${max(1, avg + widget.conMod)}', 'stats',
                        () {
                  _landing?.cancel();
                  setState(() {
                    _method = 'average';
                    _rolling = false;
                  });
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile(
                        'roll',
                        l10n.roll,
                        _roll == null || _method != 'roll'
                            ? tr.t('$d в приложении', '$d in the app')
                            : tr.t('Выпало $_roll · ещё раз',
                                'Rolled $_roll · again'),
                        'dice',
                        _startRoll)),
                const SizedBox(width: 8),
                Expanded(
                    child: _tile('manual', l10n.advancementOwnDie,
                        tr.t('Бросок за столом', 'Rolled at the table'), 'edit',
                        _ownRoll)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LineIcon('heart', size: 18, color: c.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      widget.currentHp == null
                          ? (l10n.advancementNoHealing)
                          : (l10n.advancementHpPreserved(widget.currentHp!)),
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: c.onSurfaceVariant)))
            ]),
          ]),
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

  // A method tile (`.mtile`): selected, it squares its corners and fills
  // its round icon with the secondary colour.
  Widget _tile(String id, String title, String subtitle, String icon,
      VoidCallback action) {
    final c = Theme.of(context).colorScheme;
    final on = _method == id;
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      selected: on,
      child: Pressable(
        key: ValueKey('hp-method-$id'),
        onTap: _rolling
            ? null
            : () {
                HapticFeedback.selectionClick();
                action();
              },
        scale: .96,
        child: AnimatedContainer(
          duration: dur,
          curve: AppMotion.snappyCurve,
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(on ? 16 : 22),
            color: on
                ? pageMix(c.secondary, .15, c.surfaceContainerLow)
                : c.surfaceContainerLow,
            border: Border.all(
                color: on
                    ? c.secondary.withValues(alpha: .5)
                    : Colors.transparent,
                width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: dur,
              curve: AppMotion.snappyCurve,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: on ? c.secondary : c.onSurface.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(on ? 12 : 19)),
              child: LineIcon(icon,
                  size: 20, color: on ? c.surface : c.onSurface),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, height: 1.3, color: c.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
