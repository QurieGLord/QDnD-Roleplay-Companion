import 'package:flutter/material.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';
import 'package:qd_and_d/core/ui/companion_kit.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../../../core/magic/class_spell_grants.dart';
import '../../../../../core/magic/spellbook_state.dart';
import '../../../../../core/models/character.dart';
import '../../../../../core/models/spell.dart';
import '../../../../../core/progression/character_class_context.dart';
import '../../../../../core/services/spellbook_actions_service.dart';
import '../../../../../core/utils/spell_utils.dart';
import '../../class_widgets/instrument/instrument_kit.dart';

/// A spell row of a circle (prototype `.sp`): the preparation star (a lock
/// when always prepared, a bookmark when known), the name with its
/// concentration and ritual badges, school and casting time, and the cast
/// button. An unprepared spell fades.
class AbilitiesSpellListItem extends StatelessWidget {
  const AbilitiesSpellListItem({
    super.key,
    required this.spell,
    required this.character,
    required this.locale,
    required this.isPrepared,
    required this.isSpontaneous,
    required this.canCast,
    required this.onOpenDetails,
    required this.onCastSpell,
    required this.onTogglePreparation,
    this.showOwner = false,
  });

  final Spell spell;
  final Character character;
  final String locale;
  final bool isPrepared;
  final bool isSpontaneous;
  final bool canCast;
  final bool showOwner;
  final VoidCallback onOpenDetails;
  final VoidCallback onCastSpell;
  final VoidCallback onTogglePreparation;

  /// The class sources that own this spell (`class:<id>`).
  List<String> _owners() {
    try {
      return SpellbookState.read(character.spellbookData).ownersOf(spell.id).where((s) => s.startsWith('class:')).toList();
    } catch (_) {
      return const [];
    }
  }

  bool _always(List<String> owners) {
    try {
      final state = SpellbookState.read(character.spellbookData);
      if (owners.any((o) => state.ids(o, 'alwaysPrepared').contains(spell.id))) return true;
      for (final entry in character.classes) {
        if (ClassSpellGrants.ids(character, entry.id).map((id) => ClassSpellGrants.spell(id)?.id).contains(spell.id)) return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final ru = locale == 'ru';
    final owners = _owners();
    final always = spell.level > 0 && _always(owners);
    final preparer = spell.level > 0 && !always && owners.any((o) => SpellbookActionsService.preparationLimit(character, o) != null);
    final ownerId = owners.isEmpty ? character.classes.firstOrNull?.id : owners.first.substring(6);
    final ownerAccent = ownerId == null ? c.secondary : classAccent(context, ownerId);

    Widget star;
    if (spell.level == 0) {
      star = Icon(Icons.auto_awesome_outlined, size: 17, color: c.onSurfaceVariant);
    } else if (always) {
      star = Tooltip(message: ru ? 'Всегда подготовлено' : 'Always prepared', child: Icon(Icons.lock_rounded, size: 17, color: c.secondary));
    } else if (preparer || !isSpontaneous) {
      star = Pressable(
        key: ValueKey('spell-prepare-${spell.id}'),
        onTap: onTogglePreparation,
        scale: .85,
        semanticLabel: ru ? 'Подготовка' : 'Preparation',
        child: SizedBox.square(
          dimension: 30,
          child: AnimatedRotation(
            turns: isPrepared ? .2 : 0,
            duration: AppMotion.of(context, const Duration(milliseconds: 400)),
            curve: AppMotion.snappyCurve,
            child: Icon(isPrepared ? Icons.star_rounded : Icons.star_outline_rounded, size: 19, color: isPrepared ? accentOf(context, 2) : c.onSurfaceVariant),
          ),
        ),
      );
    } else {
      star = Icon(Icons.bookmark_outline_rounded, size: 17, color: c.onSurfaceVariant);
    }

    final badges = [
      if (spell.concentration) ru ? 'К' : 'C',
      if (spell.ritual) ru ? 'Р' : 'R',
    ];
    final faded = !isPrepared && spell.level > 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: faded ? .55 : 1,
      child: Pressable(
        onTap: onOpenDetails,
        scale: .99,
        semanticLabel: spell.getName(locale),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(children: [
            SizedBox.square(dimension: 30, child: Center(child: star)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: spell.getName(locale)),
                    for (final b in badges)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          decoration: BoxDecoration(color: c.onSurface.withValues(alpha: .09), borderRadius: BorderRadius.circular(6)),
                          child: Text(b, style: TextStyle(fontFamily: AppType.body, fontSize: 10, fontWeight: FontWeight.w600, height: 1, color: c.onSurfaceVariant)),
                        ),
                      ),
                  ]),
                  style: const TextStyle(fontFamily: AppType.body, fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${SpellUtils.getLocalizedSchool(l10n, spell.school)} · ${SpellUtils.getLocalizedValue(l10n, spell.castingTime)}'),
                    if (showOwner && ownerId != null)
                      TextSpan(text: ' · ${CharacterClassContext(character, ownerId).name(locale)}', style: TextStyle(color: ownerAccent)),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: AppType.body, fontSize: 12, height: 1.3, color: c.onSurfaceVariant),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Pressable(
              key: ValueKey('spell-cast-${spell.id}'),
              onTap: onCastSpell,
              scale: .92,
              semanticLabel: l10n.castSpell,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: canCast && isPrepared ? 1 : .35,
                child: Container(
                  width: 44,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.primary.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)),
                  child: InstrumentGlyph('wand', size: 20, color: c.primary),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

}
