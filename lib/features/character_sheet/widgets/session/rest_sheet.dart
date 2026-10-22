import 'short_rest_dice_sheet.dart';
import '../../../../core/magic/magic_slots.dart';
import '../../../../core/services/feature_service.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../core/models/character.dart';
import '../../../../core/services/gameplay_actions_service.dart';
import '../../../../core/services/qdnd_bundle_codec.dart';
import '../../../../core/services/spell_service.dart';
import 'value_editor_dialog.dart';
import 'package:qd_and_d/core/theme/app_palettes.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import '../../../../core/ui/companion_kit.dart';

/// The prototype's rest tiles: two calm tiles side by side, each an icon in
/// the violet accent and its name.
class SheetRestActions extends StatelessWidget {
  const SheetRestActions({
    super.key,
    required this.busy,
    required this.onShortRest,
    required this.onLongRest,
  });
  final bool busy;
  final VoidCallback onShortRest, onLongRest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context), c = t.colorScheme;
    final violet = AppAccents.of(context).at(5);
    Widget tile(String id, String label, String semantic, String icon,
            VoidCallback callback) =>
        Expanded(
          child: Opacity(
            opacity: busy ? .45 : 1,
            child: Pressable(
              key: ValueKey('sheet-rest-$id'),
              onTap: busy ? null : callback,
              scale: .97,
              semanticLabel: semantic,
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: c.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
                  child: Row(children: [
                    LineIcon(icon, size: 22, color: violet),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label,
                          style: t.textTheme.labelLarge?.copyWith(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        tile('short', l10n.restShortTile, l10n.shortRest, 'cup', onShortRest),
        const SizedBox(width: 8),
        tile('long', l10n.restLongTile, l10n.longRest, 'moon', onLongRest),
      ]),
    );
  }
}

Future<bool> showRestSheet(BuildContext context, Character character,
    {required bool short}) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  // Apply the actual rules to an owned copy. Previewing never touches storage,
  // the live hero, or shared feature definitions.
  final after = QdndBundleCodec.cloneCharacter(character);
  FeatureService.prepareKnownResourcePools(after);
  if (short) {
    after.shortRest();
  } else {
    after.longRest();
  }
  return showSheetValueEditor(
    context,
    title: short ? l10n.shortRest : l10n.longRest,
    icon: short ? Icons.local_cafe_outlined : Icons.bedtime_outlined,
    fields: const [],
    actionLabel: l10n.rest,
    description: short ? l10n.shortRestDescription : l10n.longRestDescription,
    content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _RestPreview(changes: _changes(character, after, l10n, locale)),
      if (short && character.hitDice.length == character.classes.length)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
                icon: const Icon(Icons.casino_outlined),
                label: Text(locale == 'ru'
                    ? 'Отдых с костями хитов'
                    : 'Rest with Hit Dice'),
                onPressed: () async {
                  final changed =
                      await showShortRestDiceSheet(context, character);
                  if (context.mounted && changed) Navigator.pop(context, true);
                })),
    ]),
    onSave: (_, __) => GameplayActionsService.rest(character, short: short),
  );
}

class _RestChange {
  const _RestChange(this.id, this.label, this.result);
  final String id, label, result;
}

List<_RestChange> _changes(
    Character before, Character after, AppLocalizations l10n, String locale) {
  final changes = <_RestChange>[];
  void number(String id, String label, int old, int next, {int? maximum}) {
    if (old == next) return;
    String value(int n) => maximum == null ? '$n' : '$n / $maximum';
    changes.add(_RestChange(id, label, '${value(old)} → ${value(next)}'));
  }

  number('hp', l10n.hpShort, before.currentHp, after.currentHp,
      maximum: after.maxHp);
  for (int i = 0; i < after.spellSlots.length; i++) {
    number(
        'slot-${i + 1}',
        l10n.levelSlot(i + 1),
        i < before.spellSlots.length ? before.spellSlots[i] : 0,
        after.spellSlots[i],
        maximum: i < after.maxSpellSlots.length ? after.maxSpellSlots[i] : 0);
  }
  try {
    final old = MagicSlots.read(before).pact,
        next = MagicSlots.read(after).pact;
    if (old != null && next != null) {
      number('pact', locale == 'ru' ? 'Магия договора' : 'Pact Magic',
          old.current, next.current,
          maximum: next.maximum);
    }
  } catch (_) {}
  for (int i = 0; i < before.features.length; i++) {
    final feature = before.features[i];
    if (Character.isChannelDivinityResource(feature)) continue;
    final old = feature.resourcePool, next = after.features[i].resourcePool;
    if (old != null && next != null) {
      number(
          'pool-$i', feature.getName(locale), old.currentUses, next.currentUses,
          maximum: next.maxUses);
    }
  }
  number(
      'channel-divinity',
      l10n.channelDivinity,
      before.editableChannelDivinityCharges,
      after.editableChannelDivinityCharges,
      maximum: after.getMaxChannelDivinityCharges());
  number('wild-shape', l10n.wildShape, before.wildShapeCharges,
      after.wildShapeCharges,
      maximum: 2);
  number(
      'hit-dice',
      l10n.gameStateHitDice,
      before.hitDice.fold(0, (sum, n) => sum + n),
      after.hitDice.fold(0, (sum, n) => sum + n),
      maximum: after.maxHitDice);
  void ready(String id, String label, bool old, bool next) {
    if (old && !next) {
      changes.add(_RestChange(id, label, l10n.sheetRestReady));
    }
  }

  ready('arcane-recovery', l10n.arcaneRecovery, before.arcaneRecoveryUsed,
      after.arcaneRecoveryUsed);
  ready('natural-recovery', l10n.naturalRecovery, before.naturalRecoveryUsed,
      after.naturalRecoveryUsed);
  for (final entry in before.signatureSpellsUsed.entries) {
    ready(
        'signature-${entry.key}',
        SpellService.getSpellById(entry.key)?.getName(locale) ?? entry.key,
        entry.value,
        after.signatureSpellsUsed[entry.key] ?? false);
  }
  return changes;
}

class _RestPreview extends StatelessWidget {
  const _RestPreview({required this.changes});
  final List<_RestChange> changes;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), l10n = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (changes.isEmpty)
        Text(l10n.sheetRestNothingToRecover,
            key: const ValueKey('sheet-rest-no-changes'))
      else ...[
        Text(l10n.sheetRestPreviewTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.lgPlus)),
          child: Column(children: [
            for (int i = 0; i < changes.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                key: ValueKey('sheet-rest-change-${changes[i].id}'),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: LayoutBuilder(builder: (context, constraints) {
                  final label =
                      Text(changes[i].label, style: theme.textTheme.bodyMedium);
                  final result = Text(changes[i].result,
                      style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700));
                  if (constraints.maxWidth < 290 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [label, const SizedBox(height: 4), result]);
                  }
                  return Row(children: [
                    Expanded(child: label),
                    const SizedBox(width: 16),
                    Flexible(child: result),
                  ]);
                }),
              ),
            ]
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Text(l10n.sheetRestPreserves,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
