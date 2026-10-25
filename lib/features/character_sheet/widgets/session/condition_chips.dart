import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../../core/models/character.dart';
import '../../../../core/models/condition.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../core/ui/condition_presentation.dart';
import '../../../../core/ui/expressive_kit.dart';
import '../../../../core/ui/companion_kit.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../class_widgets/instrument/instrument_kit.dart';

/// Conditions as stamped seals (wave 3, `.seal`): a coloured glyph and the
/// name. A tap opens the conditions sheet, a hold reads the rule. A new
/// seal is stamped in.
class SheetConditionChips extends StatefulWidget {
  const SheetConditionChips(
      {super.key,
      required this.character,
      required this.onChanged,
      this.onAdd});
  final Character character;
  final VoidCallback onChanged;

  /// Opens the conditions sheet; also shown as a trailing seal.
  final VoidCallback? onAdd;
  @override
  State<SheetConditionChips> createState() => _SheetConditionChipsState();
}

class _SheetConditionChipsState extends State<SheetConditionChips> {
  Set<String>? _known;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final hero = widget.character;
    final exhaustion = hero.exhaustionLevel;
    final keys = {
      for (final x in hero.activeConditions) x.name,
      if (exhaustion > 0) 'exhaustion',
    };
    final known = _known;
    _known = keys;
    Widget seal(
            String id, String label, String glyph, Color accent, String rule) =>
        _Stamp(
          key: ValueKey('sheet-condition-$id'),
          play: known != null && !known.contains(id),
          child: Peek(
            title: label,
            text: rule,
            accent: accent,
            child: Pressable(
              onTap: widget.onAdd,
              scale: .95,
              semanticLabel: label,
              child: Container(
                padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                      accent.withValues(alpha: .16), c.surfaceContainerLow),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: accent.withValues(alpha: .45), width: 1.4),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(8)),
                    child: InstrumentGlyph(glyph, size: 14, color: c.surface),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(label,
                        style: const TextStyle(
                            fontFamily: AppType.body,
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ),
          ),
        );
    // Seals that join or leave let their neighbours glide, not jump.
    return FlipWrap(spacing: 8, runSpacing: 8, children: [
      for (final condition in hero.activeConditions.toSet())
        seal(
            condition.name,
            ConditionPresentation.label(l10n, condition),
            ConditionPresentation.glyph(condition),
            AppAccents.of(context).at(ConditionPresentation.accent(condition)),
            ConditionPresentation.line(condition, ru)),
      if (exhaustion > 0)
        seal(
            'exhaustion',
            l10n.conditionExhaustion(exhaustion),
            'timer',
            AppAccents.of(context).at(1),
            [for (var i = 1; i <= exhaustion; i++) exhaustionEffect(i, ru)]
                .join(' · ')),
      if (widget.onAdd != null)
        Pressable(
          key: const ValueKey('sheet-condition-add'),
          onTap: widget.onAdd,
          scale: .95,
          semanticLabel: l10n.overviewAddCondition,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.outline, width: 1.4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LineIcon('plus', size: 16, color: c.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(ru ? 'Состояние' : 'Condition',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 13,
                      height: 1.85,
                      fontWeight: FontWeight.w600,
                      color: c.onSurfaceVariant)),
            ]),
          ),
        ),
    ]);
  }
}

/// A seal pressed in: from large and turned, past the paper, to rest.
class _Stamp extends StatelessWidget {
  const _Stamp({super.key, required this.play, required this.child});
  final bool play;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!play || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      builder: (context, p, child) {
        final scale =
            p < .6 ? 1.5 - .56 * (p / .6) : .94 + .06 * ((p - .6) / .4);
        return Opacity(
          opacity: (p / .3).clamp(0.0, 1.0),
          child: Transform.rotate(
              angle: (p < .6 ? -8 * (1 - p / .6) : 0) * 3.14159 / 180,
              child: Transform.scale(scale: scale, child: child)),
        );
      },
      child: child,
    );
  }
}

/// PHB p. 291: what each step of exhaustion adds.
String exhaustionEffect(int level, bool ru) => switch (level) {
      1 => ru
          ? 'Помеха на проверки характеристик'
          : 'Disadvantage on ability checks',
      2 => ru ? 'Скорость вдвое меньше' : 'Speed halved',
      3 => ru
          ? 'Помеха на атаки и спасброски'
          : 'Disadvantage on attacks and saves',
      4 => ru ? 'Максимум ОЗ вдвое меньше' : 'Hit point maximum halved',
      5 => ru ? 'Скорость 0' : 'Speed 0',
      6 => ru ? 'Смерть' : 'Death',
      _ => ru ? 'Без истощения' : 'No exhaustion',
    };

enum ConditionPickerResult { unchanged, changed, allParameters }

/// The conditions sheet: every condition as a seal in a grid that takes
/// its colour when it applies, and exhaustion as a stair that climbs from
/// yellow to red. Changes save as they are made.
Future<ConditionPickerResult> showConditionPicker(
    BuildContext context, Character character) async {
  var changed = false;
  final result = await showCompanionSheet<ConditionPickerResult>(context,
      builder: (context) => _ConditionPicker(
          character: character, onChanged: () => changed = true));
  if (result == ConditionPickerResult.allParameters) return result!;
  return changed
      ? ConditionPickerResult.changed
      : ConditionPickerResult.unchanged;
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
  int _bump = 0;

  Future<void> _write(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await action()) widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context)!.sheetSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(ConditionType condition) {
    final active = !widget.character.activeConditions.contains(condition);
    active ? HapticFeedback.lightImpact() : HapticFeedback.selectionClick();
    return _write(() => GameplayActionsService.setCondition(
        widget.character, condition,
        active: active));
  }

  Future<void> _exhaustion(int value) {
    if (value == widget.character.exhaustionLevel) return Future.value();
    value == 6
        ? HapticFeedback.mediumImpact()
        : HapticFeedback.selectionClick();
    _bump++;
    return _write(() async {
      await GameplayActionsService.editExhaustion(widget.character, value);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final active = widget.character.activeConditions.toSet();
    const all = ConditionType.values;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.character.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontFamily: AppType.body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.secondary)),
      const SizedBox(height: 8),
      SheetHeading(l10n.overviewConditions,
          subtitle: ru
              ? 'Коснитесь печати — наложить или снять. Удержание — полное правило.'
              : 'Tap a seal to apply or clear it. Hold to read the rule.'),
      const SizedBox(height: 14),
      for (var i = 0; i < all.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final condition in all.skip(i).take(2)) ...[
                if (condition != all[i]) const SizedBox(width: 8),
                Expanded(
                  child: _ConditionCell(
                    key: ValueKey('condition-pick-${condition.name}'),
                    condition: condition,
                    selected: active.contains(condition),
                    onTap: _busy ? null : () => _toggle(condition),
                  ),
                ),
              ],
            ]),
          ),
        ),
      const SizedBox(height: 6),
      _ExhaustionStair(
          level: widget.character.exhaustionLevel,
          bump: _bump,
          onPick: _busy ? null : _exhaustion),
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

class _ConditionCell extends StatelessWidget {
  const _ConditionCell(
      {super.key, required this.condition, required this.selected, this.onTap});
  final ConditionType condition;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final accent =
        AppAccents.of(context).at(ConditionPresentation.accent(condition));
    final name = ConditionPresentation.label(l10n, condition);
    final d = AppMotion.of(context, const Duration(milliseconds: 420));
    return Peek(
      title: name,
      text: condition.getDescription(ru ? 'ru' : 'en'),
      accent: accent,
      child: Pressable(
        onTap: onTap,
        selected: selected,
        scale: .96,
        semanticLabel: name,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(selected),
          tween: Tween(
              begin: selected && !MediaQuery.disableAnimationsOf(context)
                  ? 1.08
                  : 1,
              end: 1),
          duration: d,
          curve: AppMotion.snappyCurve,
          builder: (context, s, child) =>
              Transform.scale(scale: s, child: child),
          child: AnimatedContainer(
            duration: d,
            curve: AppMotion.snappyCurve,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                          Color.alphaBlend(accent.withValues(alpha: .30),
                              c.surfaceContainer),
                          Color.alphaBlend(accent.withValues(alpha: .12),
                              c.surfaceContainerLow),
                        ])
                  : null,
              color: selected ? null : c.surfaceContainerLow,
              borderRadius: selected
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(26),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14))
                  : BorderRadius.circular(20),
              border: Border.all(
                  color: selected ? accent : Colors.transparent, width: 1.6),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                AnimatedRotation(
                  turns: selected ? -8 / 360 : 0,
                  duration: d,
                  curve: AppMotion.snappyCurve,
                  child: AnimatedContainer(
                    duration: d,
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color:
                            selected ? accent : accent.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(12)),
                    child: InstrumentGlyph(
                        ConditionPresentation.glyph(condition),
                        size: 19,
                        color: selected ? c.surface : accent),
                  ),
                ),
                const Spacer(),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: d,
                  curve: AppMotion.snappyCurve,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(shape: BoxShape.circle, color: accent),
                    child: LineIcon('check', size: 13, color: c.surface),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              WordSafeText(name,
                  style: const TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 14.5,
                      height: 1.15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(ConditionPresentation.line(condition, ru),
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 12,
                      height: 1.32,
                      color: selected
                          ? c.onSurface.withValues(alpha: .8)
                          : c.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Exhaustion as a stair of seven columns: each step taller, the colour
/// climbing from yellow to orange to red, a skull at the top. The current
/// step stands raised with its number on a filled chip.
class _ExhaustionStair extends StatelessWidget {
  const _ExhaustionStair(
      {required this.level, required this.bump, this.onPick});
  final int level, bump;
  final ValueChanged<int>? onPick;

  static Color tone(BuildContext context, int i) {
    final a = AppAccents.of(context);
    return i == 0
        ? a.at(3)
        : i <= 2
            ? a.at(2)
            : i <= 4
                ? a.at(1)
                : a.at(0);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final current = tone(context, level);
    final d = AppMotion.of(context, const Duration(milliseconds: 520));
    return AnimatedContainer(
      duration: d,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                  current.withValues(alpha: .12), c.surfaceContainerLow),
              c.surfaceContainerLow
            ]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text((ru ? 'Истощение' : 'Exhaustion').toUpperCase(),
              style: TextStyle(
                  fontFamily: AppType.body,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: c.onSurfaceVariant)),
          const Spacer(),
          RollingNumber(level,
              style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                  color: current)),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(ru ? ' из 6' : ' of 6',
                style: TextStyle(
                    fontFamily: AppType.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.onSurfaceVariant)),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 112,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i <= 6; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _Step(
                  key: ValueKey('exhaustion-step-$i'),
                  index: i,
                  tone: tone(context, i),
                  on: i > 0 && i <= level,
                  current: i == level,
                  bump: i == level ? bump : 0,
                  onTap: onPick == null ? null : () => onPick!(i),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: AppMotion.of(context, const Duration(milliseconds: 320)),
          child: Container(
            key: ValueKey(level),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: current.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
              border: Border(left: BorderSide(color: current, width: 3)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  level == 0
                      ? (ru ? 'Без истощения' : 'No exhaustion')
                      : exhaustionEffect(level, ru),
                  style: const TextStyle(
                      fontFamily: AppType.body,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w600)),
              if (level != 1) ...[
                const SizedBox(height: 3),
                Text(
                    level == 0
                        ? (ru
                            ? 'Длительный отдых снимает одну ступень'
                            : 'A long rest removes one step')
                        : (ru
                            ? 'и всё, что ниже по лестнице'
                            : 'and everything below on the stair'),
                    style: TextStyle(
                        fontFamily: AppType.body,
                        fontSize: 12,
                        color: c.onSurfaceVariant)),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AnimatedOpacity(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 300)),
              opacity: i <= level ? 1 : .45,
              child: Row(children: [
                AnimatedContainer(
                  duration:
                      AppMotion.of(context, const Duration(milliseconds: 300)),
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: i <= level
                          ? tone(context, i)
                          : c.onSurface.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(7)),
                  child: Text('$i',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: i <= level ? c.surface : c.onSurfaceVariant)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(exhaustionEffect(i, ru),
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontSize: 12.5,
                          height: 1.3,
                          color:
                              i <= level ? c.onSurface : c.onSurfaceVariant)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.index,
    required this.tone,
    required this.on,
    required this.current,
    required this.bump,
    this.onTap,
  });
  final int index, bump;
  final Color tone;
  final bool on, current;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final ru = instrumentRu(context);
    final d = AppMotion.of(context, const Duration(milliseconds: 520));
    final zero = index == 0;
    final fill = current
        ? (zero ? .25 : 1.0)
        : on
            ? .55
            : 0.0;
    return Semantics(
      button: true,
      selected: current,
      label: ru ? 'Истощение $index' : 'Exhaustion $index',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(bump),
            tween: Tween(
                begin: bump > 0 && !MediaQuery.disableAnimationsOf(context)
                    ? 0
                    : 1,
                end: 1),
            duration: const Duration(milliseconds: 560),
            builder: (context, p, child) {
              final lift = p < .3 ? -9 * (p / .3) : -9 * (1 - (p - .3) / .7);
              return Transform.translate(offset: Offset(0, lift), child: child);
            },
            child: AnimatedSlide(
              duration: d,
              curve: AppMotion.snappyCurve,
              offset: Offset(0, current ? -3 / (16 + index * 10) : 0),
              child: AnimatedContainer(
                duration: d,
                curve: AppMotion.snappyCurve,
                height: 16.0 + index * 10,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8)),
                  color: c.onSurface.withValues(alpha: .07),
                  border: current && zero
                      ? Border.all(color: tone, width: 2)
                      : null,
                  boxShadow: current && !zero
                      ? [
                          BoxShadow(color: tone, spreadRadius: 2),
                          BoxShadow(
                              color: tone.withValues(alpha: .7),
                              blurRadius: 22,
                              spreadRadius: -6,
                              offset: const Offset(0, 8)),
                        ]
                      : null,
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedFractionallySizedBox(
                    duration: d,
                    curve: AppMotion.snappyCurve,
                    heightFactor: fill == 0 ? 0 : 1,
                    widthFactor: 1,
                    child: AnimatedOpacity(
                      duration: d,
                      opacity: fill,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(tone, Colors.white, .08)!,
                                tone
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          AnimatedScale(
            scale: current ? 1.12 : 1,
            duration: d,
            curve: AppMotion.snappyCurve,
            child: AnimatedContainer(
              duration:
                  AppMotion.of(context, const Duration(milliseconds: 300)),
              height: 24,
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: current ? tone : Colors.transparent,
                  borderRadius: BorderRadius.circular(9)),
              child: index == 6
                  ? InstrumentGlyph('skull',
                      size: 15, color: current ? c.surface : c.onSurfaceVariant)
                  : Text('$index',
                      style: TextStyle(
                          fontFamily: AppType.display,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: current ? c.surface : c.onSurfaceVariant)),
            ),
          ),
        ]),
      ),
    );
  }
}
