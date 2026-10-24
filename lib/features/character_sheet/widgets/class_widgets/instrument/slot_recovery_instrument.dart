import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart' show Pressable;
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../../core/magic/magic_slots.dart';
import '../../../../../core/models/character.dart';
import '../../../../../core/services/magic_resource_actions_service.dart';
import 'instrument_kit.dart';

/// Slot recovery after a short rest (prototype `CLASS.wizard`, fourth
/// pass): crystals of every slot in rows by circle; a dim crystal is spent,
/// touching it selects it for recovery within the budget of circles; the
/// button lights the chosen ones again. Shared by Arcane Recovery (wizard)
/// and Natural Recovery (druid).
class SlotRecoveryInstrument extends StatefulWidget {
  const SlotRecoveryInstrument({
    super.key,
    required this.hero,
    required this.classId,
    required this.title,
    required this.accent,
    required this.used,
    required this.about,
    required this.onChanged,
  });
  final Character hero;
  final String classId, title;
  final Color accent;
  final bool used;
  final InstrumentAbout about;
  final VoidCallback onChanged;
  @override
  State<SlotRecoveryInstrument> createState() => _SlotRecoveryInstrumentState();
}

class _SlotRecoveryInstrumentState extends State<SlotRecoveryInstrument> {
  // Selected crystals per circle.
  final _pick = <int, int>{};
  bool _busy = false, _restoring = false;

  int get _budget => (widget.hero.classLevel(widget.classId) + 1) ~/ 2;
  int get _used => _pick.entries.fold(0, (t, e) => t + e.key * e.value);

  Future<void> _recover() async {
    if (_busy || _used == 0) return;
    final ru = instrumentRu(context);
    setState(() {
      _busy = true;
      _restoring = true;
    });
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 480));
    try {
      final n = _used;
      await MagicResourceActionsService.recover(widget.hero, Map.of(_pick),
          classId: widget.classId);
      if (!mounted) return;
      _pick.clear();
      widget.onChanged();
      AppSnackBar.success(
          context, ru ? 'Возвращено кругов: $n' : 'Recovered $n circles');
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(
            context,
            ru
                ? 'Не удалось восстановить ячейки.'
                : 'Could not recover slots.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _restoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context);
    final c = Theme.of(context).colorScheme;
    final a2 = accentOf(context, 2);
    MagicSlots? slots;
    try {
      slots = MagicSlots.read(widget.hero);
    } catch (_) {}
    final rows = <(int, int, int)>[];
    if (slots != null) {
      for (var i = 0; i < math.min(5, slots.maximum.length); i++) {
        if (slots.maximum[i] > 0) {
          rows.add((i + 1, slots.current[i], slots.maximum[i]));
        }
      }
    }
    final spent = rows.fold<int>(0, (t, r) => t + r.$3 - r.$2);
    final used = _used, budget = _budget;
    return Instrument(
      key: ValueKey('${widget.classId}-recovery'),
      accent: widget.accent,
      title: widget.title,
      about: widget.about,
      trailing: InstrumentChip(widget.used
          ? (ru ? 'завтра' : 'tomorrow')
          : (ru ? 'раз в день' : 'once a day')),
      child: Opacity(
        opacity: widget.used ? .55 : 1,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BigCount(used, of: budget),
                    const SizedBox(height: 6),
                    // The count is chosen circles against the day's budget,
                    // not a reserve of uses.
                    InstrumentHint(ru
                        ? 'выбрано · можно вернуть до $budget ${ruPlural(budget, 'круга', 'кругов', 'кругов')}'
                        : 'chosen · up to $budget circle${budget == 1 ? '' : 's'} back'),
                  ]),
            ),
            Peek(
              title: ru ? 'Бюджет' : 'Budget',
              text: ru
                  ? 'Сумма кругов возвращаемых ячеек — до $budget'
                  : 'The circles of recovered slots add up to $budget at most',
              child: SizedBox(
                width: 120,
                child: Row(children: [
                  for (var i = 0; i < budget; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color:
                              i < used ? a2 : c.onSurface.withValues(alpha: .1),
                          boxShadow: i < used
                              ? [
                                  BoxShadow(
                                      color: a2.withValues(alpha: .6),
                                      blurRadius: 8,
                                      spreadRadius: -2)
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          // The crystals unfold when there is something to recover and fold
          // away again when all slots are full, as one morph.
          MorphSwitcher(
            child: KeyedSubtree(
              key: ValueKey(spent > 0 || widget.used ? 'open' : 'closed'),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (spent > 0 || used > 0)
                      for (final (circle, current, maximum) in rows)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: c.onSurface.withValues(alpha: .04),
                                borderRadius: BorderRadius.circular(16)),
                            child: Row(children: [
                              SizedBox(
                                  width: 54,
                                  child: Text(
                                      ru ? '$circle круг' : 'Level $circle',
                                      style: hintStyle(context).copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600))),
                              Expanded(
                                child:
                                    Wrap(spacing: 12, runSpacing: 8, children: [
                                  for (var i = 0; i < maximum; i++)
                                    _Crystal(
                                      circle: circle,
                                      state: i < current
                                          ? _Gem.lit
                                          : i < current + (_pick[circle] ?? 0)
                                              ? _Gem.selected
                                              : _Gem.dim,
                                      accent: widget.accent,
                                      gold: a2,
                                      restoring: _restoring,
                                      onTap: widget.used || _busy
                                          ? null
                                          : () {
                                              final picked = _pick[circle] ?? 0;
                                              if (i < current) {
                                                AppSnackBar.info(
                                                    context,
                                                    ru
                                                        ? 'Ячейка $circle круга полна'
                                                        : 'This slot is full');
                                                return;
                                              }
                                              if (i < current + picked) {
                                                HapticFeedback.selectionClick();
                                                setState(() =>
                                                    _pick[circle] = picked - 1);
                                                return;
                                              }
                                              if (used + circle > budget) {
                                                HapticFeedback.heavyImpact();
                                                AppSnackBar.info(
                                                    context,
                                                    ru
                                                        ? 'Бюджет — $budget'
                                                        : 'The budget is $budget');
                                                return;
                                              }
                                              HapticFeedback.selectionClick();
                                              setState(() =>
                                                  _pick[circle] = picked + 1);
                                            },
                                    ),
                                ]),
                              ),
                              RollingNumber(current,
                                  style: bigStyle(context).copyWith(
                                      fontSize: 14, color: c.onSurfaceVariant)),
                              Text('/$maximum',
                                  style: bigStyle(context).copyWith(
                                      fontSize: 14, color: c.onSurfaceVariant)),
                            ]),
                          ),
                        ),
                    const SizedBox(height: 4),
                    InstrumentHint(
                        widget.used
                            ? (ru
                                ? 'Восстановление уже было сегодня'
                                : 'Already recovered today')
                            : spent > 0
                                ? (ru
                                    ? 'Тусклые — потраченные. Коснитесь, чтобы вернуть'
                                    : 'Dim crystals are spent. Tap to recover them')
                                : (ru
                                    ? 'Все ячейки полны — возвращать нечего. Потратьте ячейку, и на коротком отдыхе её можно будет вернуть здесь'
                                    : 'All slots are full — nothing to recover. Spend a slot and you can bring it back here on a short rest'),
                        center: true),
                    if (spent > 0 || widget.used) ...[
                      const SizedBox(height: 10),
                      GoButton(
                        label: widget.used
                            ? (ru ? 'Завтра снова' : 'Again tomorrow')
                            : used > 0
                                ? (ru
                                    ? 'Вернуть ячейки · $used'
                                    : 'Recover slots · $used')
                                : (ru
                                    ? 'Выберите потраченные ячейки'
                                    : 'Choose spent slots'),
                        accent: widget.accent,
                        onTap: !widget.used && used > 0 && !_busy
                            ? _recover
                            : null,
                      ),
                    ],
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

enum _Gem { lit, dim, selected }

class _Crystal extends StatelessWidget {
  const _Crystal(
      {required this.circle,
      required this.state,
      required this.accent,
      required this.gold,
      required this.restoring,
      this.onTap});
  final int circle;
  final _Gem state;
  final Color accent, gold;
  final bool restoring;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final size = 20.0 + math.min(3, circle - 1) * 2;
    final selected = state == _Gem.selected;
    Widget gem = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: state == _Gem.dim
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: selected
                    ? [Colors.white, gold]
                    : [mixColor(Colors.white, .45, accent), accent]),
        border:
            state == _Gem.dim ? Border.all(color: c.outline, width: 2) : null,
        boxShadow: state == _Gem.dim
            ? null
            : [
                BoxShadow(
                    color: (selected ? gold : accent).withValues(alpha: .6),
                    blurRadius: 12,
                    spreadRadius: -2)
              ],
      ),
    );
    if (selected && !MediaQuery.disableAnimationsOf(context)) {
      gem = Pulse(trigger: restoring, scale: 1.2, child: gem);
    }
    return Pressable(
      onTap: onTap,
      scale: .88,
      semanticLabel: '$circle',
      child: SizedBox.square(
        dimension: size * 1.42,
        child: Center(child: Transform.rotate(angle: math.pi / 4, child: gem)),
      ),
    );
  }
}
