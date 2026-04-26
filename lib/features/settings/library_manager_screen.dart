import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qd_and_d/l10n/app_localizations.dart';
import '../../core/models/compendium_source.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/import_service.dart';
import '../../core/services/item_service.dart';
import '../../core/services/spell_service.dart';
import '../../core/services/character_data_service.dart';
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

          // Sort by date descending
          sources.sort((a, b) => b.importedAt.compareTo(a.importedAt));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.folder_zip,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                  title: Text(source.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(l10n.libraryStats(
                          source.itemCount, source.spellCount)),
                      Text(
                        l10n.libraryImportedDate(
                            DateFormat.yMMMd().format(source.importedAt)),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, source),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _importFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final importResult =
            await ImportService.importCompendiumFileDetailed(file);

        if (!context.mounted) return;
        Navigator.pop(context); // Close loader

        final parsed = importResult.parseResult;
        final message = importResult.warningCount > 0
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            action: importResult.warningCount > 0
                ? SnackBarAction(
                    label: l10n.importWarningsAction,
                    onPressed: () {
                      _showImportDiagnostics(
                        context,
                        importResult.diagnostics,
                      );
                    },
                  )
                : null,
          ),
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: diagnostics != null && !diagnostics.isEmpty
                ? SnackBarAction(
                    label: l10n.importWarningsAction,
                    onPressed: () {
                      _showImportDiagnostics(context, diagnostics);
                    },
                  )
                : null,
          ),
        );
      }
    }
  }

  void _showImportDiagnostics(
    BuildContext context,
    FC5ParseDiagnostics diagnostics,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
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
                                  l10n.importWarningsTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.importWarningsSubtitle(entries.length),
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
                            final tone = isError
                                ? colorScheme.error
                                : colorScheme.tertiary;
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
                                        : Icons.warning_amber_rounded,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.libraryDeleted)),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.errorDeletingLibrary(e.toString())),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
