import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/ability_scores.dart';
import '../widgets/advancement_layout.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class AsiStep extends StatefulWidget {
  const AsiStep(
      {super.key,
      required this.currentScores,
      required this.onAllocationChanged,
      required this.onNext});
  final AbilityScores currentScores;
  final ValueChanged<Map<String, int>> onAllocationChanged;
  final VoidCallback onNext;
  @override
  State<AsiStep> createState() => _AsiStepState();
}

class _AsiStepState extends State<AsiStep> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final List<String?> _points = [null, null];
  int _active = 0;
  Map<String, int> get _allocations => {
        for (final key in widget.currentScores.toJson().keys)
          key: _points.where((v) => v == key).length
      };
  void _assign(String stat) {
    final base = widget.currentScores.toJson()[stat] as int;
    final other = _points[1 - _active] == stat ? 1 : 0;
    if (base + other + 1 > 20) return;
    HapticFeedback.selectionClick();
    setState(() {
      _points[_active] = stat;
      if (_points[1 - _active] == null) _active = 1 - _active;
    });
    widget.onAllocationChanged(Map.of(_allocations));
  }

  String _name(String key, AppLocalizations l) => switch (key) {
        'strength' => l.abilityStr,
        'dexterity' => l.abilityDex,
        'constitution' => l.abilityCon,
        'intelligence' => l.abilityInt,
        'wisdom' => l.abilityWis,
        'charisma' => l.abilityCha,
        _ => key
      };
  IconData _icon(String key) => switch (key) {
        'strength' => Icons.fitness_center_rounded,
        'dexterity' => Icons.directions_run_rounded,
        'constitution' => Icons.favorite_outline,
        'intelligence' => Icons.psychology_outlined,
        'wisdom' => Icons.visibility_outlined,
        _ => Icons.auto_awesome_outlined
      };
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final assigned = _points.whereType<String>().length;
    return Column(children: [
      Expanded(
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
            AdvancementHeading(
                title: l.advancementAsiTitle, subtitle: l.advancementAsiHint),
            IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (var i = 0; i < 2; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                        child: Semantics(
                            selected: _active == i,
                            child: Material(
                                color: _active == i
                                    ? colors.secondaryContainer
                                    : colors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  key: ValueKey('asi-point-$i'),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _active = i);
                                  },
                                  child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(l.advancementPoint(i + 1),
                                                style: theme
                                                    .textTheme.labelMedium
                                                    ?.copyWith(
                                                        color: colors
                                                            .onSurfaceVariant)),
                                            const SizedBox(height: 4),
                                            Text(
                                                _points[i] == null
                                                    ? (l.advancementAssign)
                                                    : _name(_points[i]!, l),
                                                style:
                                                    theme.textTheme.titleSmall),
                                          ])),
                                )))),
                  ]
                ])),
            const SizedBox(height: 12),
            Text(l.advancementPointHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 20),
            for (final entry in widget.currentScores.toJson().entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ability(entry.key, entry.value as int, l)),
          ])),
      AdvancementFooter(
          label: l.continueLabel,
          onPressed: assigned == 2 ? widget.onNext : null,
          hint: l.advancementAssigned(assigned)),
    ]);
  }

  Widget _ability(String key, int base, AppLocalizations l) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final extra = _allocations[key]!;
    final total = base + extra;
    final canAssign = base + (_points[1 - _active] == key ? 1 : 0) + 1 <= 20;
    String bonus(int n) {
      final value = (n - 10) / 2;
      final mod = value.floor();
      return mod >= 0 ? '+$mod' : '$mod';
    }

    return Semantics(
        selected: extra > 0,
        child: Material(
            color: extra > 0
                ? colors.secondaryContainer.withValues(alpha: .55)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            clipBehavior: Clip.antiAlias,
            animationDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            child: InkWell(
              key: ValueKey('asi-ability-$key'),
              onTap: canAssign ? () => _assign(key) : null,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(_icon(key),
                        size: 24,
                        color: canAssign
                            ? colors.primary
                            : colors.onSurfaceVariant),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_name(key, l),
                              style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                              canAssign
                                  ? (bonus(base) == bonus(total)
                                      ? l.advancementModifier(bonus(total))
                                      : l.advancementModifierChange(
                                          bonus(base), bonus(total)))
                                  : l.maxScoreReached,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant))
                        ])),
                    const SizedBox(width: 12),
                    AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        child: Text(extra == 0 ? '$base' : '$base → $total',
                            key: ValueKey(total),
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: extra > 0
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600))),
                  ])),
            )));
  }
}
