import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/ability_scores.dart';
import '../../../core/ui/companion_kit.dart';
import '../../../core/ui/expressive_kit.dart';
import '../../../core/ui/page_kit.dart';
import '../widgets/advancement_layout.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

/// Ability score improvement (wave 6): two points as gems over a 3×2 grid
/// of abilities. A tap on an ability spends the next gem on it, a tap on an
/// ability that already has a point takes it back once both are spent, and
/// a tap on a spent gem returns that point.
class AsiStep extends StatefulWidget {
  const AsiStep(
      {super.key,
      required this.currentScores,
      required this.onAllocationChanged,
      required this.onNext,
      this.accent});
  final AbilityScores currentScores;
  final ValueChanged<Map<String, int>> onAllocationChanged;
  final VoidCallback onNext;
  final Color? accent;
  @override
  State<AsiStep> createState() => _AsiStepState();
}

class _AsiStepState extends State<AsiStep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final List<String?> _points = [null, null];
  Map<String, int> get _allocations => {
        for (final key in widget.currentScores.toJson().keys)
          key: _points.where((v) => v == key).length
      };
  int _base(String stat) => widget.currentScores.toJson()[stat] as int;

  void _changed() => widget.onAllocationChanged(Map.of(_allocations));

  void _tap(String stat) {
    final free = _points.indexOf(null);
    final mine = _points.where((p) => p == stat).length;
    if (free >= 0 && _base(stat) + mine + 1 <= 20) {
      HapticFeedback.selectionClick();
      setState(() => _points[free] = stat);
      _changed();
    } else if (mine > 0 && free < 0) {
      HapticFeedback.selectionClick();
      setState(() => _points[_points.lastIndexOf(stat)] = null);
      _changed();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _free(int i) {
    if (_points[i] == null) return;
    HapticFeedback.selectionClick();
    setState(() => _points[i] = null);
    _changed();
  }

  String _short(String key, Tr tr) => switch (key) {
        'strength' => tr.t('СИЛ', 'STR'),
        'dexterity' => tr.t('ЛОВ', 'DEX'),
        'constitution' => tr.t('ТЕЛ', 'CON'),
        'intelligence' => tr.t('ИНТ', 'INT'),
        'wisdom' => tr.t('МДР', 'WIS'),
        _ => tr.t('ХАР', 'CHA'),
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final tr = Tr(context);
    final c = Theme.of(context).colorScheme;
    final accent = widget.accent ?? c.secondary;
    final assigned = _points.whereType<String>().length;
    final keys = widget.currentScores.toJson().keys.toList();
    return Column(children: [
      AdvancementStepList(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, 20 + AdvancementDockScope.inset(context)),
              children: [
            AdvancementHeading(
                title: l.advancementAsiTitle, subtitle: l.advancementAsiHint),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: c.onSurface.withValues(alpha: .04),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                for (var i = 0; i < 2; i++) ...[
                  _Gem(
                      key: ValueKey('asi-point-$i'),
                      spent: _points[i] != null,
                      accent: accent,
                      onTap: () => _free(i)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.medium),
                    child: Text(
                        key: ValueKey(assigned == 2),
                        assigned == 2
                            ? tr.t('Оба очка вложены — касание возвращает',
                                'Both points are in — a tap takes one back')
                            : tr.t(
                                'Касание добавляет очко: оба в одну или по одному в две',
                                'A tap adds a point: both to one or one to each of two'),
                        style: TextStyle(
                            fontSize: 13, height: 1.35, color: c.onSurfaceVariant)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 16) / 3;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final key in keys)
                  SizedBox(
                      width: w,
                      child: _ability(key, _short(key, tr), accent)),
              ]);
            }),
          ]),
      AdvancementFooter(
          label: l.continueLabel,
          onPressed: assigned == 2 ? widget.onNext : null,
          hint: l.advancementAssigned(assigned)),
    ]);
  }

  Widget _ability(String key, String short, Color accent) {
    final c = Theme.of(context).colorScheme;
    final base = _base(key);
    final extra = _allocations[key]!;
    final total = base + extra;
    final up = extra > 0;
    int mod(int v) => ((v - 10) / 2).floor();
    String sign(int n) => n >= 0 ? '+$n' : '−${-n}';
    final dur = AppMotion.of(context, AppMotion.snappySettle);
    return Semantics(
      selected: up,
      child: Pressable(
        key: ValueKey('asi-ability-$key'),
        onTap: () => _tap(key),
        scale: .96,
        child: AnimatedOpacity(
          duration: AppMotion.of(context, AppMotion.medium),
          opacity: base >= 20 && !up ? .45 : 1,
          child: AnimatedContainer(
            duration: dur,
            curve: AppMotion.snappyCurve,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(up ? 16 : 22),
              color: up
                  ? pageMix(accent, .13, c.surfaceContainerLow)
                  : c.surfaceContainerLow,
              border: Border.all(
                  color: up ? accent.withValues(alpha: .5) : Colors.transparent,
                  width: 1.5),
            ),
            child: Stack(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(short,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .92,
                        color: c.onSurfaceVariant)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RollingNumber(total,
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.6,
                          color: c.onSurface)),
                ),
                const SizedBox(height: 6),
                Text(
                    '${sign(mod(total))}${mod(total) != mod(base) ? ' ↑' : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: up
                            ? Color.lerp(c.onSurface, accent, .75)
                            : c.onSurfaceVariant)),
              ]),
              Positioned(
                top: 0,
                right: 0,
                child: Row(children: [
                  for (var i = 0; i < extra; i++)
                    Padding(
                      padding: const EdgeInsets.only(left: 3),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('$key-$i'),
                        tween: Tween(begin: 0, end: 1),
                        duration: dur,
                        curve: AppMotion.snappyCurve,
                        builder: (context, t, _) => Transform.scale(
                          scale: t,
                          child: Transform.rotate(
                            angle: math.pi / 4,
                            child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(3))),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A point to spend: a gem that fades and shrinks once it is in.
class _Gem extends StatelessWidget {
  const _Gem(
      {super.key,
      required this.spent,
      required this.accent,
      required this.onTap});
  final bool spent;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final dur = AppMotion.of(context, const Duration(milliseconds: 420));
    return Pressable(
      onTap: onTap,
      scale: .9,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: AnimatedScale(
            duration: dur,
            curve: AppMotion.snappyCurve,
            scale: spent ? .7 : 1,
            child: AnimatedOpacity(
              duration: AppMotion.of(context, const Duration(milliseconds: 300)),
              opacity: spent ? .22 : 1,
              child: Transform.rotate(
                angle: math.pi / 4,
                child: AnimatedContainer(
                  duration: AppMotion.of(context, const Duration(milliseconds: 300)),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                      color: spent ? c.outline : accent,
                      borderRadius: BorderRadius.circular(7)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
