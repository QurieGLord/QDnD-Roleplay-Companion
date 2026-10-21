import '../../features/spell_almanac/spellbook_controls.dart';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../core/models/spell.dart';
import '../../core/models/character.dart';
import '../../core/services/spell_eligibility_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/ui/companion_surface.dart';
import '../../core/ui/sheet_drag_region.dart';
import '../../core/utils/spell_utils.dart';
import '../../features/spell_almanac/spell_almanac_strings.dart';

class SpellDetailsSheet extends StatefulWidget {
  const SpellDetailsSheet({
    super.key,
    required this.spell,
    this.character,
    this.editable = false,
    this.onChanged,
  });
  final Spell spell;
  final Character? character;
  final bool editable;
  final VoidCallback? onChanged;
  @override
  State<SpellDetailsSheet> createState() => _SpellDetailsSheetState();
}

class _SpellDetailsSheetState extends State<SpellDetailsSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final spell = widget.spell, hero = widget.character;
    final l = AppLocalizations.of(context)!,
        s = AlmanacStrings(context),
        locale = Localizations.localeOf(context).languageCode;
    final c = Theme.of(context).colorScheme, t = Theme.of(context).textTheme;
    final eligibility = hero == null
        ? null
        : SpellEligibilityService.checkEligibility(hero, spell);
    final known = hero?.knownSpells.contains(spell.id) ?? false;
    final editable = hero != null && widget.editable;
    final source = _source(s);
    return PopScope(
      canPop: !_busy,
      child: DraggableScrollableSheet(
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .96,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            SheetDragRegion(
              enabled: !_busy,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${spell.level == 0 ? l.cantrips : l.levelLabel(spell.level)} · ${SpellUtils.getLocalizedSchool(l, spell.school)}',
                      style: t.labelLarge?.copyWith(color: c.secondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      spell.getName(locale),
                      style: t.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    if (source != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          source,
                          style: t.bodySmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            CompanionSurface(
              quiet: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stats = [
                        (
                          l.castingTime,
                          SpellUtils.getLocalizedValue(
                            l,
                            spell.castingTime,
                          ),
                        ),
                        (
                          l.range,
                          SpellUtils.getLocalizedValue(l, spell.range),
                        ),
                        (
                          l.duration,
                          SpellUtils.getLocalizedValue(l, spell.duration),
                        ),
                        (l.components, spell.components.join(' · ')),
                      ];
                      final stacked =
                          MediaQuery.textScalerOf(context).scale(14) > 22 ||
                              constraints.maxWidth < 280;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (final stat in stats)
                            SizedBox(
                              width: stacked
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 16) / 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stat.$1,
                                    style: t.labelMedium?.copyWith(
                                      color: c.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stat.$2,
                                    style: t.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (spell.getMaterialComponents(locale)?.trim().isNotEmpty ??
                      false)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${l.materials}: ${spell.getMaterialComponents(locale)}',
                          style: t.bodyMedium,
                        ),
                      ),
                    ),
                  if (spell.concentration || spell.ritual)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (spell.concentration)
                              Chip(
                                avatar: const Icon(
                                  Icons.timelapse_rounded,
                                  size: 17,
                                ),
                                label: Text(l.concentration),
                              ),
                            if (spell.ritual)
                              Chip(
                                avatar: const Icon(
                                  Icons.menu_book_rounded,
                                  size: 17,
                                ),
                                label: Text(l.ritual),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            for (final paragraph
                in spell.getDescription(locale).split(RegExp(r'\n\s*\n')))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                  paragraph,
                  style: t.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
            if (spell.getAtHigherLevels(locale)?.trim().isNotEmpty ??
                false) ...[
              const SizedBox(height: 6),
              Text(
                l.atHigherLevels,
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                spell.getAtHigherLevels(locale)!,
                style: t.bodyLarge?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
            if (eligibility != null) ...[
              Text(
                s.t('Для твоего героя', 'For your hero'),
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              CompanionSurface(
                quiet: true,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final access in eligibility.sources)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${access.label(locale)} · ${s.t('ур.', 'lv.')} ${access.classLevel}',
                              style: t.labelLarge?.copyWith(
                                color: c.secondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              access.explanation(locale),
                              style: t.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    if (known)
                      Text(
                        s.t(
                          'Уже есть в твоём листе. Ручные исключения сохраняются.',
                          'Already on your sheet. Manual exceptions are retained.',
                        ),
                        style: t.bodySmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (spell.availableToClasses.isNotEmpty) ...[
              Text(
                l.classes,
                style: t.labelLarge?.copyWith(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final id in spell.availableToClasses)
                    Chip(
                      label: Text(
                        SpellUtils.getLocalizedClassName(context, id),
                      ),
                    ),
                ],
              ),
            ],
            if (editable) ...[
              const SizedBox(height: 24),
              SpellbookControls(
                hero: hero,
                spell: spell,
                onChanged: () {
                  setState(() {});
                  widget.onChanged?.call();
                },
                onBusyChanged: (v) => setState(() => _busy = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _source(AlmanacStrings s) {
    if (widget.spell.sourceId == null) {
      return s.t('Базовая библиотека', 'Core library');
    }
    try {
      return StorageService.getAllSources()
              .where((v) => v.id == widget.spell.sourceId)
              .firstOrNull
              ?.name ??
          s.t('Подключённая книга', 'Imported book');
    } catch (_) {
      return s.t('Подключённая книга', 'Imported book');
    }
  }
}
