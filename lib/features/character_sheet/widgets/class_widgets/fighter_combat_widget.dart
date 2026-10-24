import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/core/ui/expressive_kit.dart';

import '../../../../core/models/character.dart';
import '../../../../core/models/character_feature.dart';
import '../../../../core/progression/character_class_context.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../session/value_editors.dart';
import 'instrument/instrument_kit.dart';

/// Fighter (prototype `CLASS.fighter`): the accepted connected surface,
/// chamfered. Second Wind rolls its d10 in place and the healing rolls into
/// the hit points; Action Surge lights a second action; Indomitable rolls
/// its d20 right on the cell.
class FighterCombatWidget extends StatefulWidget {
  const FighterCombatWidget(
      {super.key,
      required this.character,
      this.secondWindFeature,
      this.actionSurgeFeature,
      this.indomitableFeature,
      this.onChanged});
  final Character character;
  final CharacterFeature? secondWindFeature, actionSurgeFeature, indomitableFeature;
  final VoidCallback? onChanged;
  @override
  State<FighterCombatWidget> createState() => _FighterCombatWidgetState();
}

class _FighterCombatWidgetState extends State<FighterCombatWidget> {
  bool _busy = false;

  /// The last Second Wind: what the d10 showed and what it healed.
  int? lastSecondWindRoll, lastSecondWindHealing;
  int _windKey = 0, _saveKey = 0;
  int? _save;
  bool _surging = false;

  CharacterClassContext get _fighter => CharacterClassContext(widget.character, 'fighter');

  CharacterFeature? _usable(CharacterFeature? f) =>
      f?.resourcePool != null && _fighter.canUseFeature(f!) ? f : null;

  List<CharacterFeature> get _styles => widget.character.features.where((f) {
        if (!_fighter.canUseFeature(f)) return false;
        final id = f.id.toLowerCase().replaceAll('_', '-');
        const containers = {'fighting-style', 'additional-fighting-style', 'fighter-fighting-style'};
        if (containers.contains(id) || {'fighting style', 'additional fighting style'}.contains(f.nameEn.toLowerCase())) {
          return false;
        }
        if (id.startsWith('ranger-') || id.startsWith('paladin-')) return false;
        return id.startsWith('fighter-fighting-style-') || id.startsWith('fighting-style-') || id.startsWith('fs-');
      }).toList();

  CharacterFeature? get _critical {
    final found = widget.character.features.where((f) {
      if (!_fighter.canUseFeature(f)) return false;
      final id = f.id.toLowerCase().replaceAll('_', '-');
      return id.contains('improved-critical') || id.contains('superior-critical');
    }).toList();
    return found.where((f) => f.id.contains('superior')).firstOrNull ?? found.firstOrNull;
  }

  Future<void> _activate(CharacterFeature feature) async {
    if (_busy || !_fighter.canUseFeature(feature)) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final secondWind = identical(feature, widget.secondWindFeature);
      final indomitable = identical(feature, widget.indomitableFeature);
      final roll = secondWind ? Random().nextInt(10) + 1 : 0;
      final healing = secondWind ? roll + _fighter.level : 0;
      final result = await GameplayActionsService.activateResource(widget.character, feature, healing: healing);
      if (!mounted || !result.spent) return;
      HapticFeedback.mediumImpact();
      setState(() {
        if (secondWind) {
          lastSecondWindRoll = roll;
          lastSecondWindHealing = result.healed;
          _windKey++;
        } else if (indomitable) {
          _save = Random().nextInt(20) + 1;
          _saveKey++;
        } else {
          _surging = true;
        }
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) AppSnackBar.error(context, l10n.sheetSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(CharacterFeature feature) async {
    final changed = await showResourceValueEditor(context, widget.character, feature);
    if (mounted && changed) setState(() => widget.onChanged?.call());
  }

  InstrumentAbout _about(CharacterFeature f, String locale, String? how) => InstrumentAbout(
      title: f.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
      paragraphs: f.getDescription(locale).split(RegExp(r'\n\s*\n')),
      how: how);

  @override
  Widget build(BuildContext context) {
    final ru = instrumentRu(context), locale = ru ? 'ru' : 'en';
    final level = _fighter.level;
    final wind = _usable(widget.secondWindFeature), surge = _usable(widget.actionSurgeFeature), indom = _usable(widget.indomitableFeature);
    final styles = _styles, critical = _critical;
    if (level == 0 || (wind == null && surge == null && indom == null && styles.isEmpty)) return const SizedBox.shrink();
    final a4 = accentOf(context, 4), a0 = accentOf(context, 0), a2 = accentOf(context, 2);
    final c = Theme.of(context).colorScheme;
    final k = ru ? 'к' : 'd';
    final crit = critical == null ? 20 : (critical.id.contains('superior') ? 18 : 19);
    final children = <Widget>[];
    if (wind != null) {
      final pool = wind.resourcePool!;
      children.add(Instrument(
        key: const ValueKey('fighter-second-wind'),
        accent: a4,
        chamfer: true,
        title: wind.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
        about: _about(wind, locale,
            ru ? 'Коснитесь кости — она бросится, и ОЗ прибавятся сами.' : 'Tap the die: it rolls and the hit points are added.'),
        trailing: RestChip(
            short: pool.recoveryType == RecoveryType.shortRest,
            onEdit: () => _edit(wind),
            onRestore: () => restoreFeature(context, widget.character, wind, done: () => setState(() => widget.onChanged?.call()))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('1${k}10 + $level', style: bigStyle(context)),
                const SizedBox(height: 6),
                InstrumentHint([
                  // An unusual reserve (overfilled, or more than one use) stays visible.
                  if (pool.maxUses != 1 || pool.currentUses > 1) '${pool.currentUses} / ${pool.maxUses}',
                  pool.currentUses > 0
                      ? (ru ? 'коснитесь кости' : 'tap the die')
                      : (ru ? 'вернёт короткий отдых' : 'a short rest restores it'),
                ].join(' · ')),
              ]),
            ),
            Opacity(
              opacity: pool.currentUses > 0 ? 1 : .4,
              child: Pressable(
                key: ValueKey('fighter-action-${wind.id}'),
                onTap: pool.currentUses > 0 && !_busy ? () => _activate(wind) : null,
                scale: .93,
                semanticLabel: wind.getName(locale),
                child: TumbleDie(
                    shape: DieShape.d10,
                    label: lastSecondWindRoll?.toString() ?? '${k}10',
                    accent: a4,
                    rollKey: _windKey,
                    sides: 10,
                    natural: lastSecondWindRoll,
                    size: 84),
              ),
            ),
          ]),
          if (lastSecondWindHealing != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Pulse(
                trigger: _windKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppPaletteRoles.heal(context).withValues(alpha: .16), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    InstrumentGlyph('heart', size: 18, color: AppPaletteRoles.heal(context)),
                    const SizedBox(width: 8),
                    RollingNumber(lastSecondWindHealing!, style: bigStyle(context).copyWith(fontSize: 24)),
                    const SizedBox(width: 6),
                    Text(ru ? 'ОЗ' : 'HP', style: hintStyle(context)),
                  ]),
                ),
              ),
            ),
        ]),
      ));
    }
    final cells = <Widget>[
      if (surge != null)
        CellTile(
          key: ValueKey('fighter-action-${surge.id}'),
          accent: a0,
          chamfer: true,
          lit: _surging,
          onTap: surge.resourcePool!.currentUses > 0 && !_busy ? () => _activate(surge) : null,
          peek: (surge.getName(locale), surge.getDescription(locale)),
          children: [
            InstrumentCap(ru ? 'Всплеск' : 'Surge', accent: a0, about: _about(surge, locale, null)),
            Row(children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Transform.rotate(
                  angle: pi / 4,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: i == 0 || _surging ? a0 : null,
                        border: i == 0 || _surging ? null : Border.all(color: c.outline, width: 2)),
                  ),
                ),
              ],
            ]),
            InstrumentHint(_surging
                ? (ru ? 'два действия' : 'two actions')
                : '${surge.resourcePool!.currentUses} / ${surge.resourcePool!.maxUses}'),
          ],
        )
      else if (level < 2)
        LockedCell(title: ru ? 'Всплеск' : 'Surge', level: 2, accent: a0),
      if (indom != null)
        CellTile(
          key: ValueKey('fighter-action-${indom.id}'),
          accent: a2,
          chamfer: true,
          onTap: indom.resourcePool!.currentUses > 0 && !_busy ? () => _activate(indom) : null,
          peek: (indom.getName(locale), indom.getDescription(locale)),
          children: [
            InstrumentCap(indom.getName(locale).replaceAll(RegExp(r'\s*\(.*?\)'), ''), accent: a2, about: _about(indom, locale, null)),
            TumbleDie(shape: DieShape.d20, label: _save?.toString() ?? '${k}20', accent: a2, rollKey: _saveKey, sides: 20, natural: _save, size: 46),
            InstrumentHint(_save != null
                ? (ru ? 'переброс' : 'reroll')
                : '${indom.resourcePool!.currentUses} / ${indom.resourcePool!.maxUses}'),
          ],
        )
      else if (level < 9)
        LockedCell(title: ru ? 'Несгибаемый' : 'Indomitable', level: 9, accent: a2),
    ];
    if (cells.isNotEmpty) children.add(TileRow(children: cells));
    if (critical != null) {
      children.add(Peek(
        title: critical.getName(locale),
        text: ru ? 'Критическое попадание на $crit–20' : 'A critical hit on $crit–20',
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            TumbleDie(shape: DieShape.d20, label: '$crit', accent: a2, size: 42),
            const SizedBox(width: 12),
            Expanded(child: Text(ru ? 'Крит на $crit–20' : 'Crit on $crit–20', style: labelStyle(context, size: 15))),
          ]),
        ),
      ));
    }
    if (styles.isNotEmpty) {
      children.add(Wrap(spacing: 6, runSpacing: 6, children: [
        for (final style in styles)
          InstrumentChip(style.getName(locale),
              glyph: 'shield',
              onTap: () => showInstrumentAbout(context, _about(style, locale, null), a4)),
      ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ]
    ]);
  }
}
