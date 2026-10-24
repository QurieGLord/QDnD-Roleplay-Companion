// ignore_for_file: avoid_print
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:qd_and_d/core/ui/sheet_drag_region.dart' show SheetSafeArea;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:uuid/uuid.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';

import '../../../core/models/character.dart';
import '../../../core/services/fc5_export_service.dart';
import '../../../core/services/fc5_parser.dart';
import '../../../core/services/import_service.dart';
import '../../../core/services/qdnd_bundle_export_service.dart';
import '../../../core/services/qdnd_bundle_codec.dart';
import '../../../core/services/qdnd_bundle_file_service.dart';
import '../../../core/services/qdnd_bundle_import_service.dart';
import '../../../core/services/qdnd_bundle_schema.dart';
import '../../../core/services/storage_service.dart';
import 'widgets/hero_deck.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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
            _SheetTitleBlock(
              icon: Icons.person_add_alt_1_rounded,
              title: l10n.createNewCharacter,
              subtitle: l10n.createCharacterSheetSubtitle,
            ),
            const SizedBox(height: 20),
            RosterReveal(
              delay: const Duration(milliseconds: 40),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.edit_note_rounded,
                title: l10n.createNewCharacter,
                subtitle: l10n.createCharacterActionDescription,
                accent: colorScheme.primary,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _openCharacterCreation(context);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            RosterReveal(
              delay: const Duration(milliseconds: 90),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.inventory_2_outlined,
                title: l10n.importQdndBundle,
                subtitle: l10n.importQdndBundleActionDescription,
                accent: colorScheme.secondary,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _importFromQdndBundle(context);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            RosterReveal(
              delay: const Duration(milliseconds: 140),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.upload_file_rounded,
                title: l10n.importFC5Character,
                subtitle: l10n.importFC5CharacterActionDescription,
                accent: colorScheme.tertiary,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _importFromFC5(context);
                  });
                },
              ),
            ),
          ],
        ),
      )),
    );
  }

  void _showCharacterOptions(BuildContext context, Character character) {
    final l10n = AppLocalizations.of(context)!;

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
            _CharacterActionSheetHeader(character: character),
            const SizedBox(height: 20),
            RosterReveal(
              delay: const Duration(milliseconds: 40),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.info_outline_rounded,
                title: l10n.viewDetails,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _showCharacterDetails(context, character);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            RosterReveal(
              delay: const Duration(milliseconds: 90),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.edit_rounded,
                title: l10n.edit,
                onTap: () {
                  _dismissSheetThen(sheetContext, () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CharacterEditScreen(character: character),
                      ),
                    );
                    if (mounted) {
                      setState(() {});
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            RosterReveal(
              delay: const Duration(milliseconds: 140),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.copy_rounded,
                title: l10n.duplicate,
                onTap: () {
                  _dismissSheetThen(sheetContext, () async {
                    await _duplicateCharacter(context, character);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            RosterReveal(
              delay: const Duration(milliseconds: 190),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.ios_share_rounded,
                title: l10n.exportCharacter,
                subtitle: l10n.exportCharacterActionDescription,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _showExportOptions(context, character);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            RosterReveal(
              delay: const Duration(milliseconds: 240),
              beginOffset: const Offset(0, 0.04),
              child: _SheetActionTile(
                icon: Icons.delete_outline_rounded,
                title: l10n.delete,
                destructive: true,
                onTap: () {
                  _dismissSheetThen(sheetContext, () {
                    _confirmDelete(context, character);
                  });
                },
              ),
            ),
          ],
        ),
      )),
    );
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

  void _showExportOptions(BuildContext context, Character character) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SheetSafeArea(child: _ExpressiveSheetShell(
        child: CharacterExportOptionsContent(
          onQdndBundle: () {
            _dismissSheetThen(sheetContext, () async {
              await _exportQdndBundle(context, character);
            });
          },
          onFc5Xml: () {
            _dismissSheetThen(sheetContext, () async {
              await _exportFC5Xml(context, character);
            });
          },
          primaryAccent: colorScheme.primary,
          secondaryAccent: colorScheme.secondary,
        ),
      )),
    );
  }

  Future<void> _exportQdndBundle(
    BuildContext context,
    Character character,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final exportResult = await QdndBundleExportService.exportCharacter(
        character,
        options: const QdndBundleExportOptions(
          includeUserCreatedContent: true,
        ),
      );
      final fileName = '${_safeBundleFileName(character.name)}.qdnd';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportQdndBundle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['qdnd'],
        bytes: exportResult.bytes,
      );

      if (outputPath == null) {
        return;
      }

      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(outputPath).writeAsBytes(exportResult.bytes, flush: true);
      }

      if (context.mounted) {
        final warningCount = exportResult.diagnostics
            .where(
              (entry) => entry.severity == QdndBundleDiagnosticSeverity.warning,
            )
            .length;
        AppSnackBar.success(
          context,
          l10n.qdndBundleExportedSuccess(fileName),
          duration: const Duration(seconds: 2),
          actionLabel: warningCount > 0 ? l10n.importWarningsAction : null,
          onAction: warningCount > 0
              ? () {
                  if (mounted) {
                    _showQdndBundleDiagnostics(
                      context,
                      exportResult.diagnostics,
                    );
                  }
                }
              : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          l10n.qdndBundleExportFailed('$e'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _exportFC5Xml(
    BuildContext context,
    Character character,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final exportResult = await FC5ExportService.exportCharacter(character);
      final fileName = '${_safeBundleFileName(character.name)}.xml';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.exportFC5Xml,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xml'],
        bytes: exportResult.bytes,
      );

      if (outputPath == null) {
        return;
      }

      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(outputPath).writeAsBytes(exportResult.bytes, flush: true);
      }

      if (context.mounted) {
        AppSnackBar.success(
          context,
          l10n.fc5XmlExportedSuccess(fileName),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          l10n.fc5XmlExportFailed('$e'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _importFromQdndBundle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single;
      final bytes = await QdndBundleFileService.readPlatformFile(selectedFile);
      final preview = await QdndBundleImportService.previewBytes(bytes);
      if (!context.mounted) return;
      final confirmed = await _showQdndBundlePreview(context, preview);
      if (confirmed != true) {
        return;
      }

      final importResult = await QdndBundleImportService.importBytes(bytes);
      final warningCount = importResult.diagnostics
          .where(
            (entry) => entry.severity == QdndBundleDiagnosticSeverity.warning,
          )
          .length;

      if (context.mounted) {
        final message = warningCount > 0
            ? l10n.qdndBundleImportedWithWarnings(
                importResult.character.name,
                warningCount,
              )
            : l10n.qdndBundleImportedSuccess(importResult.character.name);

        AppSnackBar.success(
          context,
          message,
          duration: const Duration(seconds: 2),
          actionLabel: warningCount > 0 ? l10n.importWarningsAction : null,
          onAction: warningCount > 0
              ? () {
                  if (mounted) {
                    _showQdndBundleDiagnostics(
                      context,
                      importResult.diagnostics,
                    );
                  }
                }
              : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.error(
          context,
          l10n.qdndBundleImportFailed('$e'),
          duration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<bool?> _showQdndBundlePreview(
    BuildContext context,
    QdndBundleImportPreview preview,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final classes =
        preview.classes.where((value) => value.isNotEmpty).join(', ');

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qdndBundlePreviewTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.qdndBundlePreviewSummary(
              preview.characterName,
              preview.level,
            )),
            if (classes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${l10n.classLabel}: $classes'),
            ],
            const SizedBox(height: 8),
            Text(l10n.qdndBundlePreviewDetails(
              preview.embeddedContentCount,
              preview.resolvedDependencyCount,
              preview.missingDependencyCount,
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.importQdndBundle),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFC5(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      print('🔧 _importFromFC5: Starting FC5 import');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xml'],
      );

      if (result == null || result.files.isEmpty) {
        print('🔧 _importFromFC5: User cancelled file picker');
        return;
      }

      print('🔧 _importFromFC5: File selected: ${result.files.single.path}');

      final file = File(result.files.single.path!);
      final importResult =
          await ImportService.importCharactersFromFC5File(file);
      final importedCharacters = importResult.characters;
      final firstName = importedCharacters.first.name;

      print(
        '🔧 _importFromFC5: Imported ${importedCharacters.length} character(s)',
      );

      if (context.mounted) {
        final warningCount = importResult.warningCount;
        final message = warningCount > 0
            ? l10n.importedCharactersWithWarnings(
                importedCharacters.length,
                firstName,
                warningCount,
              )
            : l10n.importedCharactersSuccess(
                importedCharacters.length,
                firstName,
              );

        AppSnackBar.success(
          context,
          message,
          duration: const Duration(seconds: 2),
          actionLabel: warningCount > 0 ? l10n.importWarningsAction : null,
          onAction: warningCount > 0
              ? () {
                  if (mounted) {
                    _showImportDiagnostics(
                      context,
                      importResult.diagnostics,
                    );
                  }
                }
              : null,
        );
      }
    } catch (e, stackTrace) {
      print('❌ _importFromFC5: ERROR: $e');
      print('❌ Stack trace: $stackTrace');

      if (context.mounted) {
        final diagnostics = e is ImportServiceException ? e.diagnostics : null;
        AppSnackBar.error(
          context,
          l10n.importFailed('$e'),
          duration: const Duration(seconds: 2),
          actionLabel: diagnostics != null && !diagnostics.isEmpty
              ? l10n.importWarningsAction
              : null,
          onAction: diagnostics != null && !diagnostics.isEmpty
              ? () {
                  if (mounted) {
                    _showImportDiagnostics(context, diagnostics);
                  }
                }
              : null,
        );
      }
    }
  }

  void _showImportDiagnostics(
    BuildContext context,
    FC5ParseDiagnostics diagnostics,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final visibleEntries = diagnostics.entries
        .where((entry) => entry.severity != FC5DiagnosticSeverity.info)
        .toList();
    final entries =
        visibleEntries.isEmpty ? diagnostics.entries : visibleEntries;

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
            _SheetTitleBlock(
              icon: Icons.rule_rounded,
              title: l10n.importWarningsTitle,
              subtitle: l10n.importWarningsSubtitle(entries.length),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final colorScheme = Theme.of(context).colorScheme;
                  final isError = entry.severity == FC5DiagnosticSeverity.error;
                  final tone =
                      isError ? colorScheme.error : colorScheme.tertiary;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        tone.withValues(alpha: 0.08),
                        colorScheme.surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                      border: Border.all(
                        color: tone.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: tone,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.message,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (entry.context != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  entry.context!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )),
    );
  }

  void _showQdndBundleDiagnostics(
    BuildContext context,
    List<QdndBundleDiagnostic> diagnostics,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final visibleEntries = diagnostics
        .where((entry) => entry.severity != QdndBundleDiagnosticSeverity.info)
        .toList();
    final entries = visibleEntries.isEmpty ? diagnostics : visibleEntries;

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
            _SheetTitleBlock(
              icon: Icons.rule_rounded,
              title: l10n.importWarningsTitle,
              subtitle: l10n.importWarningsSubtitle(entries.length),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final colorScheme = Theme.of(context).colorScheme;
                  final isError =
                      entry.severity == QdndBundleDiagnosticSeverity.error;
                  final tone =
                      isError ? colorScheme.error : colorScheme.tertiary;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        tone.withValues(alpha: 0.08),
                        colorScheme.surfaceContainerHighest,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.lgPlus),
                      border: Border.all(
                        color: tone.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isError
                              ? Icons.error_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: tone,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.message,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (entry.context != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  entry.context!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )),
    );
  }

  String _safeBundleFileName(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9а-яё]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'character' : normalized;
  }
}

class CharacterExportOptionsContent extends StatelessWidget {
  const CharacterExportOptionsContent({
    super.key,
    required this.onQdndBundle,
    required this.onFc5Xml,
    this.primaryAccent,
    this.secondaryAccent,
  });

  final VoidCallback onQdndBundle;
  final VoidCallback onFc5Xml;
  final Color? primaryAccent;
  final Color? secondaryAccent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitleBlock(
          icon: Icons.ios_share_rounded,
          title: l10n.exportCharacter,
          subtitle: l10n.exportFormatSubtitle,
        ),
        const SizedBox(height: 20),
        RosterReveal(
          delay: const Duration(milliseconds: 40),
          beginOffset: const Offset(0, 0.04),
          child: _SheetActionTile(
            icon: Icons.inventory_2_outlined,
            title: l10n.exportQdndBundle,
            subtitle: l10n.exportQdndBundleActionDescription,
            accent: primaryAccent ?? colorScheme.primary,
            onTap: onQdndBundle,
          ),
        ),
        const SizedBox(height: 12),
        RosterReveal(
          delay: const Duration(milliseconds: 90),
          beginOffset: const Offset(0, 0.04),
          child: _SheetActionTile(
            icon: Icons.code_rounded,
            title: l10n.exportFC5Xml,
            subtitle: l10n.exportFC5XmlActionDescription,
            accent: secondaryAccent ?? colorScheme.secondary,
            onTap: onFc5Xml,
          ),
        ),
      ],
    );
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

class _SheetTitleBlock extends StatelessWidget {
  const _SheetTitleBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colorScheme.primary.withValues(alpha: 0.14),
              colorScheme.surfaceContainerHighest,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lgPlus),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CharacterActionSheetHeader extends StatelessWidget {
  const _CharacterActionSheetHeader({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final localizedRaceName = getLocalizedRaceName(context, character.race);
    final accent = resolveClassAccent(colorScheme, character.characterClass);
    final localizedClassName = getCharacterClassSummary(context, character);
    final localizedSubclass = character.subclass != null
        ? getLocalizedSubclassName(
            context,
            character.characterClass,
            character.subclass!,
          )
        : null;

    return Column(
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
                      '$localizedRaceName • ${l10n.levelShort} ${character.level} $localizedClassName',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
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
        const SizedBox(height: 18),
        Text(
          l10n.characterActionsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.characterActionsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.accent,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? accent;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = destructive
        ? colorScheme.onErrorContainer
        : (accent ?? colorScheme.primary);
    final backgroundColor = destructive
        ? Color.alphaBlend(
            colorScheme.errorContainer.withValues(alpha: 0.96),
            colorScheme.surfaceContainerHighest,
          )
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.82);
    final iconTone = destructive ? colorScheme.onErrorContainer : tone;
    final subtitleColor = destructive
        ? colorScheme.onErrorContainer.withValues(alpha: 0.78)
        : colorScheme.onSurfaceVariant;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lgPlus),
        side: BorderSide(
          color: destructive
              ? colorScheme.error.withValues(alpha: 0.42)
              : tone.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: destructive
                      ? Color.alphaBlend(
                          colorScheme.error.withValues(alpha: 0.18),
                          colorScheme.errorContainer,
                        )
                      : tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(icon, color: iconTone),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color:
                            destructive ? colorScheme.onErrorContainer : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          height: 1.3,
                          fontWeight: destructive ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: destructive
                    ? colorScheme.onErrorContainer.withValues(alpha: 0.9)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
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
