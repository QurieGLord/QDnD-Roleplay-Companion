import '../../core/magic/class_spell_grants.dart';
import '../../core/magic/spell_preparation_rules.dart';
import '../../core/progression/class_spellcasting_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/magic/spellbook_state.dart';
import '../../core/models/character.dart';
import '../../core/models/spell.dart';
import '../../core/services/spell_eligibility_service.dart';
import '../../core/services/spellbook_actions_service.dart';
import '../../core/ui/app_snack_bar.dart';
import '../../core/ui/companion_surface.dart';
import 'spell_almanac_strings.dart';

/// One spell may belong to several sources. Editing one never removes another.
class SpellbookControls extends StatefulWidget {
  const SpellbookControls({
    super.key,
    required this.hero,
    required this.spell,
    required this.onChanged,
    required this.onBusyChanged,
  });
  final Character hero;
  final Spell spell;
  final VoidCallback onChanged;
  final ValueChanged<bool> onBusyChanged;
  @override
  State<SpellbookControls> createState() => _SpellbookControlsState();
}

class _SpellbookControlsState extends State<SpellbookControls> {
  String? _selected;
  bool _busy = false;
  Future<bool> _tableRuling(String message) async {
    final s = AlmanacStrings(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.t('Решение стола', 'A table ruling')),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.t('Назад', 'Back')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.t('Подтвердить', 'Confirm')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _act(Future<void> Function() action, String message) async {
    if (_busy) return;
    setState(() => _busy = true);
    widget.onBusyChanged(true);
    try {
      await action();
      if (!mounted) return;
      HapticFeedback.selectionClick();
      widget.onChanged();
      AppSnackBar.success(context, message);
    } catch (_) {
      if (mounted) {
        final s = AlmanacStrings(context);
        AppSnackBar.error(
          context,
          s.t(
            'Не удалось сохранить изменение. Попробуй ещё раз.',
            'Could not save the change. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _known(bool known, bool requiresRuling) async {
    final s = AlmanacStrings(context);
    if (requiresRuling && !known) {
      final ok = await _tableRuling(
        s.t(
          'Добавить заклинание по договорённости с мастером? Это изменит список героя, без выдачи ячеек и классовых умений.',
          'Add this spell by agreement with your GM? This edits the spell list without granting slots or class features.',
        ),
      );
      if (!ok || !mounted) return;
    }
    await _act(
      () async {
        await SpellbookActionsService.setKnown(
          widget.hero,
          widget.spell.id,
          !known,
          source: _selected == 'unassigned' ? null : _selected,
        );
      },
      known
          ? s.t('Убрано из выбранного списка', 'Removed from the selected list')
          : s.t('Добавлено в выбранный список', 'Added to the selected list'),
    );
  }

  Future<void> _prepare(bool prepared) async {
    final s = AlmanacStrings(context), hero = widget.hero, source = _selected!;
    final limit = SpellbookActionsService.preparationLimit(hero, source);
    final count = SpellbookActionsService.preparedCount(hero, source);
    final access = SpellEligibilityService.classAccess(hero, widget.spell)
        .where((a) => 'class:${a.classId}' == source)
        .firstOrNull;
    final ruling = !prepared &&
        (limit == null ||
            SpellbookActionsService.hasUnassignedPreparation(hero) ||
            count >= limit ||
            access?.state != SpellAccessState.available);
    if (ruling) {
      final ok = await _tableRuling(
        SpellbookActionsService.hasUnassignedPreparation(hero)
            ? s.t(
                'В старом листе остались подготовленные заклинания без указанного класса. Подтвердить подготовку вручную?',
                'Some prepared spells on this older sheet have no class assigned. Confirm preparation manually?')
            : limit == null
                ? s.t(
                    'Правила подготовки этого источника не описаны. Подготовить по решению мастера?',
                    'Preparation rules for this source are not described. Prepare by GM ruling?',
                  )
                : s.t(
                    'Подготовлено $count из $limit. Подготовить ещё одно по решению мастера?',
                    '$count of $limit prepared. Prepare another by GM ruling?',
                  ),
      );
      if (!ok || !mounted) return;
    }
    await _act(
      () async {
        await SpellbookActionsService.setPrepared(
          hero,
          widget.spell.id,
          !prepared,
          source: source,
          tableRuling: ruling,
        );
      },
      prepared
          ? s.t('Подготовка снята', 'No longer prepared')
          : s.t('Заклинание подготовлено', 'Spell prepared'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AlmanacStrings(context),
        t = Theme.of(context).textTheme,
        c = Theme.of(context).colorScheme;
    final hero = widget.hero, spell = widget.spell;
    SpellbookState state;
    try {
      state = SpellbookState.read(hero.spellbookData);
    } on FormatException {
      return Text(
        s.t(
          'Сохранённые списки требуют более новой версии приложения. Заклинания оставлены без изменений.',
          'These spell lists need a newer app version. The saved spells have been retained.',
        ),
      );
    }
    final accesses = SpellEligibilityService.classAccess(hero, spell);
    final owners = state.ownersOf(spell.id);
    final legacy = hero.knownSpells.contains(spell.id) && owners.isEmpty;
    final available = accesses
        .where((a) => a.state == SpellAccessState.available)
        .firstOrNull;
    _selected ??= legacy
        ? 'unassigned'
        : owners.firstOrNull ??
            (available != null ? 'class:${available.classId}' : 'manual');
    final selected = _selected!;
    final granted = selected.startsWith('class:') &&
        ClassSpellGrants.ids(hero, selected.substring(6))
            .any((id) => ClassSpellGrants.spell(id)?.id == spell.id);
    final known = granted ||
        (selected == 'unassigned' ? legacy : state.knows(selected, spell.id));
    final access = selected.startsWith('class:')
        ? accesses.where((a) => 'class:${a.classId}' == selected).firstOrNull
        : null;
    final prepared = state.ids(selected, 'prepared').contains(spell.id) ||
        state.ids(selected, 'alwaysPrepared').contains(spell.id);
    final always =
        granted || state.ids(selected, 'alwaysPrepared').contains(spell.id);
    final prepares = access?.spellcastingType == SpellcastingType.prepared ||
        selected == 'manual';
    SpellPreparationRules? preparation;
    if (selected.startsWith('class:')) {
      try {
        preparation =
            ClassSpellcastingProfile.resolve(hero, selected.substring(6))
                ?.preparation;
      } catch (_) {}
    }
    final wizard = preparation?.mode == SpellPreparationMode.book;
    final directPreparation = !known &&
        spell.level > 0 &&
        prepares &&
        preparation?.mode == SpellPreparationMode.prepared &&
        access?.state == SpellAccessState.available;
    final limit = SpellbookActionsService.preparationLimit(hero, selected);
    final count = SpellbookActionsService.preparedCount(hero, selected);
    final names = <String, String>{
      for (final a in accesses)
        'class:${a.classId}': a.label(s.ru ? 'ru' : 'en'),
      'manual': s.t('Решение стола', 'Table ruling'),
      if (legacy || selected == 'unassigned')
        'unassigned': s.t('Источник не указан', 'Unassigned'),
    };
    return CompanionSurface(
      contour: CompanionContour.fold,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('В твоём листе', 'On your sheet'),
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (names.length > 1)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final entry in names.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: selected == entry.key,
                    avatar: state.knows(entry.key, spell.id)
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
                    onSelected: _busy
                        ? null
                        : (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = entry.key);
                          },
                  ),
              ],
            ),
          const SizedBox(height: 10),
          if (selected == 'unassigned')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.t(
                  'В старом листе источник не указан. Выбери класс выше, чтобы связать с ним это заклинание. Остальные записи не изменятся.',
                  'This older sheet has no source for this spell. Choose a class above to assign it. Other records stay as they are.',
                ),
                style: t.bodySmall,
              ),
            ),
          if (known && spell.level > 0 && prepares)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                always
                    ? s.t('Всегда подготовлено', 'Always prepared')
                    : limit == null
                        ? s.t(
                            'Подготовка по решению стола',
                            'Preparation by table ruling',
                          )
                        : s.t(
                            'Подготовлено $count из $limit',
                            'Prepared $count of $limit',
                          ),
                style: t.labelLarge?.copyWith(color: c.secondary),
              ),
            ),
          if (!always && !directPreparation)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const ValueKey('almanac-change-known'),
                onPressed: _busy
                    ? null
                    : () => _known(
                          known,
                          access?.state != SpellAccessState.available,
                        ),
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        known
                            ? Icons.bookmark_remove_outlined
                            : Icons.bookmark_add_outlined,
                      ),
                label: Text(
                  known
                      ? s.t(
                          wizard ? 'Убрать из книги' : 'Убрать из списка',
                          wizard ? 'Remove from spellbook' : 'Remove from list',
                        )
                      : s.t(
                          wizard ? 'Вписать в книгу' : 'Добавить в список',
                          wizard ? 'Add to spellbook' : 'Add to list',
                        ),
                ),
              ),
            ),
          if ((known || directPreparation) &&
              spell.level > 0 &&
              prepares &&
              !always)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('almanac-prepare'),
                  onPressed: _busy ? null : () => _prepare(prepared),
                  icon: Icon(
                    prepared ? Icons.star_rounded : Icons.star_outline_rounded,
                  ),
                  label: Text(
                    prepared
                        ? s.t('Снять подготовку', 'Unprepare')
                        : s.t('Подготовить', 'Prepare'),
                  ),
                ),
              ),
            ),
          if (!known && access?.state != SpellAccessState.available)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                s.t(
                  'Добавление потребует подтвердить решение стола.',
                  'Adding requires a table ruling.',
                ),
                style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          if (spell.level == 0 && known)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                s.t(
                  'Заговоры не требуют подготовки.',
                  'Cantrips do not need preparation.',
                ),
                style: t.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
