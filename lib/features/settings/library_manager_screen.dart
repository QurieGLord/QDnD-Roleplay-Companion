import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qd_and_d/core/ui/app_snack_bar.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/import_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/character_data_service.dart';
import '../../core/services/fc5_compendium_zip_service.dart';
import '../../core/services/fc5_parser.dart';

class LibraryManagerScreen extends StatelessWidget {
  const LibraryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libraryManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.importContentLibrary,
            onPressed: () => _importFile(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<CompendiumSource>>(
        valueListenable: StorageService.getSourcesListenable(),
        builder: (context, box, child) {
          final sources = box.values.toList();

          if (sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noLibraries,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noLibrariesHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }

          final rows = _libraryRows(sources);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row.archive != null) {
                return _ArchiveSourceCard(
                  archive: row.archive!,
                  onDeleteArchive: () =>
                      _confirmDeleteArchive(context, row.archive!),
                  onDeleteModule: (source) => _confirmDelete(context, source),
                );
              }
              return _SourceCard(
                source: row.source!,
                onDelete: () => _confirmDelete(context, row.source!),
              );
            },
          );
        },
      ),
    );
  }

  List<_LibraryRow> _libraryRows(List<CompendiumSource> sources) {
    final archiveGroups = <String, List<CompendiumSource>>{};
    final singles = <CompendiumSource>[];

    for (final source in sources) {
      final archiveId = source.archiveId;
      if (archiveId == null || archiveId.trim().isEmpty) {
        singles.add(source);
      } else {
        archiveGroups.putIfAbsent(archiveId, () => []).add(source);
      }
    }

    final rows = <_LibraryRow>[
      ...singles.map(_LibraryRow.source),
      ...archiveGroups.values.map((modules) {
        modules.sort((a, b) => a.name.compareTo(b.name));
        return _LibraryRow.archive(_ArchiveSourceGroup(modules));
      }),
    ];

    rows.sort(
      (a, b) => b.importedAt.compareTo(a.importedAt),
    );
    return rows;
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml', 'zip'],
    );

    if (!context.mounted) return;

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase() ??
          file.path.split('.').last.toLowerCase();

      if (extension == 'zip') {
        await _previewZipImport(context, file);
        return;
      }

      final l10n = AppLocalizations.of(context)!;
      final progress = ValueNotifier(
        _ImportProgressState(
          icon: Icons.library_books_rounded,
          title: l10n.fc5LoadingImportTitle,
          stage: l10n.fc5LoadingStageImportingSelectedModules,
        ),
      );
      _showImportProgressDialog(context, progress);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      try {
        final importResult =
            await ImportService.importCompendiumFileDetailed(file);

        if (!context.mounted) return;
        Navigator.pop(context); // Close loader

        final message = _formatImportResultMessage(context, importResult);
        final hasDiagnostics = _hasImportDiagnostics(importResult.diagnostics);

        AppSnackBar.success(
          context,
          message,
          actionLabel: hasDiagnostics ? l10n.importDiagnosticsAction : null,
          onAction: hasDiagnostics
              ? () {
                  _showImportDiagnostics(
                    context,
                    importResult.diagnostics,
                  );
                }
              : null,
        );
      } catch (e) {
        if (!context.mounted) return;
        Navigator.pop(context); // Close loader

        final diagnostics = e is ImportServiceException ? e.diagnostics : null;
        final message = e is ImportServiceException
            ? l10n.libraryImportFailed(
                diagnostics != null && diagnostics.hasErrors
                    ? l10n.libraryImportUnsupported
                    : e.message,
              )
            : l10n.libraryImportFailed(e.toString());

        AppSnackBar.error(
          context,
          message,
          actionLabel: diagnostics != null && _hasImportDiagnostics(diagnostics)
              ? l10n.importDiagnosticsAction
              : null,
          onAction: diagnostics != null && _hasImportDiagnostics(diagnostics)
              ? () {
                  _showImportDiagnostics(context, diagnostics);
                }
              : null,
        );
      } finally {
        progress.dispose();
      }
    }
  }

  Future<void> _previewZipImport(BuildContext context, File file) async {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final progress = ValueNotifier(
      _ImportProgressState(
        icon: Icons.folder_zip_rounded,
        title: l10n.fc5LoadingScanTitle,
        stage: l10n.fc5LoadingStageReadingArchive,
      ),
    );
    _showImportProgressDialog(context, progress);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    try {
      final preview = await FC5CompendiumZipService.previewFile(
        file,
        onProgress: (scanProgress) {
          progress.value = _ImportProgressState(
            icon: Icons.folder_zip_rounded,
            title: l10n.fc5LoadingScanTitle,
            stage: _zipScanStageText(l10n, scanProgress),
            detail: scanProgress.path,
            progress: scanProgress.total > 0
                ? scanProgress.current / scanProgress.total
                : null,
          );
        },
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (preview.entries.isEmpty) {
        AppSnackBar.warning(context, l10n.fc5ZipNoXml);
        return;
      }

      final selectedEntries = await _showZipImportPreview(context, preview);
      if (selectedEntries == null ||
          selectedEntries.isEmpty ||
          !context.mounted) {
        return;
      }

      await _importZipEntries(context, file, preview, selectedEntries);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      final message = e is FC5CompendiumZipException ? e.message : e.toString();
      AppSnackBar.error(context, l10n.libraryImportFailed(message));
    } finally {
      progress.dispose();
    }
  }

  Future<void> _importZipEntries(
    BuildContext context,
    File file,
    FC5CompendiumZipPreview preview,
    List<FC5CompendiumZipEntryPreview> entries,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final progress = ValueNotifier(
      _ImportProgressState(
        icon: Icons.file_upload_outlined,
        title: l10n.fc5LoadingImportTitle,
        stage: l10n.fc5LoadingStageImportingSelectedModules,
        progress: 0,
      ),
    );
    _showImportProgressDialog(context, progress);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final archiveId = const Uuid().v4();
    final batch = _ZipBatchImportSummary();
    try {
      for (var index = 0; index < entries.length; index++) {
        final entry = entries[index];
        progress.value = _ImportProgressState(
          icon: Icons.file_upload_outlined,
          title: l10n.fc5LoadingImportTitle,
          stage: l10n.fc5LoadingStageImportingSelectedModules,
          detail: entry.displayName,
          progress: index / entries.length,
        );
        await Future<void>.delayed(Duration.zero);

        try {
          final xmlContent = await FC5CompendiumZipService.readXmlEntry(
            file,
            entry.rawPath,
          );
          final importResult =
              await ImportService.importCompendiumXmlContentDetailed(
            xmlContent,
            sourceName: entry.displayPath,
            archiveId: archiveId,
            archiveName: preview.archiveName,
            moduleName: entry.displayName,
            modulePath: entry.displayPath,
            sourceKind: 'zip_module',
          );
          batch.addResult(importResult);
        } catch (e) {
          batch.addException(e, entry.displayName);
        }
      }

      progress.value = _ImportProgressState(
        icon: Icons.file_upload_outlined,
        title: l10n.fc5LoadingImportTitle,
        stage: l10n.fc5LoadingStageImportingSelectedModules,
        progress: 1,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      final message = batch.failedModules > 0
          ? l10n.fc5ZipBatchImportedWithIssues(
              batch.importedModules,
              batch.failedModules,
              batch.items,
              batch.spells,
              batch.races,
              batch.classes,
              batch.backgrounds,
              batch.feats,
              batch.duplicatesSkipped,
              batch.unsupportedSkipped,
            )
          : l10n.fc5ZipBatchImported(
              batch.importedModules,
              batch.items,
              batch.spells,
              batch.races,
              batch.classes,
              batch.backgrounds,
              batch.feats,
              batch.duplicatesSkipped,
              batch.unsupportedSkipped,
            );

      final hasDiagnostics = _hasImportDiagnostics(batch.diagnostics);
      final snackBar = batch.failedModules > 0 || batch.importedModules == 0
          ? AppSnackBar.warning
          : AppSnackBar.success;
      snackBar(
        context,
        message,
        actionLabel: hasDiagnostics ? l10n.importDiagnosticsAction : null,
        onAction: hasDiagnostics
            ? () {
                _showImportDiagnostics(
                  context,
                  batch.diagnostics,
                );
              }
            : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);

      final diagnostics = e is ImportServiceException ? e.diagnostics : null;
      final message = e is ImportServiceException
          ? l10n.libraryImportFailed(
              diagnostics != null && diagnostics.hasErrors
                  ? l10n.libraryImportUnsupported
                  : e.message,
            )
          : l10n.libraryImportFailed(e.toString());

      AppSnackBar.error(
        context,
        message,
        actionLabel: diagnostics != null && _hasImportDiagnostics(diagnostics)
            ? l10n.importDiagnosticsAction
            : null,
        onAction: diagnostics != null && _hasImportDiagnostics(diagnostics)
            ? () {
                _showImportDiagnostics(context, diagnostics);
              }
            : null,
      );
    } finally {
      progress.dispose();
    }
  }

  Future<List<FC5CompendiumZipEntryPreview>?> _showZipImportPreview(
    BuildContext context,
    FC5CompendiumZipPreview preview,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final selectedPaths = _defaultZipSelection(preview);

    return showModalBottomSheet<List<FC5CompendiumZipEntryPreview>>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final selectedEntries = preview.entries
              .where((entry) => selectedPaths.contains(entry.rawPath))
              .toList(growable: false);
          final hasCombinedSelected =
              selectedEntries.any((entry) => entry.isCombinedCandidate);
          final hasSeparateSelected = selectedEntries
              .any((entry) => !entry.isCombinedCandidate && entry.canImport);
          final selectedSummary = _summarizeZipEntries(selectedEntries);

          void setSelected(FC5CompendiumZipEntryPreview entry, bool selected) {
            if (!entry.canImport) return;
            setSheetState(() {
              if (selected) {
                selectedPaths.add(entry.rawPath);
              } else {
                selectedPaths.remove(entry.rawPath);
              }
            });
          }

          final bottomInset = MediaQuery.of(sheetContext).viewPadding.bottom;
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            builder: (sheetContext, scrollController) {
              return SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    12 + bottomInset,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Material(
                        color: colorScheme.surfaceContainerLow,
                        elevation: 8,
                        shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                        surfaceTintColor: colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                          side: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.68),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    child: Container(
                                      width: 42,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.28),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Color.alphaBlend(
                                            colorScheme.secondary
                                                .withValues(alpha: 0.12),
                                            colorScheme.surfaceContainerHighest,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                        child: Icon(
                                          Icons.folder_zip_rounded,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.fc5ZipPreviewTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              l10n.fc5ZipPreviewSummary(
                                                preview.entries.length,
                                                preview.ignoredFileCount,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setSheetState(() {
                                            selectedPaths
                                              ..clear()
                                              ..addAll(preview.entries
                                                  .where((entry) =>
                                                      entry.canImport)
                                                  .map((entry) =>
                                                      entry.rawPath));
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.select_all_rounded,
                                        ),
                                        label: Text(l10n.fc5ZipSelectAll),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setSheetState(selectedPaths.clear);
                                        },
                                        icon: const Icon(
                                          Icons.clear_all_rounded,
                                        ),
                                        label: Text(l10n.fc5ZipClearSelection),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _ZipPreviewInfoCard(
                                    text: l10n.fc5ZipSelectedSummary(
                                      selectedEntries.length,
                                      selectedSummary.items,
                                      selectedSummary.spells,
                                      selectedSummary.races,
                                      selectedSummary.classes,
                                      selectedSummary.backgrounds,
                                      selectedSummary.feats,
                                      selectedSummary.monsters,
                                    ),
                                    tone: colorScheme.secondary,
                                  ),
                                  if (hasCombinedSelected &&
                                      hasSeparateSelected) ...[
                                    const SizedBox(height: 10),
                                    _ZipPreviewInfoCard(
                                      text: l10n.fc5ZipDuplicateRisk,
                                      tone: colorScheme.tertiary,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                itemCount: preview.entries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final entry = preview.entries[index];
                                  return _ZipEntryTile(
                                    entry: entry,
                                    selected:
                                        selectedPaths.contains(entry.rawPath),
                                    onChanged: entry.canImport
                                        ? (selected) => setSelected(
                                              entry,
                                              selected ?? false,
                                            )
                                        : null,
                                  );
                                },
                              ),
                            ),
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 12, 20, 20),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                border: Border(
                                  top: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.55),
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: selectedEntries.isEmpty
                                      ? null
                                      : () => Navigator.pop(
                                            sheetContext,
                                            selectedEntries,
                                          ),
                                  icon: const Icon(Icons.file_upload_outlined),
                                  label: Text(l10n.fc5ZipImportSelected),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Set<String> _defaultZipSelection(FC5CompendiumZipPreview preview) {
    final suggested = preview.suggestedEntry;
    if (suggested != null && suggested.isCombinedCandidate) {
      return {suggested.rawPath};
    }
    return preview.entries
        .where((entry) => entry.canImport)
        .map((entry) => entry.rawPath)
        .toSet();
  }

  _ZipEntrySummary _summarizeZipEntries(
    Iterable<FC5CompendiumZipEntryPreview> entries,
  ) {
    final summary = _ZipEntrySummary();
    for (final entry in entries) {
      summary.items += entry.items;
      summary.spells += entry.spells;
      summary.races += entry.races;
      summary.classes += entry.classes;
      summary.backgrounds += entry.backgrounds;
      summary.feats += entry.feats;
      summary.monsters += entry.monsters;
    }
    return summary;
  }

  String _zipScanStageText(
    AppLocalizations l10n,
    FC5CompendiumZipScanProgress progress,
  ) {
    switch (progress.stage) {
      case FC5CompendiumZipScanStage.readingArchive:
        return l10n.fc5LoadingStageReadingArchive;
      case FC5CompendiumZipScanStage.scanningXml:
        if (progress.total <= 0) return l10n.fc5LoadingStageScanningXml;
        return l10n.fc5LoadingStageScanningXmlProgress(
          progress.current,
          progress.total,
        );
      case FC5CompendiumZipScanStage.preparingModules:
        return l10n.fc5LoadingStagePreparingModules;
    }
  }

  void _showImportProgressDialog(
    BuildContext context,
    ValueNotifier<_ImportProgressState> progress,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FC5ImportProgressDialog(progress: progress),
    );
  }

  String _formatImportResultMessage(
    BuildContext context,
    CompendiumImportResult importResult,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = importResult.parseResult;
    final baseMessage = importResult.warningCount > 0
        ? l10n.libraryImportedWithWarnings(
            importResult.sourceName,
            importResult.warningCount,
            parsed.items.length,
            parsed.spells.length,
            parsed.races.length,
            parsed.classes.length,
            parsed.backgrounds.length,
            parsed.feats.length,
          )
        : l10n.libraryImportedSuccess(
            importResult.sourceName,
            parsed.items.length,
            parsed.spells.length,
            parsed.races.length,
            parsed.classes.length,
            parsed.backgrounds.length,
            parsed.feats.length,
          );
    final duplicateCount = importResult.skippedDuplicateCount;
    final unsupportedCount = importResult.skippedUnsupportedCount;
    if (duplicateCount == 0 && unsupportedCount == 0) return baseMessage;
    return '$baseMessage ${l10n.libraryImportSkippedSummary(
      duplicateCount,
      unsupportedCount,
    )}';
  }

  bool _hasImportDiagnostics(FC5ParseDiagnostics diagnostics) {
    return diagnostics.entries.any(_isVisibleImportDiagnostic);
  }

  bool _isVisibleImportDiagnostic(FC5Diagnostic entry) {
    if (entry.severity != FC5DiagnosticSeverity.info) return true;
    return const {
      'duplicates_skipped',
      'unsupported_nodes_skipped',
      'class_overlays_aggregated',
    }.contains(entry.code);
  }

  void _showImportDiagnostics(
    BuildContext context,
    FC5ParseDiagnostics diagnostics,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final entries =
        diagnostics.entries.where(_isVisibleImportDiagnostic).toList();
    if (entries.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
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
                  borderRadius: BorderRadius.circular(32),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.68),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                colorScheme.tertiary.withValues(alpha: 0.14),
                                colorScheme.surfaceContainerHighest,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.rule_rounded,
                              color: colorScheme.tertiary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.importDiagnosticsTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.importDiagnosticsSubtitle(
                                      entries.length),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: entries.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final isError =
                                entry.severity == FC5DiagnosticSeverity.error;
                            final isWarning =
                                entry.severity == FC5DiagnosticSeverity.warning;
                            final tone = isError
                                ? colorScheme.error
                                : isWarning
                                    ? colorScheme.tertiary
                                    : colorScheme.secondary;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color.alphaBlend(
                                  tone.withValues(alpha: 0.08),
                                  colorScheme.surfaceContainerHighest,
                                ),
                                borderRadius: BorderRadius.circular(18),
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
                                        : isWarning
                                            ? Icons.warning_amber_rounded
                                            : Icons.info_outline_rounded,
                                    color: tone,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.message,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        if (entry.context != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.context!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, CompendiumSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLibraryTitle),
        content: Text(
          l10n.deleteLibraryMessage(
              source.name, source.itemCount, source.spellCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;

      try {
        await StorageService.deleteSource(source.id);

        // Reload in-memory caches to reflect changes immediately
        await ItemService.reload();
        await SpellService.reload();
        await CharacterDataService.reload();

        if (!context.mounted) return;
        AppSnackBar.success(context, l10n.libraryDeleted);
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, l10n.errorDeletingLibrary(e.toString()));
      }
    }
  }

  Future<void> _confirmDeleteArchive(
    BuildContext context,
    _ArchiveSourceGroup archive,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteArchiveTitle),
        content: Text(
          l10n.deleteArchiveMessage(
            archive.name,
            archive.modules.length,
            archive.itemCount,
            archive.spellCount,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;

      try {
        await StorageService.deleteSources(
          archive.modules.map((source) => source.id),
        );

        await ItemService.reload();
        await SpellService.reload();
        await CharacterDataService.reload();

        if (!context.mounted) return;
        AppSnackBar.success(context, l10n.libraryDeleted);
      } catch (e) {
        if (!context.mounted) return;
        AppSnackBar.error(context, l10n.errorDeletingLibrary(e.toString()));
      }
    }
  }
}

class _LibraryRow {
  const _LibraryRow._({this.source, this.archive});

  factory _LibraryRow.source(CompendiumSource source) =>
      _LibraryRow._(source: source);

  factory _LibraryRow.archive(_ArchiveSourceGroup archive) =>
      _LibraryRow._(archive: archive);

  final CompendiumSource? source;
  final _ArchiveSourceGroup? archive;

  DateTime get importedAt =>
      archive?.importedAt ??
      source?.importedAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class _ArchiveSourceGroup {
  _ArchiveSourceGroup(this.modules);

  final List<CompendiumSource> modules;

  String get name => modules.first.archiveName?.trim().isNotEmpty == true
      ? modules.first.archiveName!
      : modules.first.name;

  DateTime get importedAt {
    return modules
        .map((source) => source.importedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  int get itemCount => modules.fold(0, (sum, source) => sum + source.itemCount);
  int get spellCount =>
      modules.fold(0, (sum, source) => sum + source.spellCount);
  int get raceCount => modules.fold(0, (sum, source) => sum + source.raceCount);
  int get classCount =>
      modules.fold(0, (sum, source) => sum + source.classCount);
  int get backgroundCount =>
      modules.fold(0, (sum, source) => sum + source.backgroundCount);
  int get featCount => modules.fold(0, (sum, source) => sum + source.featCount);
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.onDelete,
  });

  final CompendiumSource source;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.library_books_rounded,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(source.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(l10n.libraryStats(source.itemCount, source.spellCount)),
            Text(
              l10n.libraryImportedDate(
                DateFormat.yMMMd().format(source.importedAt),
              ),
              style: TextStyle(fontSize: 12, color: colorScheme.outline),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _ArchiveSourceCard extends StatelessWidget {
  const _ArchiveSourceCard({
    required this.archive,
    required this.onDeleteArchive,
    required this.onDeleteModule,
  });

  final _ArchiveSourceGroup archive;
  final VoidCallback onDeleteArchive;
  final ValueChanged<CompendiumSource> onDeleteModule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(
            Icons.folder_zip_rounded,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(archive.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          l10n.libraryArchiveStats(
            archive.modules.length,
            archive.itemCount,
            archive.spellCount,
            archive.raceCount,
            archive.classCount,
            archive.backgroundCount,
            archive.featCount,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDeleteArchive,
        ),
        children: [
          for (final module in archive.modules)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
              leading: Icon(
                Icons.description_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(
                module.moduleName ?? module.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((module.modulePath ?? '').isNotEmpty)
                    Text(
                      module.modulePath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    l10n.libraryStats(module.itemCount, module.spellCount),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDeleteModule(module),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImportProgressState {
  const _ImportProgressState({
    required this.icon,
    required this.title,
    required this.stage,
    this.detail,
    this.progress,
  });

  final IconData icon;
  final String title;
  final String stage;
  final String? detail;
  final double? progress;
}

class _FC5ImportProgressDialog extends StatelessWidget {
  const _FC5ImportProgressDialog({required this.progress});

  final ValueNotifier<_ImportProgressState> progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: colorScheme.surfaceContainerLow,
            elevation: 8,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
            surfaceTintColor: colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ValueListenableBuilder<_ImportProgressState>(
              valueListenable: progress,
              builder: (context, state, _) {
                return Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Color.alphaBlend(
                                colorScheme.secondary.withValues(alpha: 0.14),
                                colorScheme.surfaceContainerHighest,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              state.icon,
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state.stage,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (state.detail != null &&
                          state.detail!.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          state.detail!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      LinearProgressIndicator(value: state.progress),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ZipEntrySummary {
  int items = 0;
  int spells = 0;
  int races = 0;
  int classes = 0;
  int backgrounds = 0;
  int feats = 0;
  int monsters = 0;
}

class _ZipBatchImportSummary {
  final FC5ParseDiagnostics diagnostics = FC5ParseDiagnostics();

  int importedModules = 0;
  int skippedModules = 0;
  int failedModules = 0;
  int items = 0;
  int spells = 0;
  int races = 0;
  int classes = 0;
  int backgrounds = 0;
  int feats = 0;
  int duplicatesSkipped = 0;
  int unsupportedSkipped = 0;

  void addResult(CompendiumImportResult result) {
    importedModules += 1;
    final parsed = result.parseResult;
    items += parsed.items.length;
    spells += parsed.spells.length;
    races += parsed.races.length;
    classes += parsed.classes.length;
    backgrounds += parsed.backgrounds.length;
    feats += parsed.feats.length;
    duplicatesSkipped += result.skippedDuplicateCount;
    unsupportedSkipped += result.skippedUnsupportedCount;
    diagnostics.merge(result.diagnostics);
  }

  void addException(Object error, String context) {
    if (error is ImportServiceException) {
      diagnostics.merge(error.diagnostics);
      duplicatesSkipped += _diagnosticAggregateCount(
        error.diagnostics,
        'duplicates_skipped',
      );
      unsupportedSkipped += _diagnosticAggregateCount(
        error.diagnostics,
        'unsupported_nodes_skipped',
      );
      if (error.diagnostics.entries.any(
        (entry) => entry.code == 'duplicate_source',
      )) {
        duplicatesSkipped += 1;
      }
      if (error.diagnostics.hasErrors) {
        failedModules += 1;
      } else {
        skippedModules += 1;
      }
      return;
    }

    failedModules += 1;
    diagnostics.error(
      'zip_entry_import_failed',
      'Failed to import ZIP entry: $error',
      context: context,
    );
  }

  int _diagnosticAggregateCount(
    FC5ParseDiagnostics diagnostics,
    String code,
  ) {
    var total = 0;
    for (final entry
        in diagnostics.entries.where((entry) => entry.code == code)) {
      final raw = entry.context ?? entry.message;
      final match = RegExp(r'\d+').firstMatch(raw);
      if (match != null) {
        total += int.tryParse(match.group(0) ?? '') ?? 0;
      }
    }
    return total;
  }
}

class _ZipPreviewInfoCard extends StatelessWidget {
  const _ZipPreviewInfoCard({
    required this.text,
    required this.tone,
  });

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: 0.08),
          colorScheme.surfaceContainerHighest,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tone.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
      ),
    );
  }
}

class _ZipEntryTile extends StatelessWidget {
  const _ZipEntryTile({
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  final FC5CompendiumZipEntryPreview entry;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    final tone = enabled ? colorScheme.secondary : colorScheme.outline;
    final subtitle = entry.supportedCount > 0
        ? l10n.fc5ZipEntryStats(
            entry.supportedCount,
            entry.items,
            entry.spells,
            entry.races,
            entry.classes,
            entry.backgrounds,
            entry.feats,
            entry.monsters,
          )
        : l10n.fc5ZipEntryUnsupportedStats(entry.monsters);

    return Material(
      color: colorScheme.surfaceContainerHigh.withValues(
        alpha: enabled ? 0.92 : 0.5,
      ),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? () => onChanged?.call(!selected) : null,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Checkbox(
                  value: enabled ? selected : false,
                  onChanged: onChanged,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: enabled
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                    ),
                    if (entry.isCombinedCandidate) ...[
                      const SizedBox(height: 8),
                      _ZipEntryBadge(label: l10n.fc5ZipRecommendedBadge),
                    ] else if (!enabled) ...[
                      const SizedBox(height: 8),
                      _ZipEntryBadge(label: l10n.fc5ZipUnsupportedBadge),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tone.withValues(alpha: enabled ? 0.14 : 0.08),
                    colorScheme.surfaceContainerHighest,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  enabled ? Icons.description_outlined : Icons.block_rounded,
                  color: tone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZipEntryBadge extends StatelessWidget {
  const _ZipEntryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
