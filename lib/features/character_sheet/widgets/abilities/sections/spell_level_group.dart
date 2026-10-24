import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/magic/spell_use.dart';
import '../../../../../core/magic/spellbook_state.dart';
import '../../../../../core/models/character.dart';
import '../../../../../core/models/spell.dart';
import '../../class_widgets/instrument/instrument_kit.dart';
import 'spell_list_item.dart';

/// Remaining and total slots of one circle, shown as marks in its header.
typedef CircleSlots = ({int current, int maximum});

/// One circle of the Magic section (prototype `.circle`, variant A): the
/// header carries the circle's slot marks — a touch spends one, a hold
/// edits — and folds the spells below it.
class AbilitiesSpellLevelGroup extends StatefulWidget {
  const AbilitiesSpellLevelGroup({
    super.key,
    required this.character,
    required this.level,
    required this.spells,
    required this.locale,
    required this.initiallyExpanded,
    required this.onExpandedChanged,
    required this.onOpenDetails,
    required this.onCastSpell,
    required this.onTogglePreparation,
    this.slots,
    this.onSpendSlot,
    this.onEditSlot,
    this.showOwner = false,
    this.title,
    this.subtitle,
    this.tint,
  });

  final Character character;
  final int level;
  final List<Spell> spells;
  final String locale;
  final bool initiallyExpanded;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<Spell> onOpenDetails;
  final ValueChanged<Spell> onCastSpell;
  final ValueChanged<Spell> onTogglePreparation;
  final CircleSlots? slots;
  final VoidCallback? onSpendSlot, onEditSlot;

  /// Several spellcasting classes: each row names its owner.
  final bool showOwner;

  /// Overrides for a slot-only row (Pact Magic, a circle kept for upcasting).
  final String? title, subtitle;
  final Color? tint;

  @override
  State<AbilitiesSpellLevelGroup> createState() => _AbilitiesSpellLevelGroupState();
}

class _AbilitiesSpellLevelGroupState extends State<AbilitiesSpellLevelGroup> {
  late bool _open = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant AbilitiesSpellLevelGroup old) {
    super.didUpdateWidget(old);
    if (old.initiallyExpanded != widget.initiallyExpanded) _open = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final ru = widget.locale == 'ru';
    final level = widget.level;
    final spells = [...widget.spells]..sort((a, b) {
        final ready = (_ready(b) ? 1 : 0) - (_ready(a) ? 1 : 0);
        return ready != 0 ? ready : a.getName(widget.locale).compareTo(b.getName(widget.locale));
      });
    final readyCount = spells.where(_ready).length;
    final foldable = spells.isNotEmpty;
    final title = widget.title ?? (level == 0 ? l10n.cantrips : (ru ? '$level круг' : 'Level $level'));
    final subtitle = widget.subtitle ??
        (level == 0
            ? (ru ? 'без ячеек' : 'no slots')
            : ru
                ? '$readyCount ${ruPlural(readyCount, 'заклинание', 'заклинания', 'заклинаний')}'
                : '$readyCount spell${readyCount == 1 ? '' : 's'}');
    final slots = widget.slots;

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        Flexible(
          flex: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 68),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontFamily: AppType.display, fontSize: 16, fontWeight: FontWeight.w600, height: 1.2)),
              Text(subtitle, style: TextStyle(fontFamily: AppType.body, fontSize: 12, fontWeight: FontWeight.w500, height: 1.2, color: c.onSurfaceVariant)),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: slots == null
              ? const SizedBox.shrink()
              : _Marks(
                  key: ValueKey('slot-marks-$level'),
                  current: slots.current,
                  maximum: slots.maximum,
                  onSpend: widget.onSpendSlot,
                  onEdit: widget.onEditSlot,
                ),
        ),
        const SizedBox(width: 10),
        if (slots != null)
          Row(key: ValueKey('slot-count-${widget.title == null ? level : 'pact'}'), mainAxisSize: MainAxisSize.min, children: [
            RollingNumber(slots.current, style: _leftStyle(c)),
            Text('/${slots.maximum}', style: _leftStyle(c)),
          ])
        else
          Text('${spells.length}', style: _leftStyle(c)),
        if (foldable) ...[
          const SizedBox(width: 10),
          AnimatedRotation(
            turns: _open ? .5 : 0,
            duration: AppMotion.of(context, const Duration(milliseconds: 260)),
            curve: AppMotion.snappyCurve,
            child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: c.onSurfaceVariant),
          ),
        ],
      ]),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.tint == null ? c.surfaceContainerLow : mixColor(widget.tint!, .1, c.surfaceContainerLow),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (foldable)
          Pressable(
            key: ValueKey('spell-circle-$level'),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _open = !_open);
              widget.onExpandedChanged(_open);
            },
            onLongPress: widget.onEditSlot,
            scale: .99,
            semanticLabel: title,
            child: header,
          )
        else
          GestureDetector(onLongPress: widget.onEditSlot, child: header),
        AnimatedSize(
          duration: AppMotion.of(context, const Duration(milliseconds: 380)),
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: !_open || !foldable
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                  child: Column(children: [
                    for (final spell in spells)
                      AbilitiesSpellListItem(
                        key: ValueKey('spell-row-${spell.id}'),
                        spell: spell,
                        character: widget.character,
                        locale: widget.locale,
                        isPrepared: _ready(spell),
                        isSpontaneous: spell.level == 0 ||
                            SpellUse.sources(widget.character, spell)
                                .any((s) => s.ready && !widget.character.preparedSpells.contains(spell.id)),
                        canCast: _canCast(spell),
                        showOwner: widget.showOwner,
                        onOpenDetails: () => widget.onOpenDetails(spell),
                        onCastSpell: () => widget.onCastSpell(spell),
                        onTogglePreparation: () => widget.onTogglePreparation(spell),
                      ),
                  ]),
                ),
        ),
      ]),
    );
  }

  TextStyle _leftStyle(ColorScheme c) => TextStyle(
      fontFamily: AppType.display,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1,
      color: c.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()]);

  bool _ready(Spell spell) {
    try {
      return SpellUse.ready(widget.character, spell);
    } catch (_) {
      return false;
    }
  }

  bool _canCast(Spell spell) {
    try {
      if (SpellbookState.read(widget.character.spellbookData).ownersOf(spell.id).contains('manual')) return true;
      return SpellUse.options(widget.character, spell).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

/// Slot marks of a circle header: lit for each remaining slot, a ring for a
/// spent one. A touch on any mark spends one slot; a hold edits.
class _Marks extends StatelessWidget {
  const _Marks({super.key, required this.current, required this.maximum, this.onSpend, this.onEdit});
  final int current, maximum;
  final VoidCallback? onSpend, onEdit;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (var i = 0; i < maximum; i++)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onSpend,
          onLongPress: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AnimatedScale(
              scale: i < current ? 1 : .86,
              duration: AppMotion.of(context, const Duration(milliseconds: 300)),
              curve: AppMotion.snappyCurve,
              child: AnimatedContainer(
                duration: AppMotion.of(context, const Duration(milliseconds: 300)),
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < current ? c.secondary : Colors.transparent,
                  border: i < current ? null : Border.all(color: c.outline, width: 1.8),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
