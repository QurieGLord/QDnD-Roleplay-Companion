import '../../../shared/widgets/magic_allocation_sheet.dart';
import '../../../core/magic/magic_slots.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../../core/models/character.dart';
import '../../../core/services/gameplay_actions_service.dart';
import 'session/resource_counter.dart';
import 'session/value_editor_dialog.dart';

class SpellSlotsWidget extends StatefulWidget {
  const SpellSlotsWidget(
      {super.key,
      required this.character,
      required this.onChanged,
      this.showSlots = true,
      this.showArcanum = true,
      this.prominent = false});
  final Character character;
  final VoidCallback onChanged;
  final bool showSlots, showArcanum, prominent;
  @override
  State<SpellSlotsWidget> createState() => _SpellSlotsWidgetState();
}

class _SpellSlotsWidgetState extends State<SpellSlotsWidget> {
  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  int _current(int level) =>
      MagicSlots.read(widget.character).remaining(MagicPool.shared, level);
  int _maximum(int level) {
    final maximum = MagicSlots.read(widget.character).maximum;
    return level <= maximum.length ? maximum[level - 1] : 0;
  }

  Widget _slotTile(int level) {
    final l10n = AppLocalizations.of(context)!;
    return SheetResourceCounter(
      key: ValueKey('slot-counter-$level'),
      prominent: widget.prominent,
      name: l10n.levelSlot(level),
      badge: '$level',
      current: () => _current(level),
      maximum: () => _maximum(level),
      onStep: (delta) => GameplayActionsService.changeMagicSlot(
          widget.character, MagicPool.shared, level, delta),
      onEdit: () => showSheetValueEditor(context,
          title: l10n.levelSlot(level),
          icon: Icons.auto_awesome,
          fields: [
            SheetNumberField('value', l10n.sheetRemainder, _current(level),
                hint: l10n.gameStateNormalMaximum(_maximum(level)))
          ],
          onSave: (values, _) => GameplayActionsService.editMagicSlot(
              widget.character, MagicPool.shared, level, values['value']!)),
      onChanged: _changed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character, l10n = AppLocalizations.of(context)!;
    final ru = Localizations.localeOf(context).languageCode == 'ru';
    MagicSlots state;
    try {
      state = MagicSlots.read(c);
    } catch (_) {
      return Column(children: [
        Text(ru
            ? 'Нужно разделить запасы магии старого листа.'
            : 'Separate this older sheet’s spell pools.'),
        TextButton(
            onPressed: () async {
              final changed = await showMagicAllocationSheet(context, c);
              if (changed) _changed();
            },
            child: Text(ru ? 'Уточнить запасы' : 'Resolve spell pools'))
      ]);
    }
    final pact = state.pact;
    final arcanumLevels = [
      for (int level = 6; level <= 9; level++)
        if (c.classLevel('warlock') >= (level - 1) * 2 + 1) level
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.showSlots) ...[
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 0,
            children: [
              for (int level = 1;
                  level <=
                      math.min(9,
                          math.max(state.current.length, state.maximum.length));
                  level++)
                if (_current(level) > 0 || _maximum(level) > 0) _slotTile(level)
            ]),
        if (pact != null) ...[
          if (state.current.any((n) => n > 0) ||
              state.maximum.any((n) => n > 0))
            const SizedBox(height: 12),
          Text(ru ? 'Магия договора' : 'Pact Magic',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge),
          Wrap(alignment: WrapAlignment.center, children: [
            SheetResourceCounter(
                key: const ValueKey('pact-slot-counter'),
                prominent: widget.prominent,
                name:
                    '${ru ? 'Магия договора' : 'Pact Magic'} · ${l10n.levelLabel(pact.circle)}',
                badge: '${pact.circle}',
                current: () => MagicSlots.read(c).pact!.current,
                maximum: () => MagicSlots.read(c).pact!.maximum,
                onStep: (delta) => GameplayActionsService.changeMagicSlot(
                    c, MagicPool.pact, pact.circle, delta),
                onEdit: () => showSheetValueEditor(context,
                    title: ru ? 'Магия договора' : 'Pact Magic',
                    icon: Icons.auto_awesome,
                    fields: [
                      SheetNumberField(
                          'value', l10n.sheetRemainder, pact.current,
                          hint: l10n.gameStateNormalMaximum(pact.maximum))
                    ],
                    onSave: (values, _) => GameplayActionsService.editMagicSlot(
                        c, MagicPool.pact, pact.circle, values['value']!)),
                onChanged: _changed)
          ]),
        ],
        const SizedBox(height: 12),
        Text(l10n.sheetTapHoldHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
      if (widget.showArcanum && arcanumLevels.isNotEmpty) ...[
        if (widget.showSlots) const Divider(height: 24),
        if (widget.showSlots)
          Text(l10n.sheetArcanum,
              style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final level in arcanumLevels)
                SheetResourceCounter(
                  key: ValueKey('arcanum-counter-$level'),
                  prominent: widget.prominent,
                  name: l10n.levelSlot(level),
                  badge: '$level',
                  current: () =>
                      GameplayActionsService.arcanumFeature(c, level)
                          ?.resourcePool
                          ?.currentUses ??
                      0,
                  maximum: () =>
                      GameplayActionsService.arcanumFeature(c, level)
                          ?.resourcePool
                          ?.maxUses ??
                      1,
                  onStep: (delta) =>
                      GameplayActionsService.changeArcanum(c, level, delta),
                  onEdit: () {
                    final f = GameplayActionsService.arcanumFeature(c, level);
                    return showSheetValueEditor(
                      context,
                      title: '${l10n.sheetArcanum} · ${l10n.levelSlot(level)}',
                      icon: Icons.auto_awesome,
                      fields: [
                        SheetNumberField('value', l10n.sheetRemainder,
                            f?.resourcePool?.currentUses ?? 0,
                            hint: l10n.gameStateNormalMaximum(
                                f?.resourcePool?.maxUses ?? 1))
                      ],
                      onSave: (values, _) => GameplayActionsService.editArcanum(
                          c, level, values['value']!),
                    );
                  },
                  onChanged: _changed,
                ),
            ]),
      ],
    ]);
  }
}
