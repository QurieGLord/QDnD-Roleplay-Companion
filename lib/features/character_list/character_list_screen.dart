// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/sheet_drag_region.dart' show SheetSafeArea;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/services/storage_service.dart';
import 'hero_transfer.dart';
import 'widgets/hero_deck.dart';
import '../../core/theme/app_palettes.dart';
import '../../core/ui/page_kit.dart';
import '../../core/ui/companion_kit.dart';
import 'widgets/character_roster_visuals.dart';
import 'widgets/empty_state.dart';
import 'widgets/roster_reveal.dart';
import 'package:qd_and_d/features/character_creation/character_creation_wizard.dart';
import 'package:qd_and_d/features/character_edit/character_edit_screen.dart';
import 'package:qd_and_d/features/character_sheet/character_sheet_screen.dart';
import 'package:qd_and_d/core/theme/app_tokens.dart';

class CharacterListScreen extends StatefulWidget {
  const CharacterListScreen({super.key});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  bool _revealing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder(
      valueListenable: Hive.box<Character>('characters').listenable(),
      builder: (context, Box<Character> box, _) {
        final characters = box.values.toList();
        final hasCharacters = characters.isNotEmpty;

        return Scaffold(
          // Fields here sit at the top or in sheets over the page; the page never
          // resizes for the keyboard, so it is not laid out again on every frame
          // of the keyboard's slide.
          resizeToAvoidBottomInset: false,
          backgroundColor: colorScheme.surface,
          floatingActionButton: hasCharacters
              ? RosterReveal(
                  key: const ValueKey('character_list_fab'),
                  delay: const Duration(milliseconds: 220),
                  beginOffset: const Offset(0, 0.16),
                  beginScale: 0.94,
                  child: _CreateFab(
                    label: l10n.createNewCharacter,
                    onPressed: () => _showCreateCharacterDialog(context),
                  ),
                )
              : null,
          // While a hero's sheet grows out of its card, the lobby recedes:
          // it shrinks a little and dims, then comes back on return.
          body: _RecedeBehindReveal(
            active: _revealing,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RosterReveal(
                    key: const ValueKey('character_list_header'),
                    delay: const Duration(milliseconds: 40),
                    child: _RosterHeader(
                      count: characters.length,
                      onSettings: () {
                        Navigator.of(context).pushNamed('/settings');
                      },
                    ),
                  ),
                  Expanded(
                    child: hasCharacters
                        ? RosterReveal(
                            key: const ValueKey('character_list_deck'),
                            delay: const Duration(milliseconds: 80),
                            child: HeroDeck(
                              characters: characters,
                              onOpen: (character, origin) async {
                                setState(() => _revealing = true);
                                await Navigator.push(
                                  context,
                                  DeckRevealRoute<void>(
                                    origin: origin,
                                    heroId: character.id,
                                    builder: (context) => CharacterSheetScreen(
                                      character: character,
                                    ),
                                    faceBuilder: (context, height) => DeckCard(
                                      character: character,
                                      height: height,
                                      face: true,
                                      onTap: () {},
                                      onHold: () {},
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  setState(() => _revealing = false);
                                }
                              },
                              onHold: (character) {
                                _showCharacterOptions(context, character);
                              },
                            ),
                          )
                        : CustomScrollView(slivers: [
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 28),
                                child: RosterReveal(
                                  key: const ValueKey('character_list_empty'),
                                  delay: const Duration(milliseconds: 120),
                                  child: EmptyState(
                                    onCreate: () =>
                                        _openCharacterCreation(context),
                                    onImport: () =>
                                        _showCreateCharacterDialog(context),
                                    importLabel: l10n.importCharacter,
                                  ),
                                ),
                              ),
                            ),
                          ]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissSheetThen(BuildContext sheetContext, VoidCallback action) {
    Navigator.of(sheetContext).pop();
    Future<void>.microtask(() {
      if (mounted) {
        action();
      }
    });
  }

  Future<void> _openCharacterCreation(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CharacterCreationWizard(),
      ),
    );
  }

  void _showCreateCharacterDialog(BuildContext context) {
    final s = Tr(context);
    showCompanionSheet<void>(context, builder: (sheet) {
      final a = AppAccents.of(sheet);
      void then(VoidCallback action) => _dismissSheetThen(sheet, action);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageSheetHead(
            kicker: s.t('Отряд', 'Party'),
            title: s.t('Добавить героя', 'Add a hero')),
        const SizedBox(height: 14),
        SheetListRow(
          leading: PageSeal('plus', accent: a.at(3)),
          accent: a.at(3),
          index: 0,
          title: s.t('Новый герой', 'New hero'),
          subtitle: s.t('Мастер создания: раса, класс, характеристики',
              'The creation wizard: race, class, abilities'),
          onTap: () => then(() => _openCharacterCreation(context)),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('download', accent: a.at(1)),
          accent: a.at(1),
          index: 1,
          title: s.t('Из файла QDnD', 'From a QDnD file'),
          subtitle: s.t('Полная копия героя с другого устройства · .qdnd',
              'A full copy of a hero from another device · .qdnd'),
          onTap: () => then(() => importHero(context, qdnd: true)),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('file', accent: a.at(4)),
          accent: a.at(4),
          index: 2,
          title: s.t('Из файла XML', 'From an XML file'),
          subtitle: s.t('Лист персонажа из другого приложения · .xml',
              'A character sheet from another app · .xml'),
          onTap: () => then(() => importHero(context, qdnd: false)),
        ),
      ]);
    });
  }

  void _showCharacterOptions(BuildContext context, Character character) {
    final s = Tr(context);
    showCompanionSheet<void>(context, builder: (sheet) {
      final a = AppAccents.of(sheet);
      void then(VoidCallback action) => _dismissSheetThen(sheet, action);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HeroHeadCard(
          name: character.name,
          accent: AppAccents.of(sheet).forClass(character.classes.isEmpty
              ? character.characterClass
              : character.classes.first.id),
          cap: '${getLocalizedRaceName(sheet, character.race)} · '
              '${getCharacterClassSummary(sheet, character)} ${character.level}',
          line: character.subclass == null
              ? null
              : getLocalizedSubclassName(
                  sheet, character.characterClass, character.subclass!),
        ),
        const SizedBox(height: 14),
        SheetListRow(
          leading: PageSeal('eye', accent: a.at(5)),
          accent: a.at(5),
          index: 0,
          title: s.t('Подробнее', 'Details'),
          subtitle: s.t('Характеристики и история одним взглядом',
              'Abilities and story at a glance'),
          onTap: () => then(() => _showCharacterDetails(context, character)),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('edit', accent: a.at(4)),
          accent: a.at(4),
          index: 1,
          title: s.t('Анкета героя', 'The hero\'s card'),
          subtitle: s.t('Имя, облик, личность, предыстория',
              'Name, looks, personality, backstory'),
          onTap: () => then(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CharacterEditScreen(character: character),
              ),
            );
            if (mounted) setState(() {});
          }),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('share', accent: a.at(1)),
          accent: a.at(1),
          index: 2,
          title: s.t('Перенести героя', 'Move the hero'),
          subtitle: s.t('Файл для другого устройства или приложения',
              'A file for another device or app'),
          onTap: () => then(() => showHeroTransfer(context, character)),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('layers', accent: a.at(2)),
          accent: a.at(2),
          index: 3,
          title: s.t('Дублировать', 'Duplicate'),
          subtitle: s.t('Копия героя рядом с ним', 'A copy of the hero beside them'),
          onTap: () => then(() => _duplicateCharacter(context, character)),
        ),
        const SizedBox(height: 6),
        SheetListRow(
          leading: PageSeal('trash', accent: a.at(0)),
          accent: a.at(0),
          index: 4,
          title: s.t('Удалить', 'Delete'),
          subtitle: s.t('Спросим ещё раз', 'We will ask once more'),
          onTap: () => then(() => _confirmDelete(context, character)),
        ),
      ]);
    });
  }

  void _showCharacterDetails(BuildContext context, Character character) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final localizedRaceName = getLocalizedRaceName(context, character.race);
    final localizedClassName = getCharacterClassSummary(context, character);
    final localizedSubclass = character.subclass != null
        ? getLocalizedSubclassName(
            context,
            character.characterClass,
            character.subclass!,
          )
        : null;
    final accent = resolveClassAccent(colorScheme, character.characterClass);
    final identity = l10n.characterCardIdentity(
      localizedRaceName,
      character.level,
      localizedClassName,
    );
    final appearanceText = [
      character.appearance,
      character.appearanceDescription,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join('\n');
    final abilityTiles = [
      _AbilityScoreTile(
        label: l10n.abilityStrAbbr,
        score: character.abilityScores.strength,
        modifier: character.abilityScores.strengthModifier,
        accent: accent,
      ),
      _AbilityScoreTile(
        label: l10n.abilityDexAbbr,
        score: character.abilityScores.dexterity,
        modifier: character.abilityScores.dexterityModifier,
        accent: accent,
      ),
      _AbilityScoreTile(
        label: l10n.abilityConAbbr,
        score: character.abilityScores.constitution,
        modifier: character.abilityScores.constitutionModifier,
        accent: accent,
      ),
      _AbilityScoreTile(
        label: l10n.abilityIntAbbr,
        score: character.abilityScores.intelligence,
        modifier: character.abilityScores.intelligenceModifier,
        accent: accent,
      ),
      _AbilityScoreTile(
        label: l10n.abilityWisAbbr,
        score: character.abilityScores.wisdom,
        modifier: character.abilityScores.wisdomModifier,
        accent: accent,
      ),
      _AbilityScoreTile(
        label: l10n.abilityChaAbbr,
        score: character.abilityScores.charisma,
        modifier: character.abilityScores.charismaModifier,
        accent: accent,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SheetSafeArea(child: _ExpressiveSheetShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  accent.withValues(alpha: 0.1),
                  colorScheme.surfaceContainerHighest,
                ),
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  _ActionSheetAvatar(character: character, accent: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          character.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          identity,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (localizedSubclass != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            localizedSubclass,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailMetricTile(
                      width: tileWidth,
                      label: l10n.hpShort,
                      value: '${character.currentHp}/${character.maxHp}',
                      icon: Icons.favorite_rounded,
                      accent: colorScheme.error,
                    ),
                    _DetailMetricTile(
                      width: tileWidth,
                      label: l10n.armorClassAC,
                      value: '${character.armorClass}',
                      icon: Icons.shield_rounded,
                      accent: colorScheme.secondary,
                    ),
                    _DetailMetricTile(
                      width: tileWidth,
                      label: l10n.speedSPEED,
                      value: '${character.speed}',
                      icon: Icons.directions_run_rounded,
                      accent: colorScheme.tertiary,
                    ),
                    _DetailMetricTile(
                      width: tileWidth,
                      label: l10n.initiativeINIT,
                      value: character.formatModifier(
                        character.initiativeBonus,
                      ),
                      icon: Icons.bolt_rounded,
                      accent: colorScheme.primary,
                    ),
                    _DetailMetricTile(
                      width: tileWidth,
                      label: l10n.proficiencyPROF,
                      value: '+${character.proficiencyBonus}',
                      icon: Icons.workspace_premium_rounded,
                      accent: colorScheme.secondary,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Text(
              l10n.abilityScoresTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = (constraints.maxWidth - 16) / 3;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: abilityTiles
                      .map((tile) => SizedBox(width: tileWidth, child: tile))
                      .toList(),
                );
              },
            ),
            if (character.background != null &&
                character.background!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              _DetailTextPanel(
                title: l10n.background,
                text: character.background!,
              ),
            ],
            if (appearanceText.isNotEmpty) ...[
              const SizedBox(height: 10),
              _DetailTextPanel(
                title: l10n.appearance,
                text: appearanceText,
              ),
            ],
          ],
        ),
      )),
    );
  }

  void _confirmDelete(BuildContext context, Character character) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = resolveClassAccent(colorScheme, character.characterClass);
    final localizedRaceName = getLocalizedRaceName(context, character.race);
    final localizedClassName = getCharacterClassSummary(context, character);
    final localizedSubclass = character.subclass != null
        ? getLocalizedSubclassName(
            context,
            character.characterClass,
            character.subclass!,
          )
        : null;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 10,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
            surfaceTintColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.xlPlus),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.68),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                          border: Border.all(
                            color: colorScheme.error.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.deleteConfirmationTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.deleteConfirmationMessage(character.name),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        accent.withValues(alpha: 0.08),
                        colorScheme.surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        _ActionSheetAvatar(
                          character: character,
                          accent: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                character.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$localizedRaceName • ${l10n.levelShort} ${character.level} $localizedClassName',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (localizedSubclass != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  localizedSubclass,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.lgPlus),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            await StorageService.deleteCharacter(character.id);
                            if (!mounted) {
                              return;
                            }

                            if (dialogContext.mounted) {
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                            }

                            if (!context.mounted) {
                              return;
                            }

                            AppSnackBar.success(
                              context,
                              l10n.deletedSuccess(character.name),
                              duration: const Duration(seconds: 2),
                            );
                          },
                          icon: const Icon(Icons.delete_rounded),
                          label: Text(l10n.delete),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadii.lgPlus),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _duplicateCharacter(
    BuildContext context,
    Character original,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final duplicate = QdndBundleCodec.cloneCharacter(original)
        ..id = const Uuid().v4()
        ..name = '${original.name} (Copy)'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await StorageService.saveCharacter(duplicate);

      if (context.mounted) {
        AppSnackBar.success(
          context,
          l10n.duplicatedSuccess(original.name),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          l10n.duplicateFailed('$e'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

}

class _RosterHeader extends StatelessWidget {
  const _RosterHeader({
    required this.count,
    required this.onSettings,
  });

  final int count;
  final VoidCallback onSettings;

  // The deck is the screen; the header stays a quiet title above it.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.characters,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: AppType.display,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.1,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count > 0
                      ? l10n.lobbyReady(count)
                      : l10n.rosterHeaderSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Pressable(
            onTap: onSettings,
            scale: .92,
            semanticLabel: l10n.settings,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.onSurface.withValues(alpha: .08),
              ),
              child:
                  LineIcon('settings', size: 20, color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// The prototype's create button: 56 high, corners 20, primary container.
class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onPressed,
        semanticLabel: label,
        child: Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(18, 0, 22, 0),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .6),
                  blurRadius: 26,
                  spreadRadius: -10,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LineIcon('plus', size: 22, color: c.onSurface),
            const SizedBox(width: 10),
            Text(label,
                style: t.textTheme.labelLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface)),
          ]),
        ),
      ),
    );
  }
}

/// Shrinks the lobby to 0.95 and dims it while a sheet is revealed over it,
/// following the reveal route's own progress.
class _RecedeBehindReveal extends StatelessWidget {
  const _RecedeBehindReveal({required this.active, required this.child});
  final bool active;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final progress = route?.secondaryAnimation;
    if (progress == null || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return AnimatedBuilder(
      animation: progress,
      child: child,
      builder: (context, child) {
        final p = active ? progress.value.clamp(0.0, 1.0) : 0.0;
        if (p == 0) return child!;
        // A plain dark veil, not a colour filter: filtering the whole lobby
        // every frame would cost frames during the reveal.
        return Transform.scale(
          scale: 1 - .05 * p,
          child: Stack(fit: StackFit.passthrough, children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child:
                    ColoredBox(color: Colors.black.withValues(alpha: .35 * p)),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _ExpressiveSheetShell extends StatelessWidget {
  const _ExpressiveSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Material(
              color: colorScheme.surfaceContainerLow,
              elevation: 8,
              shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
              surfaceTintColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.xlPlus),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.68),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSheetAvatar extends StatelessWidget {
  const _ActionSheetAvatar({
    required this.character,
    required this.accent,
  });

  final Character character;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: 0.18),
              colorScheme.surfaceContainerHighest,
            ),
            Color.alphaBlend(
              colorScheme.secondary.withValues(alpha: 0.1),
              colorScheme.surfaceContainer,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: character.avatarPath != null
          ? Image.file(
              File(character.avatarPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  getClassIcon(character.characterClass),
                  color: accent,
                );
              },
            )
          : Icon(
              getClassIcon(character.characterClass),
              color: accent,
            ),
    );
  }
}

class _DetailMetricTile extends StatelessWidget {
  const _DetailMetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.76),
                borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                border: Border.all(color: accent.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityScoreTile extends StatelessWidget {
  const _AbilityScoreTile({
    required this.label,
    required this.score,
    required this.modifier,
    required this.accent,
  });

  final String label;
  final int score;
  final int modifier;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modifierText = modifier >= 0 ? '+$modifier' : '$modifier';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.08),
          colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
        border: Border.all(color: accent.withValues(alpha: 0.13)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            modifierText,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailTextPanel extends StatelessWidget {
  const _DetailTextPanel({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
