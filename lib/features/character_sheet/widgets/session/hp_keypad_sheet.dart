import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/character.dart';
import '../../../../core/services/gameplay_actions_service.dart';

enum HpChange { damage, healing, temporary }

// The last applied amount per hero, for "same as last time" at the table.
final _lastAmount = <String, int>{};

/// Damage, healing and temporary HP from one number pad: the amount is
/// typed with the thumb, quick amounts sit above the keys, and the button
/// names exactly what will happen.
Future<bool> showHpKeypad(BuildContext context, Character character,
    {HpChange mode = HpChange.damage}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final l10n = AppLocalizations.of(context)!;
  // The sheet answers with the concentration DC to announce, 0 for none.
  final dc = await showCompanionSheet<int>(context,
      builder: (_) => _HpKeypad(character: character, mode: mode));
  if (dc == null) return false;
  if (dc > 0 && context.mounted) {
    AppSnackBar.info(context, l10n.sheetConcentrationDc(dc));
  }
  return true;
}

class _HpKeypad extends StatefulWidget {
  const _HpKeypad({required this.character, required this.mode});
  final Character character;
  final HpChange mode;
  @override
  State<_HpKeypad> createState() => _HpKeypadState();
}

class _HpKeypadState extends State<_HpKeypad> {
  late HpChange _mode = widget.mode;
  int _amount = 0;
  bool _saving = false;

  Character get _hero => widget.character;

  void _set(int value) {
    HapticFeedback.selectionClick();
    setState(() => _amount = value.clamp(0, 9999));
  }

  void _key(String key) {
    if (key == 'del') return _set(_amount ~/ 10);
    final next = int.parse('$_amount$key');
    _set(math.min(next, 9999));
  }

  Future<void> _apply() async {
    if (_amount <= 0 || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final amount = _amount;
    final concentration =
        _mode == HpChange.damage && _hero.concentratingOn != null;
    try {
      switch (_mode) {
        case HpChange.damage:
          await GameplayActionsService.changeHealth(_hero, amount,
              healing: false);
        case HpChange.healing:
          await GameplayActionsService.changeHealth(_hero, amount,
              healing: true);
        case HpChange.temporary:
          // Temporary HP never stacks: the larger pool stays.
          await GameplayActionsService.editHealth(_hero,
              current: _hero.currentHp,
              maximum: _hero.maxHp,
              temporary: math.max(_hero.temporaryHp, amount));
      }
      _lastAmount[_hero.id] = amount;
      if (_mode == HpChange.damage && _hero.currentHp == 0) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      if (!mounted) return;
      Navigator.pop(context, concentration ? math.max(10, amount ~/ 2) : 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, l10n.sheetSaveFailed);
    }
  }

  String _actionLabel(AppLocalizations l10n) {
    if (_amount == 0) {
      return switch (_mode) {
        HpChange.damage => l10n.hpKeypadEnterDamage,
        HpChange.healing => l10n.hpKeypadEnterHealing,
        HpChange.temporary => l10n.hpKeypadEnterTemporary,
      };
    }
    return switch (_mode) {
      HpChange.damage => l10n.hpKeypadApplyDamage(_amount),
      HpChange.healing => l10n.hpKeypadApplyHealing(_amount),
      HpChange.temporary => l10n.hpKeypadApplyTemporary(_amount),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final last = _lastAmount[_hero.id];
    Widget key(String value) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _Key(
              key: ValueKey('hp-key-$value'),
              label: value == 'del' ? l10n.hpKeypadErase : value,
              onTap: _saving ? null : () => _key(value),
              child: value == 'del'
                  ? LineIcon('del', size: 24, color: c.onSurface)
                  : Text(value,
                      style: AppType.numeric(t.textTheme.titleLarge).copyWith(
                          fontSize: 22, fontWeight: FontWeight.w600)),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetHeading('${l10n.hpShort} · ${_hero.currentHp} / ${_hero.maxHp}'),
      const SizedBox(height: 14),
      FlowSegment<HpChange>(
        keyPrefix: 'hp-mode',
        values: HpChange.values,
        labels: [l10n.damage, l10n.heal, l10n.hpKeypadTemporary],
        selected: _mode,
        onChanged: (mode) => setState(() => _mode = mode),
      ),
      const SizedBox(height: 14),
      Semantics(
        liveRegion: true,
        child: Center(
          child: Text('$_amount',
              key: const ValueKey('hp-keypad-amount'),
              style: AppType.numeric(t.textTheme.displayMedium).copyWith(
                  fontSize: 56,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.6,
                  color: _amount == 0 ? c.onSurfaceVariant : c.onSurface)),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final n in const [1, 5, 10])
              OutlineChip(
                  label: '+$n',
                  onTap: _saving ? null : () => _set(_amount + n)),
            if (last != null)
              OutlineChip(
                  label: l10n.hpKeypadSameAsLast(last),
                  onTap: _saving ? null : () => _set(last)),
          ]),
      const SizedBox(height: 10),
      for (final row in const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['del', '0', '00'],
      ])
        Row(children: [for (final k in row) key(k)]),
      const SizedBox(height: 10),
      ToneButton(
        key: const ValueKey('hp-keypad-apply'),
        kind: _mode == HpChange.healing ? ToneKind.heal : ToneKind.primary,
        height: 54,
        expand: true,
        fontSize: 15,
        label: _actionLabel(l10n),
        onPressed: _amount == 0 || _saving ? null : _apply,
      ),
    ]);
  }
}

/// A number-pad key: 56 high, corners 18, on the low surface; it dips and
/// lights up while pressed.
class _Key extends StatefulWidget {
  const _Key(
      {super.key, required this.child, required this.label, this.onTap});
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: Pressable(
        onTap: widget.onTap,
        scale: .94,
        semanticLabel: widget.label,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _down ? c.surfaceContainerHigh : c.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18)),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
